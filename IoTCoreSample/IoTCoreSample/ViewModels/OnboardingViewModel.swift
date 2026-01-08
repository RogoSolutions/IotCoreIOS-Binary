//
//  OnboardingViewModel.swift
//  IoTCoreSample
//
//  ViewModel for the Onboarding Wizard - manages step navigation and state
//

import SwiftUI
import IotCoreIOS
import Combine
import CoreBluetooth

// MARK: - Onboarding Step

enum OnboardingStep: Int, CaseIterable {
    case discovery = 1
    case selectDevice = 2
    case connect = 3
    case networkStatus = 4
    case wifiConfig = 5
    case cloudSync = 6

    var title: String {
        switch self {
        case .discovery: return "Discover Devices"
        case .selectDevice: return "Select Device"
        case .connect: return "Connect"
        case .networkStatus: return "Network Status"
        case .wifiConfig: return "WiFi Configuration"
        case .cloudSync: return "Cloud Sync"
        }
    }

    var subtitle: String {
        switch self {
        case .discovery: return "Scan for nearby BLE devices"
        case .selectDevice: return "Choose a device to configure"
        case .connect: return "Establish BLE connection"
        case .networkStatus: return "Check current network status (optional)"
        case .wifiConfig: return "Configure WiFi settings"
        case .cloudSync: return "Register device with cloud"
        }
    }

    var icon: String {
        switch self {
        case .discovery: return "antenna.radiowaves.left.and.right"
        case .selectDevice: return "checklist"
        case .connect: return "link"
        case .networkStatus: return "network"
        case .wifiConfig: return "wifi"
        case .cloudSync: return "cloud"
        }
    }

    static var totalSteps: Int {
        return Self.allCases.count
    }
}

// MARK: - Onboarding ViewModel

@MainActor
class OnboardingViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var currentStep: OnboardingStep = .discovery
    @Published var selectedDevice: DiscoveredDevice?
    @Published var isConnected = false
    @Published var errorMessage: String?

    // Connection state from config handler
    @Published var deviceMacAddress: String?
    @Published var hasNetworkStatus = false
    @Published var isWifiConnected = false
    @Published var syncProgress: Int = 0
    @Published var isLoading = false

    // Completed steps tracking
    @Published var completedSteps: Set<OnboardingStep> = []

    // WiFi configuration data
    @Published var scannedNetworks: [RGBIoTWifiInfo] = []
    @Published var selectedSSID: String = "Rogo_Nest"
    @Published var wifiPassword: String = "nao123456"
    @Published var deviceLabel: String = ""

    // MARK: - Private Properties

    private var handler: RGBIoTConfigWifiDeviceHandler? {
        return IoTAppCore.current?.configWifiDeviceHandler
    }

    // MARK: - Computed Properties

    var canGoBack: Bool {
        return currentStep.rawValue > 1
    }

    var canGoNext: Bool {
        switch currentStep {
        case .discovery:
            return true // Can always proceed to selection to view discovered devices
        case .selectDevice:
            return selectedDevice != nil
        case .connect:
            return isConnected
        case .networkStatus:
            return true // Network status is OPTIONAL - can always proceed to WiFi config
        case .wifiConfig:
            return isWifiConnected
        case .cloudSync:
            return completedSteps.contains(.cloudSync)
        }
    }

    var isLastStep: Bool {
        return currentStep == .cloudSync
    }

    var isFirstStep: Bool {
        return currentStep == .discovery
    }

    var nextButtonTitle: String {
        switch currentStep {
        case .discovery:
            return "Select Device"
        case .selectDevice:
            return "Connect"
        case .connect:
            return "Check Network"
        case .networkStatus:
            return "Configure WiFi"
        case .wifiConfig:
            return "Sync to Cloud"
        case .cloudSync:
            return "Finish"
        }
    }

    // MARK: - Navigation Actions

    func goToNextStep() {
        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            return
        }
        completedSteps.insert(currentStep)
        currentStep = nextStep
    }

    func goToPreviousStep() {
        guard let prevStep = OnboardingStep(rawValue: currentStep.rawValue - 1) else {
            return
        }
        currentStep = prevStep
    }

    func goToStep(_ step: OnboardingStep) {
        // Only allow going to completed steps or current step or next step
        if step.rawValue <= currentStep.rawValue || completedSteps.contains(OnboardingStep(rawValue: step.rawValue - 1) ?? .discovery) {
            currentStep = step
        }
    }

    // MARK: - Device Selection

    func selectDevice(_ device: DiscoveredDevice) {
        selectedDevice = device
        deviceLabel = device.displayName
    }

    func clearSelection() {
        selectedDevice = nil
        deviceLabel = ""
    }

    // MARK: - BLE Connection

    func connectToDevice() {
        guard let device = selectedDevice?.device else {
            errorMessage = "No device selected"
            return
        }

        guard let handler = handler else {
            errorMessage = "SDK not initialized"
            return
        }

        isLoading = true
        errorMessage = nil

        handler.connect(device: device) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let (macAddr, _)):
                    self.isConnected = true
                    self.deviceMacAddress = macAddr
                    self.completedSteps.insert(.connect)

                case .failure(let error):
                    self.errorMessage = "Connection failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func disconnect() {
        handler?.cancelConfig()
        isConnected = false
        deviceMacAddress = nil
        hasNetworkStatus = false
        isWifiConnected = false
        scannedNetworks = []
        syncProgress = 0
        completedSteps.remove(.connect)
        completedSteps.remove(.networkStatus)
        completedSteps.remove(.wifiConfig)
        completedSteps.remove(.cloudSync)
    }

    // MARK: - Network Status

    func checkNetworkStatus() {
        guard let handler = handler else {
            errorMessage = "SDK not initialized"
            return
        }

        guard isConnected else {
            errorMessage = "Device not connected"
            return
        }

        isLoading = true
        errorMessage = nil

        handler.getNwkConnectivity { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success:
                    self.hasNetworkStatus = true
                    self.completedSteps.insert(.networkStatus)

                case .failure(let error):
                    self.errorMessage = "Failed to get network status: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - WiFi Configuration

    func scanWifi(interfaceNo: Int = 0, duration: Int = 10) {
        guard let handler = handler else {
            errorMessage = "SDK not initialized"
            return
        }

        guard isConnected else {
            errorMessage = "Device not connected"
            return
        }

        isLoading = true
        errorMessage = nil
        scannedNetworks = []

        handler.scanWifi(infNo: interfaceNo, seconds: duration) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let networks):
                    self.scannedNetworks = networks

                case .failure(let error):
                    self.errorMessage = "WiFi scan failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func connectToWifi(interfaceNo: Int = 0) {
        guard let handler = handler else {
            errorMessage = "SDK not initialized"
            return
        }

        guard isConnected else {
            errorMessage = "Device not connected"
            return
        }

        guard !selectedSSID.isEmpty else {
            errorMessage = "Please select or enter a WiFi network"
            return
        }

        isLoading = true
        errorMessage = nil

        handler.connectWifi(infNo: interfaceNo, ssid: selectedSSID, pwd: wifiPassword) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success:
                    self.isWifiConnected = true
                    self.completedSteps.insert(.wifiConfig)

                case .failure(let error):
                    self.errorMessage = "WiFi connection failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Cloud Sync

    func syncToCloud() {
        // Default sync with no mesh config - not recommended
        syncToCloudWithMeshConfig(meshUuid: nil, meshNwkKeys: nil, meshAppKeys: nil, groupId: nil, groupElementId: nil)
    }

    /// Sync device to cloud with mesh configuration from active location and optional group
    /// - Parameters:
    ///   - meshUuid: BLE mesh UUID from location
    ///   - meshNwkKeys: BLE mesh network keys from location
    ///   - meshAppKeys: BLE mesh app keys from location
    ///   - groupId: Optional group UUID to assign device to a group/room
    ///   - groupElementId: Optional group elementId for device sync
    func syncToCloudWithMeshConfig(
        meshUuid: String?,
        meshNwkKeys: [String]?,
        meshAppKeys: [String]?,
        groupId: String?,
        groupElementId: Int?
    ) {
        guard let handler = handler else {
            errorMessage = "SDK not initialized"
            return
        }

        guard isConnected else {
            errorMessage = "Device not connected"
            return
        }

        guard !deviceLabel.isEmpty else {
            errorMessage = "Please enter a device label"
            return
        }

        isLoading = true
        errorMessage = nil
        syncProgress = 0

        print("Syncing to cloud with config:")
        print("  - meshUuid: \(meshUuid ?? "nil")")
        print("  - meshNwkKeys: \(meshNwkKeys?.count ?? 0) keys")
        print("  - meshAppKeys: \(meshAppKeys?.count ?? 0) keys")
        print("  - groupId: \(groupId ?? "nil")")
        print("  - groupElementId: \(groupElementId.map { String($0) } ?? "nil")")

        handler.syncDeviceToCloud(
            label: deviceLabel,
            desc: nil,
            groupId: groupId,
            groupAddr: groupElementId,
            devSubType: nil,
            elementInfos: nil,
            meshUuid: meshUuid,
            meshNwkKeys: meshNwkKeys,
            meshAppKeys: meshAppKeys
        ) { [weak self] status, error in
            Task { @MainActor in
                guard let self = self else { return }

                self.syncProgress = status

                if status == 100 {
                    self.isLoading = false
                    self.completedSteps.insert(.cloudSync)
                } else if status < 0 {
                    self.isLoading = false
                    self.errorMessage = "Cloud sync failed: \(error?.localizedDescription ?? "Unknown error")"
                }
            }
        }
    }

    // MARK: - Reset

    func resetOnboarding() {
        disconnect()
        currentStep = .discovery
        selectedDevice = nil
//        selectedSSID = ""
//        wifiPassword = ""
        deviceLabel = ""
        errorMessage = nil
        completedSteps.removeAll()
    }
}
