//
//  SmartTestViewModel.swift
//  IoTCoreSample
//
//  ViewModel for testing Smart Automation APIs
//

import Foundation
import IotCoreIOS
import Combine

@MainActor
class SmartTestViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var lastResult: String?
    @Published var lastError: String?
    @Published var flowLog: [String] = []

    // Device list
    @Published var devices: [IoTDevice] = []
    @Published var isLoadingDevices = false

    // State from scenario creation
    @Published var createdSmartUuid: String?
    @Published var createdSmid: Int?

    // MARK: - Fetch Devices

    func fetchDevices() {
        guard let sdk = IoTAppCore.current else { return }
        isLoadingDevices = true
        sdk.callApiGetUserDevices { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoadingDevices = false
                if case .success(let data) = result {
                    if let parsed = try? JSONDecoder().decode([IoTDevice].self, from: data) {
                        self.devices = parsed
                    }
                }
            }
        }
    }

    /// Get element IDs for a device from elementInfos keys
    func elementIds(for device: IoTDevice) -> [Int] {
        if let infos = device.elementInfos {
            return infos.keys.compactMap { Int($0) }.sorted()
        }
        return device.elementIds ?? [0]
    }

    // MARK: - Scenario Full Flow
    // Flow: REST addSmart → MQTT bindCmd → REST addSmartCmd → ready to activate

    func createScenario(
        label: String,
        locationId: String,
        targetDeviceId: String,
        elementId: Int,
        cmd: [Int],
        delay: Int,
        reversing: Int
    ) {
        guard let sdk = IoTAppCore.current else {
            showError("SDK not initialized")
            return
        }
        guard !locationId.isEmpty else {
            showError("Location ID is required")
            return
        }
        guard !targetDeviceId.isEmpty else {
            showError("Target Device ID is required")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil
        flowLog = []
        appendLog("=== Create Scenario Flow ===")

        // Step 1: REST — Create Smart container
        appendLog("[Step 1/3] REST: POST /api/v1/smart/add ...")

        let smartParams: [String: Any] = [
            "label": label,
            "locId": locationId,
            "type": 0,       // Scenario
            "subType": -1     // Default
        ]

        sdk.callApiPost("smart/add", params: smartParams, headers: nil) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }

                switch result {
                case .success(let data):
                    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let uuid = json["uuid"] as? String,
                          let smid = json["smid"] as? Int else {
                        self.isLoading = false
                        self.appendLog("[Step 1] FAILED: Cannot parse response")
                        self.showError("Cannot parse smart/add response")
                        return
                    }

                    self.createdSmartUuid = uuid
                    self.createdSmid = smid
                    self.appendLog("[Step 1] OK: uuid=\(uuid), smid=\(smid)")

                    // Step 2: MQTT — Bind SmartCmd to hub
                    self.step2_bindSmartCmd(
                        sdk: sdk,
                        smid: smid,
                        targetDeviceId: targetDeviceId,
                        elementId: elementId,
                        cmd: cmd,
                        delay: delay,
                        reversing: reversing,
                        smartUuid: uuid
                    )

                case .failure(let error):
                    self.isLoading = false
                    self.appendLog("[Step 1] FAILED: \(error.localizedDescription)")
                    self.showError("Create Smart failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func step2_bindSmartCmd(
        sdk: any RGBIotCore,
        smid: Int,
        targetDeviceId: String,
        elementId: Int,
        cmd: [Int],
        delay: Int,
        reversing: Int,
        smartUuid: String
    ) {
        appendLog("[Step 2/3] MQTT: bindDeviceSmartCmd(smid=\(smid), elm=\(elementId), delay=\(delay), rev=\(reversing)) ...")

        sdk.deviceCmdHandler.bindDeviceSmartCmd(
            smid: smid,
            devId: targetDeviceId,
            elm: elementId,
            attrValue: cmd,
            delay: delay,
            reversing: reversing
        ) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }

                switch result {
                case .success:
                    self.appendLog("[Step 2] OK: MQTT bind ACK received")

                    // Step 3: REST — Persist SmartCmd to cloud
                    self.step3_persistSmartCmd(
                        sdk: sdk,
                        smartUuid: smartUuid,
                        targetDeviceId: targetDeviceId,
                        elementId: elementId,
                        cmd: cmd,
                        delay: delay,
                        reversing: reversing
                    )

                case .failure(let error):
                    self.isLoading = false
                    self.appendLog("[Step 2] FAILED: \(error.localizedDescription)")
                    self.showError("MQTT bindCmd failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func step3_persistSmartCmd(
        sdk: any RGBIotCore,
        smartUuid: String,
        targetDeviceId: String,
        elementId: Int,
        cmd: [Int],
        delay: Int,
        reversing: Int
    ) {
        appendLog("[Step 3/3] REST: POST /api/v1/smartcmd/add ...")

        let cmdEntry: [String: Any] = [
            "cmd": cmd,
            "delay": delay,
            "reversing": reversing
        ]

        let smartCmdParams: [String: Any] = [
            "smartId": smartUuid,
            "targetId": targetDeviceId,
            "target": 1,
            "filter": 2,
            "type": 0,
            "cfm": 0,
            "cmds": ["\(elementId)": cmdEntry]
        ]

        sdk.callApiPost("smartcmd/add", params: smartCmdParams, headers: nil) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let data):
                    var detail = ""
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let cmdUuid = json["uuid"] as? String {
                        detail = ", cmdUuid=\(cmdUuid)"
                    }
                    self.appendLog("[Step 3] OK: SmartCmd persisted\(detail)")
                    self.appendLog("=== Scenario Created! smid=\(self.createdSmid ?? 0) ===")
                    self.appendLog("Use 'Activate Smart' with smid=\(self.createdSmid ?? 0) to run")
                    self.lastResult = "Scenario created! smid=\(self.createdSmid ?? 0)"

                case .failure(let error):
                    self.appendLog("[Step 3] FAILED: \(error.localizedDescription)")
                    self.showError("Persist SmartCmd failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Smart Active

    func activeSmart(smid: Int) {
        guard let sdk = IoTAppCore.current else {
            showError("SDK not initialized")
            return
        }

        lastError = nil
        lastResult = nil

        sdk.deviceCmdHandler.activeSmart(smid: smid)
        lastResult = "activeSmart(smid=\(smid)) sent (fire-and-forget)"
        appendLog("MQTT: activeSmart(smid=\(smid)) sent")
    }

    // MARK: - Delete Scenario
    // Flow: MQTT removeAnnounce → REST DELETE

    func deleteScenario(smartUuid: String, smid: Int) {
        guard let sdk = IoTAppCore.current else {
            showError("SDK not initialized")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil
        appendLog("=== Delete Scenario ===")

        // Step 1: MQTT remove announce
        appendLog("[Delete 1/2] MQTT: smartRemoveAnnounce(smid=\(smid))")
        sdk.deviceCmdHandler.smartRemoveAnnounce(smid: smid)
        appendLog("[Delete 1/2] OK: sent (fire-and-forget)")

        // Step 2: REST delete
        appendLog("[Delete 2/2] REST: DELETE /api/v1/smart/\(smartUuid) ...")
        sdk.callApiDelete("smart/\(smartUuid)", params: nil, headers: nil) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success:
                    self.appendLog("[Delete 2/2] OK: Smart deleted from cloud")
                    self.lastResult = "Scenario deleted"
                    self.createdSmartUuid = nil
                    self.createdSmid = nil
                case .failure(let error):
                    self.appendLog("[Delete 2/2] FAILED: \(error.localizedDescription)")
                    self.showError("Delete failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Individual MQTT Primitives (for manual testing)

    func bindSmartTrigger(
        smid: Int, devId: String, typeTrigger: Int, elm: Int,
        condition: Int, attrValueCondition: [Int], timeCfg: [Int]?
    ) {
        guard let sdk = IoTAppCore.current else { showError("SDK not initialized"); return }
        guard !devId.isEmpty else { showError("Device ID required"); return }

        isLoading = true; lastError = nil; lastResult = nil
        sdk.deviceCmdHandler.bindDeviceSmartTrigger(
            smid: smid, devId: devId, typeTrigger: typeTrigger, elm: elm,
            condition: condition, attrValueCondition: attrValueCondition,
            elmExt: nil, conditionExt: nil, attrValueConditionExt: nil,
            timeCfg: timeCfg, timeJob: nil
        ) { [weak self] result in
            Task { @MainActor in
                self?.isLoading = false
                self?.handleAckResult(result, commandName: "Bind Smart Trigger")
            }
        }
    }

    func unbindSmartTrigger(smid: Int, devId: String) {
        guard let sdk = IoTAppCore.current else { showError("SDK not initialized"); return }
        guard !devId.isEmpty else { showError("Device ID required"); return }
        isLoading = true; lastError = nil; lastResult = nil
        sdk.deviceCmdHandler.unbindDeviceSmartTrigger(smid: smid, devId: devId) { [weak self] result in
            Task { @MainActor in
                self?.isLoading = false
                self?.handleAckResult(result, commandName: "Unbind Smart Trigger")
            }
        }
    }

    func bindSmartCmd(smid: Int, devId: String, elm: Int, attrValue: [Int], delay: Int?, reversing: Int? = nil) {
        guard let sdk = IoTAppCore.current else { showError("SDK not initialized"); return }
        guard !devId.isEmpty else { showError("Device ID required"); return }
        isLoading = true; lastError = nil; lastResult = nil
        sdk.deviceCmdHandler.bindDeviceSmartCmd(smid: smid, devId: devId, elm: elm, attrValue: attrValue, delay: delay, reversing: reversing) { [weak self] result in
            Task { @MainActor in
                self?.isLoading = false
                self?.handleAckResult(result, commandName: "Bind Smart Cmd")
            }
        }
    }

    func unbindSmartCmd(smid: Int, devId: String) {
        guard let sdk = IoTAppCore.current else { showError("SDK not initialized"); return }
        guard !devId.isEmpty else { showError("Device ID required"); return }
        isLoading = true; lastError = nil; lastResult = nil
        sdk.deviceCmdHandler.unbindDeviceSmartCmd(smid: smid, devId: devId) { [weak self] result in
            Task { @MainActor in
                self?.isLoading = false
                self?.handleAckResult(result, commandName: "Unbind Smart Cmd")
            }
        }
    }

    func setSmartTriggerMode(smid: Int, smartType: Int, enabled: Bool, disableMinutes: Int?) {
        guard let sdk = IoTAppCore.current else { showError("SDK not initialized"); return }
        isLoading = true; lastError = nil; lastResult = nil
        sdk.deviceCmdHandler.setSmartTriggerMode(smid: smid, smartType: smartType, enabled: enabled, disableMinutes: disableMinutes) { [weak self] result in
            Task { @MainActor in
                self?.isLoading = false
                self?.handleAckResult(result, commandName: "Set Trigger Mode (\(enabled ? "enable" : "disable"))")
            }
        }
    }

    func getSmartTriggerMode(smid: Int) {
        guard let sdk = IoTAppCore.current else { showError("SDK not initialized"); return }
        isLoading = true; lastError = nil; lastResult = nil
        sdk.deviceCmdHandler.getSmartTriggerMode(smid: smid) { [weak self] result in
            Task { @MainActor in
                self?.isLoading = false
                switch result {
                case .success(let enabled):
                    self?.lastResult = "Trigger Mode: \(enabled ? "ENABLED" : "DISABLED")"
                case .failure(let error):
                    self?.handleError(error, commandName: "Get Trigger Mode")
                }
            }
        }
    }

    func smartRemoveAnnounce(smid: Int) {
        guard let sdk = IoTAppCore.current else { showError("SDK not initialized"); return }
        sdk.deviceCmdHandler.smartRemoveAnnounce(smid: smid)
        lastResult = "smartRemoveAnnounce(smid=\(smid)) sent (fire-and-forget)"
    }

    // MARK: - Helpers

    private func appendLog(_ message: String) {
        flowLog.append(message)
        print("Smart: \(message)")
    }

    private func handleAckResult(_ result: Result<Int, Error>, commandName: String) {
        switch result {
        case .success(let code):
            lastResult = "\(commandName): Success (code=\(code))"
        case .failure(let error):
            handleError(error, commandName: commandName)
        }
    }

    private func handleError(_ error: Error, commandName: String) {
        lastError = "\(commandName) failed: \(error.localizedDescription)"
    }

    private func showError(_ message: String) {
        lastError = message
    }
}
