//
//  DeviceControlDetailView.swift
//  IoTCoreSample
//
//  Device detail view with control options
//

import SwiftUI

struct DeviceControlDetailView: View {
    let device: IoTDevice
    @ObservedObject var viewModel: DeviceControlViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingRebootConfirm = false
    @State private var showingResetConfirm = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Device Info Card
                deviceInfoCard

                // State Section
                stateSection

                // Control Section
                controlSection

                // Network Section
                networkSection

                // System Actions Section
                systemActionsSection

                // Operators Testing Section
                operatorsTestingSection

                // Results Section
                resultsSection
            }
            .padding()
        }
        .navigationTitle(device.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.selectDevice(device)
        }
        .overlay {
            if viewModel.isLoadingState {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .alert("Reboot Device?", isPresented: $showingRebootConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Reboot", role: .destructive) {
                viewModel.rebootDevice()
            }
        } message: {
            Text("The device will restart. This may take a few seconds.")
        }
        .alert("Reset Device?", isPresented: $showingResetConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                viewModel.resetDevice()
            }
        } message: {
            Text("This will reset the device to factory defaults. All settings will be lost.")
        }
        .alert("Delete Device?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteDevice { success in
                    if success {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This will permanently delete the device from your account. This action cannot be undone.")
        }
    }

    // MARK: - Device Info Card

    private var deviceInfoCard: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: device.displayIcon)
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
            }

            // Name
            Text(device.displayName)
                .font(.title2)
                .fontWeight(.bold)

            // Product Info
            if let productId = device.productId {
                Text(productId)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Device Details
            VStack(spacing: 8) {
                if let mac = device.mac {
                    HStack {
                        Text("MAC:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(mac)
                            .font(.system(.caption, design: .monospaced))
                    }
                }

                if let firmVer = device.firmVer {
                    HStack {
                        Text("Firmware:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(firmVer)
                            .font(.caption)
                    }
                }

                HStack {
                    Text("UUID:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(device.id)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - State Section

    private var stateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device State")
                .font(.headline)

            Button {
                viewModel.getDeviceState()
            } label: {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Get Current State")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }

            if !viewModel.stateDescription.isEmpty {
                Text(viewModel.stateDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Control Section

    private var controlSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Control")
                .font(.headline)

            // Elements Input
            VStack(alignment: .leading, spacing: 4) {
                Text("Elements")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("0 or 0,1,2", text: $viewModel.controlElements)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.numbersAndPunctuation)
            }

            // Attribute Values Input
            VStack(alignment: .leading, spacing: 4) {
                Text("Attribute Values")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("1,255,255,255", text: $viewModel.controlAttrValue)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.numbersAndPunctuation)

                Text("Format: on/off,R,G,B (e.g., 1,255,0,0 for red)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Quick Controls
            HStack(spacing: 12) {
                Button {
                    viewModel.controlAttrValue = "1,255,255,255"
                    viewModel.sendControl()
                } label: {
                    VStack {
                        Image(systemName: "power")
                            .font(.title2)
                        Text("ON")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(8)
                }

                Button {
                    viewModel.controlAttrValue = "0,0,0,0"
                    viewModel.sendControl()
                } label: {
                    VStack {
                        Image(systemName: "power")
                            .font(.title2)
                        Text("OFF")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.gray)
                    .cornerRadius(8)
                }
            }

            // Send Control Button
            Button {
                viewModel.sendControl()
            } label: {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Send Control")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Network Section

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network")
                .font(.headline)

            Button {
                viewModel.getConnectivity()
            } label: {
                HStack {
                    Image(systemName: "wifi")
                    Text("Get Connectivity Status")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple.opacity(0.1))
                .foregroundColor(.purple)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - System Actions Section

    private var systemActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Actions")
                .font(.headline)

            HStack(spacing: 12) {
                // Reboot Button
                Button {
                    showingRebootConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reboot")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
                }

                // Reset Button
                Button {
                    showingResetConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
                }
            }

            // Delete Button (full width, more prominent)
            Button {
                showingDeleteConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete Device")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(8)
            }

            Text("Reboot restarts the device. Reset restores factory defaults. Delete removes the device from your account.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Operators Testing Section

    private var operatorsTestingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Operators Testing")
                .font(.headline)

            NavigationLink {
                OperatorsTestingView(device: device)
            } label: {
                HStack {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Test SDK Operators")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.teal.opacity(0.1))
                .foregroundColor(.teal)
                .cornerRadius(8)
            }

            Text("Test individual SDK operations like certificates, WiFi scanning, cloud info, and device identification.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        Group {
            if viewModel.lastOperationResult != nil || viewModel.lastOperationError != nil {
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

                    if let result = viewModel.lastOperationResult {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)

                            Text(result)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }

                    if let error = viewModel.lastOperationError {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)

                            Text(error)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    // Note: Preview uses a mock IoTDevice. In real app, IoTDevice comes from API.
    NavigationView {
        Text("Preview requires actual IoTDevice from API")
    }
}
