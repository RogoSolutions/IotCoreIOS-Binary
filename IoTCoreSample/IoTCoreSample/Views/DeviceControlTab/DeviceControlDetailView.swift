//
//  DeviceControlDetailView.swift
//  IoTCoreSample
//
//  Device detail view with collapsible sections for control options
//

import SwiftUI
import IotCoreIOS

struct DeviceControlDetailView: View {
    let device: IoTDevice
    @ObservedObject var viewModel: DeviceControlViewModel
    @Environment(\.presentationMode) private var presentationMode

    // MARK: - Alert State
    @State private var showingRebootConfirm = false
    @State private var showingResetConfirm = false
    @State private var showingDeleteConfirm = false

    // MARK: - UI State for Collapsible Sections
    @State private var selectedCommand: DeviceCommand? = nil
    @State private var parameterValues: [String: String] = [:]
    @State private var expandedSections: Set<String> = ["quickActions", "history"]
    @State private var expandedCategories: Set<String> = []

    // MARK: - Command Execution State
    @State private var isExecutingCommand = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 1. Device Info Header (compact, always visible)
                deviceInfoHeader

                // 2. Transport Selector (global, always visible)
                TransportSelectorView(
                    selectedTransport: $viewModel.selectedTransport,
                    bleStatus: viewModel.bleStatus,
                    mqttStatus: viewModel.mqttStatus
                )

                // 2.1 Transport Action Buttons
                transportActionButtons

                // 3. Quick Actions (collapsible)
                quickActionsSection

                // 4. All Commands (collapsible)
                allCommandsSection

                // 5. System Actions (collapsible)
                systemActionsSection

                // 6. Execution History (collapsible)
                executionHistorySection
            }
            .padding()
        }
        .navigationTitle(device.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.selectDevice(device)
            viewModel.updateTransportStatus()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isLoadingState || isExecutingCommand {
                    ProgressView()
                        .scaleEffect(0.8)
                }
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
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        } message: {
            Text("This will permanently delete the device from your account. This action cannot be undone.")
        }
    }

    // MARK: - Section Expansion Binding Helper

    private func binding(for section: String) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section) },
            set: { isExpanded in
                if isExpanded {
                    expandedSections.insert(section)
                } else {
                    expandedSections.remove(section)
                }
            }
        )
    }

    private func categoryBinding(for category: String) -> Binding<Bool> {
        Binding(
            get: { expandedCategories.contains(category) },
            set: { isExpanded in
                if isExpanded {
                    expandedCategories.insert(category)
                } else {
                    expandedCategories.remove(category)
                }
            }
        )
    }

    // MARK: - 1. Device Info Header (Compact)

    private var deviceInfoHeader: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 56, height: 56)

                Image(systemName: device.displayIcon)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.headline)
                    .lineLimit(1)

                if let productId = device.productId {
                    Text(productId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let mac = device.mac {
                    Text(mac)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Firmware badge
            if let firmVer = device.firmVer {
                Text("v\(firmVer)")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 2.1 Transport Action Buttons

    private var transportActionButtons: some View {
        HStack(spacing: 12) {
            // Scan BLE Button
            Button {
                viewModel.startBLEScan()
            } label: {
                Label("Scan BLE", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            // Connect MQTT Button
            Button {
                viewModel.reconnectMQTT()
            } label: {
                Label("Connect MQTT", systemImage: "cloud")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 3. Quick Actions Section (Collapsible)

    private var quickActionsSection: some View {
        VStack(spacing: 0) {
            DisclosureGroup(isExpanded: binding(for: "quickActions")) {
                VStack(spacing: 12) {
                    // ON / OFF / Get State buttons
                    HStack(spacing: 12) {
                        // ON Button
                        Button {
                            executeQuickAction(attrValue: "1,255,255,255")
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "power")
                                    .font(.title2)
                                Text("ON")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(10)
                        }

                        // OFF Button
                        Button {
                            executeQuickAction(attrValue: "0,0,0,0")
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "power")
                                    .font(.title2)
                                Text("OFF")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.gray.opacity(0.15))
                            .foregroundColor(.gray)
                            .cornerRadius(10)
                        }

                        // Get State Button
                        Button {
                            viewModel.getDeviceState()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.title2)
                                Text("State")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(10)
                        }
                    }

                    // State description if available
                    if !viewModel.stateDescription.isEmpty {
                        Text(viewModel.stateDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }

                    // Last result or error
                    if let result = viewModel.lastOperationResult {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(result)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }

                    if let error = viewModel.lastOperationError {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.top, 12)
            } label: {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.orange)
                    Text("Quick Actions")
                        .font(.headline)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 4. All Commands Section (Collapsible)

    private var allCommandsSection: some View {
        VStack(spacing: 0) {
            DisclosureGroup(isExpanded: binding(for: "allCommands")) {
                VStack(spacing: 8) {
                    // 8 category groups with nested commands
                    ForEach(CommandCategory.allCases.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { category in
                        commandCategoryGroup(category)
                    }

                    // Show parameter form when command selected
                    if let command = selectedCommand {
                        Divider()
                            .padding(.vertical, 8)

                        selectedCommandForm(command: command)
                    }
                }
                .padding(.top, 12)
            } label: {
                HStack {
                    Image(systemName: "terminal")
                        .foregroundColor(.teal)
                    Text("All Commands")
                        .font(.headline)
                    Spacer()
                    Text("24")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    private func commandCategoryGroup(_ category: CommandCategory) -> some View {
        let commands = DeviceCommand.commands(in: category)

        return DisclosureGroup(isExpanded: categoryBinding(for: category.rawValue)) {
            VStack(spacing: 4) {
                ForEach(commands) { command in
                    commandRow(command)
                }
            }
            .padding(.leading, 8)
        } label: {
            HStack {
                Image(systemName: category.icon)
                    .frame(width: 20)
                    .foregroundColor(.secondary)
                Text(category.rawValue)
                    .font(.subheadline)
                Spacer()
                Text("\(commands.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func commandRow(_ command: DeviceCommand) -> some View {
        Button {
            selectCommand(command)
        } label: {
            HStack {
                Text(command.displayName)
                    .font(.subheadline)
                    .foregroundColor(selectedCommand == command ? .blue : .primary)
                Spacer()
                if selectedCommand == command {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(selectedCommand == command ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func selectedCommandForm(command: DeviceCommand) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Command header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(command.displayName)
                        .font(.headline)
                    Text(command.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    selectedCommand = nil
                    parameterValues.removeAll()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }

            // Parameter form
            CommandParameterFormView(
                command: command,
                deviceId: device.id,
                parameterValues: $parameterValues
            )

            // Execute button
            Button {
                executeSelectedCommand(command)
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Execute")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isExecutingCommand)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
    }

    // MARK: - 5. System Actions Section (Collapsible)

    private var systemActionsSection: some View {
        VStack(spacing: 0) {
            DisclosureGroup(isExpanded: binding(for: "systemActions")) {
                VStack(spacing: 12) {
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
                            .background(Color.orange.opacity(0.15))
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
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .cornerRadius(8)
                        }
                    }

                    // Delete Button (full width)
                    Button {
                        showingDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete Device")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                    }

                    Text("Reboot restarts the device. Reset restores factory defaults. Delete removes the device from your account.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 12)
            } label: {
                HStack {
                    Image(systemName: "gearshape.2")
                        .foregroundColor(.purple)
                    Text("System Actions")
                        .font(.headline)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 6. Execution History Section (Collapsible)

    private var executionHistorySection: some View {
        VStack(spacing: 0) {
            DisclosureGroup(isExpanded: binding(for: "history")) {
                VStack(spacing: 8) {
                    if viewModel.executionHistory.isEmpty {
                        Text("No commands executed yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        // Clear history button
                        HStack {
                            Spacer()
                            Button("Clear History") {
                                viewModel.clearHistory()
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 4)

                        // History list
                        ForEach(viewModel.executionHistory) { execution in
                            executionRow(execution)
                        }
                    }
                }
                .padding(.top, 12)
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.indigo)
                    Text("Execution History")
                        .font(.headline)
                    Spacer()
                    if !viewModel.executionHistory.isEmpty {
                        Text("\(viewModel.executionHistory.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    private func executionRow(_ execution: CommandExecution) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Result indicator
                Image(systemName: execution.result?.isSuccess == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(execution.result?.isSuccess == true ? .green : .red)
                    .font(.caption)

                // Command name
                Text(execution.command.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                // Expand/collapse button for response data
                if execution.responseData.hasData {
                    Button {
                        viewModel.toggleHistoryExpanded(execution.id)
                    } label: {
                        Image(systemName: execution.isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Timestamp
                Text(execution.formattedTimestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Transport badge and copy button
            HStack {
                Text(execution.transport.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)

                // Show "Has Data" badge if response data exists
                if execution.responseData.hasData {
                    Text("Has Data")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(4)
                }

                Spacer()

                // Copy to clipboard button
                if execution.responseData.hasData {
                    Button {
                        copyResponseToClipboard(execution)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            // Result message
            if let result = execution.result {
                Text(result.message)
                    .font(.caption)
                    .foregroundColor(result.isSuccess ? .secondary : .red)
                    .lineLimit(execution.isExpanded ? nil : 2)
            }

            // Expanded response data view
            if execution.isExpanded && execution.responseData.hasData {
                ResponseDataView(responseData: execution.responseData)
            }
        }
        .padding(10)
        .background(Color(UIColor.systemGray5))
        .cornerRadius(8)
    }

    /// Copy response data to clipboard
    private func copyResponseToClipboard(_ execution: CommandExecution) {
        let text = execution.responseData.formattedDescription
        UIPasteboard.general.string = text
        // Show brief feedback via lastOperationResult
        viewModel.lastOperationResult = "Response copied to clipboard"
    }

    // MARK: - Command Execution

    private func selectCommand(_ command: DeviceCommand) {
        selectedCommand = command
        parameterValues.removeAll()
        // Initialize with default values and device ID
        for param in command.parameters {
            if param.name == "devId" {
                parameterValues[param.name] = device.id
            } else if !param.defaultValue.isEmpty {
                parameterValues[param.name] = param.defaultValue
            }
        }
    }

    private func executeQuickAction(attrValue: String) {
        viewModel.controlAttrValue = attrValue
        viewModel.controlElements = "0"
        viewModel.sendControl()
    }

    private func executeSelectedCommand(_ command: DeviceCommand) {
        guard let sdk = IoTAppCore.current else {
            viewModel.lastOperationError = "SDK not initialized"
            return
        }

        isExecutingCommand = true

        Task {
            do {
                let result = try await executeCommandAsync(command, handler: sdk.deviceCmdHandler)
                await MainActor.run {
                    viewModel.lastOperationResult = result
                    viewModel.lastOperationError = nil
                    viewModel.addToHistory(
                        command: command.rawValue,
                        parameters: parameterValues,
                        result: result,
                        isSuccess: true
                    )
                    isExecutingCommand = false
                }
            } catch {
                await MainActor.run {
                    viewModel.lastOperationError = error.localizedDescription
                    viewModel.lastOperationResult = nil
                    viewModel.addToHistory(
                        command: command.rawValue,
                        parameters: parameterValues,
                        result: error.localizedDescription,
                        isSuccess: false
                    )
                    isExecutingCommand = false
                }
            }
        }
    }

    // MARK: - Command Execution Async

    private func executeCommandAsync(_ command: DeviceCommand, handler: RGBIotDeviceCmdHandler) async throws -> String {
        switch command {
        case .getDeviceState:
            return try await executeGetDeviceState(handler: handler)
        case .controlDevice:
            return try await executeControlDevice(handler: handler)
        case .controlDeviceGroup:
            return try await executeControlDeviceGroup(handler: handler)
        case .controlDeviceLocation:
            return try await executeControlDeviceLocation(handler: handler)
        case .settingAttribute:
            return try await executeSettingAttribute(handler: handler)
        case .setCountdown:
            return try await executeSetCountdown(handler: handler)
        case .connect:
            return try await executeConnect(handler: handler)
        case .unbindDeviceGroup:
            return try await executeUnbindDeviceGroup(handler: handler)
        case .requestScanWifi:
            return try await executeRequestScanWifi(handler: handler)
        case .requestConnectWifi:
            return try await executeRequestConnectWifi(handler: handler)
        case .activeSmart:
            return executeActiveSmart(handler: handler)
        case .bindDeviceSmartTrigger:
            return try await executeBindDeviceSmartTrigger(handler: handler)
        case .unbindDeviceSmartTrigger:
            return try await executeUnbindDeviceSmartTrigger(handler: handler)
        case .bindDeviceSmartCmd:
            return try await executeBindDeviceSmartCmd(handler: handler)
        case .unbindDeviceSmartCmd:
            return try await executeUnbindDeviceSmartCmd(handler: handler)
        case .sendVendorMsgBytes:
            return executeSendVendorMsgBytes(handler: handler)
        case .sendVendorMsgJson:
            return executeSendVendorMsgJson(handler: handler)
        case .startWileDirectBle:
            return try await executeStartWileDirectBle(handler: handler)
        case .stopWileDirectBle:
            return executeStopWileDirectBle(handler: handler)
        case .checkDeviceSoftwareVersion:
            return executeCheckDeviceSoftwareVersion(handler: handler)
        case .updateDeviceSoftware:
            return executeUpdateDeviceSoftware(handler: handler)
        case .resetDevice:
            return try await executeResetDevice(handler: handler)
        case .rebootDevice:
            return try await executeRebootDevice(handler: handler)
        case .getLogAttrBlocks:
            return try await executeGetLogAttrBlocks(handler: handler)
        }
    }

    // MARK: - Device State & Control Commands
    // TODO: T-832 - Fix timeout handling properly

    private func executeGetDeviceState(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let devId = parameterValues["devId"] ?? device.id
        return try await withCheckedThrowingContinuation { continuation in
            handler.getDeviceState(devId: devId) { result in
                switch result {
                case .success(let state):
                    continuation.resume(returning: "Device state retrieved: \(state)")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeControlDevice(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let devId = parameterValues["devId"] ?? device.id
        let elements = parseIntArray(parameterValues["elements"] ?? "0")
        // Combine attribute and values into attrValue array
        let attribute = Int(parameterValues["attribute"] ?? "1") ?? 1
        let values = parseIntArray(parameterValues["values"] ?? "")
        let attrValue = [attribute] + values
        return try await withCheckedThrowingContinuation { continuation in
            handler.controlDevice(devId: devId, elements: elements, attrValue: attrValue) { result in
                switch result {
                case .success(let ack):
                    continuation.resume(returning: "Control sent successfully. ACK: \(ack)")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeControlDeviceGroup(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let groupAddr = Int(parameterValues["groupAddr"] ?? "49153") ?? 49153
        // Combine attribute and values into attrValue array
        let attribute = Int(parameterValues["attribute"] ?? "1") ?? 1
        let values = parseIntArray(parameterValues["values"] ?? "")
        let attrValue = [attribute] + values
        let targetDevType = Int(parameterValues["targetDevType"] ?? "0") ?? 0
        return try await withCheckedThrowingContinuation { continuation in
            handler.controlDeviceGroup(groupAddr: groupAddr, attrValue: attrValue, targetDevType: targetDevType) { result in
                switch result {
                case .success(let ack):
                    continuation.resume(returning: "Group control sent. ACK: \(ack)")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeControlDeviceLocation(handler: RGBIotDeviceCmdHandler) async throws -> String {
        // Combine attribute and values into attrValue array
        let attribute = Int(parameterValues["attribute"] ?? "1") ?? 1
        let values = parseIntArray(parameterValues["values"] ?? "")
        let attrValue = [attribute] + values
        let targetDevType = Int(parameterValues["targetDevType"] ?? "0") ?? 0
        return try await withCheckedThrowingContinuation { continuation in
            handler.controlDeviceLocation(attrValue: attrValue, targetDevType: targetDevType) { result in
                switch result {
                case .success(let ack):
                    continuation.resume(returning: "Location control sent. ACK: \(ack)")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeSettingAttribute(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let devId = parameterValues["devId"] ?? device.id
        let element = Int(parameterValues["element"] ?? "0") ?? 0
        let attrValue = parseIntArray(parameterValues["attrValue"] ?? "")
        return try await withCheckedThrowingContinuation { continuation in
            handler.settingAttribute(devId: devId, element: element, attrValue: attrValue) { result in
                switch result {
                case .success(let ack):
                    continuation.resume(returning: "Setting applied. ACK: \(ack)")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeSetCountdown(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let devId = parameterValues["devId"] ?? device.id
        let elements = parseIntArray(parameterValues["elements"] ?? "0")
        let attrValueStart = parseIntArray(parameterValues["attrValueStart"] ?? "")
        let attrValueStop = parseIntArray(parameterValues["attrValueStop"] ?? "")
        let minutes = Int(parameterValues["minutes"] ?? "30") ?? 30
        return try await withCheckedThrowingContinuation { continuation in
            handler.setCountdown(
                devId: devId,
                elements: elements,
                attrValueStart: attrValueStart,
                attrValueStop: attrValueStop,
                minutes: minutes
            ) { result in
                switch result {
                case .success(let ack):
                    continuation.resume(returning: "Countdown set for \(minutes) minutes. ACK: \(ack)")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Connection & Binding Commands

    private func executeConnect(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let devId = parameterValues["devId"] ?? device.id
        let groupAddr = Int(parameterValues["groupAddr"] ?? "49153") ?? 49153
        return try await withCheckedThrowingContinuation { continuation in
            handler.connect(devId: devId, groupAddr: groupAddr) { result in
                switch result {
                case .success(let ack):
                    continuation.resume(returning: "Device bound to group \(groupAddr). ACK: \(ack)")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeUnbindDeviceGroup(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let devId = parameterValues["devId"] ?? device.id
        let elements = parseIntArray(parameterValues["elements"] ?? "0")
        let groupAddr = Int(parameterValues["groupAddr"] ?? "49153") ?? 49153
        return try await withCheckedThrowingContinuation { continuation in
            handler.unbindDeviceGroup(devId: devId, elements: elements, groupAddr: groupAddr) { result in
                switch result {
                case .success(let ack):
                    continuation.resume(returning: "Device unbound from group \(groupAddr). ACK: \(ack)")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - WiFi Operations Commands

    private func executeRequestScanWifi(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let devId = parameterValues["devId"] ?? device.id
        return try await withCheckedThrowingContinuation { continuation in
            handler.requestScanWifi(devId: devId) { result in
                switch result {
                case .success(let networks):
                    let networkList = networks.map { $0.ssid ?? "Unknown" }.joined(separator: ", ")
                    continuation.resume(returning: "Found \(networks.count) networks: \(networkList)")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeRequestConnectWifi(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let devId = parameterValues["devId"] ?? device.id
        let ssid = parameterValues["ssid"] ?? ""
        let pwd = parameterValues["pwd"] ?? ""
        return try await withCheckedThrowingContinuation { continuation in
            handler.requestConnectWifi(devId: devId, ssid: ssid, pwd: pwd) { result in
                switch result {
                case .success(let connectivity):
                    let connected = connectivity.isWiFiConnected ?? false
                    continuation.resume(returning: "WiFi connection \(connected ? "successful" : "initiated")")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Smart Automation Commands

    private func executeActiveSmart(handler: RGBIotDeviceCmdHandler) -> String {
        let smid = Int(parameterValues["smid"] ?? "0") ?? 0
        handler.activeSmart(smid: smid)
        return "Smart automation \(smid) activated (fire-and-forget)"
    }

    private func executeBindDeviceSmartTrigger(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let smid = Int(parameterValues["smid"] ?? "0") ?? 0
        let devId = parameterValues["devId"] ?? device.id
        let typeTrigger = Int(parameterValues["typeTrigger"] ?? "0") ?? 0
        let elm = Int(parameterValues["elm"] ?? "0") ?? 0
        let condition = Int(parameterValues["condition"] ?? "0") ?? 0
        let attrValueCondition = parseIntArray(parameterValues["attrValueCondition"] ?? "")
        let elmExt: Int? = parameterValues["elmExt"].flatMap { Int($0) }
        let conditionExt: Int? = parameterValues["conditionExt"].flatMap { Int($0) }
        let attrValueConditionExt: [Int]? = parameterValues["attrValueConditionExt"].map { parseIntArray($0) }
        let timeCfg: [Int]? = parameterValues["timeCfg"].map { parseIntArray($0) }
        let timeJob: [Int]? = parameterValues["timeJob"].map { parseIntArray($0) }

        return try await withCheckedThrowingContinuation { continuation in
            handler.bindDeviceSmartTrigger(
                smid: smid,
                devId: devId,
                typeTrigger: typeTrigger,
                elm: elm,
                condition: condition,
                attrValueCondition: attrValueCondition,
                elmExt: elmExt,
                conditionExt: conditionExt,
                attrValueConditionExt: attrValueConditionExt,
                timeCfg: timeCfg,
                timeJob: timeJob
            ) { result in
                switch result {
                case .success(let ack):
                    continuation.resume(returning: "Smart trigger bound. ACK: \(ack)")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeUnbindDeviceSmartTrigger(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let smid = Int(parameterValues["smid"] ?? "0") ?? 0
        let devId = parameterValues["devId"] ?? device.id
        return try await withCheckedThrowingContinuation { continuation in
            handler.unbindDeviceSmartTrigger(smid: smid, devId: devId) { result in
                switch result {
                case .success(let ack):
                    continuation.resume(returning: "Smart trigger unbound. ACK: \(ack)")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeBindDeviceSmartCmd(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let smid = Int(parameterValues["smid"] ?? "0") ?? 0
        let devId = parameterValues["devId"] ?? device.id
        let elm = Int(parameterValues["elm"] ?? "0") ?? 0
        let attrValue = parseIntArray(parameterValues["attrValue"] ?? "")
        let delay: Int? = parameterValues["delay"].flatMap { Int($0) }
        return try await withCheckedThrowingContinuation { continuation in
            handler.bindDeviceSmartCmd(
                smid: smid,
                devId: devId,
                elm: elm,
                attrValue: attrValue,
                delay: delay
            ) { result in
                switch result {
                case .success(let ack):
                    continuation.resume(returning: "Smart command bound. ACK: \(ack)")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeUnbindDeviceSmartCmd(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let smid = Int(parameterValues["smid"] ?? "0") ?? 0
        let devId = parameterValues["devId"] ?? device.id
        return try await withCheckedThrowingContinuation { continuation in
            handler.unbindDeviceSmartCmd(smid: smid, devId: devId) { result in
                switch result {
                case .success(let ack):
                    continuation.resume(returning: "Smart command unbound. ACK: \(ack)")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Vendor Message Commands

    private func executeSendVendorMsgBytes(handler: RGBIotDeviceCmdHandler) -> String {
        let devId = parameterValues["devId"] ?? device.id
        let typeMsg = UInt8(parameterValues["typeMsg"] ?? "0") ?? 0
        let vendorMsg = parseUInt8Array(parameterValues["vendorMsg"] ?? "")
        handler.sendVendorMsg(devId: devId, typeMsg: typeMsg, vendorMsg: vendorMsg)
        return "Vendor message (bytes) sent (fire-and-forget)"
    }

    private func executeSendVendorMsgJson(handler: RGBIotDeviceCmdHandler) -> String {
        let devId = parameterValues["devId"] ?? device.id
        let typeMsg = UInt8(parameterValues["typeMsg"] ?? "0") ?? 0
        let json = parameterValues["json"] ?? "{}"
        handler.sendVendorMsg(devId: devId, typeMsg: typeMsg, json: json)
        return "Vendor message (JSON) sent (fire-and-forget)"
    }

    // MARK: - Wile Direct BLE Commands

    private func executeStartWileDirectBle(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let devId = parameterValues["devId"] ?? device.id
        return try await withCheckedThrowingContinuation { continuation in
            handler.startWileDirectBle(devId: devId) { result in
                switch result {
                case .success:
                    continuation.resume(returning: "Wile Direct BLE started")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeStopWileDirectBle(handler: RGBIotDeviceCmdHandler) -> String {
        handler.stopWileDirectBle()
        return "Wile Direct BLE stopped (fire-and-forget)"
    }

    // MARK: - OTA & System Commands

    private func executeCheckDeviceSoftwareVersion(handler: RGBIotDeviceCmdHandler) -> String {
        let devId = parameterValues["devId"] ?? device.id
        handler.checkDeviceSoftwareVersion(devId: devId)
        return "Software version check initiated (fire-and-forget)"
    }

    private func executeUpdateDeviceSoftware(handler: RGBIotDeviceCmdHandler) -> String {
        let devId = parameterValues["devId"] ?? device.id
        let urlOta = parameterValues["urlOta"] ?? ""
        let forceHttpNonSecure = (parameterValues["forceHttpNonSecure"] ?? "false").lowercased() == "true"
        handler.updateDeviceSoftware(devId: devId, urlOta: urlOta, forceHttpNonSecure: forceHttpNonSecure)
        return "OTA update initiated (fire-and-forget)"
    }

    private func executeResetDevice(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let devId = parameterValues["devId"] ?? device.id
        return try await withCheckedThrowingContinuation { continuation in
            handler.resetDevice(devId: devId) { result in
                switch result {
                case .success:
                    continuation.resume(returning: "Device reset to factory defaults")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeRebootDevice(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let devId = parameterValues["devId"] ?? device.id
        return try await withCheckedThrowingContinuation { continuation in
            handler.rebootDevice(devId: devId) { result in
                switch result {
                case .success:
                    continuation.resume(returning: "Device rebooted successfully")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Log Commands

    private func executeGetLogAttrBlocks(handler: RGBIotDeviceCmdHandler) async throws -> String {
        let devId = parameterValues["devId"] ?? device.id
        let element = Int(parameterValues["element"] ?? "0") ?? 0
        let attr = Int(parameterValues["attr"] ?? "0") ?? 0
        let timeCheckpoint = Double(parameterValues["timeCheckpoint"] ?? "0") ?? 0
        return try await withCheckedThrowingContinuation { continuation in
            handler.getLogAttrBlocks(devId: devId, element: element, attr: attr, timeCheckpoint: timeCheckpoint) { result in
                switch result {
                case .success(let blocks):
                    continuation.resume(returning: "Retrieved \(blocks.count) log blocks")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Parameter Parsing Helpers

    private func parseIntArray(_ string: String) -> [Int] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return trimmed
            .components(separatedBy: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    private func parseUInt8Array(_ string: String) -> [UInt8] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return trimmed
            .components(separatedBy: ",")
            .compactMap { UInt8($0.trimmingCharacters(in: .whitespaces)) }
    }
}

// MARK: - Response Data View

/// A view to display formatted response data from command execution
struct ResponseDataView: View {
    let responseData: CommandResponseData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.purple)
                Text("Response Data")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Content based on response type
            switch responseData {
            case .deviceStateDescription(let description):
                deviceStateDescriptionView(description)
            case .ackCode(let code):
                ackCodeView(code)
            case .connectivity(let connections):
                connectivityView(connections)
            case .wifiNetworks(let networks):
                wifiNetworksView(networks)
            case .logBlocks(let count):
                logBlocksView(count)
            case .none:
                EmptyView()
            }
        }
        .padding(10)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Subviews

    private func deviceStateDescriptionView(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Device State:")
                .font(.caption)
                .fontWeight(.medium)

            Text(description)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ackCodeView(_ code: Int) -> some View {
        HStack {
            Text("ACK Code:")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(code)")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
        }
    }

    private func connectivityView(_ connections: [ConnectivityInfo]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(connections.enumerated()), id: \.offset) { index, conn in
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interface \(index)")
                        .font(.caption)
                        .fontWeight(.medium)

                    HStack(spacing: 12) {
                        Label(
                            conn.isWiFiConnected ? "WiFi On" : "WiFi Off",
                            systemImage: conn.isWiFiConnected ? "wifi" : "wifi.slash"
                        )
                        .font(.caption2)
                        .foregroundColor(conn.isWiFiConnected ? .green : .gray)

                        Label(
                            conn.isCloudConnected ? "Cloud On" : "Cloud Off",
                            systemImage: conn.isCloudConnected ? "cloud.fill" : "cloud"
                        )
                        .font(.caption2)
                        .foregroundColor(conn.isCloudConnected ? .green : .gray)
                    }

                    if let ssid = conn.wifiSSID {
                        Text("SSID: \(ssid)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let rssi = conn.wifiSignalStrength {
                        Text("Signal: \(rssi) dBm")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 8)
            }
        }
    }

    private func wifiNetworksView(_ networks: [WifiNetworkInfo]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Found \(networks.count) networks")
                .font(.caption)
                .fontWeight(.medium)

            ForEach(Array(networks.enumerated()), id: \.offset) { _, network in
                HStack {
                    Image(systemName: "wifi")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text(network.ssid)
                        .font(.caption2)
                }
            }
        }
    }

    private func logBlocksView(_ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Log Blocks: \(count) entries")
                .font(.caption)
                .fontWeight(.medium)

            if count == 0 {
                Text("No log data available")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        Text("Preview requires actual IoTDevice from API")
    }
}
