//
//  OperatorsTestingViewModel.swift
//  IoTCoreSample
//
//  ViewModel for testing SDK operators (BLE operations)
//  Allows testing all public SDK operations on a connected device.
//

import Foundation
import IotCoreIOS
import Combine

// MARK: - Transport Type

/// Transport type for device communication
/// Note: Currently only BLE is implemented. MQTT and Bonjour are placeholders for future.
enum OperatorTransportType: String, CaseIterable, Identifiable {
    case ble = "BLE"
    case mqtt = "MQTT"
    case bonjour = "Bonjour"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ble: return "Bluetooth LE"
        case .mqtt: return "MQTT"
        case .bonjour: return "Bonjour"
        }
    }

    var icon: String {
        switch self {
        case .ble: return "antenna.radiowaves.left.and.right"
        case .mqtt: return "network"
        case .bonjour: return "bonjour"
        }
    }

    /// Whether this transport is currently available
    var isAvailable: Bool {
        switch self {
        case .ble: return true
        case .mqtt: return false  // Future
        case .bonjour: return false  // Future
        }
    }
}

// MARK: - Operator Definition

/// Definition of a testable operator
struct TestableOperator: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let requiresConnection: Bool
    let requiresParameters: Bool

    init(
        id: String,
        name: String,
        description: String,
        icon: String,
        requiresConnection: Bool = true,
        requiresParameters: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.requiresConnection = requiresConnection
        self.requiresParameters = requiresParameters
    }
}

// MARK: - ViewModel

@MainActor
class OperatorsTestingViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedTransport: OperatorTransportType = .ble
    @Published var isLoading = false
    @Published var currentOperationId: String?
    @Published var lastResult: String?
    @Published var lastError: String?

    // WiFi parameters
    @Published var wifiInterfaceNo: String = "0"
    @Published var wifiScanDuration: String = "10"
    @Published var wifiSSID: String = ""
    @Published var wifiPassword: String = ""
    @Published var scannedNetworks: [RGBIoTWifiInfo] = []

    // Cloud info parameters
    @Published var cloudApiUrl: String = ""
    @Published var cloudUserId: String = ""
    @Published var cloudLocationId: String = ""
    @Published var cloudPartnerId: String = ""

    // MQTT host info parameters
    @Published var mqttUrl: String = ""
    @Published var mqttEndpoint: String = ""
    @Published var mqttPort: String = "8883"

    // MARK: - Device

    private let device: IoTDevice

    // MARK: - Operators List

    let operators: [TestableOperator] = [
        TestableOperator(
            id: "sendHttpsCertificate",
            name: "Send HTTPS Certificate",
            description: "Send HTTPS certificate to device for secure cloud communication",
            icon: "lock.shield"
        ),
        TestableOperator(
            id: "sendMqttCertificate",
            name: "Send MQTT Certificate",
            description: "Send MQTT certificate to device for secure MQTT communication",
            icon: "lock.shield.fill"
        ),
        TestableOperator(
            id: "sendCloudInfo",
            name: "Send Cloud Info",
            description: "Configure device cloud connection (apiUrl, userId, locationId, partnerId)",
            icon: "cloud",
            requiresParameters: true
        ),
        TestableOperator(
            id: "sendMqttHostInfo",
            name: "Send MQTT Host Info",
            description: "Configure MQTT broker connection (url, endpoint, port)",
            icon: "network",
            requiresParameters: true
        ),
        TestableOperator(
            id: "scanWifi",
            name: "Scan WiFi",
            description: "Scan for available WiFi networks",
            icon: "wifi.circle",
            requiresParameters: true
        ),
        TestableOperator(
            id: "connectWifi",
            name: "Connect WiFi",
            description: "Connect device to a WiFi network",
            icon: "wifi.circle.fill",
            requiresParameters: true
        ),
        TestableOperator(
            id: "getFirmwareVersion",
            name: "Get Firmware Version",
            description: "Get device firmware version",
            icon: "info.circle"
        ),
        TestableOperator(
            id: "getNwkConnectivity",
            name: "Get Network Connectivity",
            description: "Get device network connectivity status",
            icon: "network.badge.shield.half.filled"
        ),
        TestableOperator(
            id: "sendRequestIdentifyDevice",
            name: "Identify Device",
            description: "Request device to identify itself (blink LED)",
            icon: "lightbulb.fill"
        )
    ]

    // MARK: - Private Properties

    private var handler: RGBIoTConfigWifiDeviceHandler? {
        return IoTAppCore.current?.configWifiDeviceHandler
    }

    // MARK: - Initialization

    init(device: IoTDevice) {
        self.device = device

        // Pre-fill cloud info from SDK if available
        if let sdk = IoTAppCore.current {
            cloudLocationId = sdk.getAppLocation() ?? ""
        }
    }

    // MARK: - Operation Execution

    func executeOperator(_ operatorId: String) {
        guard selectedTransport.isAvailable else {
            showError("Transport \(selectedTransport.displayName) is not available yet")
            return
        }

        guard handler != nil else {
            showError("SDK not initialized or configWifiDeviceHandler unavailable")
            return
        }

        isLoading = true
        currentOperationId = operatorId
        lastError = nil
        lastResult = nil

        switch operatorId {
        case "sendHttpsCertificate":
            sendHttpsCertificate()
        case "sendMqttCertificate":
            sendMqttCertificate()
        case "sendCloudInfo":
            sendCloudInfo()
        case "sendMqttHostInfo":
            sendMqttHostInfo()
        case "scanWifi":
            scanWifi()
        case "connectWifi":
            connectWifi()
        case "getFirmwareVersion":
            getFirmwareVersion()
        case "getNwkConnectivity":
            getNwkConnectivity()
        case "sendRequestIdentifyDevice":
            sendRequestIdentifyDevice()
        default:
            isLoading = false
            currentOperationId = nil
            showError("Unknown operator: \(operatorId)")
        }
    }

    // MARK: - Operation Implementations

    private func sendHttpsCertificate() {
        guard let handler = handler else {
            finishWithError("Handler not available")
            return
        }

        let certificate = Self.sampleHttpsCertificate

        handler.sendHttpsCertificate(
            certificate,
            progress: { [weak self] current, total in
                Task { @MainActor in
                    self?.lastResult = "Sending HTTPS certificate: \(current)/\(total)"
                }
            },
            completion: { [weak self] result in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.isLoading = false
                    self.currentOperationId = nil

                    switch result {
                    case .success:
                        self.lastResult = "HTTPS Certificate sent successfully\nSize: \(certificate.count) bytes"
                    case .failure(let error):
                        self.finishWithError("Failed to send HTTPS certificate: \(error.localizedDescription)")
                    }
                }
            }
        )
    }

    private func sendMqttCertificate() {
        guard let handler = handler else {
            finishWithError("Handler not available")
            return
        }

        let certificate = Self.sampleMqttCertificate

        handler.sendMqttCertificate(
            certificate,
            progress: { [weak self] current, total in
                Task { @MainActor in
                    self?.lastResult = "Sending MQTT certificate: \(current)/\(total)"
                }
            },
            completion: { [weak self] result in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.isLoading = false
                    self.currentOperationId = nil

                    switch result {
                    case .success:
                        self.lastResult = "MQTT Certificate sent successfully\nSize: \(certificate.count) bytes"
                    case .failure(let error):
                        self.finishWithError("Failed to send MQTT certificate: \(error.localizedDescription)")
                    }
                }
            }
        )
    }

    private func sendCloudInfo() {
        guard let handler = handler else {
            finishWithError("Handler not available")
            return
        }

        guard !cloudApiUrl.isEmpty else {
            finishWithError("API URL is required")
            return
        }

        guard !cloudUserId.isEmpty else {
            finishWithError("User ID is required")
            return
        }

        guard !cloudLocationId.isEmpty else {
            finishWithError("Location ID is required")
            return
        }

        guard !cloudPartnerId.isEmpty else {
            finishWithError("Partner ID is required")
            return
        }

        handler.sendCloudInfo(
            apiUrl: cloudApiUrl,
            userId: cloudUserId,
            locationId: cloudLocationId,
            partnerId: cloudPartnerId
        ) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                self.currentOperationId = nil

                switch result {
                case .success:
                    self.lastResult = """
                    Cloud info sent successfully
                    API URL: \(self.cloudApiUrl)
                    User ID: \(self.cloudUserId)
                    Location ID: \(self.cloudLocationId)
                    Partner ID: \(self.cloudPartnerId)
                    """
                case .failure(let error):
                    self.finishWithError("Failed to send cloud info: \(error.localizedDescription)")
                }
            }
        }
    }

    private func sendMqttHostInfo() {
        // Note: sendMqttHostInfo is not exposed as a public API yet.
        // This would require adding it to the RGBIoTConfigWifiDeviceHandler protocol.
        // For now, show a placeholder message.
        finishWithError("sendMqttHostInfo is not yet exposed as a public API. It is used internally during syncDeviceToCloud.")
    }

    private func scanWifi() {
        guard let handler = handler else {
            finishWithError("Handler not available")
            return
        }

        let infNo = Int(wifiInterfaceNo) ?? 0
        let seconds = Int(wifiScanDuration) ?? 10

        handler.scanWifi(infNo: infNo, seconds: seconds) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                self.currentOperationId = nil

                switch result {
                case .success(let networks):
                    self.scannedNetworks = networks
                    var resultText = "WiFi Networks Found: \(networks.count)\n"
                    for (index, network) in networks.enumerated() {
                        resultText += "\n[\(index + 1)] \(network.ssid ?? "Unknown")"
                        resultText += "\n    RSSI: \(network.rssi ?? 0) dBm"
                        resultText += "\n    Channel: \(network.channel ?? 0)"
                    }
                    self.lastResult = resultText

                case .failure(let error):
                    self.finishWithError("Failed to scan WiFi: \(error.localizedDescription)")
                }
            }
        }
    }

    private func connectWifi() {
        guard let handler = handler else {
            finishWithError("Handler not available")
            return
        }

        guard !wifiSSID.isEmpty else {
            finishWithError("WiFi SSID is required")
            return
        }

        let infNo = Int(wifiInterfaceNo) ?? 0

        handler.connectWifi(infNo: infNo, ssid: wifiSSID, pwd: wifiPassword) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                self.currentOperationId = nil

                switch result {
                case .success:
                    self.lastResult = """
                    WiFi Connection Successful
                    SSID: \(self.wifiSSID)
                    Interface: \(infNo)
                    """
                case .failure(let error):
                    self.finishWithError("Failed to connect WiFi: \(error.localizedDescription)")
                }
            }
        }
    }

    private func getFirmwareVersion() {
        // Note: getFirmwareVersion is available on the handler but not exposed in the public protocol.
        // We need to access it through the concrete implementation or use a workaround.
        // For now, show a placeholder or attempt through the internal API.

        // Since getFirmwareVersion is not in the public RGBIoTConfigWifiDeviceHandler protocol,
        // we cannot call it here. Show a message indicating this.
        finishWithError("getFirmwareVersion is not exposed in the public API. It is used internally during syncDeviceToCloud.")
    }

    private func getNwkConnectivity() {
        guard let handler = handler else {
            finishWithError("Handler not available")
            return
        }

        handler.getNwkConnectivity { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                self.currentOperationId = nil

                switch result {
                case .success(let connectivity):
                    var resultText = "Network Connectivity:\n"
                    for (index, conn) in connectivity.enumerated() {
                        resultText += "\n[\(index)]:"
                        let wifiStatus = conn.isWiFiConnected ?? false
                        resultText += "\n  WiFi: \(wifiStatus ? "Connected" : "Disconnected")"
                        resultText += "\n  Cloud: \(conn.isCloudConnected ?? false ? "Connected" : "Disconnected")"
                        if let ssid = conn.wifiSSID {
                            resultText += "\n  SSID: \(ssid)"
                        }
                        if let rssi = conn.wifiSignalStrength {
                            resultText += "\n  Signal: \(rssi) dBm"
                        }
                        if let endpoint = conn.cloudEndpoint {
                            resultText += "\n  Cloud Endpoint: \(endpoint)"
                        }
                    }
                    self.lastResult = resultText

                case .failure(let error):
                    self.finishWithError("Failed to get connectivity: \(error.localizedDescription)")
                }
            }
        }
    }

    private func sendRequestIdentifyDevice() {
        guard let handler = handler else {
            finishWithError("Handler not available")
            return
        }

        handler.sendRequestIdentifyDevice { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                self.currentOperationId = nil

                switch result {
                case .success:
                    self.lastResult = "Device identify request sent successfully\nDevice should be blinking/identifying now"
                case .failure(let error):
                    self.finishWithError("Failed to send identify request: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func showError(_ message: String) {
        lastError = message
    }

    private func finishWithError(_ message: String) {
        isLoading = false
        currentOperationId = nil
        lastError = message
    }

    func clearResults() {
        lastResult = nil
        lastError = nil
        scannedNetworks = []
    }

    func selectNetwork(_ network: RGBIoTWifiInfo) {
        wifiSSID = network.ssid ?? ""
    }

    // MARK: - Sample Certificates

    /// Sample HTTPS certificate for testing (Let's Encrypt R10)
    static let sampleHttpsCertificate: String = """
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
    """

    /// Sample MQTT certificate for testing (same as HTTPS for demo)
    static let sampleMqttCertificate: String = sampleHttpsCertificate
}
