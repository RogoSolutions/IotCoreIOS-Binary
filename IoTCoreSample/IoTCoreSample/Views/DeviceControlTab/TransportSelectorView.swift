//
//  TransportSelectorView.swift
//  IoTCoreSample
//
//  Transport selection component for device control
//  Allows switching between BLE, MQTT, and Auto transport modes
//

import SwiftUI
import UIKit

// MARK: - Transport Option

/// Available transport options for device communication
enum TransportOption: String, CaseIterable, Identifiable {
    case ble = "BLE"
    case mqtt = "MQTT"
    case auto = "Auto"

    var id: String { rawValue }

    /// Display name for the transport option
    var displayName: String {
        switch self {
        case .ble:
            return "BLE"
        case .mqtt:
            return "MQTT"
        case .auto:
            return "Auto"
        }
    }

    /// Description text explaining the transport option
    var description: String {
        switch self {
        case .ble:
            return "Direct Bluetooth Low Energy connection. Best for nearby devices with low latency."
        case .mqtt:
            return "Cloud-based MQTT connection. Works from anywhere with internet access."
        case .auto:
            return "Automatically selects the best available transport based on connectivity."
        }
    }

    /// Icon for the transport option
    var icon: String {
        switch self {
        case .ble:
            return "antenna.radiowaves.left.and.right"
        case .mqtt:
            return "cloud"
        case .auto:
            return "arrow.triangle.branch"
        }
    }
}

// MARK: - Connection Status

/// Connection status for a transport channel
enum ConnectionStatus: Equatable {
    case connected
    case connecting
    case disconnected
    case unavailable

    /// Display text for the status
    var displayText: String {
        switch self {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .unavailable:
            return "Unavailable"
        }
    }

    /// Color associated with the status
    var color: Color {
        switch self {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected:
            return .gray
        case .unavailable:
            return .red
        }
    }

    /// Whether the status indicates an active connection
    var isActive: Bool {
        switch self {
        case .connected, .connecting:
            return true
        case .disconnected, .unavailable:
            return false
        }
    }
}

// MARK: - Transport Selector View

/// A view component for selecting transport mode with connection status indicators
struct TransportSelectorView: View {
    @Binding var selectedTransport: TransportOption
    let bleStatus: ConnectionStatus
    let mqttStatus: ConnectionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            Text("Transport")
                .font(.headline)

            // Segmented Picker
            Picker("Transport", selection: $selectedTransport) {
                ForEach(TransportOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)

            // Status Indicators
            HStack(spacing: 16) {
                statusBadge(label: "BLE", status: bleStatus)
                statusBadge(label: "MQTT", status: mqttStatus)
                Spacer()
            }

            // Description for Selected Option
            descriptionView
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
    }

    // MARK: - Status Badge

    private func statusBadge(label: String, status: ConnectionStatus) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption)
                .fontWeight(.medium)

            Text(status.displayText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(UIColor.systemGray5))
        .cornerRadius(6)
    }

    // MARK: - Description View

    private var descriptionView: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: selectedTransport.icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(selectedTransport.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview("All States") {
    VStack(spacing: 20) {
        TransportSelectorView(
            selectedTransport: .constant(.auto),
            bleStatus: .connected,
            mqttStatus: .connected
        )

        TransportSelectorView(
            selectedTransport: .constant(.ble),
            bleStatus: .connecting,
            mqttStatus: .disconnected
        )

        TransportSelectorView(
            selectedTransport: .constant(.mqtt),
            bleStatus: .unavailable,
            mqttStatus: .connected
        )
    }
    .padding()
}

#Preview("Default State") {
    TransportSelectorView(
        selectedTransport: .constant(.auto),
        bleStatus: .disconnected,
        mqttStatus: .disconnected
    )
    .padding()
}
