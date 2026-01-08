//
//  DeviceCommandTestViewModel.swift
//  IoTCoreSample
//
//  ViewModel for testing Device Command Handler APIs
//

import Foundation
import IotCoreIOS
import Combine

@MainActor
class DeviceCommandTestViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var lastResult: String?
    @Published var lastError: String?

    // MARK: - Device Commands

    func connectDevice(devId: String, groupAddr: Int) {
        guard let sdk = IoTAppCore.current else {
            showError("SDK not initialized")
            return
        }

        guard !devId.isEmpty else {
            showError("Device ID is required")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil

        print("📡 Connecting device: \(devId), groupAddr: \(groupAddr)")

        sdk.deviceCmdHandler.connect(devId: devId, groupAddr: groupAddr) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                self.handleAckResult(result, commandName: "Connect Device")
            }
        }
    }

    func getDeviceState(devId: String) {
        guard let sdk = IoTAppCore.current else {
            showError("SDK not initialized")
            return
        }

        guard !devId.isEmpty else {
            showError("Device ID is required")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil

        print("📡 Getting device state: \(devId)")

        sdk.deviceCmdHandler.getDeviceState(devId: devId) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let state):
                    self.lastResult = """
                    Device State:
                    - Device ID: \(devId)
                    - State: \(state)
                    """
                    print("✅ Get device state success")

                case .failure(let error):
                    self.handleError(error, commandName: "Get Device State")
                }
            }
        }
    }

    func controlDevice(devId: String, elements: [Int], attrValue: [Int]) {
        guard let sdk = IoTAppCore.current else {
            showError("SDK not initialized")
            return
        }

        guard !devId.isEmpty else {
            showError("Device ID is required")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil

        print("📡 Controlling device: \(devId)")
        print("   Elements: \(elements)")
        print("   Attr Values: \(attrValue)")

        sdk.deviceCmdHandler.controlDevice(
            devId: devId,
            elements: elements,
            attrValue: attrValue
        ) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                self.handleAckResult(result, commandName: "Control Device")
            }
        }
    }

    func controlDeviceGroup(groupAddr: Int, attrValue: [Int], targetDevType: Int) {
        guard let sdk = IoTAppCore.current else {
            showError("SDK not initialized")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil

        print("📡 Controlling device group: \(groupAddr)")
        print("   Attr Values: \(attrValue)")
        print("   Target Device Type: \(targetDevType)")

        sdk.deviceCmdHandler.controlDeviceGroup(
            groupAddr: groupAddr,
            attrValue: attrValue,
            targetDevType: targetDevType
        ) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                self.handleAckResult(result, commandName: "Control Device Group")
            }
        }
    }

    func resetDevice(devId: String) {
        guard let sdk = IoTAppCore.current else {
            showError("SDK not initialized")
            return
        }

        guard !devId.isEmpty else {
            showError("Device ID is required")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil

        print("📡 Resetting device: \(devId)")

        sdk.deviceCmdHandler.resetDevice(devId: devId) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success:
                    self.lastResult = "Device reset successfully"
                    print("✅ Reset device success")

                case .failure(let error):
                    self.handleError(error, commandName: "Reset Device")
                }
            }
        }
    }

    func rebootDevice(devId: String) {
        guard let sdk = IoTAppCore.current else {
            showError("SDK not initialized")
            return
        }

        guard !devId.isEmpty else {
            showError("Device ID is required")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil

        print("📡 Rebooting device: \(devId)")

        sdk.deviceCmdHandler.rebootDevice(devId: devId) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success:
                    self.lastResult = "Device rebooted successfully"
                    print("✅ Reboot device success")

                case .failure(let error):
                    self.handleError(error, commandName: "Reboot Device")
                }
            }
        }
    }

    func getDeviceConnectivity(devId: String) {
        guard let sdk = IoTAppCore.current else {
            showError("SDK not initialized")
            return
        }

        guard !devId.isEmpty else {
            showError("Device ID is required")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil

        print("📡 Getting device connectivity: \(devId)")

        sdk.deviceCmdHandler.getDeviceConnectivity(devId: devId) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let connectivity):
                    var resultText = "Device Connectivity:\n"
                    for (index, conn) in connectivity.enumerated() {
                        resultText += "\n[\(index)]:\n"
                        resultText += "  WiFi Connected: \(conn.isWiFiConnected ?? false)\n"
                        resultText += "  Cloud Connected: \(conn.isCloudConnected ?? false)\n"
                        if let ssid = conn.wifiSSID {
                            resultText += "  SSID: \(ssid)\n"
                        }
                        if let rssi = conn.wifiSignalStrength {
                            resultText += "  Signal: \(rssi) dBm\n"
                        }
                    }
                    self.lastResult = resultText
                    print("✅ Get device connectivity success")

                case .failure(let error):
                    self.handleError(error, commandName: "Get Device Connectivity")
                }
            }
        }
    }

    func requestScanWifi(devId: String) {
        guard let sdk = IoTAppCore.current else {
            showError("SDK not initialized")
            return
        }

        guard !devId.isEmpty else {
            showError("Device ID is required")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil

        print("📡 Requesting WiFi scan: \(devId)")

        sdk.deviceCmdHandler.requestScanWifi(devId: devId) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let networks):
                    var resultText = "WiFi Networks Found: \(networks.count)\n"
                    for (index, network) in networks.enumerated() {
                        resultText += "\n[\(index + 1)] \(network.ssid ?? "Unknown")\n"
                        resultText += "  RSSI: \(network.rssi ?? 0) dBm\n"
                        resultText += "  Security: \(network.security?.rawValue ?? 0)\n"
                        resultText += "  Channel: \(network.channel ?? 0)\n"
                    }
                    self.lastResult = resultText
                    print("✅ WiFi scan success: \(networks.count) networks")

                case .failure(let error):
                    self.handleError(error, commandName: "Request Scan WiFi")
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func handleAckResult(_ result: Result<Int, Error>, commandName: String) {
        switch result {
        case .success(let ackCode):
            lastResult = """
            \(commandName) Success
            ACK Code: \(ackCode)
            """
            print("✅ \(commandName) success, ACK: \(ackCode)")

        case .failure(let error):
            handleError(error, commandName: commandName)
        }
    }

    private func handleError(_ error: Error, commandName: String) {
        print("❌ \(commandName) error: \(error.localizedDescription)")
        showError("\(commandName) failed: \(error.localizedDescription)")
    }

    private func showError(_ message: String) {
        lastError = message
    }

    func clearResults() {
        lastResult = nil
        lastError = nil
    }
}
