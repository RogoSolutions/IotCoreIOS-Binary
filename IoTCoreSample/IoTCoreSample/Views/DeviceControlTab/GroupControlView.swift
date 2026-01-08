//
//  GroupControlView.swift
//  IoTCoreSample
//
//  Group control view for sending commands to device groups
//

import SwiftUI

struct GroupControlView: View {
    @ObservedObject var viewModel: DeviceControlViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var groupAddress: String = "49153"
    @State private var attrValue: String = "1,255,255,255"
    @State private var targetDevType: String = "0"

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Info Section
                    infoSection

                    // Input Section
                    inputSection

                    // Quick Controls
                    quickControlsSection

                    // Send Button
                    sendButtonSection

                    // Results Section
                    if viewModel.lastOperationResult != nil || viewModel.lastOperationError != nil {
                        resultsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Group Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        viewModel.clearResults()
                    }
                    .disabled(viewModel.lastOperationResult == nil && viewModel.lastOperationError == nil)
                }
            }
            .overlay {
                if viewModel.isLoadingState {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)

                Text("Group Control")
                    .font(.headline)
            }

            Text("Send control commands to all devices in a group. Devices must be bound to the group address to receive commands.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Parameters")
                .font(.headline)

            // Group Address
            VStack(alignment: .leading, spacing: 4) {
                Text("Group Address")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("49153", text: $groupAddress)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)

                Text("Default group addresses start at 49153 (0xC001)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Attribute Values
            VStack(alignment: .leading, spacing: 4) {
                Text("Attribute Values")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("1,255,255,255", text: $attrValue)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.numbersAndPunctuation)

                Text("Format: on/off,R,G,B (e.g., 1,255,0,0 for red)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Target Device Type
            VStack(alignment: .leading, spacing: 4) {
                Text("Target Device Type")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("0", text: $targetDevType)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)

                Text("0 = all devices in group, or specify device type")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Quick Controls Section

    private var quickControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Controls")
                .font(.headline)

            HStack(spacing: 12) {
                // All ON
                Button {
                    attrValue = "1,255,255,255"
                    sendGroupControl()
                } label: {
                    VStack {
                        Image(systemName: "lightbulb.fill")
                            .font(.title2)
                        Text("All ON")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(8)
                }

                // All OFF
                Button {
                    attrValue = "0,0,0,0"
                    sendGroupControl()
                } label: {
                    VStack {
                        Image(systemName: "lightbulb")
                            .font(.title2)
                        Text("All OFF")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.gray)
                    .cornerRadius(8)
                }
            }

            // Color presets
            HStack(spacing: 12) {
                // Red
                Button {
                    attrValue = "1,255,0,0"
                    sendGroupControl()
                } label: {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }

                // Green
                Button {
                    attrValue = "1,0,255,0"
                    sendGroupControl()
                } label: {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }

                // Blue
                Button {
                    attrValue = "1,0,0,255"
                    sendGroupControl()
                } label: {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }

                // White
                Button {
                    attrValue = "1,255,255,255"
                    sendGroupControl()
                } label: {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.gray, lineWidth: 2)
                        )
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Send Button Section

    private var sendButtonSection: some View {
        Button {
            sendGroupControl()
        } label: {
            HStack {
                Image(systemName: "paperplane.fill")
                Text("Send Group Control")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
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

    // MARK: - Actions

    private func sendGroupControl() {
        guard let groupAddrInt = Int(groupAddress) else {
            viewModel.lastOperationError = "Invalid group address"
            return
        }

        guard let attrValueArray = parseIntArray(attrValue) else {
            viewModel.lastOperationError = "Invalid attribute values format"
            return
        }

        let targetDevTypeInt = Int(targetDevType) ?? 0

        viewModel.sendGroupControl(
            groupAddr: groupAddrInt,
            attrValue: attrValueArray,
            targetDevType: targetDevTypeInt
        )
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

// MARK: - Preview

#Preview {
    GroupControlView(viewModel: DeviceControlViewModel())
}
