//
//  LocationViewModel.swift
//  IoTCoreSample
//
//  ViewModel for managing user locations
//

import Foundation
import IotCoreIOS
import Combine

@MainActor
class LocationViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var locations: [Location] = []
    @Published var activeLocation: Location?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Computed Properties

    var activeLocationId: String? {
        IoTAppCore.current?.getAppLocation()
    }

    var hasActiveLocation: Bool {
        activeLocationId != nil
    }

    var activeLocationDisplayName: String {
        if let location = activeLocation {
            return location.displayName
        } else if let locationId = activeLocationId {
            // Location ID is set but location details not loaded
            return "ID: \(locationId.prefix(8))..."
        }
        return "Not Set"
    }

    // MARK: - Initialization

    init() {
        loadActiveLocation()
    }

    // MARK: - Public Methods

    /// Fetch locations from API
    func fetchLocations() {
        guard let sdk = IoTAppCore.current else {
            errorMessage = "SDK not initialized"
            return
        }

        guard sdk.isAuthenticated else {
            errorMessage = "Please login first"
            return
        }

        isLoading = true
        errorMessage = nil

        print("Fetching locations from API...")

        sdk.callApiGet("location/get", params: nil, headers: nil) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let data):
                    self.handleLocationResponse(data)

                case .failure(let error):
                    print("Failed to fetch locations: \(error)")
                    self.errorMessage = "Failed to fetch locations: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Set active location
    func setActiveLocation(_ location: Location) {
        guard let sdk = IoTAppCore.current else {
            errorMessage = "SDK not initialized"
            return
        }

        print("Setting active location: \(location.uuid) (\(location.displayName))")
        sdk.setAppLocation(locationId: location.uuid)
        activeLocation = location
        errorMessage = nil

        // Save to UserDefaults for persistence across app restarts
        saveActiveLocationDetails(location)
    }

    /// Clear active location
    func clearActiveLocation() {
        // Note: SDK doesn't have a clear method, but we can track locally
        activeLocation = nil
        UserDefaults.standard.removeObject(forKey: "activeLocationDetails")
        print("Active location cleared")
    }

    /// Load active location from SDK and local storage
    func loadActiveLocation() {
        guard let locationId = IoTAppCore.current?.getAppLocation() else {
            activeLocation = nil
            return
        }

        // Try to find the location in our loaded list
        if let location = locations.first(where: { $0.uuid == locationId }) {
            activeLocation = location
            return
        }

        // Try to load from UserDefaults
        if let savedLocation = loadActiveLocationDetails(),
           savedLocation.uuid == locationId {
            activeLocation = savedLocation
        }
    }

    /// Refresh all - fetch locations and update active location
    func refresh() {
        fetchLocations()
    }

    // MARK: - Private Methods

    private func handleLocationResponse(_ data: Data) {
        // Debug: print raw response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Location API response: \(jsonString.prefix(500))...")
        }

        guard let parsedLocations = Location.parseFromAPIResponse(data) else {
            errorMessage = "Failed to parse location data"
            return
        }

        print("Parsed \(parsedLocations.count) locations")
        locations = parsedLocations

        // Update active location if it's in the list
        if let activeId = activeLocationId,
           let location = parsedLocations.first(where: { $0.uuid == activeId }) {
            activeLocation = location
            saveActiveLocationDetails(location)
        }
    }

    private func saveActiveLocationDetails(_ location: Location) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(location) {
            UserDefaults.standard.set(data, forKey: "activeLocationDetails")
        }
    }

    private func loadActiveLocationDetails() -> Location? {
        guard let data = UserDefaults.standard.data(forKey: "activeLocationDetails") else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(Location.self, from: data)
    }
}
