//
//  ConfigWifiDeviceTestViewModel.swift
//  IoTCoreSample
//
//  ViewModel for testing Config Wifi Device Handler APIs (BLE onboarding)
//

import Foundation
import CoreBluetooth
import IotCoreIOS
import Combine

enum ConfigStep: Int, CaseIterable {
    case bleConnect = 1
    case checkNetwork = 2
    case scanWifi = 3
    case connectWifi = 4
    case syncCloud = 5

    var title: String {
        switch self {
        case .bleConnect: return "1. BLE Connection"
        case .checkNetwork: return "2. Network Status"
        case .scanWifi: return "3. WiFi Scan"
        case .connectWifi: return "4. WiFi Connect"
        case .syncCloud: return "5. Cloud Sync"
        }
    }

    var icon: String {
        switch self {
        case .bleConnect: return "antenna.radiowaves.left.and.right"
        case .checkNetwork: return "network"
        case .scanWifi: return "wifi.circle"
        case .connectWifi: return "wifi.circle.fill"
        case .syncCloud: return "cloud.fill"
        }
    }
}

@MainActor
class ConfigWifiDeviceTestViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var lastResult: String?
    @Published var lastError: String?

    @Published var isConnected = false
    @Published var deviceMacAddress: String? = nil
    @Published var firmwareVersion: String? = nil
    @Published var scannedNetworks: [RGBIoTWifiInfo] = []
    @Published var hasNetworkStatus = false
    @Published var isWifiConnected = false

    @Published var syncProgress: Int = 0
    @Published var completedSteps: Set<ConfigStep> = []
    @Published var currentStep: ConfigStep?

    private var handler: RGBIoTConfigWifiDeviceHandler? {
        return IoTAppCore.current?.configWifiDeviceHandler
    }

    // MARK: - Connection

    func connect(device: RGBDiscoveredBLEDevice) {
        guard let handler = handler else {
            showError("SDK not initialized")
            return
        }

        isLoading = true
        currentStep = .bleConnect
        lastError = nil
        lastResult = nil

        print("📡 Connecting to device: \(device.name ?? "Unknown"), ProductId: \(device.productId ?? "N/A")")

        handler.connect(device: device) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                self.currentStep = nil

                switch result {
                case .success(let (macAddr, provisionStatus)):
                    self.isConnected = true
                    self.deviceMacAddress = macAddr
                    self.completedSteps.insert(.bleConnect)

                    var resultText = "✅ Connected to \(device.name ?? "device") successfully\n"
                    if let mac = macAddr {
                        resultText += "📍 MAC Address: \(mac)\n"
                    }
                    if let productId = device.productId {
                        resultText += "🏷️ Product ID: \(productId)\n"
                    }
                    resultText += "📊 Provision Status: \(provisionStatus == 0 ? "Unprovisioned" : "Provisioned")"

                    self.lastResult = resultText
                    print("✅ Connected successfully - MAC: \(macAddr ?? "N/A"), ProductId: \(device.productId ?? "N/A")")

                case .failure(let error):
                    self.handleError(error, commandName: "BLE Connection")
                }
            }
        }
    }

    func disconnect() {
        handler?.cancelConfig()
        isConnected = false
        deviceMacAddress = nil
        firmwareVersion = nil
        scannedNetworks = []
        hasNetworkStatus = false
        isWifiConnected = false
        completedSteps.removeAll()
        currentStep = nil
        lastResult = "Disconnected"
        print("📴 Disconnected")
    }

    // MARK: - Network Connectivity

    func getNetworkConnectivity() {
        guard let handler = handler else {
            showError("SDK not initialized")
            return
        }

        guard isConnected else {
            showError("Device not connected")
            return
        }

        isLoading = true
        currentStep = .checkNetwork
        lastError = nil
        lastResult = nil

        print("📡 Getting network connectivity...")

        handler.getNwkConnectivity { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                self.currentStep = nil

                switch result {
                case .success(let connectivity):
                    self.hasNetworkStatus = true
                    self.completedSteps.insert(.checkNetwork)

                    var resultText = "✅ Network Connectivity:\n"
                    for (index, conn) in connectivity.enumerated() {
                        resultText += "\n[\(index)]:\n"
                        let wifiStatus = conn.isWiFiConnected ?? false
                        resultText += "  WiFi: \(wifiStatus ? "✅ Connected" : "❌ Disconnected")\n"
                        resultText += "  Cloud: \(conn.isCloudConnected ?? false ? "✅ Connected" : "❌ Disconnected")\n"
                        if let ssid = conn.wifiSSID {
                            resultText += "  SSID: \(ssid)\n"
                        }
                        if let rssi = conn.wifiSignalStrength {
                            resultText += "  Signal: \(rssi) dBm\n"
                        }
                        if let endpoint = conn.cloudEndpoint {
                            resultText += "  Cloud: \(endpoint)\n"
                        }
                    }
                    self.lastResult = resultText
                    print("✅ Get connectivity success")

                case .failure(let error):
                    self.handleError(error, commandName: "Network Status Check")
                }
            }
        }
    }

    // MARK: - WiFi Scan

    func scanWifi(infNo: Int, seconds: Int) {
        guard let handler = handler else {
            showError("SDK not initialized")
            return
        }

        guard isConnected else {
            showError("Device not connected")
            return
        }

        isLoading = true
        currentStep = .scanWifi
        lastError = nil
        lastResult = nil
        scannedNetworks = []

        print("📡 Scanning WiFi (interface: \(infNo), duration: \(seconds)s)...")

        handler.scanWifi(infNo: infNo, seconds: seconds) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                self.currentStep = nil

                switch result {
                case .success(let networks):
                    self.scannedNetworks = networks
                    self.completedSteps.insert(.scanWifi)

                    var resultText = "✅ WiFi Networks Found: \(networks.count)\n"
                    for (index, network) in networks.enumerated() {
                        resultText += "\n[\(index + 1)] \(network.ssid ?? "Unknown")\n"
                        resultText += "  RSSI: \(network.rssi ?? 0) dBm\n"
                        resultText += "  Security: \(self.securityTypeString(network.security))\n"
                        resultText += "  Channel: \(network.channel ?? 0)\n"
                    }
                    self.lastResult = resultText
                    print("✅ WiFi scan success: \(networks.count) networks")

                case .failure(let error):
                    self.handleError(error, commandName: "WiFi Scan")
                }
            }
        }
    }

    // MARK: - WiFi Connect

    func connectWifi(infNo: Int, ssid: String, password: String) {
        guard let handler = handler else {
            showError("SDK not initialized")
            return
        }

        guard isConnected else {
            showError("Device not connected")
            return
        }

        guard !ssid.isEmpty else {
            showError("SSID is required")
            return
        }

        isLoading = true
        currentStep = .connectWifi
        lastError = nil
        lastResult = nil

        print("📡 Connecting to WiFi: \(ssid)")

        handler.connectWifi(infNo: infNo, ssid: ssid, pwd: password) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                self.currentStep = nil

                switch result {
                case .success:
                    self.isWifiConnected = true
                    self.completedSteps.insert(.connectWifi)
                    self.lastResult = """
                    ✅ WiFi Connection Success
                    SSID: \(ssid)
                    Device is now connected to WiFi
                    """
                    print("✅ WiFi connect success")

                case .failure(let error):
                    self.handleError(error, commandName: "WiFi Connection")
                }
            }
        }
    }

    // MARK: - Sync to Cloud

    func syncDeviceToCloud(label: String, desc: String?) {
        guard let handler = handler else {
            showError("SDK not initialized")
            return
        }

        guard isConnected else {
            showError("Device not connected")
            return
        }

        guard !label.isEmpty else {
            showError("Device label is required")
            return
        }

        isLoading = true
        currentStep = .syncCloud
        lastError = nil
        lastResult = nil
        syncProgress = 0

        print("📡 Syncing device to cloud: \(label)")

        handler.syncDeviceToCloud(
            label: label,
            desc: desc,
            groupId: nil,
            groupAddr: nil,
            devSubType: nil,
            elementInfos: nil,
            meshUuid: "fadb7d50-55ad-4cb9-a246-7a25a933869d",
            meshNwkKeys: [
                "e46e6bce-2fbb-4dbd-bed6-d2d469f2e127"
              ],
            meshAppKeys: [
                "bdc60a61-b9a2-41dd-b8d2-d645575f118d",
                "dfccc1d3-7b7e-46d9-85eb-034999c3d49c",
                "da82211a-0014-477c-8631-059aac6fc6be",
                "36920009-2dc4-48e6-bfb9-5d264a2c9aa1",
                "5119462c-8977-45ec-ae35-ce534da2c1c5"
              ]
        ) { [weak self] status, error in
            Task { @MainActor in
                guard let self = self else { return }

                self.syncProgress = status

                if status == 100 {
                    // Success
                    self.isLoading = false
                    self.currentStep = nil
                    self.completedSteps.insert(.syncCloud)
                    self.lastResult = """
                    ✅ Device Synced Successfully
                    Label: \(label)
                    Status: Complete (100%)
                    🎉 Onboarding Complete!
                    """
                    print("✅ Device sync complete")

                } else if status < 0 {
                    // Error
                    self.isLoading = false
                    self.currentStep = nil

                    let errorMessage = error?.localizedDescription ?? "Unknown error"
                    self.showError("Device sync failed: \(errorMessage)")
                    print("❌ Device sync failed: \(errorMessage)")

                } else {
                    // Progress update
                    print("⏳ Sync progress: \(status)%")
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func handleError(_ error: Error, commandName: String) {
        print("❌ \(commandName) error: \(error.localizedDescription)")
        showError("\(commandName) failed: \(error.localizedDescription)")
    }

    private func showError(_ message: String) {
        lastError = message
    }

    private func securityTypeString(_ security: RGBWiFiSecurityType?) -> String {
        guard let security = security else { return "Unknown" }
        switch security {
        case .WIFI_AUTH_OPEN:
            return "Open"
        case .WIFI_AUTH_WEP:
            return "WEP"
        case .WIFI_AUTH_WPA_PSK:
            return "WPA-PSK"
        case .WIFI_AUTH_WPA2_PSK:
            return "WPA2-PSK"
        case .WIFI_AUTH_WPA_WPA2_PSK:
            return "WPA/WPA2-PSK"
        case .WIFI_AUTH_WPA2_ENTERPRISE:
            return "WPA2-Enterprise"
        case .WIFI_AUTH_WPA3_PSK:
            return "WPA3-PSK"
        case .WIFI_AUTH_WPA2_WPA3_PSK:
            return "WPA2/WPA3-PSK"
        case .WIFI_AUTH_WAPI_PSK:
            return "WAPI-PSK"
        case .WIFI_AUTH_MAX:
            return "MAX"
        @unknown default:
            return "Unknow"
        }
    }

    func clearResults() {
        lastResult = nil
        lastError = nil
    }

    // MARK: - Device Operations

    /// Request device to identify itself (e.g., blink LED)
    func requestDeviceIdentify() {
        guard let handler = handler else {
            showError("SDK not initialized")
            return
        }

        guard isConnected else {
            showError("Device not connected")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil

        print("📡 Requesting device to identify...")

        handler.sendRequestIdentifyDevice { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success:
                    self.lastResult = """
                    ✅ Device Identify Requested
                    Device should be blinking/identifying now
                    """
                    print("✅ Device identify request sent")

                case .failure(let error):
                    self.handleError(error, commandName: "Device Identify")
                }
            }
        }
    }

    /// Send HTTPS certificate to device
    func sendHttpsCertificate(_ certificate: String) {
        guard let handler = handler else {
            showError("SDK not initialized")
            return
        }

        guard isConnected else {
            showError("Device not connected")
            return
        }

        guard !certificate.isEmpty else {
            showError("Certificate is empty")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil

        print("📡 Sending HTTPS certificate (\(certificate.count) bytes)...")

        handler.sendHttpsCertificate(
            certificate,
            progress: { [weak self] current, total in
                Task { @MainActor in
                    self?.lastResult = "⏳ Sending HTTPS cert: \(current)/\(total)"
                }
            },
            completion: { [weak self] result in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.isLoading = false

                    switch result {
                    case .success:
                        self.lastResult = """
                        ✅ HTTPS Certificate Sent
                        Size: \(certificate.count) bytes
                        Device received certificate successfully
                        """
                        print("✅ HTTPS certificate sent successfully")

                    case .failure(let error):
                        self.handleError(error, commandName: "Send HTTPS Certificate")
                    }
                }
            }
        )
    }

    /// Send MQTT certificate to device
    func sendMqttCertificate(_ certificate: String) {
        guard let handler = handler else {
            showError("SDK not initialized")
            return
        }

        guard isConnected else {
            showError("Device not connected")
            return
        }

        guard !certificate.isEmpty else {
            showError("Certificate is empty")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil

        print("📡 Sending MQTT certificate (\(certificate.count) bytes)...")

        handler.sendMqttCertificate(
            certificate,
            progress: { [weak self] current, total in
                Task { @MainActor in
                    self?.lastResult = "⏳ Sending MQTT cert: \(current)/\(total)"
                }
            },
            completion: { [weak self] result in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.isLoading = false

                    switch result {
                    case .success:
                        self.lastResult = """
                        ✅ MQTT Certificate Sent
                        Size: \(certificate.count) bytes
                        Device received certificate successfully
                        """
                        print("✅ MQTT certificate sent successfully")

                    case .failure(let error):
                        self.handleError(error, commandName: "Send MQTT Certificate")
                    }
                }
            }
        )
    }
}
