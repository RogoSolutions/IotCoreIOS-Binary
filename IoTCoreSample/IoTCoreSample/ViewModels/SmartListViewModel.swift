//
//  SmartListViewModel.swift
//  IoTCoreSample
//
//  Browse + delete Smart entities for the currently selected location.
//  See task: docs/06-PHASES/phase-10-smart-automation/wave-3/T-040-sample-app-smart-list-view.md
//

import Foundation
import Combine
import IotCoreIOS

@MainActor
final class SmartListViewModel: ObservableObject {

    // MARK: - Published State

    @Published var allSmarts: [SmartItem] = []
    @Published var filter: SmartType? = nil   // nil = All
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastInfo: String?

    // MARK: - Derived

    /// Smarts visible in the list — filtered by current location and the
    /// selected type filter.
    var filteredSmarts: [SmartItem] {
        let locId = currentLocationId
        return allSmarts.filter { item in
            // Location filter — only show Smart belonging to the active loc.
            if let locId = locId, !locId.isEmpty {
                guard item.locId == locId else { return false }
            }
            // Type filter
            if let filter = filter {
                guard item.smartType == filter else { return false }
            }
            return true
        }
    }

    /// Active location id from the SDK (set by Device Control tab).
    var currentLocationId: String? {
        let id = IoTAppCore.current?.getAppLocation()
        return (id?.isEmpty == false) ? id : nil
    }

    // MARK: - Fetch

    func fetch() {
        guard let sdk = IoTAppCore.current else {
            errorMessage = "SDK not initialized"
            return
        }
        isLoading = true
        errorMessage = nil
        lastInfo = nil

        sdk.callApiGet("smart/get", params: nil, headers: nil) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success(let data):
                    do {
                        let items = try JSONDecoder().decode([SmartItem].self, from: data)
                        self.allSmarts = items
                        self.lastInfo = "Fetched \(items.count) Smart(s)"
                    } catch {
                        self.errorMessage = "Decode failed: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    self.errorMessage = "smart/get failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Delete

    func delete(_ smart: SmartItem) {
        guard let sdk = IoTAppCore.current else {
            errorMessage = "SDK not initialized"
            return
        }
        isLoading = true
        errorMessage = nil
        lastInfo = nil

        // Best-effort MQTT remove announce when we have a numeric smid.
        if let smid = smart.smid {
            sdk.deviceCmdHandler.smartRemoveAnnounce(smid: smid)
        }

        sdk.callApiPost("smart/delete", params: ["uuid": smart.uuid], headers: nil) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success:
                    self.allSmarts.removeAll { $0.uuid == smart.uuid }
                    self.lastInfo = "Deleted \(smart.displayLabel)"
                case .failure(let error):
                    self.errorMessage = "smart/delete failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
