//
//  OperationTestView.swift
//  IoTCoreSample
//
//  Created on 2025-12-11.
//  View for testing Operations with connection management
//

import SwiftUI
import CoreBluetooth
import IotCoreIOS

struct OperationTestView: View {
    @StateObject private var viewModel = OperationTestViewModel()
    @State private var showingOperationPicker = false
    @State private var showingDevicePicker = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Section
                    connectionSection

                    // Connection Status Alert
                    if !viewModel.isConnectionReady {
                        connectionRequiredAlert
                    }

                    // Selected Operation
                    selectedOperationSection

                    // Parameters Form
                    if let operation = viewModel.selectedOperation, operation.hasParameters {
                        parametersSection(operation: operation)
                    }

                    // Execute Button
                    executeButton

                    // Results
                    resultsSection

                    // Execution Log
                    logSection
                }
                .padding()
            }
            .navigationTitle("Operation Tester")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.clearLog()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .sheet(isPresented: $showingOperationPicker) {
                OperationPickerView(viewModel: viewModel, isPresented: $showingOperationPicker)
            }
            .sheet(isPresented: $showingDevicePicker) {
                DevicePickerView(viewModel: viewModel, isPresented: $showingDevicePicker)
            }
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BLE Connection")
                .font(.headline)

            // Connection Status
            HStack {
                Circle()
                    .fill(connectionStatusColor)
                    .frame(width: 10, height: 10)

                Text(viewModel.connectionState.displayText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                if case .connecting = viewModel.connectionState {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(Color(.systemGray5))
            .cornerRadius(8)

            // Connected Device Info
            if let device = viewModel.connectedDevice {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connected Device")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(device.name ?? "Unknown Device")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("RSSI: \(device.rssi) dBm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            // Connection Buttons
            HStack(spacing: 12) {
                if viewModel.connectionState.isConnected {
                    Button {
                        viewModel.disconnect()
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button {
                        showingDevicePicker = true
                    } label: {
                        Label("Scan & Connect", systemImage: "antenna.radiowaves.left.and.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled({
                        if case .connecting = viewModel.connectionState {
                            return true
                        }
                        return false
                    }())
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private var connectionStatusColor: Color {
        switch viewModel.connectionState {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }

    // MARK: - Connection Required Alert

    private var connectionRequiredAlert: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Connection Required")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Connect to a device to execute operations")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - Selected Operation Section

    private var selectedOperationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Selected Operation")
                    .font(.headline)

                Spacer()

                Button("Choose") {
                    showingOperationPicker = true
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isConnectionReady)
            }

            if let operation = viewModel.selectedOperation {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: operation.category.icon)
                            .foregroundColor(.blue)

                        Text(operation.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Spacer()
                    }

                    Text(operation.description)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Label(operation.category.rawValue, systemImage: "folder")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        if operation.hasParameters {
                            Label("\(operation.parameters.count) params", systemImage: "list.bullet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Label("No params", systemImage: "checkmark.circle")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text(viewModel.isConnectionReady ? "Tap 'Choose' to select an operation" : "Connect first to select operations")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    // MARK: - Parameters Section

    private func parametersSection(operation: OperationDefinition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parameters")
                .font(.headline)

            ForEach(operation.parameters, id: \.name) { param in
                parameterField(param)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private func parameterField(_ param: OperationParameter) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(param.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if param.isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }

                Spacer()

                Text(param.type == .intArray ? "Array" : param.type == .int ? "Int" : "String")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TextField(
                param.placeholder.isEmpty ? "Enter \(param.name)" : param.placeholder,
                text: Binding(
                    get: { viewModel.parameterValues[param.name] ?? "" },
                    set: { viewModel.parameterValues[param.name] = $0 }
                )
            )
            .textFieldStyle(.roundedBorder)
            .autocapitalization(.none)
        }
    }

    // MARK: - Execute Button

    private var executeButton: some View {
        Button {
            viewModel.executeOperation()
        } label: {
            HStack {
                if viewModel.isExecuting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "play.fill")
                }

                Text(viewModel.isExecuting ? "Executing..." : "Execute Operation")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.canExecute ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(!viewModel.canExecute)
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Result")
                    .font(.headline)

                Spacer()

                if !viewModel.lastResult.isEmpty || !viewModel.lastError.isEmpty {
                    Button("Clear") {
                        viewModel.clearResults()
                    }
                    .font(.caption)
                }
            }

            if !viewModel.lastResult.isEmpty {
                HStack(alignment: .top) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Text(viewModel.lastResult)
                        .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }

            if !viewModel.lastError.isEmpty {
                HStack(alignment: .top) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)

                    Text(viewModel.lastError)
                        .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            if viewModel.lastResult.isEmpty && viewModel.lastError.isEmpty {
                Text("No results yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    // MARK: - Log Section

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Execution Log")
                .font(.headline)

            if viewModel.executionLog.isEmpty {
                Text("No logs yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(viewModel.executionLog.enumerated().reversed()), id: \.offset) { _, log in
                            Text(log)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 200)
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Device Picker View

struct DevicePickerView: View {
    @ObservedObject var viewModel: OperationTestViewModel
    @Binding var isPresented: Bool
    @StateObject private var discoveryViewModel = DiscoveryViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats Header
                if discoveryViewModel.isScanning || !discoveryViewModel.discoveredDevices.isEmpty {
                    HStack(spacing: 20) {
                        HStack(spacing: 4) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.caption)
                            Text("\(discoveryViewModel.discoveredDevices.count) devices")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if discoveryViewModel.isScanning {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Scanning...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                }

                // Device List
                if discoveryViewModel.discoveredDevices.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Spacer()

                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)

                        Text("No Devices Found")
                            .font(.headline)

                        Text(discoveryViewModel.isScanning ? "Searching for devices..." : "Tap refresh to scan")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                } else {
                    List {
                        ForEach(discoveryViewModel.discoveredDevices) { device in
                            Button {
                                // Convert DiscoveredDevice to RGBDiscoveredBLEDevice
                                let rgbDevice = RGBDiscoveredBLEDevice(
                                    macAddress: device.macAddr,
                                    productId: device.productId,
                                    deviceCategoryType: .UNKNOW,
                                    name: device.displayName,
                                    peripheral: device.peripheral,
                                    rssi: device.rssi,
                                    advertisementData: device.advertisementData
                                )
                                viewModel.connectToDevice(rgbDevice)
                                isPresented = false
                            } label: {
                                DevicePickerRow(device: device)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Select Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if discoveryViewModel.isScanning {
                            discoveryViewModel.stopScanning()
                        } else {
                            discoveryViewModel.startScanning()
                        }
                    } label: {
                        Image(systemName: discoveryViewModel.isScanning ? "stop.circle" : "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                discoveryViewModel.startScanning()
            }
            .onDisappear {
                discoveryViewModel.stopScanning()
            }
        }
    }
}

// MARK: - Device Picker Row

struct DevicePickerRow: View {
    let device: DiscoveredDevice

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(device.type.color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: device.type.icon)
                    .font(.title3)
                    .foregroundColor(device.type.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    // Type Badge
                    Text(device.type.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(device.type.color.opacity(0.2))
                        .foregroundColor(device.type.color)
                        .cornerRadius(4)

                    // Category Badge
                    if let category = device.categoryName {
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }

                    // MAC
                    if let mac = device.macAddr {
                        Text(mac)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // RSSI Indicator
            VStack(alignment: .trailing, spacing: 4) {
                // Signal Bars
                HStack(spacing: 2) {
                    ForEach(1...4, id: \.self) { bar in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(bar <= device.signalBars ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 4, height: CGFloat(bar * 4))
                    }
                }

                Text("\(device.rssi) dBm")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Operation Picker View

struct OperationPickerView: View {
    @ObservedObject var viewModel: OperationTestViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.operationsByCategory, id: \.0) { category, operations in
                    Section {
                        ForEach(operations) { operation in
                            Button {
                                viewModel.selectOperation(operation)
                                isPresented = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(operation.displayName)
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        Text(operation.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        if operation.hasParameters {
                                            Text("\(operation.parameters.count) parameters")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                        }
                                    }

                                    Spacer()

                                    if viewModel.selectedOperation?.id == operation.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }
            }
            .navigationTitle("Select Operation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct OperationTestView_Previews: PreviewProvider {
    static var previews: some View {
        OperationTestView()
    }
}
