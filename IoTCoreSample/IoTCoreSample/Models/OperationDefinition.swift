//
//  OperationDefinition.swift
//  IoTCoreSample
//
//  Created on 2025-12-11.
//  Model for defining testable operations
//

import Foundation

// MARK: - Parameter Type

enum OperationParameterType {
    case string
    case int
    case intArray
    case data
    case bool
}

// MARK: - Parameter Definition

struct OperationParameter {
    let name: String
    let displayName: String
    let type: OperationParameterType
    let defaultValue: String
    let placeholder: String
    let isRequired: Bool

    init(
        name: String,
        displayName: String,
        type: OperationParameterType,
        defaultValue: String = "",
        placeholder: String = "",
        isRequired: Bool = true
    ) {
        self.name = name
        self.displayName = displayName
        self.type = type
        self.defaultValue = defaultValue
        self.placeholder = placeholder
        self.isRequired = isRequired
    }
}

// MARK: - Operation Category

enum OperationCategory: String, CaseIterable {
    case control = "Device Control"
    case deviceInfo = "Device Info"
    case network = "Network"
    case groupManagement = "Group Management"
    case system = "System"

    var icon: String {
        switch self {
        case .control: return "slider.horizontal.3"
        case .deviceInfo: return "info.circle"
        case .network: return "wifi"
        case .groupManagement: return "rectangle.3.group"
        case .system: return "gearshape"
        }
    }
}

// MARK: - Operation Definition

struct OperationDefinition: Identifiable {
    let id: String
    let name: String
    let displayName: String
    let category: OperationCategory
    let description: String
    let parameters: [OperationParameter]

    var hasParameters: Bool {
        !parameters.isEmpty
    }

    init(
        id: String,
        name: String,
        displayName: String,
        category: OperationCategory,
        description: String,
        parameters: [OperationParameter] = []
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.category = category
        self.description = description
        self.parameters = parameters
    }
}

// MARK: - All Operations

extension OperationDefinition {
    static let allOperations: [OperationDefinition] = [
        // MARK: - Device Control

        OperationDefinition(
            id: "sendControl",
            name: "RGBSendControlOperation",
            displayName: "Send Control",
            category: .control,
            description: "Control device attributes (color, brightness, etc.)",
            parameters: [
                OperationParameter(
                    name: "elements",
                    displayName: "Elements",
                    type: .intArray,
                    defaultValue: "0",
                    placeholder: "0 or 0,1,2"
                ),
                OperationParameter(
                    name: "attrValue",
                    displayName: "Attribute Values",
                    type: .intArray,
                    defaultValue: "1,255,0,0",
                    placeholder: "1,255,0,0 (on,R,G,B)"
                )
            ]
        ),

        OperationDefinition(
            id: "sendGroupControl",
            name: "RGBSendGroupControlOperation",
            displayName: "Send Group Control",
            category: .control,
            description: "Control group of devices",
            parameters: [
                OperationParameter(
                    name: "groupAddr",
                    displayName: "Group Address",
                    type: .int,
                    defaultValue: "49153",
                    placeholder: "Group address (hex or decimal)"
                ),
                OperationParameter(
                    name: "attrValue",
                    displayName: "Attribute Values",
                    type: .intArray,
                    defaultValue: "1,255,0,0",
                    placeholder: "1,255,0,0"
                ),
                OperationParameter(
                    name: "targetDevType",
                    displayName: "Target Device Type",
                    type: .int,
                    defaultValue: "0",
                    placeholder: "0 for all devices",
                    isRequired: false
                )
            ]
        ),

        OperationDefinition(
            id: "sendSetting",
            name: "RGBSendSettingOperation",
            displayName: "Send Setting",
            category: .control,
            description: "Set device settings/attributes",
            parameters: [
                OperationParameter(
                    name: "element",
                    displayName: "Element",
                    type: .int,
                    defaultValue: "0",
                    placeholder: "Element index"
                ),
                OperationParameter(
                    name: "attrValue",
                    displayName: "Attribute Values",
                    type: .intArray,
                    defaultValue: "1,100",
                    placeholder: "Comma separated values"
                )
            ]
        ),

        // MARK: - Device Info

        OperationDefinition(
            id: "getDeviceState",
            name: "RGBGetDeviceStateOperation",
            displayName: "Get Device State",
            category: .deviceInfo,
            description: "Query device current state",
            parameters: [
                OperationParameter(
                    name: "element",
                    displayName: "Element",
                    type: .int,
                    defaultValue: "0",
                    placeholder: "Element index",
                    isRequired: false
                ),
                OperationParameter(
                    name: "attributes",
                    displayName: "Attributes",
                    type: .intArray,
                    defaultValue: "",
                    placeholder: "Empty for all attributes",
                    isRequired: false
                )
            ]
        ),

        OperationDefinition(
            id: "getFirmwareVersion",
            name: "RGBGetFirmwareVersionOperation",
            displayName: "Get Firmware Version",
            category: .deviceInfo,
            description: "Get device firmware version"
        ),

        OperationDefinition(
            id: "getWileDeviceInfo",
            name: "RGBGetWileDeviceInfoOperation",
            displayName: "Get Wile Device Info",
            category: .deviceInfo,
            description: "Get Wile device information (MAC, etc.)"
        ),

        // MARK: - Network

        OperationDefinition(
            id: "getNetworkConnectivity",
            name: "RGBGetNetworkConnectivityOperation",
            displayName: "Get Network Connectivity",
            category: .network,
            description: "Get device network connectivity status"
        ),

        OperationDefinition(
            id: "requestWiFiScan",
            name: "RGBRequestWiFiScanOperation",
            displayName: "Request WiFi Scan",
            category: .network,
            description: "Scan for available WiFi networks",
            parameters: [
                OperationParameter(
                    name: "interfaceNumber",
                    displayName: "Interface Number",
                    type: .int,
                    defaultValue: "0",
                    placeholder: "0",
                    isRequired: false
                ),
                OperationParameter(
                    name: "scanDuration",
                    displayName: "Scan Duration (seconds)",
                    type: .int,
                    defaultValue: "10",
                    placeholder: "10",
                    isRequired: false
                )
            ]
        ),

        OperationDefinition(
            id: "setWiFiConnect",
            name: "RGBSetWiFiConnectOperation",
            displayName: "Connect to WiFi",
            category: .network,
            description: "Connect device to WiFi network",
            parameters: [
                OperationParameter(
                    name: "interfaceNumber",
                    displayName: "Interface Number",
                    type: .int,
                    defaultValue: "0",
                    placeholder: "0",
                    isRequired: false
                ),
                OperationParameter(
                    name: "ssid",
                    displayName: "WiFi SSID",
                    type: .string,
                    placeholder: "Network name"
                ),
                OperationParameter(
                    name: "password",
                    displayName: "WiFi Password",
                    type: .string,
                    placeholder: "Network password"
                )
            ]
        ),

        OperationDefinition(
            id: "setCloudInfo",
            name: "RGBSetCloudInfoOperation",
            displayName: "Set Cloud Info",
            category: .network,
            description: "Configure cloud endpoint and partner ID",
            parameters: [
                OperationParameter(
                    name: "cloudEndpoint",
                    displayName: "Cloud Endpoint",
                    type: .string,
                    placeholder: "mqtt.example.com"
                ),
                OperationParameter(
                    name: "partnerId",
                    displayName: "Partner ID",
                    type: .string,
                    placeholder: "Partner identifier"
                )
            ]
        ),

        // MARK: - Group Management

        OperationDefinition(
            id: "bindDeviceToGroup",
            name: "RGBBindDeviceToGroupOperation",
            displayName: "Bind to Group",
            category: .groupManagement,
            description: "Bind device elements to a group",
            parameters: [
                OperationParameter(
                    name: "elements",
                    displayName: "Elements",
                    type: .intArray,
                    defaultValue: "0",
                    placeholder: "0 or 0,1,2"
                ),
                OperationParameter(
                    name: "groupAddr",
                    displayName: "Group Address",
                    type: .int,
                    defaultValue: "49153",
                    placeholder: "Group address"
                )
            ]
        ),

        OperationDefinition(
            id: "unbindDeviceFromGroup",
            name: "RGBUnbindDeviceFromGroupOperation",
            displayName: "Unbind from Group",
            category: .groupManagement,
            description: "Unbind device elements from a group",
            parameters: [
                OperationParameter(
                    name: "elements",
                    displayName: "Elements",
                    type: .intArray,
                    defaultValue: "0",
                    placeholder: "0 or 0,1,2"
                ),
                OperationParameter(
                    name: "groupAddr",
                    displayName: "Group Address",
                    type: .int,
                    defaultValue: "49153",
                    placeholder: "Group address"
                )
            ]
        ),

        // MARK: - System

        OperationDefinition(
            id: "rebootDevice",
            name: "RGBRebootDeviceOperation",
            displayName: "Reboot Device",
            category: .system,
            description: "Reboot the device"
        ),

        OperationDefinition(
            id: "resetDevice",
            name: "RGBResetDeviceOperation",
            displayName: "Reset Device",
            category: .system,
            description: "Factory reset the device"
        ),

        OperationDefinition(
            id: "requestDeviceIdentify",
            name: "RGBRequestDeviceIdentifyOperation",
            displayName: "Identify Device",
            category: .system,
            description: "Make device identify itself (blink, beep, etc.)"
        )
    ]

    static func getOperation(byId id: String) -> OperationDefinition? {
        allOperations.first { $0.id == id }
    }

    static func getOperations(byCategory category: OperationCategory) -> [OperationDefinition] {
        allOperations.filter { $0.category == category }
    }
}
