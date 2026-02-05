//
//  CommandExecution.swift
//  IoTCoreSample
//
//  Models for tracking command execution history
//

import Foundation
import IotCoreIOS

// MARK: - Response Data Wrapper

/// Wrapper for command response data to enable type-safe storage
/// Note: SDK types like RGBDeviceState have internal properties, so we store
/// simplified/extracted data for display purposes.
enum CommandResponseData {
    /// Device state as a formatted string (using String(describing:))
    /// Note: RGBDeviceState has internal properties, so we capture description
    case deviceStateDescription(String)
    case ackCode(Int)
    case connectivity([ConnectivityInfo])
    case wifiNetworks([WifiNetworkInfo])
    case logBlocks(count: Int)
    case none

    /// Format the response data for display
    var formattedDescription: String {
        switch self {
        case .deviceStateDescription(let description):
            return description
        case .ackCode(let code):
            return "ACK Code: \(code)"
        case .connectivity(let connections):
            return formatConnectivity(connections)
        case .wifiNetworks(let networks):
            return formatWifiNetworks(networks)
        case .logBlocks(let count):
            return "Log Blocks: \(count) entries"
        case .none:
            return ""
        }
    }

    /// Check if response has displayable data
    var hasData: Bool {
        switch self {
        case .none:
            return false
        default:
            return true
        }
    }

    // MARK: - Formatting Helpers

    private func formatConnectivity(_ connections: [ConnectivityInfo]) -> String {
        var lines: [String] = []
        for (index, conn) in connections.enumerated() {
            lines.append("Interface \(index):")
            lines.append("  WiFi: \(conn.isWiFiConnected ? "Connected" : "Disconnected")")
            lines.append("  Cloud: \(conn.isCloudConnected ? "Connected" : "Disconnected")")
            if let ssid = conn.wifiSSID {
                lines.append("  SSID: \(ssid)")
            }
            if let rssi = conn.wifiSignalStrength {
                lines.append("  Signal: \(rssi) dBm")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func formatWifiNetworks(_ networks: [WifiNetworkInfo]) -> String {
        var lines: [String] = []
        lines.append("Found \(networks.count) networks:")
        for network in networks {
            lines.append("  - \(network.ssid)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Helper Structs for Response Data

/// Simplified connectivity info for display (extracted from SDK type)
struct ConnectivityInfo {
    let isWiFiConnected: Bool
    let isCloudConnected: Bool
    let wifiSSID: String?
    let wifiSignalStrength: Int?
}

/// Simplified WiFi network info for display (extracted from SDK type)
struct WifiNetworkInfo {
    let ssid: String
    let rssi: Int?
}

// MARK: - Execution Result

/// Result of a command execution
enum ExecutionResult: Equatable {
    case success(String)
    case failure(String)

    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var message: String {
        switch self {
        case .success(let msg):
            return msg
        case .failure(let msg):
            return msg
        }
    }
}

// MARK: - Command Execution

/// Represents a single command execution with its result
struct CommandExecution: Identifiable {
    let id: UUID
    let timestamp: Date
    let command: DeviceCommand
    let parameters: [String: String]
    let transport: TransportOption
    var result: ExecutionResult?
    var responseData: CommandResponseData

    /// Track whether response details are expanded in UI
    var isExpanded: Bool = false

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        command: DeviceCommand,
        parameters: [String: String],
        transport: TransportOption,
        result: ExecutionResult? = nil,
        responseData: CommandResponseData = .none
    ) {
        self.id = id
        self.timestamp = timestamp
        self.command = command
        self.parameters = parameters
        self.transport = transport
        self.result = result
        self.responseData = responseData
    }

    /// Formatted timestamp for display (HH:mm:ss)
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}
