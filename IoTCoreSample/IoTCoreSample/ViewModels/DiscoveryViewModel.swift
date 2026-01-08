//
//  DiscoveryViewModel.swift
//  IoTCoreSample
//
//  BLE Device Discovery ViewModel
//

import SwiftUI
import IotCoreIOS
import Combine
import CoreBluetooth

@MainActor
class DiscoveryViewModel: ObservableObject {

    // MARK: - Constants

    /// Maximum scan duration in seconds (auto-stop to save battery)
    static let maxScanDuration: TimeInterval = 60.0

    // MARK: - Published Properties

    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var scanDuration: TimeInterval = 0
    @Published var selectedFilter: DeviceTypeFilter = .all

    // MARK: - Private Properties

    private var scanTimer: Timer?
    private var scanStartTime: Date?
    private var autoStopTimer: Timer?

    // MARK: - Actions

    func startScanning() {
        guard !isScanning else { return }

        // Clear previous results
        discoveredDevices.removeAll()
        errorMessage = nil
        isScanning = true
        scanStartTime = Date()

        // Start scan timer (updates duration every 0.1s)
        scanTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.scanStartTime else { return }
            self.scanDuration = Date().timeIntervalSince(startTime)
        }

        // Start auto-stop timer (60 seconds to save battery)
        autoStopTimer = Timer.scheduledTimer(withTimeInterval: Self.maxScanDuration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.errorMessage = "Scan auto-stopped after \(Int(Self.maxScanDuration))s to save battery. Tap to scan again."
            self.stopScanning()
        }

        // Start BLE discovery
        IoTAppCore.current?.discoverySmartConfigHandler.discovery(
            onFoundWile: { [weak self] device in
                self?.handleFoundDevice(type: .wile, device: device)
            },
            onFoundMesh: { [weak self] device in
                self?.handleFoundDevice(type: .mesh, device: device)
            },
            onUnrecognized: { [weak self] device in
                self?.handleFoundDevice(type: .unknown, device: device)
            },
            onError: { [weak self] error in
                self?.errorMessage = (error as? IotCoreError)?.errorDescription ?? error.localizedDescription
                self?.stopScanning()
            }
        )
    }

    func stopScanning() {
        isScanning = false
        scanTimer?.invalidate()
        scanTimer = nil
        autoStopTimer?.invalidate()
        autoStopTimer = nil

        IoTAppCore.current?.discoverySmartConfigHandler.stopDiscovery()
    }

    func clearResults() {
        discoveredDevices.removeAll()
        scanDuration = 0
    }

    // MARK: - Private Methods

    private func handleFoundDevice(type: DeviceType, device: RGBDiscoveredBLEDevice) {
        let deviceId = device.macAddress ?? device.peripheral.identifier.uuidString

        // Check if device already exists
        if let index = discoveredDevices.firstIndex(where: { $0.id == deviceId }) {
            // Update existing device
            discoveredDevices[index].rssi = device.rssi ?? -100
            discoveredDevices[index].lastSeen = Date()
        } else {
            // Add new device
            let discoveredDevice = DiscoveredDevice(
                id: deviceId,
                type: type,
                device: device,  // Store complete SDK device
                rssi: device.rssi ?? -100,
                lastSeen: Date()
            )
            discoveredDevices.append(discoveredDevice)
        }

        // Sort by RSSI (strongest first)
        discoveredDevices.sort { $0.rssi > $1.rssi }
    }

    // MARK: - Computed Properties

    /// Filtered devices based on selected filter
    var filteredDevices: [DiscoveredDevice] {
        switch selectedFilter {
        case .all:
            return discoveredDevices
        case .wile:
            return discoveredDevices.filter { $0.type == .wile }
        case .mesh:
            return discoveredDevices.filter { $0.type == .mesh }
        case .unknown:
            return discoveredDevices.filter { $0.type == .unknown }
        }
    }

    var wileDevices: [DiscoveredDevice] {
        return discoveredDevices.filter { $0.type == .wile }
    }

    var meshDevices: [DiscoveredDevice] {
        return discoveredDevices.filter { $0.type == .mesh }
    }

    var unknownDevices: [DiscoveredDevice] {
        return discoveredDevices.filter { $0.type == .unknown }
    }

    /// Remaining scan time in seconds (0 if not scanning)
    var remainingScanTime: Int {
        guard isScanning else { return 0 }
        let remaining = Self.maxScanDuration - scanDuration
        return max(0, Int(remaining))
    }
}

// MARK: - Device Type Filter

enum DeviceTypeFilter: String, CaseIterable {
    case all = "All"
    case wile = "Wile"
    case mesh = "Mesh"
    case unknown = "Unrecognized"

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .wile: return "wifi"
        case .mesh: return "network"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Models

enum DeviceType: String {
    case wile = "Wile"
    case mesh = "Mesh"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .wile: return "wifi"
        case .mesh: return "network"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .wile: return .blue
        case .mesh: return .purple
        case .unknown: return .gray
        }
    }
}

struct DiscoveredDevice: Identifiable {
    let id: String
    let type: DeviceType
    let device: RGBDiscoveredBLEDevice  // Store original SDK device
    var rssi: Int
    var lastSeen: Date

    // Convenience accessors
    var macAddr: String? { device.macAddress }
    var productId: String? { device.productId }
    var categoryName: String? { device.deviceCategoryType.displayName }
    var advertisementData: Data? { device.advertisementData }
    var peripheral: CBPeripheral { device.peripheral }

    var displayName: String {
        return productId ?? macAddr ?? peripheral.name ?? "Unknown Device"
    }

    var signalStrength: String {
        if rssi > -50 {
            return "Excellent"
        } else if rssi > -70 {
            return "Good"
        } else if rssi > -85 {
            return "Fair"
        } else {
            return "Weak"
        }
    }

    var signalBars: Int {
        if rssi > -50 {
            return 4
        } else if rssi > -70 {
            return 3
        } else if rssi > -85 {
            return 2
        } else {
            return 1
        }
    }
}
