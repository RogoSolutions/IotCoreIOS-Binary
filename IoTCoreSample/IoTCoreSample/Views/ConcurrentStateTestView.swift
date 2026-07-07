//
//  ConcurrentStateTestView.swift
//  IoTCoreSample
//
//  UI harness to reproduce + verify Bug 2 (crash on concurrent getDeviceState).
//  Sample-app only — does NOT touch SDK production code.
//
//  How to use:
//    1. Log in + select a location (so the device list is populated).
//    2. Open Settings tab → Developer Tools → "Concurrent State (Bug 2)".
//    3. Tap "Load Devices" to fetch the user's devices.
//    4. Set the number of stress rounds, optionally toggle
//       "Include checkFirmwareVersion" (reproduces the device-detail combo).
//    5. Tap "Fire N concurrent getDeviceState".
//       - BEFORE the fix: app is expected to crash mid-run.
//       - AFTER the fix: run completes and shows "PASS (no crash)".
//

import SwiftUI

struct ConcurrentStateTestView: View {
    @StateObject private var viewModel = ConcurrentStateTestViewModel()

    var body: some View {
        List {
            devicesSection
            configSection
            actionsSection
            countersSection
            logSection
        }
        .navigationTitle("Concurrent State")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel.devices.isEmpty {
                viewModel.loadDevices()
            }
        }
    }

    // MARK: - Devices

    private var devicesSection: some View {
        Section {
            HStack {
                Image(systemName: "square.stack.3d.up")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                Text("Devices loaded")
                Spacer()
                if viewModel.isLoadingDevices {
                    ProgressView()
                } else {
                    Text("\(viewModel.devices.count)")
                        .font(.headline)
                        .foregroundColor(viewModel.devices.isEmpty ? .orange : .primary)
                }
            }

            Button {
                viewModel.loadDevices()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise").frame(width: 24)
                    Text("Load Devices")
                }
            }
            .disabled(viewModel.isLoadingDevices || viewModel.isRunning)

            if let err = viewModel.deviceLoadError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        } header: {
            Text("Devices")
        } footer: {
            Text("Requires login + a selected location. All loaded devices are hit simultaneously each round.")
                .font(.caption)
        }
    }

    // MARK: - Config

    private var configSection: some View {
        Section {
            HStack {
                Text("Stress rounds")
                Spacer()
                TextField("5", text: $viewModel.roundsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle(isOn: $viewModel.includeFirmwareCheck) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Include checkFirmwareVersion")
                    Text("Fires getDeviceState + version check together (detail-screen combo)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(viewModel.isRunning)
        } header: {
            Text("Stress Configuration")
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section {
            Button {
                viewModel.fireConcurrent()
            } label: {
                HStack {
                    if viewModel.isRunning {
                        ProgressView().frame(width: 24)
                    } else {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                    }
                    Text(fireButtonTitle)
                        .fontWeight(.semibold)
                }
            }
            .disabled(viewModel.isRunning || viewModel.devices.isEmpty)

            Button {
                viewModel.clearLog()
            } label: {
                HStack {
                    Image(systemName: "trash").frame(width: 24)
                    Text("Clear Log")
                }
                .foregroundColor(.red)
            }
            .disabled(viewModel.isRunning)
        }
    }

    private var fireButtonTitle: String {
        let rounds = max(1, Int(viewModel.roundsText.trimmingCharacters(in: .whitespaces)) ?? 1)
        let perDevice = viewModel.includeFirmwareCheck ? 2 : 1
        let count = rounds * viewModel.devices.count * perDevice
        return "Fire \(count) concurrent calls"
    }

    // MARK: - Counters

    private var countersSection: some View {
        Section {
            statusRow

            counterRow(label: "Fired", value: viewModel.totalFired, color: .blue)
            counterRow(label: "Completed", value: viewModel.completedCount, color: .primary,
                       trailing: "/ \(viewModel.expectedCount)")
            counterRow(label: "Success", value: viewModel.successCount, color: .green)
            counterRow(label: "Error", value: viewModel.errorCount, color: .orange)

            if viewModel.passedNoCrash {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("PASS (no crash)")
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        } header: {
            Text("Results")
        }
    }

    private var statusRow: some View {
        HStack(alignment: .top) {
            Image(systemName: viewModel.isRunning ? "hourglass" : "info.circle")
                .foregroundColor(viewModel.isRunning ? .orange : .secondary)
                .frame(width: 24)
            Text(viewModel.statusText)
                .font(.subheadline)
        }
    }

    private func counterRow(label: String, value: Int, color: Color, trailing: String = "") -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(value)\(trailing.isEmpty ? "" : " ")\(trailing)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(color)
        }
    }

    // MARK: - Log

    private var logSection: some View {
        Section {
            if viewModel.logLines.isEmpty {
                Text("No callbacks yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.logLines) { line in
                    Text(line.text)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        } header: {
            Text("Callback Log (newest first)")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ConcurrentStateTestView()
    }
}
