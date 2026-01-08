//
//  GroupViewModel.swift
//  IoTCoreSample
//
//  ViewModel for managing groups (rooms) - fetches from API and handles selection
//

import Foundation
import Combine
import IotCoreIOS

@MainActor
class GroupViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var groups: [DeviceGroup] = []
    @Published var selectedGroup: DeviceGroup?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Computed Properties

    var hasSelectedGroup: Bool {
        selectedGroup != nil
    }

    var selectedGroupDisplayName: String {
        selectedGroup?.displayName ?? "No group selected"
    }

    /// Get groups filtered by location ID
    func groups(forLocationId locationId: String?) -> [DeviceGroup] {
        guard let locationId = locationId else { return groups }
        return groups.filter { $0.locationId == locationId }
    }

    // MARK: - API Operations

    /// Fetch all groups from API
    func fetchGroups() {
        guard let sdk = IoTAppCore.current else {
            errorMessage = "SDK not initialized"
            return
        }

        isLoading = true
        errorMessage = nil

        sdk.callApiGet("group/get", params: nil, headers: nil) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let data):
                    if let parsedGroups = DeviceGroup.parseFromAPIResponse(data) {
                        self.groups = parsedGroups
                    } else {
                        self.errorMessage = "Failed to parse groups response"
                    }

                case .failure(let error):
                    self.errorMessage = "Failed to fetch groups: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Selection

    func selectGroup(_ group: DeviceGroup?) {
        selectedGroup = group
    }

    func clearSelection() {
        selectedGroup = nil
    }
}
