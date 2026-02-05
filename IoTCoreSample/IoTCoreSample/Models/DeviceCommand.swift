//
//  DeviceCommand.swift
//  IoTCoreSample
//
//  Created on 2025-01-19.
//  Model defining all 24 device commands from RGBIotDeviceCmdHandler protocol
//

import Foundation

// MARK: - Command Category

/// Categories for organizing device commands
enum CommandCategory: String, CaseIterable {
    case deviceStateControl = "Device State & Control"
    case connectionBinding = "Connection & Binding"
    case wifiOperations = "WiFi Operations"
    case smartAutomation = "Smart Automation"
    case vendorMessages = "Vendor Messages"
    case wileDirectBle = "Wile Direct BLE"
    case otaSystem = "OTA & System"
    case logs = "Logs"

    var icon: String {
        switch self {
        case .deviceStateControl: return "slider.horizontal.3"
        case .connectionBinding: return "link"
        case .wifiOperations: return "wifi"
        case .smartAutomation: return "wand.and.stars"
        case .vendorMessages: return "envelope"
        case .wileDirectBle: return "antenna.radiowaves.left.and.right"
        case .otaSystem: return "gearshape.2"
        case .logs: return "doc.text"
        }
    }

    var sortOrder: Int {
        switch self {
        case .deviceStateControl: return 0
        case .connectionBinding: return 1
        case .wifiOperations: return 2
        case .smartAutomation: return 3
        case .vendorMessages: return 4
        case .wileDirectBle: return 5
        case .otaSystem: return 6
        case .logs: return 7
        }
    }
}

// MARK: - Parameter Type

/// Types of parameters that commands can accept
enum ParameterType {
    case string
    case int
    case intArray
    case double
    case bool
    case uint8
    case uint8Array
}

// MARK: - Command Parameter

/// Definition of a command parameter
struct CommandParameter {
    let name: String
    let displayName: String
    let type: ParameterType
    let defaultValue: String
    let placeholder: String
    let isRequired: Bool
    let helpText: String?

    init(
        name: String,
        displayName: String,
        type: ParameterType,
        defaultValue: String = "",
        placeholder: String = "",
        isRequired: Bool = true,
        helpText: String? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.type = type
        self.defaultValue = defaultValue
        self.placeholder = placeholder
        self.isRequired = isRequired
        self.helpText = helpText
    }
}

// MARK: - Device Command

/// All 24 device commands from RGBIotDeviceCmdHandler protocol
enum DeviceCommand: String, CaseIterable, Identifiable {
    // Device State & Control (6)
    case getDeviceState
    case controlDevice
    case controlDeviceGroup
    case controlDeviceLocation
    case settingAttribute
    case setCountdown

    // Connection & Binding (2)
    case connect
    case unbindDeviceGroup

    // WiFi Operations (2)
    case requestScanWifi
    case requestConnectWifi

    // Smart Automation (5)
    case activeSmart
    case bindDeviceSmartTrigger
    case unbindDeviceSmartTrigger
    case bindDeviceSmartCmd
    case unbindDeviceSmartCmd

    // Vendor Messages (2)
    case sendVendorMsgBytes
    case sendVendorMsgJson

    // Wile Direct BLE (2)
    case startWileDirectBle
    case stopWileDirectBle

    // OTA & System (4)
    case checkDeviceSoftwareVersion
    case updateDeviceSoftware
    case resetDevice
    case rebootDevice

    // Logs (1)
    case getLogAttrBlocks

    // MARK: - Identifiable

    var id: String { rawValue }

    // MARK: - Display Name

    var displayName: String {
        switch self {
        case .getDeviceState:
            return "Get Device State"
        case .controlDevice:
            return "Control Device"
        case .controlDeviceGroup:
            return "Control Device Group"
        case .controlDeviceLocation:
            return "Control Device Location"
        case .settingAttribute:
            return "Setting Attribute"
        case .setCountdown:
            return "Set Countdown"
        case .connect:
            return "Connect (Bind to Group)"
        case .unbindDeviceGroup:
            return "Unbind Device Group"
        case .requestScanWifi:
            return "Request Scan WiFi"
        case .requestConnectWifi:
            return "Request Connect WiFi"
        case .activeSmart:
            return "Activate Smart"
        case .bindDeviceSmartTrigger:
            return "Bind Device Smart Trigger"
        case .unbindDeviceSmartTrigger:
            return "Unbind Device Smart Trigger"
        case .bindDeviceSmartCmd:
            return "Bind Device Smart Command"
        case .unbindDeviceSmartCmd:
            return "Unbind Device Smart Command"
        case .sendVendorMsgBytes:
            return "Send Vendor Message (Bytes)"
        case .sendVendorMsgJson:
            return "Send Vendor Message (JSON)"
        case .startWileDirectBle:
            return "Start Wile Direct BLE"
        case .stopWileDirectBle:
            return "Stop Wile Direct BLE"
        case .checkDeviceSoftwareVersion:
            return "Check Device Software Version"
        case .updateDeviceSoftware:
            return "Update Device Software"
        case .resetDevice:
            return "Reset Device"
        case .rebootDevice:
            return "Reboot Device"
        case .getLogAttrBlocks:
            return "Get Log Attribute Blocks"
        }
    }

    // MARK: - Category

    var category: CommandCategory {
        switch self {
        case .getDeviceState, .controlDevice, .controlDeviceGroup,
             .controlDeviceLocation, .settingAttribute, .setCountdown:
            return .deviceStateControl

        case .connect, .unbindDeviceGroup:
            return .connectionBinding

        case .requestScanWifi, .requestConnectWifi:
            return .wifiOperations

        case .activeSmart, .bindDeviceSmartTrigger, .unbindDeviceSmartTrigger,
             .bindDeviceSmartCmd, .unbindDeviceSmartCmd:
            return .smartAutomation

        case .sendVendorMsgBytes, .sendVendorMsgJson:
            return .vendorMessages

        case .startWileDirectBle, .stopWileDirectBle:
            return .wileDirectBle

        case .checkDeviceSoftwareVersion, .updateDeviceSoftware,
             .resetDevice, .rebootDevice:
            return .otaSystem

        case .getLogAttrBlocks:
            return .logs
        }
    }

    // MARK: - Description

    var description: String {
        switch self {
        case .getDeviceState:
            return "Query the current state of a device including all element attributes"
        case .controlDevice:
            return "Send control commands to a device (on/off, color, brightness, etc.)"
        case .controlDeviceGroup:
            return "Send control commands to all devices in a group"
        case .controlDeviceLocation:
            return "Send control commands to all devices in a location"
        case .settingAttribute:
            return "Set a specific attribute on a device element"
        case .setCountdown:
            return "Set a countdown timer to execute start/stop attribute values"
        case .connect:
            return "Bind a device to a group address"
        case .unbindDeviceGroup:
            return "Unbind device elements from a group"
        case .requestScanWifi:
            return "Request device to scan for available WiFi networks"
        case .requestConnectWifi:
            return "Request device to connect to a specific WiFi network"
        case .activeSmart:
            return "Activate a smart automation rule"
        case .bindDeviceSmartTrigger:
            return "Bind a device as a trigger for smart automation"
        case .unbindDeviceSmartTrigger:
            return "Unbind a device from being a smart automation trigger"
        case .bindDeviceSmartCmd:
            return "Bind a device to receive smart automation commands"
        case .unbindDeviceSmartCmd:
            return "Unbind a device from receiving smart automation commands"
        case .sendVendorMsgBytes:
            return "Send vendor-specific message as raw bytes"
        case .sendVendorMsgJson:
            return "Send vendor-specific message as JSON string"
        case .startWileDirectBle:
            return "Start direct BLE communication with a Wile device"
        case .stopWileDirectBle:
            return "Stop direct BLE communication"
        case .checkDeviceSoftwareVersion:
            return "Check the current firmware/software version of the device"
        case .updateDeviceSoftware:
            return "Initiate OTA firmware update on the device"
        case .resetDevice:
            return "Factory reset the device to default settings"
        case .rebootDevice:
            return "Reboot the device"
        case .getLogAttrBlocks:
            return "Get historical log attribute blocks from the device"
        }
    }

    // MARK: - Parameters

    var parameters: [CommandParameter] {
        switch self {
        case .getDeviceState:
            return [
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                )
            ]

        case .controlDevice:
            return [
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                ),
                CommandParameter(
                    name: "elements",
                    displayName: "Elements",
                    type: .intArray,
                    defaultValue: "0",
                    placeholder: "0 or 0,1,2",
                    helpText: "Element indices to control"
                ),
                CommandParameter(
                    name: "attribute",
                    displayName: "Attribute",
                    type: .int,
                    defaultValue: "1",
                    placeholder: "1 (ON/OFF)",
                    helpText: "Attribute ID (1=ON/OFF, 2=Brightness, 3=Color...)"
                ),
                CommandParameter(
                    name: "values",
                    displayName: "Values",
                    type: .intArray,
                    defaultValue: "255,0,0",
                    placeholder: "255,0,0 (R,G,B)",
                    helpText: "Values for the attribute"
                )
            ]

        case .controlDeviceGroup:
            return [
                CommandParameter(
                    name: "groupAddr",
                    displayName: "Group Address",
                    type: .int,
                    defaultValue: "49153",
                    placeholder: "Group address (hex or decimal)"
                ),
                CommandParameter(
                    name: "attribute",
                    displayName: "Attribute",
                    type: .int,
                    defaultValue: "1",
                    placeholder: "1 (ON/OFF)",
                    helpText: "Attribute ID"
                ),
                CommandParameter(
                    name: "values",
                    displayName: "Values",
                    type: .intArray,
                    defaultValue: "255,0,0",
                    placeholder: "255,0,0"
                ),
                CommandParameter(
                    name: "targetDevType",
                    displayName: "Target Device Type",
                    type: .int,
                    defaultValue: "0",
                    placeholder: "0 for all devices",
                    isRequired: false
                )
            ]

        case .controlDeviceLocation:
            return [
                CommandParameter(
                    name: "attribute",
                    displayName: "Attribute",
                    type: .int,
                    defaultValue: "1",
                    placeholder: "1 (ON/OFF)",
                    helpText: "Attribute ID"
                ),
                CommandParameter(
                    name: "values",
                    displayName: "Values",
                    type: .intArray,
                    defaultValue: "255,0,0",
                    placeholder: "255,0,0"
                ),
                CommandParameter(
                    name: "targetDevType",
                    displayName: "Target Device Type",
                    type: .int,
                    defaultValue: "0",
                    placeholder: "0 for all devices",
                    isRequired: false
                )
            ]

        case .settingAttribute:
            return [
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                ),
                CommandParameter(
                    name: "element",
                    displayName: "Element",
                    type: .int,
                    defaultValue: "0",
                    placeholder: "Element index"
                ),
                CommandParameter(
                    name: "attrValue",
                    displayName: "Attribute Values",
                    type: .intArray,
                    defaultValue: "1,100",
                    placeholder: "Comma separated values"
                )
            ]

        case .setCountdown:
            return [
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                ),
                CommandParameter(
                    name: "elements",
                    displayName: "Elements",
                    type: .intArray,
                    defaultValue: "0",
                    placeholder: "0 or 0,1,2"
                ),
                CommandParameter(
                    name: "attrValueStart",
                    displayName: "Start Attribute Values",
                    type: .intArray,
                    defaultValue: "1,255,255,255",
                    placeholder: "Values when countdown starts"
                ),
                CommandParameter(
                    name: "attrValueStop",
                    displayName: "Stop Attribute Values",
                    type: .intArray,
                    defaultValue: "0,0,0,0",
                    placeholder: "Values when countdown ends"
                ),
                CommandParameter(
                    name: "minutes",
                    displayName: "Minutes",
                    type: .int,
                    defaultValue: "30",
                    placeholder: "Countdown duration in minutes"
                )
            ]

        case .connect:
            return [
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                ),
                CommandParameter(
                    name: "groupAddr",
                    displayName: "Group Address",
                    type: .int,
                    defaultValue: "49153",
                    placeholder: "Group address to bind to"
                )
            ]

        case .unbindDeviceGroup:
            return [
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                ),
                CommandParameter(
                    name: "elements",
                    displayName: "Elements",
                    type: .intArray,
                    defaultValue: "0",
                    placeholder: "0 or 0,1,2"
                ),
                CommandParameter(
                    name: "groupAddr",
                    displayName: "Group Address",
                    type: .int,
                    defaultValue: "49153",
                    placeholder: "Group address to unbind from"
                )
            ]

        case .requestScanWifi:
            return [
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                )
            ]

        case .requestConnectWifi:
            return [
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                ),
                CommandParameter(
                    name: "ssid",
                    displayName: "WiFi SSID",
                    type: .string,
                    placeholder: "Network name"
                ),
                CommandParameter(
                    name: "pwd",
                    displayName: "WiFi Password",
                    type: .string,
                    placeholder: "Network password"
                )
            ]

        case .activeSmart:
            return [
                CommandParameter(
                    name: "smid",
                    displayName: "Smart ID",
                    type: .int,
                    placeholder: "Smart automation rule ID"
                )
            ]

        case .bindDeviceSmartTrigger:
            return [
                CommandParameter(
                    name: "smid",
                    displayName: "Smart ID",
                    type: .int,
                    placeholder: "Smart automation rule ID"
                ),
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                ),
                CommandParameter(
                    name: "typeTrigger",
                    displayName: "Trigger Type",
                    type: .int,
                    defaultValue: "0",
                    placeholder: "Type of trigger"
                ),
                CommandParameter(
                    name: "elm",
                    displayName: "Element",
                    type: .int,
                    defaultValue: "0",
                    placeholder: "Element index"
                ),
                CommandParameter(
                    name: "condition",
                    displayName: "Condition",
                    type: .int,
                    defaultValue: "0",
                    placeholder: "Condition type"
                ),
                CommandParameter(
                    name: "attrValueCondition",
                    displayName: "Condition Attribute Values",
                    type: .intArray,
                    placeholder: "Condition values"
                ),
                CommandParameter(
                    name: "elmExt",
                    displayName: "Extended Element",
                    type: .int,
                    placeholder: "Optional extended element",
                    isRequired: false
                ),
                CommandParameter(
                    name: "conditionExt",
                    displayName: "Extended Condition",
                    type: .int,
                    placeholder: "Optional extended condition",
                    isRequired: false
                ),
                CommandParameter(
                    name: "attrValueConditionExt",
                    displayName: "Extended Condition Values",
                    type: .intArray,
                    placeholder: "Optional extended condition values",
                    isRequired: false
                ),
                CommandParameter(
                    name: "timeCfg",
                    displayName: "Time Configuration",
                    type: .intArray,
                    placeholder: "Optional time configuration",
                    isRequired: false
                ),
                CommandParameter(
                    name: "timeJob",
                    displayName: "Time Job",
                    type: .intArray,
                    placeholder: "Optional time job configuration",
                    isRequired: false
                )
            ]

        case .unbindDeviceSmartTrigger:
            return [
                CommandParameter(
                    name: "smid",
                    displayName: "Smart ID",
                    type: .int,
                    placeholder: "Smart automation rule ID"
                ),
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                )
            ]

        case .bindDeviceSmartCmd:
            return [
                CommandParameter(
                    name: "smid",
                    displayName: "Smart ID",
                    type: .int,
                    placeholder: "Smart automation rule ID"
                ),
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                ),
                CommandParameter(
                    name: "elm",
                    displayName: "Element",
                    type: .int,
                    defaultValue: "0",
                    placeholder: "Element index"
                ),
                CommandParameter(
                    name: "attrValue",
                    displayName: "Attribute Values",
                    type: .intArray,
                    placeholder: "Command attribute values"
                ),
                CommandParameter(
                    name: "delay",
                    displayName: "Delay",
                    type: .int,
                    placeholder: "Optional delay in seconds",
                    isRequired: false
                )
            ]

        case .unbindDeviceSmartCmd:
            return [
                CommandParameter(
                    name: "smid",
                    displayName: "Smart ID",
                    type: .int,
                    placeholder: "Smart automation rule ID"
                ),
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                )
            ]

        case .sendVendorMsgBytes:
            return [
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                ),
                CommandParameter(
                    name: "typeMsg",
                    displayName: "Message Type",
                    type: .uint8,
                    defaultValue: "0",
                    placeholder: "Vendor message type"
                ),
                CommandParameter(
                    name: "vendorMsg",
                    displayName: "Vendor Message",
                    type: .uint8Array,
                    placeholder: "Comma separated byte values (0-255)"
                )
            ]

        case .sendVendorMsgJson:
            return [
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                ),
                CommandParameter(
                    name: "typeMsg",
                    displayName: "Message Type",
                    type: .uint8,
                    defaultValue: "0",
                    placeholder: "Vendor message type"
                ),
                CommandParameter(
                    name: "json",
                    displayName: "JSON Message",
                    type: .string,
                    placeholder: "{\"key\": \"value\"}"
                )
            ]

        case .startWileDirectBle:
            return [
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                )
            ]

        case .stopWileDirectBle:
            return []

        case .checkDeviceSoftwareVersion:
            return [
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                )
            ]

        case .updateDeviceSoftware:
            return [
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                ),
                CommandParameter(
                    name: "urlOta",
                    displayName: "OTA URL",
                    type: .string,
                    placeholder: "https://example.com/firmware.bin"
                ),
                CommandParameter(
                    name: "forceHttpNonSecure",
                    displayName: "Force HTTP (Non-Secure)",
                    type: .bool,
                    defaultValue: "false",
                    placeholder: "true/false",
                    isRequired: false,
                    helpText: "Allow non-HTTPS download"
                )
            ]

        case .resetDevice:
            return [
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                )
            ]

        case .rebootDevice:
            return [
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                )
            ]

        case .getLogAttrBlocks:
            return [
                CommandParameter(
                    name: "devId",
                    displayName: "Device ID",
                    type: .string,
                    placeholder: "Device UUID"
                ),
                CommandParameter(
                    name: "element",
                    displayName: "Element",
                    type: .int,
                    defaultValue: "0",
                    placeholder: "Element index"
                ),
                CommandParameter(
                    name: "attr",
                    displayName: "Attribute",
                    type: .int,
                    defaultValue: "0",
                    placeholder: "Attribute type"
                ),
                CommandParameter(
                    name: "timeCheckpoint",
                    displayName: "Time Checkpoint",
                    type: .double,
                    defaultValue: "0",
                    placeholder: "Unix timestamp",
                    helpText: "Start time for log retrieval"
                )
            ]
        }
    }

    // MARK: - Helper Properties

    var hasParameters: Bool {
        !parameters.isEmpty
    }

    var requiredParameters: [CommandParameter] {
        parameters.filter { $0.isRequired }
    }

    var optionalParameters: [CommandParameter] {
        parameters.filter { !$0.isRequired }
    }

    /// Whether this command requires a device ID
    var requiresDeviceId: Bool {
        parameters.contains { $0.name == "devId" }
    }

    /// Whether this command has a completion callback (returns a result)
    var hasCompletionCallback: Bool {
        switch self {
        case .activeSmart, .sendVendorMsgBytes, .sendVendorMsgJson,
             .stopWileDirectBle, .checkDeviceSoftwareVersion, .updateDeviceSoftware:
            return false
        default:
            return true
        }
    }
}

// MARK: - Static Helpers

extension DeviceCommand {
    /// Get all commands in a specific category
    static func commands(in category: CommandCategory) -> [DeviceCommand] {
        allCases.filter { $0.category == category }
    }

    /// Get all commands grouped by category
    static var commandsByCategory: [(category: CommandCategory, commands: [DeviceCommand])] {
        CommandCategory.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { category in
                (category: category, commands: commands(in: category))
            }
    }

    /// Find a command by its raw value
    static func command(byId id: String) -> DeviceCommand? {
        DeviceCommand(rawValue: id)
    }
}
