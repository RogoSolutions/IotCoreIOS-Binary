//
//  DeviceControlViewModel.swift
//  IoTCoreSample
//
//  ViewModel for Device Control Tab - manages device list and control operations
//

import Foundation
import IotCoreIOS
import Combine

// Note: TransportOption and ConnectionStatus are defined in TransportSelectorView.swift
// Note: CommandExecution is defined in DeviceCmdTestViewModel.swift

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

    // MARK: - Constants

    private let selectedLocationKey = "DeviceControl_SelectedLocationId"

    // MARK: - Published Properties

    @Published var devices: [IoTDevice] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDevice: IoTDevice?

    // Location filtering
    @Published var locations: [Location] = []
    @Published var selectedLocationId: String? = nil

    // Group filtering
    @Published var groups: [DeviceGroup] = []

    // MARK: - Computed Properties

    /// Devices filtered by selected location
    var filteredDevices: [IoTDevice] {
        guard let locationId = selectedLocationId else {
            return devices // "All" - show all devices
        }
        return devices.filter { $0.locationId == locationId
        }
    }

    /// Devices grouped by groupId for the current filtered list
    /// Returns tuples of (groupId, groupName, devices) sorted with named groups first, ungrouped last
    var devicesByGroup: [(groupId: String?, groupName: String, devices: [IoTDevice])] {
        // Group devices by groupId
        let grouped = Dictionary(grouping: filteredDevices) { $0.groupId }

        var groupedData: [(groupId: String?, groupName: String, devices: [IoTDevice])] = []

        // Create tuples with group names
        for (groupId, groupDevices) in grouped {
            let groupName: String
            if let gid = groupId, let group = groups.first(where: { $0.uuid == gid }) {
                groupName = group.label
            } else if groupId == nil {
                groupName = "Ungrouped"
            } else {
                groupName = "Unknown Group"
            }
            groupedData.append((groupId: groupId, groupName: groupName, devices: groupDevices))
        }

        // Sort: named groups first (alphabetically), then ungrouped at the end
        return groupedData.sorted { item1, item2 in
            if item1.groupId == nil { return false }
            if item2.groupId == nil { return true }
            return item1.groupName.localizedCaseInsensitiveCompare(item2.groupName) == .orderedAscending
        }
    }

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

    // Transport selection (global)
    @Published var selectedTransport: TransportOption = .auto
    @Published var bleStatus: ConnectionStatus = .disconnected
    @Published var mqttStatus: ConnectionStatus = .disconnected

    // Execution history (for all operations)
    @Published var executionHistory: [CommandExecution] = []

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

    // MARK: - Location Operations

    /// Fetch locations from API for filtering
    func fetchLocations() {
        guard let sdk = IoTAppCore.current else {
            print("[DeviceControlViewModel] SDK not initialized - cannot fetch locations")
            return
        }

        sdk.callApiGet("location/get", params: nil, headers: nil) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }

                switch result {
                case .success(let data):
                    if let parsedLocations = Location.parseFromAPIResponse(data) {
                        self.locations = parsedLocations
                        self.loadSavedLocation()
                        print("[DeviceControlViewModel] Loaded \(parsedLocations.count) locations")
                    } else {
                        print("[DeviceControlViewModel] Failed to parse locations response")
                    }

                case .failure(let error):
                    print("[DeviceControlViewModel] Failed to fetch locations: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Select a location for filtering devices
    /// - Parameter locationId: Location UUID or nil for "All"
    func selectLocation(_ locationId: String?) {
        selectedLocationId = locationId
        saveSelectedLocation()
    }

    /// Save the selected location to UserDefaults for persistence across app launches
    private func saveSelectedLocation() {
        if let locationId = selectedLocationId {
            UserDefaults.standard.set(locationId, forKey: selectedLocationKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedLocationKey)
        }
    }

    /// Load the saved location from UserDefaults and validate it still exists
    private func loadSavedLocation() {
        let savedId = UserDefaults.standard.string(forKey: selectedLocationKey)

        // Validate the saved location still exists
        if let savedId = savedId {
            if locations.contains(where: { $0.uuid == savedId }) {
                selectedLocationId = savedId
            } else {
                // Saved location no longer exists, reset to "All"
                selectedLocationId = nil
                saveSelectedLocation()
            }
        }
    }

    // MARK: - Group Operations

    /// Fetch groups (rooms) from API for grouping devices
    func fetchGroups() {
        guard let sdk = IoTAppCore.current else {
            print("[DeviceControlViewModel] SDK not initialized - cannot fetch groups")
            return
        }

        sdk.callApiGet("group/get", params: nil, headers: nil) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }

                switch result {
                case .success(let data):
                    if let parsedGroups = DeviceGroup.parseFromAPIResponse(data) {
                        self.groups = parsedGroups
                        print("[DeviceControlViewModel] Loaded \(parsedGroups.count) groups")
                    } else {
                        print("[DeviceControlViewModel] Failed to parse groups response")
                    }

                case .failure(let error):
                    print("[DeviceControlViewModel] Failed to fetch groups: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Get device count for a specific location
    /// - Parameter locationId: Location UUID or nil for "All"
    /// - Returns: Number of devices in the location
    func deviceCount(forLocationId locationId: String?) -> Int {
        guard let locationId = locationId else {
            return devices.count
        }
        return devices.filter { $0.locationId == locationId }.count
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

        let parameters = ["devId": device.id]

        sdk.deviceCmdHandler.getDeviceState(devId: device.id) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoadingState = false

                switch result {
                case .success(let state):
                    self.deviceState = state
                    self.stateDescription = "State retrieved successfully"
                    let resultText = "Device state retrieved via \(self.selectedTransport.displayName)"
                    self.lastOperationResult = resultText
                    // Extract state data for history display using String(describing:)
                    // Note: RGBDeviceState has internal properties, so we capture the description
                    let stateDescription = String(describing: state)
                    let responseData = CommandResponseData.deviceStateDescription(stateDescription)
                    self.addToHistory(
                        command: DeviceCommand.getDeviceState.rawValue,
                        parameters: parameters,
                        result: resultText,
                        isSuccess: true,
                        responseData: responseData
                    )

                case .failure(let error):
                    let errorText = "Failed to get state: \(error.localizedDescription)"
                    self.lastOperationError = errorText
                    self.addToHistory(
                        command: DeviceCommand.getDeviceState.rawValue,
                        parameters: parameters,
                        result: errorText,
                        isSuccess: false
                    )
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

        let parameters = [
            "devId": device.id,
            "elements": controlElements,
            "attrValue": controlAttrValue
        ]

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
                    let resultText = "Control sent via \(self.selectedTransport.displayName) (ACK: \(ackCode))"
                    self.lastOperationResult = resultText
                    self.addToHistory(
                        command: DeviceCommand.controlDevice.rawValue,
                        parameters: parameters,
                        result: resultText,
                        isSuccess: true,
                        responseData: .ackCode(ackCode)
                    )

                case .failure(let error):
                    let errorText = "Control failed: \(error.localizedDescription)"
                    self.lastOperationError = errorText
                    self.addToHistory(
                        command: DeviceCommand.controlDevice.rawValue,
                        parameters: parameters,
                        result: errorText,
                        isSuccess: false
                    )
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

        let parameters = ["devId": device.id]

        sdk.deviceCmdHandler.rebootDevice(devId: device.id) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoadingState = false

                switch result {
                case .success:
                    let resultText = "Device reboot initiated via \(self.selectedTransport.displayName)"
                    self.lastOperationResult = resultText
                    self.addToHistory(
                        command: DeviceCommand.rebootDevice.rawValue,
                        parameters: parameters,
                        result: resultText,
                        isSuccess: true
                    )

                case .failure(let error):
                    let errorText = "Reboot failed: \(error.localizedDescription)"
                    self.lastOperationError = errorText
                    self.addToHistory(
                        command: DeviceCommand.rebootDevice.rawValue,
                        parameters: parameters,
                        result: errorText,
                        isSuccess: false
                    )
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

        let parameters = ["devId": device.id]

        sdk.deviceCmdHandler.resetDevice(devId: device.id) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoadingState = false

                switch result {
                case .success:
                    let resultText = "Device reset to factory defaults via \(self.selectedTransport.displayName)"
                    self.lastOperationResult = resultText
                    self.addToHistory(
                        command: DeviceCommand.resetDevice.rawValue,
                        parameters: parameters,
                        result: resultText,
                        isSuccess: true
                    )

                case .failure(let error):
                    let errorText = "Reset failed: \(error.localizedDescription)"
                    self.lastOperationError = errorText
                    self.addToHistory(
                        command: DeviceCommand.resetDevice.rawValue,
                        parameters: parameters,
                        result: errorText,
                        isSuccess: false
                    )
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

        let parameters = ["devId": device.id]

        sdk.deviceCmdHandler.getDeviceConnectivity(devId: device.id) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoadingState = false

                switch result {
                case .success(let connectivity):
                    var resultText = "Connectivity Info via \(self.selectedTransport.displayName):\n"
                    for (index, conn) in connectivity.enumerated() {
                        resultText += "\nInterface \(index):\n"
                        resultText += "  WiFi: \(conn.isWiFiConnected ? "Connected" : "Disconnected")\n"
                        resultText += "  Cloud: \(conn.isCloudConnected ? "Connected" : "Disconnected")\n"
                        if let ssid = conn.wifiSSID {
                            resultText += "  SSID: \(ssid)\n"
                        }
                        if let rssi = conn.wifiSignalStrength {
                            resultText += "  Signal: \(rssi) dBm\n"
                        }
                    }
                    self.lastOperationResult = resultText
                    // Extract connectivity data for history display
                    let connectivityInfos = connectivity.map { conn in
                        ConnectivityInfo(
                            isWiFiConnected: conn.isWiFiConnected,
                            isCloudConnected: conn.isCloudConnected,
                            wifiSSID: conn.wifiSSID,
                            wifiSignalStrength: conn.wifiSignalStrength
                        )
                    }
                    // Note: getConnectivity uses getDeviceState as closest DeviceCommand match for history
                    self.addToHistory(
                        command: "getConnectivity",
                        parameters: parameters,
                        result: "Connectivity retrieved successfully",
                        isSuccess: true,
                        responseData: .connectivity(connectivityInfos)
                    )

                case .failure(let error):
                    let errorText = "Failed to get connectivity: \(error.localizedDescription)"
                    self.lastOperationError = errorText
                    self.addToHistory(
                        command: "getConnectivity",
                        parameters: parameters,
                        result: errorText,
                        isSuccess: false
                    )
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

    // MARK: - Transport Status

    /// Update transport status from SDK
    /// Call this on appear to refresh BLE and MQTT connection status
    func updateTransportStatus() {
        guard let core = IoTAppCore.current, let device = selectedDevice else {
            bleStatus = .unavailable
            mqttStatus = .disconnected
            return
        }

        // Check MQTT connection status
        mqttStatus = core.isMQTTConnected() ? .connected : .disconnected

        // Check BLE availability for this device
        bleStatus = core.isBLEAvailable(for: device.id) ? .connected : .disconnected
    }

    /// Start BLE scan to discover nearby devices
    /// This refreshes BLE availability status after scanning
    func startBLEScan() {
        // For now, just refresh status
        // In a full implementation, this would trigger a BLE scan
        updateTransportStatus()
    }

    /// Reconnect MQTT service
    /// Initiates MQTT connection and updates status on completion
    func reconnectMQTT() {
        guard let core = IoTAppCore.current else {
            lastOperationError = "SDK not initialized"
            return
        }

        mqttStatus = .connecting

        core.connectService { [weak self] result in
            Task { @MainActor in
                self?.updateTransportStatus()
                switch result {
                case .success:
                    self?.lastOperationResult = "MQTT connection initiated"
                case .failure(let error):
                    self?.lastOperationError = "MQTT connect failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Helpers

    func clearResults() {
        lastOperationResult = nil
        lastOperationError = nil
    }

    // MARK: - History Management

    /// Add a command execution to history
    /// - Parameters:
    ///   - command: The command that was executed (e.g., "getDeviceState", "controlDevice")
    ///   - parameters: Dictionary of parameters used
    ///   - result: The result message
    ///   - isSuccess: Whether the execution was successful
    ///   - responseData: Optional response data from the command
    func addToHistory(
        command: String,
        parameters: [String: String],
        result: String,
        isSuccess: Bool,
        responseData: CommandResponseData = .none
    ) {
        // Map string command to DeviceCommand enum (use .getDeviceState as fallback)
        let deviceCommand = DeviceCommand.allCases.first { $0.rawValue == command } ?? .getDeviceState

        let executionResult: ExecutionResult = isSuccess
            ? .success(result)
            : .failure(result)

        let execution = CommandExecution(
            command: deviceCommand,
            parameters: parameters,
            transport: selectedTransport,
            result: executionResult,
            responseData: responseData
        )

        // Insert at beginning (newest first)
        executionHistory.insert(execution, at: 0)
    }

    /// Toggle expanded state for a history item
    func toggleHistoryExpanded(_ executionId: UUID) {
        if let index = executionHistory.firstIndex(where: { $0.id == executionId }) {
            executionHistory[index].isExpanded.toggle()
        }
    }

    /// Clear all execution history
    func clearHistory() {
        executionHistory.removeAll()
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
