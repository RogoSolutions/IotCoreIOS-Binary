//
//  DeviceCommandTestView.swift
//  IoTCoreSample
//
//  View for testing Device Command Handler APIs
//

import SwiftUI

struct DeviceCommandTestView: View {
    @StateObject private var viewModel = DeviceCommandTestViewModel()

    @State private var deviceId = ""
    @State private var groupAddr = ""
    @State private var elements = "[0]"
    @State private var attrValue = "[1, 255, 255, 255]"
    @State private var targetDevType = "1"

    var body: some View {
        List {
            // Device Info Section
            deviceInfoSection

            // Basic Commands
            basicCommandsSection

            // Control Commands
            controlCommandsSection

            // WiFi Commands
            wifiCommandsSection

            // Dangerous Commands
            dangerousCommandsSection

            // Results Section
            resultsSection
        }
        .navigationTitle("Device Commands")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
    }

    // MARK: - Device Info Section

    private var deviceInfoSection: some View {
        Section {
            TextField("Device ID", text: $deviceId)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .placeholder(when: deviceId.isEmpty) {
                    Text("Enter device MAC address")
                        .foregroundColor(.gray)
                }
        } header: {
            Text("Device Information")
        } footer: {
            Text("Enter the device MAC address for testing. Most commands require this.")
                .font(.caption)
        }
    }

    // MARK: - Basic Commands Section

    private var basicCommandsSection: some View {
        Section {
            Button {
                viewModel.getDeviceState(devId: deviceId)
            } label: {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Get Device State")
                }
            }
            .disabled(deviceId.isEmpty)

            HStack {
                TextField("Group Address", text: $groupAddr)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)

                Button {
                    if let groupAddrInt = Int(groupAddr) {
                        viewModel.connectDevice(devId: deviceId, groupAddr: groupAddrInt)
                    }
                } label: {
                    Text("Connect")
                }
                .disabled(deviceId.isEmpty || groupAddr.isEmpty)
            }

            Button {
                viewModel.getDeviceConnectivity(devId: deviceId)
            } label: {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Get Connectivity")
                }
            }
            .disabled(deviceId.isEmpty)
        } header: {
            Text("Basic Commands")
        }
    }

    // MARK: - Control Commands Section

    private var controlCommandsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Elements (JSON array)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("[0, 1, 2]", text: $elements)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .font(.system(.body, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Attribute Values (JSON array)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("[1, 255, 255, 255]", text: $attrValue)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .font(.system(.body, design: .monospaced))
            }

            Button {
                if let elementsArray = parseIntArray(elements),
                   let attrValueArray = parseIntArray(attrValue) {
                    viewModel.controlDevice(
                        devId: deviceId,
                        elements: elementsArray,
                        attrValue: attrValueArray
                    )
                } else {
                    viewModel.lastError = "Invalid JSON format for elements or attributes"
                }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("Control Device")
                }
            }
            .disabled(deviceId.isEmpty)

            // Control Group
            HStack {
                TextField("Group", text: $groupAddr)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 80)

                TextField("Type", text: $targetDevType)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 60)

                Button {
                    if let groupAddrInt = Int(groupAddr),
                       let targetDevTypeInt = Int(targetDevType),
                       let attrValueArray = parseIntArray(attrValue) {
                        viewModel.controlDeviceGroup(
                            groupAddr: groupAddrInt,
                            attrValue: attrValueArray,
                            targetDevType: targetDevTypeInt
                        )
                    }
                } label: {
                    Text("Control Group")
                        .font(.caption)
                }
                .disabled(groupAddr.isEmpty || targetDevType.isEmpty)
            }
        } header: {
            Text("Control Commands")
        } footer: {
            Text("Use JSON array format: [1, 255, 255, 255] for RGB light control.")
                .font(.caption)
        }
    }

    // MARK: - WiFi Commands Section

    private var wifiCommandsSection: some View {
        Section {
            Button {
                viewModel.requestScanWifi(devId: deviceId)
            } label: {
                HStack {
                    Image(systemName: "wifi")
                    Text("Scan WiFi Networks")
                }
            }
            .disabled(deviceId.isEmpty)
        } header: {
            Text("WiFi Commands")
        }
    }

    // MARK: - Dangerous Commands Section

    private var dangerousCommandsSection: some View {
        Section {
            Button {
                viewModel.rebootDevice(devId: deviceId)
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Reboot Device")
                }
                .foregroundColor(.red)
            }
            .disabled(deviceId.isEmpty)

            Button {
                viewModel.resetDevice(devId: deviceId)
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Reset Device (Factory Reset)")
                }
                .foregroundColor(.red)
            }
            .disabled(deviceId.isEmpty)
        } header: {
            Text("Dangerous Commands")
        } footer: {
            Text("⚠️ These commands will reboot or reset the device. Use with caution!")
                .font(.caption)
                .foregroundColor(.red)
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        Section {
            if let error = viewModel.lastError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.vertical, 4)
            }

            if let result = viewModel.lastResult {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Response")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Copy") {
                            UIPasteboard.general.string = result
                        }
                        .font(.caption)
                    }

                    ScrollView {
                        Text(result)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 300)
                }
            }

            if viewModel.lastError != nil || viewModel.lastResult != nil {
                Button("Clear Results") {
                    viewModel.clearResults()
                }
                .foregroundColor(.orange)
            }
        } header: {
            Text("Results")
        }
    }

    // MARK: - Helper Functions

    private func parseIntArray(_ string: String) -> [Int]? {
        guard let data = string.data(using: .utf8),
              let array = try? JSONDecoder().decode([Int].self, from: data) else {
            return nil
        }
        return array
    }
}

// MARK: - TextField Placeholder Extension moved to ViewExtensions.swift

#Preview {
    NavigationView {
        DeviceCommandTestView()
    }
}
