//
//  OperationTestViewModel.swift
//  IoTCoreSample
//
//  Created on 2025-12-11.
//  ViewModel for testing Operations using public SDK API
//

import Foundation
import Combine
import CoreBluetooth
import IotCoreIOS

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case error(String)

    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error(let message): return "Error: \(message)"
        }
    }

    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

@MainActor
class OperationTestViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var connectionState: ConnectionState = .disconnected
    @Published var connectedDevice: RGBDiscoveredBLEDevice?

    @Published var selectedOperation: OperationDefinition?
    @Published var parameterValues: [String: String] = [:]

    @Published var isExecuting: Bool = false
    @Published var lastResult: String = ""
    @Published var lastError: String = ""
    @Published var executionLog: [String] = []

    // MARK: - Computed Properties

    var operations: [OperationDefinition] {
        OperationDefinition.allOperations
    }

    var operationsByCategory: [(OperationCategory, [OperationDefinition])] {
        var result: [(OperationCategory, [OperationDefinition])] = []
        for category in OperationCategory.allCases {
            let ops = operations.filter { $0.category == category }
            if !ops.isEmpty {
                result.append((category, ops))
            }
        }
        return result
    }

    var isConnectionReady: Bool {
        connectionState.isConnected
    }

    var canExecute: Bool {
        guard !isExecuting else { return false }
        guard isConnectionReady else { return false }
        guard let operation = selectedOperation else { return false }

        // Check required parameters
        for param in operation.parameters where param.isRequired {
            let value = parameterValues[param.name] ?? ""
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
        }

        return true
    }

    var deviceId: String {
        connectedDevice?.peripheral.identifier.uuidString ?? ""
    }

    // MARK: - Initialization

    init() {
        addLog("Operation Tester initialized")
    }

    // MARK: - Connection Actions

    func connectToDevice(_ device: RGBDiscoveredBLEDevice) {
        connectionState = .connecting
        connectedDevice = device
        let deviceName = device.name ?? "Unknown Device"
        addLog("Connecting to: \(deviceName)")
        addLog("Device ID: \(device.peripheral.identifier.uuidString)")

        // Test connection by trying to get device state
        Task {
            do {
                guard let handler = IoTAppCore.current?.deviceCmdHandler else {
                    throw NSError(domain: "OperationTest", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "SDK not initialized"])
                }

                let devId = device.peripheral.identifier.uuidString

                addLog("Testing connection...")
                self.connectionState = .connected
                self.addLog("✅ Connected: ")
                self.addLog("✅ Ready to execute operations")
                // Try a simple operation to verify connection
//                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
//                    handler.getDeviceState(devId: devId) { result in
//                        switch result {
//                        case .success:
//                            continuation.resume(returning: "Connection verified")
//                        case .failure(let error):
//                            continuation.resume(throwing: error)
//                        }
//                    }
//                }
//
//                await MainActor.run {
//                    self.connectionState = .connected
//                    self.addLog("✅ Connected: \(result)")
//                    self.addLog("✅ Ready to execute operations")
//                }

            } catch {
                await MainActor.run {
                    self.connectionState = .error(error.localizedDescription)
                    self.addLog("❌ Connection failed: \(error.localizedDescription)")
                    self.connectedDevice = nil
                }
            }
        }
    }

    func disconnect() {
        guard connectionState.isConnected else { return }

        addLog("Disconnecting...")

        connectionState = .disconnected
        connectedDevice = nil

        addLog("Disconnected")
    }

    // MARK: - Operation Actions

    func selectOperation(_ operation: OperationDefinition) {
        selectedOperation = operation
        // Initialize parameter values with defaults
        parameterValues.removeAll()
        for param in operation.parameters {
            parameterValues[param.name] = param.defaultValue
        }
        addLog("Selected operation: \(operation.displayName)")
    }

    func clearResults() {
        lastResult = ""
        lastError = ""
    }

    func clearLog() {
        executionLog.removeAll()
    }

    func executeOperation() {
        guard let operation = selectedOperation else { return }
        guard isConnectionReady else { return }

        isExecuting = true
        lastError = ""
        lastResult = ""

        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        addLog("[\(timestamp)] Executing: \(operation.displayName)")

        // Log parameters
        if !operation.parameters.isEmpty {
            addLog("   Parameters:")
            for param in operation.parameters {
                if let value = parameterValues[param.name], !value.isEmpty {
                    addLog("   - \(param.displayName): \(value)")
                }
            }
        }

        Task {
            do {
                let result = try await executeOperationAsync(operation)
                await MainActor.run {
                    self.isExecuting = false
                    self.lastResult = result
                    self.addLog("✅ Success: \(result)")
                }
            } catch {
                await MainActor.run {
                    self.isExecuting = false
                    self.lastError = error.localizedDescription
                    self.addLog("❌ Error: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Private Execution (using public SDK API)

    private func executeOperationAsync(_ operation: OperationDefinition) async throws -> String {
        guard let handler = IoTAppCore.current?.deviceCmdHandler else {
            throw NSError(domain: "OperationTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "SDK not initialized"])
        }

        let devId = deviceId

        addLog("   Device ID: \(devId)")
        addLog("   Starting execution...")

        // Execute based on operation ID using public API
        switch operation.id {

        // MARK: Device Control

        case "sendControl":
            let elements = try parseIntArray(parameterValues["elements"] ?? "0")
            let attrValue = try parseIntArray(parameterValues["attrValue"] ?? "")
            return try await executeControlDevice(handler: handler, devId: devId, elements: elements, attrValue: attrValue)

        case "sendGroupControl":
            let groupAddr = try parseInt(parameterValues["groupAddr"] ?? "")
            let attrValue = try parseIntArray(parameterValues["attrValue"] ?? "")
            let targetDevType = Int(parameterValues["targetDevType"] ?? "0") ?? 0
            return try await executeControlDeviceGroup(handler: handler, groupAddr: groupAddr, attrValue: attrValue, targetDevType: targetDevType)

        case "sendSetting":
            let element = try parseInt(parameterValues["element"] ?? "0")
            let attrValue = try parseIntArray(parameterValues["attrValue"] ?? "")
            return try await executeSettingAttribute(handler: handler, devId: devId, element: element, attrValue: attrValue)

        // MARK: Device Info

        case "getDeviceState":
            return try await executeGetDeviceState(handler: handler, devId: devId)

        // MARK: Network

        case "getNetworkConnectivity":
            return try await executeGetDeviceConnectivity(handler: handler, devId: devId)

        case "requestWiFiScan":
            return try await executeRequestScanWifi(handler: handler, devId: devId)

        case "setWiFiConnect":
            let ssid = parameterValues["ssid"] ?? ""
            let password = parameterValues["password"] ?? ""
            return try await executeRequestConnectWifi(handler: handler, devId: devId, ssid: ssid, password: password)

        // MARK: Group Management

        case "bindDeviceToGroup":
            let elements = try parseIntArray(parameterValues["elements"] ?? "0")
            let groupAddr = try parseInt(parameterValues["groupAddr"] ?? "")
            return try await executeConnect(handler: handler, devId: devId, groupAddr: groupAddr)

        case "unbindDeviceFromGroup":
            let elements = try parseIntArray(parameterValues["elements"] ?? "0")
            let groupAddr = try parseInt(parameterValues["groupAddr"] ?? "")
            return try await executeUnbindDeviceGroup(handler: handler, devId: devId, elements: elements, groupAddr: groupAddr)

        // MARK: System

        case "rebootDevice":
            return try await executeRebootDevice(handler: handler, devId: devId)

        case "resetDevice":
            return try await executeResetDevice(handler: handler, devId: devId)

        default:
            throw NSError(domain: "OperationTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation not yet implemented: \(operation.id)"])
        }
    }

    // MARK: - API Method Wrappers

    private func executeControlDevice(handler: RGBIotDeviceCmdHandler, devId: String, elements: [Int], attrValue: [Int]) async throws -> String {
        addLog("   Calling handler.controlDevice...")
        return try await withCheckedThrowingContinuation { continuation in
            handler.controlDevice(devId: devId, elements: elements, attrValue: attrValue) { result in
                switch result {
                case .success:
                    continuation.resume(returning: "Control sent successfully")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeControlDeviceGroup(handler: RGBIotDeviceCmdHandler, groupAddr: Int, attrValue: [Int], targetDevType: Int) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            handler.controlDeviceGroup(groupAddr: groupAddr, attrValue: attrValue, targetDevType: targetDevType) { result in
                switch result {
                case .success:
                    continuation.resume(returning: "Group control sent successfully")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeSettingAttribute(handler: RGBIotDeviceCmdHandler, devId: String, element: Int, attrValue: [Int]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            handler.settingAttribute(devId: devId, element: element, attrValue: attrValue) { result in
                switch result {
                case .success:
                    continuation.resume(returning: "Setting sent successfully")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeGetDeviceState(handler: RGBIotDeviceCmdHandler, devId: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            handler.getDeviceState(devId: devId) { result in
                switch result {
                case .success(let state):
                    let stateDesc = "Device state retrieved successfully"
                    continuation.resume(returning: stateDesc)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeGetDeviceConnectivity(handler: RGBIotDeviceCmdHandler, devId: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            handler.getDeviceConnectivity(devId: devId) { result in
                switch result {
                case .success(let connectivity):
                    continuation.resume(returning: "Connectivity: \(connectivity.count) interfaces")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeRequestScanWifi(handler: RGBIotDeviceCmdHandler, devId: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            handler.requestScanWifi(devId: devId) { result in
                switch result {
                case .success(let networks):
                    continuation.resume(returning: "Found \(networks.count) WiFi networks")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeRequestConnectWifi(handler: RGBIotDeviceCmdHandler, devId: String, ssid: String, password: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            handler.requestConnectWifi(devId: devId, ssid: ssid, pwd: password) { result in
                switch result {
                case .success(let connectivity):
                    continuation.resume(returning: "WiFi connection initiated")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeConnect(handler: RGBIotDeviceCmdHandler, devId: String, groupAddr: Int) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            handler.connect(devId: devId, groupAddr: groupAddr) { result in
                switch result {
                case .success:
                    continuation.resume(returning: "Bound to group \(groupAddr)")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeUnbindDeviceGroup(handler: RGBIotDeviceCmdHandler, devId: String, elements: [Int], groupAddr: Int) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            handler.unbindDeviceGroup(devId: devId, elements: elements, groupAddr: groupAddr) { result in
                switch result {
                case .success:
                    continuation.resume(returning: "Unbound from group \(groupAddr)")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeRebootDevice(handler: RGBIotDeviceCmdHandler, devId: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            handler.rebootDevice(devId: devId) { result in
                switch result {
                case .success:
                    continuation.resume(returning: "Device rebooted")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeResetDevice(handler: RGBIotDeviceCmdHandler, devId: String) async throws -> String {
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

    // MARK: - Helper Methods

    private func addLog(_ message: String) {
        executionLog.append(message)
        // Keep only last 50 logs
        if executionLog.count > 50 {
            executionLog.removeFirst()
        }
    }

    private func parseIntArray(_ string: String) throws -> [Int] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "OperationTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Value required"])
        }

        let parts = trimmed.components(separatedBy: ",")
        var result: [Int] = []
        for part in parts {
            guard let value = Int(part.trimmingCharacters(in: .whitespaces)) else {
                throw NSError(domain: "OperationTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid integer: \(part)"])
            }
            result.append(value)
        }
        return result
    }

    private func parseInt(_ string: String) throws -> Int {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed) else {
            throw NSError(domain: "OperationTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid integer: \(string)"])
        }
        return value
    }
}
