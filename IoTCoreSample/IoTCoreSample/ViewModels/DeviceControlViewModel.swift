//
//  DeviceControlViewModel.swift
//  IoTCoreSample
//
//  ViewModel for Device Control Tab - manages device list and control operations
//

import Foundation
import IotCoreIOS
import Combine

// MARK: - Device Models (from PO specification)

/// Element info for device elements
struct ROElementInfo: Codable {
    let attrs: [Int]?
    let devType: Int?
    let label: String?
    let setting: [Int]?

    enum CodingKeys: String, CodingKey {
        case attrs
        case devType = "deviceType"
        case label
        case setting
    }
}

/// IoT Device model - matches API response structure
/// Note: This model is for Sample App parsing. SDK may have its own internal model.
struct IoTDevice: Decodable, Identifiable {
    // MARK: - Public Properties
    let mac: String?
    let label: String?
    let desc: String?
    let productId: String?
    let protocolCtl: Int?
    let firmCode: Int?
    let firmVer: String?
    let userId: String?
    let locationId: String?
    let uuid: String?
    let groupId: String?
    let elementIds: [Int]?
    let fav: Bool?

    // MARK: - Internal Properties
    let nwkAddr: String?
    let rootUuid: String?
    let srcAddr: Int?
    let partnerId: String?
    let elementInfos: [String: ROElementInfo]?
    let features: [Int]?
    let productInfos: [Int]?
    let cdev: Int?
    let endpoint: String?
    let eid: Int?
    let link: Int?
    let createdAt: String?
    let updatedAt: String?
    let extraInfo: [String: JSONValue]?

    // MARK: - Identifiable
    var id: String {
        // Use uuid as primary identifier, fallback to mac
        return uuid ?? mac ?? "unknown"
    }

    // MARK: - Display Helpers
    var displayName: String {
        return label ?? mac ?? "Unknown Device"
    }

    var displayIcon: String {
        // Use productInfos or label to determine icon
        if let label = label?.lowercased() {
            if label.contains("công tắc") || label.contains("switch") {
                return "switch.2"
            } else if label.contains("ổ cắm") || label.contains("plug") || label.contains("socket") {
                return "powerplug.fill"
            } else if label.contains("đèn") || label.contains("light") || label.contains("bulb") {
                return "lightbulb.fill"
            } else if label.contains("cảm biến") || label.contains("sensor") {
                return "sensor.fill"
            }
        }
        return "lightbulb.fill"
    }
}

/// Generic JSON value for extraInfo parsing
enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode JSONValue")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - ViewModel

@MainActor
class DeviceControlViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var devices: [IoTDevice] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDevice: IoTDevice?

    // Detail view state
    @Published var isLoadingState = false
    @Published var deviceState: RGBDeviceState?
    @Published var stateDescription: String = ""

    // Control inputs
    @Published var controlElements: String = "0"
    @Published var controlAttrValue: String = "1,255,255,255"

    // Operation result
    @Published var lastOperationResult: String?
    @Published var lastOperationError: String?

    // MARK: - Device List Operations

    func fetchDevices() {
        guard let sdk = IoTAppCore.current else {
            errorMessage = "SDK not initialized"
            return
        }

        isLoading = true
        errorMessage = nil

        sdk.callApiGetUserDevices { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let data):
                    self.parseDevicesResponse(data)

                case .failure(let error):
                    self.errorMessage = "Failed to fetch devices: \(error.localizedDescription)"
                }
            }
        }
    }

    private func parseDevicesResponse(_ data: Data) {
        do {
            // API response is a direct array: [{device1}, {device2}, ...]
            let decoder = JSONDecoder()
            let parsedDevices = try decoder.decode([IoTDevice].self, from: data)
            self.devices = parsedDevices
        } catch {
            // Log error details for debugging
            print("[DeviceControlViewModel] Parse error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("[DeviceControlViewModel] Response data: \(jsonString.prefix(500))...")
            }
            errorMessage = "Failed to parse response: \(error.localizedDescription)"
        }
    }

    // MARK: - Device Selection

    func selectDevice(_ device: IoTDevice) {
        selectedDevice = device
        deviceState = nil
        stateDescription = ""
        lastOperationResult = nil
        lastOperationError = nil
    }

    func clearSelection() {
        selectedDevice = nil
        deviceState = nil
        stateDescription = ""
    }

    // MARK: - Device State

    func getDeviceState() {
        guard let device = selectedDevice else { return }
        guard let sdk = IoTAppCore.current else {
            lastOperationError = "SDK not initialized"
            return
        }

        isLoadingState = true
        lastOperationError = nil
        lastOperationResult = nil

        sdk.deviceCmdHandler.getDeviceState(devId: device.id) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoadingState = false

                switch result {
                case .success(let state):
                    self.deviceState = state
                    self.stateDescription = "State retrieved successfully"
                    self.lastOperationResult = "Device state retrieved"

                case .failure(let error):
                    self.lastOperationError = "Failed to get state: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Device Control

    func sendControl() {
        guard let device = selectedDevice else { return }
        guard let sdk = IoTAppCore.current else {
            lastOperationError = "SDK not initialized"
            return
        }

        // Parse elements
        guard let elements = parseIntArray(controlElements) else {
            lastOperationError = "Invalid elements format. Use comma-separated integers (e.g., 0 or 0,1,2)"
            return
        }

        // Parse attrValue
        guard let attrValue = parseIntArray(controlAttrValue) else {
            lastOperationError = "Invalid attribute values format. Use comma-separated integers (e.g., 1,255,0,0)"
            return
        }

        isLoadingState = true
        lastOperationError = nil
        lastOperationResult = nil

        sdk.deviceCmdHandler.controlDevice(
            devId: device.id,
            elements: elements,
            attrValue: attrValue
        ) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoadingState = false

                switch result {
                case .success(let ackCode):
                    self.lastOperationResult = "Control sent successfully (ACK: \(ackCode))"

                case .failure(let error):
                    self.lastOperationError = "Control failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func rebootDevice() {
        guard let device = selectedDevice else { return }
        guard let sdk = IoTAppCore.current else {
            lastOperationError = "SDK not initialized"
            return
        }

        isLoadingState = true
        lastOperationError = nil
        lastOperationResult = nil

        sdk.deviceCmdHandler.rebootDevice(devId: device.id) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoadingState = false

                switch result {
                case .success:
                    self.lastOperationResult = "Device reboot initiated"

                case .failure(let error):
                    self.lastOperationError = "Reboot failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func resetDevice() {
        guard let device = selectedDevice else { return }
        guard let sdk = IoTAppCore.current else {
            lastOperationError = "SDK not initialized"
            return
        }

        isLoadingState = true
        lastOperationError = nil
        lastOperationResult = nil

        sdk.deviceCmdHandler.resetDevice(devId: device.id) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoadingState = false

                switch result {
                case .success:
                    self.lastOperationResult = "Device reset to factory defaults"

                case .failure(let error):
                    self.lastOperationError = "Reset failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Network Operations

    func getConnectivity() {
        guard let device = selectedDevice else { return }
        guard let sdk = IoTAppCore.current else {
            lastOperationError = "SDK not initialized"
            return
        }

        isLoadingState = true
        lastOperationError = nil
        lastOperationResult = nil

        sdk.deviceCmdHandler.getDeviceConnectivity(devId: device.id) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoadingState = false

                switch result {
                case .success(let connectivity):
                    var resultText = "Connectivity Info:\n"
                    for (index, conn) in connectivity.enumerated() {
                        resultText += "\nInterface \(index):\n"
                        resultText += "  WiFi: \(conn.isWiFiConnected ?? false ? "Connected" : "Disconnected")\n"
                        resultText += "  Cloud: \(conn.isCloudConnected ?? false ? "Connected" : "Disconnected")\n"
                        if let ssid = conn.wifiSSID {
                            resultText += "  SSID: \(ssid)\n"
                        }
                        if let rssi = conn.wifiSignalStrength {
                            resultText += "  Signal: \(rssi) dBm\n"
                        }
                    }
                    self.lastOperationResult = resultText

                case .failure(let error):
                    self.lastOperationError = "Failed to get connectivity: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Group Control

    func sendGroupControl(groupAddr: Int, attrValue: [Int], targetDevType: Int = 0) {
        guard let sdk = IoTAppCore.current else {
            lastOperationError = "SDK not initialized"
            return
        }

        isLoadingState = true
        lastOperationError = nil
        lastOperationResult = nil

        sdk.deviceCmdHandler.controlDeviceGroup(
            groupAddr: groupAddr,
            attrValue: attrValue,
            targetDevType: targetDevType
        ) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoadingState = false

                switch result {
                case .success(let ackCode):
                    self.lastOperationResult = "Group control sent successfully (ACK: \(ackCode))"

                case .failure(let error):
                    self.lastOperationError = "Group control failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Delete Device

    /// Delete device from cloud via API
    /// - Parameters:
    ///   - completion: Callback with success (true) or failure (false)
    func deleteDevice(completion: @escaping (Bool) -> Void) {
        guard let device = selectedDevice else {
            lastOperationError = "No device selected"
            completion(false)
            return
        }

        guard let sdk = IoTAppCore.current else {
            lastOperationError = "SDK not initialized"
            completion(false)
            return
        }

        guard let deviceUuid = device.uuid else {
            lastOperationError = "Device UUID not available"
            completion(false)
            return
        }

        isLoadingState = true
        lastOperationError = nil
        lastOperationResult = nil

        let params: [String: Any] = ["uuid": deviceUuid]

        sdk.callApiPost("device/delete", params: params, headers: nil) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoadingState = false

                switch result {
                case .success(let data):
                    // Parse response: {"uuid": "xxx", "success": true}
                    if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = response["success"] as? Bool,
                       success == true {
                        self.lastOperationResult = "Device deleted successfully"
                        // Remove from local list
                        self.devices.removeAll { $0.id == device.id }
                        self.selectedDevice = nil
                        completion(true)
                    } else {
                        self.lastOperationError = "Delete failed: Invalid response"
                        completion(false)
                    }

                case .failure(let error):
                    self.lastOperationError = "Delete failed: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }
    }

    // MARK: - Helpers

    func clearResults() {
        lastOperationResult = nil
        lastOperationError = nil
    }

    private func parseIntArray(_ string: String) -> [Int]? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.components(separatedBy: ",")
        var result: [Int] = []

        for part in parts {
            let cleaned = part.trimmingCharacters(in: .whitespaces)
            guard let value = Int(cleaned) else { return nil }
            result.append(value)
        }

        return result
    }
}
