//
//  CertificateTransferView.swift
//  IoTCoreSample
//
//  Certificate Transfer Tool - Send HTTPS/MQTT certificates to devices
//

import SwiftUI
import Combine
import CoreBluetooth
import IotCoreIOS

struct CertificateTransferView: View {
    @StateObject private var viewModel = CertificateTransferViewModel()
    @StateObject private var discoveryViewModel = DiscoveryViewModel()

    @State private var showingDeviceSelector = false
    @State private var selectedPeripheral: CBPeripheral?
    @State private var customCertificate = ""
    @State private var showingCertificateEditor = false

    var body: some View {
        List {
            // Info Section
            infoSection

            // Connection Section
            connectionSection

            // Certificate Selection Section
            certificateSelectionSection

            // Transfer Actions Section
            transferActionsSection

            // Results Section
            resultsSection
        }
        .navigationTitle("Certificate Transfer")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDeviceSelector) {
            deviceSelectorSheet
        }
        .sheet(isPresented: $showingCertificateEditor) {
            certificateEditorSheet
        }
        .overlay {
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)

                    if viewModel.transferProgress > 0 && viewModel.transferProgress < 100 {
                        VStack(spacing: 8) {
                            ProgressView(value: Double(viewModel.transferProgress), total: 100)
                                .frame(width: 200)
                            Text("Transferring: \(viewModel.transferProgress)%")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.4))
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.green)
                    Text("Certificate Transfer Tool")
                        .font(.headline)
                }

                Text("Transfer HTTPS or MQTT certificates to IoT devices via BLE. This is typically required for secure cloud communication setup.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        Section {
            if viewModel.isConnected {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connected")
                            .font(.headline)
                        if let mac = viewModel.deviceMacAddress {
                            Text(mac)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }

                Button {
                    viewModel.disconnect()
                    selectedPeripheral = nil
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Disconnect")
                    }
                    .foregroundColor(.red)
                }
            } else {
                Button {
                    showingDeviceSelector = true
                } label: {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Select Device")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }

                if let peripheral = selectedPeripheral {
                    HStack {
                        Text("Selected:")
                            .foregroundColor(.secondary)
                        Text(peripheral.name ?? "Unknown")
                    }
                }
            }
        } header: {
            Text("Device Connection")
        } footer: {
            Text("Connect to a BLE device to transfer certificates.")
                .font(.caption)
        }
    }

    // MARK: - Certificate Selection Section

    private var certificateSelectionSection: some View {
        Section {
            // Certificate Type Picker
            Picker("Certificate Type", selection: $viewModel.selectedCertificateType) {
                Text("HTTPS").tag(CertificateType.https)
                Text("MQTT").tag(CertificateType.mqtt)
            }
            .pickerStyle(.segmented)

            // Certificate Source
            Picker("Source", selection: $viewModel.selectedCertificateSource) {
                Text("Sample (Let's Encrypt)").tag(CertificateSource.sample)
                Text("Custom").tag(CertificateSource.custom)
            }

            if viewModel.selectedCertificateSource == .custom {
                Button {
                    showingCertificateEditor = true
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        Text(customCertificate.isEmpty ? "Enter Certificate" : "Edit Certificate")
                        Spacer()
                        if !customCertificate.isEmpty {
                            Text("\(customCertificate.count) bytes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Certificate Info
            HStack {
                Text("Size:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(viewModel.currentCertificateSize) bytes")
                    .font(.system(.body, design: .monospaced))
            }
        } header: {
            Text("Certificate")
        } footer: {
            Text("The sample certificate is a Let's Encrypt R10 intermediate certificate for testing purposes.")
                .font(.caption)
        }
    }

    // MARK: - Transfer Actions Section

    private var transferActionsSection: some View {
        Section {
            Button {
                if viewModel.selectedCertificateSource == .custom {
                    viewModel.transferCertificate(customCertificate)
                } else {
                    viewModel.transferSampleCertificate()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.up.doc.fill")
                    Text("Transfer Certificate")
                    Spacer()
                    if viewModel.lastTransferSuccessful {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .disabled(!viewModel.canTransfer || (viewModel.selectedCertificateSource == .custom && customCertificate.isEmpty))

            if viewModel.transferProgress > 0 && viewModel.transferProgress < 100 {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: Double(viewModel.transferProgress), total: 100)
                    Text("Progress: \(viewModel.transferProgress)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Transfer")
        } footer: {
            if !viewModel.isConnected {
                Text("Connect to a device first to enable certificate transfer.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        Section {
            if let error = viewModel.lastError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.vertical, 4)
            }

            if let result = viewModel.lastResult {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Result")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Copy") {
                            UIPasteboard.general.string = result
                        }
                        .font(.caption)
                    }

                    ScrollView {
                        Text(result)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                }
            }

            if viewModel.lastError != nil || viewModel.lastResult != nil {
                Button("Clear Results") {
                    viewModel.clearResults()
                }
                .foregroundColor(.orange)
            }
        } header: {
            Text("Results")
        }
    }

    // MARK: - Device Selector Sheet

    private var deviceSelectorSheet: some View {
        NavigationView {
            List {
                Section {
                    if discoveryViewModel.isScanning {
                        HStack {
                            ProgressView()
                            Text("Scanning...")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button {
                            discoveryViewModel.startScanning()
                        } label: {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Start Scanning")
                            }
                        }
                    }
                } header: {
                    Text("BLE Scanning")
                }

                Section {
                    if discoveryViewModel.discoveredDevices.isEmpty {
                        Text("No devices found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(discoveryViewModel.discoveredDevices, id: \.macAddr) { device in
                            Button {
                                selectDevice(device)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(device.macAddr ?? "Unknown")
                                        .font(.headline)

                                    HStack {
                                        if let productId = device.productId {
                                            Text("Product: \(productId)")
                                                .font(.caption)
                                        }

                                        Text("\(device.rssi) dBm")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Devices (\(discoveryViewModel.discoveredDevices.count))")
                }
            }
            .navigationTitle("Select Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        discoveryViewModel.stopScanning()
                        showingDeviceSelector = false
                    }
                }
            }
        }
    }

    // MARK: - Certificate Editor Sheet

    private var certificateEditorSheet: some View {
        NavigationView {
            VStack {
                TextEditor(text: $customCertificate)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding()

                Text("Paste your PEM-encoded certificate content here (without BEGIN/END markers).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Custom Certificate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingCertificateEditor = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingCertificateEditor = false
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func selectDevice(_ device: DiscoveredDevice) {
        selectedPeripheral = device.peripheral
        discoveryViewModel.stopScanning()
        showingDeviceSelector = false
        viewModel.connect(device: device.device)
    }
}

// MARK: - Supporting Types

enum CertificateType: String, CaseIterable {
    case https = "HTTPS"
    case mqtt = "MQTT"
}

enum CertificateSource: String, CaseIterable {
    case sample = "Sample"
    case custom = "Custom"
}

// MARK: - ViewModel

@MainActor
class CertificateTransferViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isConnected = false
    @Published var isLoading = false
    @Published var deviceMacAddress: String?

    @Published var selectedCertificateType: CertificateType = .https
    @Published var selectedCertificateSource: CertificateSource = .sample

    @Published var transferProgress: Int = 0
    @Published var lastTransferSuccessful = false

    @Published var lastError: String?
    @Published var lastResult: String?

    // MARK: - Private Properties

    private var configHandler: RGBIoTConfigWifiDeviceHandler?

    // Sample Let's Encrypt R10 Certificate
    private let sampleCertificate = """
        MIIFBTCCAu2gAwIBAgIQS6hSk/eaL6JzBkuoBI110DANBgkqhkiG9w0BAQsFADBP
        MQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJuZXQgU2VjdXJpdHkgUmVzZWFy
        Y2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBYMTAeFw0yNDAzMTMwMDAwMDBa
        Fw0yNzAzMTIyMzU5NTlaMDMxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBF
        bmNyeXB0MQwwCgYDVQQDEwNSMTAwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
        AoIBAQDPV+XmxFQS7bRH/sknWHZGUCiMHT6I3wWd1bUYKb3dtVq/+vbOo76vACFL
        YlpaPAEvxVgD9on/jhFD68G14BQHlo9vH9fnuoE5CXVlt8KvGFs3Jijno/QHK20a
        /6tYvJWuQP/py1fEtVt/eA0YYbwX51TGu0mRzW4Y0YCF7qZlNrx06rxQTOr8IfM4
        FpOUurDTazgGzRYSespSdcitdrLCnF2YRVxvYXvGLe48E1KGAdlX5jgc3421H5KR
        mudKHMxFqHJV8LDmowfs/acbZp4/SItxhHFYyTr6717yW0QrPHTnj7JHwQdqzZq3
        DZb3EoEmUVQK7GH29/Xi8orIlQ2NAgMBAAGjgfgwgfUwDgYDVR0PAQH/BAQDAgGG
        MB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDATASBgNVHRMBAf8ECDAGAQH/
        AgEAMB0GA1UdDgQWBBS7vMNHpeS8qcbDpHIMEI2iNeHI6DAfBgNVHSMEGDAWgBR5
        tFnme7bl5AFzgAiIyBpY9umbbjAyBggrBgEFBQcBAQQmMCQwIgYIKwYBBQUHMAKG
        Fmh0dHA6Ly94MS5pLmxlbmNyLm9yZy8wEwYDVR0gBAwwCjAIBgZngQwBAgEwJwYD
        VR0fBCAwHjAcoBqgGIYWaHR0cDovL3gxLmMubGVuY3Iub3JnLzANBgkqhkiG9w0B
        AQsFAAOCAgEAkrHnQTfreZ2B5s3iJeE6IOmQRJWjgVzPw139vaBw1bGWKCIL0vIo
        zwzn1OZDjCQiHcFCktEJr59L9MhwTyAWsVrdAfYf+B9haxQnsHKNY67u4s5Lzzfd
        u6PUzeetUK29v+PsPmI2cJkxp+iN3epi4hKu9ZzUPSwMqtCceb7qPVxEbpYxY1p9
        1n5PJKBLBX9eb9LU6l8zSxPWV7bK3lG4XaMJgnT9x3ies7msFtpKK5bDtotij/l0
        GaKeA97pb5uwD9KgWvaFXMIEt8jVTjLEvwRdvCn294GPDF08U8lAkIv7tghluaQh
        1QnlE4SEN4LOECj8dsIGJXpGUk3aU3KkJz9icKy+aUgA+2cP21uh6NcDIS3XyfaZ
        QjmDQ993ChII8SXWupQZVBiIpcWO4RqZk3lr7Bz5MUCwzDIA359e57SSq5CCkY0N
        4B6Vulk7LktfwrdGNVI5BsC9qqxSwSKgRJeZ9wygIaehbHFHFhcBaMDKpiZlBHyz
        rsnnlFXCb5s8HKn5LsUgGvB24L7sGNZP2CX7dhHov+YhD+jozLW2p9W4959Bz2Ei
        RmqDtmiXLnzqTpXbI+suyCsohKRg6Un0RC47+cpiVwHiXZAW+cn8eiNIjqbVgXLx
        KPpdzvvtTnOPlC7SQZSYmdunr3Bf9b77AiC/ZidstK36dRILKz7OA54=
        """

    // MARK: - Computed Properties

    var canTransfer: Bool {
        return isConnected && !isLoading
    }

    var currentCertificateSize: Int {
        return sampleCertificate.count
    }

    // MARK: - Connection Management

    func connect(device: RGBDiscoveredBLEDevice) {
        isLoading = true
        clearResults()

        configHandler = IoTAppCore.current?.configWifiDeviceHandler
        configHandler?.connect(device: device) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let (macAddress, _)):
                    self?.isConnected = true
                    self?.deviceMacAddress = macAddress
                    self?.lastResult = "Connected to device: \(macAddress ?? "Unknown")"

                case .failure(let error):
                    self?.isConnected = false
                    self?.lastError = "Connection failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func disconnect() {
        configHandler?.cancelConfig()
        isConnected = false
        deviceMacAddress = nil
        configHandler = nil
        clearResults()
    }

    // MARK: - Certificate Transfer

    func transferSampleCertificate() {
        transferCertificate(sampleCertificate)
    }

    func transferCertificate(_ certificate: String) {
        guard canTransfer else { return }

        isLoading = true
        transferProgress = 0
        lastTransferSuccessful = false
        clearResults()

        switch selectedCertificateType {
        case .https:
            sendHttpsCertificate(certificate)
        case .mqtt:
            sendMqttCertificate(certificate)
        }
    }

    private func sendHttpsCertificate(_ certificate: String) {
        configHandler?.sendHttpsCertificate(
            certificate,
            progress: { [weak self] current, total in
                DispatchQueue.main.async {
                    if total > 0 {
                        self?.transferProgress = (current * 100) / total
                    }
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.handleTransferResult(result, type: "HTTPS")
                }
            }
        )
    }

    private func sendMqttCertificate(_ certificate: String) {
        configHandler?.sendMqttCertificate(
            certificate,
            progress: { [weak self] current, total in
                DispatchQueue.main.async {
                    if total > 0 {
                        self?.transferProgress = (current * 100) / total
                    }
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.handleTransferResult(result, type: "MQTT")
                }
            }
        )
    }

    private func handleTransferResult(_ result: Result<Void, Error>, type: String) {
        switch result {
        case .success:
            transferProgress = 100
            lastTransferSuccessful = true
            lastResult = "\(type) certificate transferred successfully"

        case .failure(let error):
            transferProgress = 0
            lastTransferSuccessful = false
            lastError = "\(type) certificate transfer failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Results Management

    func clearResults() {
        lastError = nil
        lastResult = nil
        transferProgress = 0
        lastTransferSuccessful = false
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        CertificateTransferView()
    }
}
