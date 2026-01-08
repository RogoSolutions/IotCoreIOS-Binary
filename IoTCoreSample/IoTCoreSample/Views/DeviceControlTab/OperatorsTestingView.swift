//
//  OperatorsTestingView.swift
//  IoTCoreSample
//
//  View for testing SDK operators (BLE operations) on a device
//  Part of Device Control Detail - accessible via "Operators Testing" section
//

import SwiftUI
import IotCoreIOS

struct OperatorsTestingView: View {
    @StateObject private var viewModel: OperatorsTestingViewModel
    @Environment(\.dismiss) private var dismiss

    private let device: IoTDevice

    init(device: IoTDevice) {
        self.device = device
        _viewModel = StateObject(wrappedValue: OperatorsTestingViewModel(device: device))
    }

    var body: some View {
        List {
            // Transport Selector
            transportSection

            // Operators List
            operatorsSection

            // Parameter Input Sections (contextual)
            parameterSections

            // Results Section
            resultsSection
        }
        .navigationTitle("Operators Testing")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                loadingOverlay
            }
        }
    }

    // MARK: - Transport Section

    private var transportSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Transport")
                    .font(.headline)

                Picker("Transport", selection: $viewModel.selectedTransport) {
                    ForEach(OperatorTransportType.allCases) { transport in
                        HStack {
                            Image(systemName: transport.icon)
                            Text(transport.displayName)
                        }
                        .tag(transport)
                    }
                }
                .pickerStyle(.segmented)

                // Transport availability info
                HStack(spacing: 4) {
                    if viewModel.selectedTransport.isAvailable {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Available")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text("Coming Soon")
                            .foregroundColor(.orange)
                    }
                }
                .font(.caption)
            }
        } header: {
            Text("Configuration")
        } footer: {
            Text("Select transport method for device communication. Currently only BLE is available.")
        }
    }

    // MARK: - Operators Section

    private var operatorsSection: some View {
        Section {
            ForEach(viewModel.operators) { op in
                operatorRow(op)
            }
        } header: {
            Text("Available Operators")
        } footer: {
            Text("Tap 'Test' to execute an operator. Some operators require parameters configured below.")
        }
    }

    private func operatorRow(_ op: TestableOperator) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: op.icon)
                    .foregroundColor(.blue)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(op.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(op.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Test Button
            Button {
                viewModel.executeOperator(op.id)
            } label: {
                if viewModel.isLoading && viewModel.currentOperationId == op.id {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 50)
                } else {
                    Text("Test")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            viewModel.selectedTransport.isAvailable
                                ? Color.blue
                                : Color.gray
                        )
                        .cornerRadius(6)
                }
            }
            .disabled(!viewModel.selectedTransport.isAvailable || viewModel.isLoading)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Parameter Sections

    @ViewBuilder
    private var parameterSections: some View {
        // WiFi Parameters
        wifiParametersSection

        // Cloud Info Parameters
        cloudInfoParametersSection

        // MQTT Host Parameters
        mqttHostParametersSection

        // Scanned Networks
        scannedNetworksSection
    }

    private var wifiParametersSection: some View {
        Section {
            HStack {
                Text("Interface No")
                    .foregroundColor(.secondary)
                Spacer()
                TextField("0", text: $viewModel.wifiInterfaceNo)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            HStack {
                Text("Scan Duration (s)")
                    .foregroundColor(.secondary)
                Spacer()
                TextField("10", text: $viewModel.wifiScanDuration)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            HStack {
                Text("SSID")
                    .foregroundColor(.secondary)
                Spacer()
                TextField("Network Name", text: $viewModel.wifiSSID)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Password")
                    .foregroundColor(.secondary)
                Spacer()
                SecureField("Password", text: $viewModel.wifiPassword)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("WiFi Parameters")
        } footer: {
            Text("Used by scanWifi and connectWifi operators")
        }
    }

    private var cloudInfoParametersSection: some View {
        Section {
            HStack {
                Text("API URL")
                    .foregroundColor(.secondary)
                Spacer()
                TextField("https://api.example.com", text: $viewModel.cloudApiUrl)
                    .multilineTextAlignment(.trailing)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
            }

            HStack {
                Text("User ID")
                    .foregroundColor(.secondary)
                Spacer()
                TextField("user_123", text: $viewModel.cloudUserId)
                    .multilineTextAlignment(.trailing)
                    .autocapitalization(.none)
            }

            HStack {
                Text("Location ID")
                    .foregroundColor(.secondary)
                Spacer()
                TextField("location_456", text: $viewModel.cloudLocationId)
                    .multilineTextAlignment(.trailing)
                    .autocapitalization(.none)
            }

            HStack {
                Text("Partner ID")
                    .foregroundColor(.secondary)
                Spacer()
                TextField("partner_789", text: $viewModel.cloudPartnerId)
                    .multilineTextAlignment(.trailing)
                    .autocapitalization(.none)
            }
        } header: {
            Text("Cloud Info Parameters")
        } footer: {
            Text("Used by sendCloudInfo operator")
        }
    }

    private var mqttHostParametersSection: some View {
        Section {
            HStack {
                Text("MQTT URL")
                    .foregroundColor(.secondary)
                Spacer()
                TextField("ssl://broker.example.com", text: $viewModel.mqttUrl)
                    .multilineTextAlignment(.trailing)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
            }

            HStack {
                Text("Endpoint")
                    .foregroundColor(.secondary)
                Spacer()
                TextField("/mqtt", text: $viewModel.mqttEndpoint)
                    .multilineTextAlignment(.trailing)
                    .autocapitalization(.none)
            }

            HStack {
                Text("Port")
                    .foregroundColor(.secondary)
                Spacer()
                TextField("8883", text: $viewModel.mqttPort)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
        } header: {
            Text("MQTT Host Parameters")
        } footer: {
            Text("Used by sendMqttHostInfo operator (not yet public API)")
        }
    }

    @ViewBuilder
    private var scannedNetworksSection: some View {
        if !viewModel.scannedNetworks.isEmpty {
            Section {
                ForEach(viewModel.scannedNetworks, id: \.ssid) { network in
                    Button {
                        viewModel.selectNetwork(network)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(network.ssid ?? "Unknown")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                HStack(spacing: 8) {
                                    Text("RSSI: \(network.rssi ?? 0) dBm")
                                    Text("Ch: \(network.channel ?? 0)")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                            if viewModel.wifiSSID == network.ssid {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            } header: {
                Text("Scanned Networks")
            } footer: {
                Text("Tap a network to select it for connection")
            }
        }
    }

    // MARK: - Results Section

    @ViewBuilder
    private var resultsSection: some View {
        if viewModel.lastResult != nil || viewModel.lastError != nil {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Result")
                            .font(.headline)
                        Spacer()
                        Button("Clear") {
                            viewModel.clearResults()
                        }
                        .font(.caption)
                    }

                    if let result = viewModel.lastResult {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(result)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }

                    if let error = viewModel.lastError {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            if let currentOp = viewModel.currentOperationId,
               let op = viewModel.operators.first(where: { $0.id == currentOp }) {
                Text("Running: \(op.name)")
                    .foregroundColor(.white)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        Text("Preview requires actual IoTDevice from API")
    }
}
