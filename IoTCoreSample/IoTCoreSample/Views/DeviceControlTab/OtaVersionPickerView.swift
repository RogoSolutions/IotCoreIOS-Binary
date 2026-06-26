//
//  OtaVersionPickerView.swift
//  IoTCoreSample
//
//  Sample-app UI for the OTA "pick version from cloud" flow.
//
//  Instead of pasting an OTA URL by hand, the PO can:
//    1. Let the app read the device's CURRENT software version
//       (checkDeviceSoftwareVersion) and derive the `revision`.
//    2. Fetch the list of cloud builds (GET /v1/version/check/{modelId}/{revision}).
//    3. Pick a build (development / release), highlighting builds NEWER than
//       the device's current version.
//    4. Resolve the firmware download URL (GET /v1/version/ota/.../{type}/{version})
//       and send `updateDeviceSoftware`.
//
//  All cloud calls go through the generic `callApiGet` primitive. JSON parsing
//  and numeric comparisons live in `OtaVersionHelper` (pure, unit-tested).
//
//  This view does NOT touch the core SDK source — it only consumes public SDK
//  APIs already exposed via `IoTAppCore.current`.
//

import SwiftUI
import Combine
import IotCoreIOS

// MARK: - Flow state

@MainActor
final class OtaVersionPickerViewModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case loadingCurrentVersion
        case loadingVersionList
        case ready          // list loaded, waiting for selection
        case resolvingPath  // selected, fetching /version/ota
        case sendingOta     // updateDeviceSoftware in flight
        case done
    }

    @Published var phase: Phase = .idle
    @Published var currentVersion: String? = nil
    @Published var revision: String? = nil
    @Published var versions: [OtaVersionItem] = []
    @Published var errorMessage: String? = nil
    /// Resolved firmware download URL (shown to the PO before sending OTA).
    @Published var resolvedPath: String? = nil
    /// Final OTA ack / result message.
    @Published var otaResult: String? = nil
    /// When the device version can't be read, the PO may enter a revision by hand.
    @Published var manualRevision: String = ""

    let device: IoTDevice

    private var sdk: (any RGBIotCore)? { IoTAppCore.current }
    private var modelId: String { device.productId ?? "" }

    init(device: IoTDevice) {
        self.device = device
    }

    var isBusy: Bool {
        switch phase {
        case .loadingCurrentVersion, .loadingVersionList, .resolvingPath, .sendingOta:
            return true
        default:
            return false
        }
    }

    // MARK: - Step 1: current version -> revision -> version list

    func start() {
        errorMessage = nil
        otaResult = nil
        resolvedPath = nil
        versions = []

        guard sdk != nil else {
            fail("SDK not initialized")
            return
        }
        guard !modelId.isEmpty else {
            fail("Device has no productId (modelId) — cannot query cloud versions.")
            return
        }

        phase = .loadingCurrentVersion
        loadCurrentVersion()
    }

    private func loadCurrentVersion() {
        guard let sdk = sdk else { fail("SDK not initialized"); return }

        sdk.deviceCmdHandler.checkDeviceSoftwareVersion(devId: device.id) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success(let info):
                    self.currentVersion = info.softwareVersion
                    if let rev = OtaVersionHelper.deriveRevision(fromVersion: info.softwareVersion) {
                        self.revision = rev
                        self.loadVersionList(revision: rev)
                    } else {
                        // Couldn't derive a revision — let PO enter one manually.
                        self.phase = .idle
                        self.errorMessage = "Could not derive revision from current version \"\(info.softwareVersion)\". Enter a revision manually below."
                    }
                case .failure(let errorCode):
                    // Device may be offline / unreachable. Offer manual revision entry.
                    self.phase = .idle
                    self.errorMessage = "Failed to read device version (code \(errorCode)). Enter a revision manually below."
                }
            }
        }
    }

    /// Used when the device version can't be read and PO types a revision.
    func loadVersionListWithManualRevision() {
        let rev = manualRevision.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rev.isEmpty else {
            fail("Enter a revision first.")
            return
        }
        errorMessage = nil
        revision = rev
        loadVersionList(revision: rev)
    }

    private func loadVersionList(revision: String) {
        guard let sdk = sdk else { fail("SDK not initialized"); return }
        guard !modelId.isEmpty else { fail("Device has no productId (modelId)."); return }

        phase = .loadingVersionList
        let path = OtaVersionHelper.versionCheckPath(modelId: modelId, revision: revision)

        sdk.callApiGet(path, urlParam: nil, headers: nil, completion: ApiResultClosureAdapter { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success(let json):
                    do {
                        let items = try OtaVersionHelper.parseVersionList(fromJson: json)
                        if items.isEmpty {
                            self.phase = .ready
                            self.versions = []
                            self.errorMessage = "No firmware builds found for modelId \(self.modelId) / revision \(revision)."
                        } else {
                            // Newest first for convenience.
                            self.versions = items.sorted {
                                OtaVersionHelper.compareVersions($0.version, $1.version) == .orderedDescending
                            }
                            self.phase = .ready
                        }
                    } catch {
                        self.failParse(error)
                    }
                case .failure(let apiError):
                    self.fail("version/check failed (code \(apiError.errorCode)): \(apiError.message)")
                }
            }
        })
    }

    // MARK: - Step 2: resolve path -> send OTA

    func selectAndSend(_ item: OtaVersionItem,
                       forceHttpNonSecure: Bool) {
        guard let sdk = sdk else { fail("SDK not initialized"); return }
        guard let revision = revision else { fail("Missing revision."); return }
        guard !modelId.isEmpty else { fail("Device has no productId (modelId)."); return }

        errorMessage = nil
        resolvedPath = nil
        otaResult = nil
        phase = .resolvingPath

        let path = OtaVersionHelper.versionOtaPath(
            modelId: modelId,
            revision: revision,
            type: item.type,
            version: item.version
        )

        sdk.callApiGet(path, urlParam: nil, headers: nil, completion: ApiResultClosureAdapter { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success(let json):
                    do {
                        let otaUrl = try OtaVersionHelper.parseOtaPath(fromJson: json)
                        self.resolvedPath = otaUrl
                        self.sendOta(urlOta: otaUrl,
                                     version: item.version,
                                     forceHttpNonSecure: forceHttpNonSecure)
                    } catch {
                        self.failParse(error)
                    }
                case .failure(let apiError):
                    self.fail("version/ota failed (code \(apiError.errorCode)): \(apiError.message)")
                }
            }
        })
    }

    private func sendOta(urlOta: String, version: String, forceHttpNonSecure: Bool) {
        guard let sdk = sdk else { fail("SDK not initialized"); return }

        phase = .sendingOta
        let versionCode = OtaVersionHelper.versionCode(fromVersion: version)

        sdk.deviceCmdHandler.updateDeviceSoftware(
            devId: device.id,
            urlOta: urlOta,
            versionCode: versionCode,
            forceHttpNonSecure: forceHttpNonSecure,
            completion: AckClosureAdapter { [weak self] result in
                Task { @MainActor in
                    guard let self = self else { return }
                    switch result {
                    case .success(let ackStatus):
                        self.phase = .done
                        self.otaResult = "OTA update command sent for v\(version) (ack=\(ackStatus))"
                    case .failure(let errorCode):
                        self.fail("updateDeviceSoftware failed (code \(errorCode)).")
                    }
                }
            }
        )
    }

    // MARK: - Helpers

    private func fail(_ message: String) {
        phase = .idle
        errorMessage = message
    }

    private func failParse(_ error: Error) {
        if let otaError = error as? OtaVersionError {
            fail(otaError.localizedMessage)
        } else {
            fail("Unexpected error: \(error.localizedDescription)")
        }
    }
}

// MARK: - View

struct OtaVersionPickerView: View {
    @StateObject private var viewModel: OtaVersionPickerViewModel
    @ObservedObject private var otaStore = OtaProgressStore.shared
    @Environment(\.presentationMode) private var presentationMode

    @State private var forceHttpNonSecure = false

    init(device: IoTDevice) {
        _viewModel = StateObject(wrappedValue: OtaVersionPickerViewModel(device: device))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    deviceInfoCard
                    statusCard

                    if !viewModel.versions.isEmpty {
                        versionListSection
                    }

                    if viewModel.phase == .idle && viewModel.versions.isEmpty {
                        manualRevisionSection
                    }

                    if let path = viewModel.resolvedPath {
                        resolvedPathCard(path)
                    }

                    if let result = viewModel.otaResult {
                        resultCard(result)
                    }

                    // Live OTA progress pushed by the device (NOTIFY 0xFE).
                    if let event = liveOtaEvent {
                        liveProgressCard(event)
                    }

                    if let error = viewModel.errorMessage {
                        errorCard(error)
                    }
                }
                .padding()
            }
            .navigationTitle("OTA From Cloud")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isBusy { ProgressView().scaleEffect(0.8) }
                }
            }
            .onAppear {
                if viewModel.phase == .idle && viewModel.versions.isEmpty {
                    viewModel.start()
                }
            }
        }
    }

    // MARK: - Sections

    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.device.displayName)
                .font(.headline)
            labeledRow("modelId", viewModel.device.productId ?? "—")
            labeledRow("Current version", viewModel.currentVersion ?? "—")
            labeledRow("Revision", viewModel.revision ?? "—")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
    }

    @ViewBuilder
    private var statusCard: some View {
        let label: String? = {
            switch viewModel.phase {
            case .loadingCurrentVersion: return "Reading device version…"
            case .loadingVersionList: return "Fetching cloud builds…"
            case .resolvingPath: return "Resolving firmware URL…"
            case .sendingOta: return "Sending OTA command…"
            default: return nil
            }
        }()
        if let label = label {
            HStack(spacing: 8) {
                ProgressView()
                Text(label).font(.subheadline).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var versionListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Available builds")
                    .font(.headline)
                Spacer()
                Toggle("Force HTTP", isOn: $forceHttpNonSecure)
                    .labelsHidden()
                Text("Force HTTP").font(.caption2).foregroundColor(.secondary)
            }

            ForEach(viewModel.versions) { item in
                versionRow(item)
            }

            Text("Tap a build to fetch its firmware URL and send the OTA command. Builds newer than the device's current version are highlighted.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
    }

    private func versionRow(_ item: OtaVersionItem) -> some View {
        let isNewer = OtaVersionHelper.isNewer(item.version, than: viewModel.currentVersion ?? "")
        return Button {
            viewModel.selectAndSend(item, forceHttpNonSecure: forceHttpNonSecure)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("v\(item.version)")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.primary)
                        typeBadge(item)
                        if isNewer {
                            Text("NEWER")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                    }
                    if !item.changeLog.isEmpty {
                        Text(item.changeLog)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isNewer ? Color.green.opacity(0.08) : Color(UIColor.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isNewer ? Color.green.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isBusy)
    }

    private func typeBadge(_ item: OtaVersionItem) -> some View {
        let color: Color = item.isRelease ? .blue : (item.isDevelopment ? .orange : .gray)
        return Text(item.type.isEmpty ? "unknown" : item.type)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    private var manualRevisionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Manual revision")
                .font(.headline)
            Text("If the device version can't be read, enter a revision (the last component of the version, e.g. \"1\") to query the cloud.")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                TextField("revision (e.g. 1)", text: $viewModel.manualRevision)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                Button("Fetch") {
                    viewModel.loadVersionListWithManualRevision()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBusy)
            }
            Button {
                viewModel.start()
            } label: {
                Label("Retry reading device version", systemImage: "arrow.clockwise")
                    .font(.subheadline)
            }
            .disabled(viewModel.isBusy)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
    }

    /// Most relevant live OTA event: prefer one matching this device id, else
    /// fall back to the newest global event (device sender id may differ in
    /// format from `device.id`, so we still surface activity).
    private var liveOtaEvent: OtaProgressEvent? {
        otaStore.latest(for: viewModel.device.id) ?? otaStore.log.first
    }

    @ViewBuilder
    private func liveProgressCard(_ event: OtaProgressEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.blue)
                Text("Live OTA progress")
                    .font(.subheadline.weight(.semibold))
            }
            switch event.kind {
            case .progress(let status, let percent):
                ProgressView(value: Double(min(max(percent, 0), 100)), total: 100)
                Text("\(percent)% • status \(status) • device \(event.deviceId)")
                    .font(.caption).foregroundColor(.secondary)
            case .success(let versionCode):
                let v = versionCode.map { String($0) }.joined(separator: ".")
                Text("Success\(versionCode.isEmpty ? "" : " • v\(v)") • device \(event.deviceId)")
                    .font(.caption).foregroundColor(.green)
            case .failure(let versionCode, let errorCode):
                let v = versionCode.map { String($0) }.joined(separator: ".")
                Text("Failed (err \(errorCode))\(versionCode.isEmpty ? "" : " • v\(v)") • device \(event.deviceId)")
                    .font(.caption).foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.08))
        .cornerRadius(10)
    }

    private func resolvedPathCard(_ path: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Firmware URL")
                .font(.subheadline.weight(.semibold))
            Text(path)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.purple.opacity(0.08))
        .cornerRadius(10)
    }

    private func resultCard(_ result: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            Text(result).font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
    }

    private func errorCard(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text(error).font(.subheadline).foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }

    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption.monospaced()).foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }
}
