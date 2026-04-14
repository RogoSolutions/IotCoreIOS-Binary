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

    // State from schedule creation
    @Published var createdScheduleUuid: String?
    @Published var createdScheduleSmartUuid: String?

    // State from automation creation
    @Published var createdAutomationSmartUuid: String?
    @Published var createdAutomationSmid: Int?

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
        delay: Int
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
        smartUuid: String
    ) {
        appendLog("[Step 2/3] MQTT: bindDeviceSmartCmd(smid=\(smid), elm=\(elementId), delay=\(delay)) ...")

        sdk.deviceCmdHandler.bindDeviceSmartCmd(
            smid: smid,
            devId: targetDeviceId,
            elm: elementId,
            attrValue: cmd,
            delay: delay
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
                        delay: delay
                    )

                case .failure(let error):
                    self.isLoading = false
                    self.appendLog("[Step 2] FAILED: \(error.localizedDescription)")
                    self.showError("MQTT bindCmd failed: \(error.localizedDescription)")
                    self.rollbackSmartContainer(sdk: sdk, smartUuid: smartUuid, flowName: "Scenario")
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
        delay: Int
    ) {
        appendLog("[Step 3/3] REST: POST /api/v1/smartcmd/add ...")

        let cmdEntry: [String: Any] = [
            "cmd": cmd,
            "delay": delay,
            "reversing": 0
        ]

        // TODO: filter should be derived from the cmd device's productCategoryType
        // (legacy: RGBSmartAPI uses device.productCategoryType). Default to 2 for now.
        let smartCmdParams: [String: Any] = [
            "smartId": smartUuid,
            "targetId": targetDeviceId,
            "target": 1,
            "filter": 2, // TODO: derive from device productCategoryType
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
                    self.rollbackSmartContainer(sdk: sdk, smartUuid: smartUuid, flowName: "Scenario")
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
        appendLog("[Delete 2/2] REST: POST /api/v1/smart/delete uuid=\(smartUuid) ...")
        sdk.callApiPost("smart/delete", params: ["uuid": smartUuid], headers: nil) { [weak self] result in
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
            smid: smid,
            smartSubType: 66, // default MOTION for manual-test UI
            devId: devId,
            typeTrigger: typeTrigger,
            elm: elm,
            condition: condition,
            attrValueCondition: attrValueCondition,
            elmExt: nil,
            conditionExt: nil,
            attrValueConditionExt: nil,
            timeCfg: timeCfg,
            timeJob: nil,
            cfm: 1
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

    func bindSmartCmd(smid: Int, devId: String, elm: Int, attrValue: [Int], delay: Int?) {
        guard let sdk = IoTAppCore.current else { showError("SDK not initialized"); return }
        guard !devId.isEmpty else { showError("Device ID required"); return }
        isLoading = true; lastError = nil; lastResult = nil
        sdk.deviceCmdHandler.bindDeviceSmartCmd(smid: smid, devId: devId, elm: elm, attrValue: attrValue, delay: delay) { [weak self] result in
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

    /// Rollback: delete the orphaned smart container from cloud after a partial
    /// flow failure (any step after smart/add). Logs the rollback attempt.
    private func rollbackSmartContainer(sdk: any RGBIotCore, smartUuid: String, flowName: String) {
        appendLog("[Rollback] \(flowName): deleting orphaned smart uuid=\(smartUuid)")
        sdk.callApiPost("smart/delete", params: ["uuid": smartUuid], headers: nil) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success:
                    self.appendLog("[Rollback] \(flowName): smart/delete OK")
                case .failure(let error):
                    self.appendLog("[Rollback] \(flowName): smart/delete FAILED: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Schedule Full Flow
    // Flow: REST smart/add (type=1) → MQTT bindCmd → REST smartcmd/add → REST schedule/add

    /// Run the full Schedule creation flow.
    /// - Parameters:
    ///   - label: Smart label
    ///   - locationId: Location UUID
    ///   - targetDeviceId: Device UUID where the action runs
    ///   - elementId: Element index
    ///   - onOffValue: 0=OFF, 1=ON (mapped to [ACT_ONOFF=1, value])
    ///   - localMinutesFromMidnight: time of day in LOCAL timezone (0..1439)
    ///   - localWeekdays: weekday indices in LOCAL timezone, 0=Sun..6=Sat
    func runScheduleFlow(
        label: String,
        locationId: String,
        targetDeviceId: String,
        elementId: Int,
        onOffValue: Int,
        localMinutesFromMidnight: Int,
        localWeekdays: [Int],
        endpoint: String?,
        partner: String?
    ) {
        guard let sdk = IoTAppCore.current else { showError("SDK not initialized"); return }
        guard !locationId.isEmpty else { showError("Location ID is required"); return }
        guard !targetDeviceId.isEmpty else { showError("Target Device ID is required"); return }
        guard !localWeekdays.isEmpty else { showError("Pick at least one weekday"); return }

        let cmd = [1, onOffValue]  // [ACT_ONOFF, value]

        isLoading = true
        lastError = nil
        lastResult = nil
        flowLog = []
        appendLog("=== Create Schedule Flow ===")
        appendLog("[Step 1/4] REST: POST smart/add (type=1) ...")

        let smartParams: [String: Any] = [
            "label": label,
            "locId": locationId,
            "type": 1,        // Schedule
            "subType": 0
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
                        self.appendLog("[Step 1] FAILED: cannot parse smart/add response")
                        self.showError("Cannot parse smart/add response")
                        return
                    }
                    self.createdScheduleSmartUuid = uuid
                    self.createdSmartUuid = uuid
                    self.createdSmid = smid
                    self.appendLog("[Step 1] OK: uuid=\(uuid), smid=\(smid)")
                    self.scheduleStep2_bindCmd(
                        sdk: sdk,
                        smartUuid: uuid,
                        smid: smid,
                        targetDeviceId: targetDeviceId,
                        elementId: elementId,
                        cmd: cmd,
                        locationId: locationId,
                        localMinutesFromMidnight: localMinutesFromMidnight,
                        localWeekdays: localWeekdays,
                        endpoint: endpoint,
                        partner: partner
                    )
                case .failure(let error):
                    self.isLoading = false
                    self.appendLog("[Step 1] FAILED: \(error.localizedDescription)")
                    self.showError("smart/add failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func scheduleStep2_bindCmd(
        sdk: any RGBIotCore,
        smartUuid: String,
        smid: Int,
        targetDeviceId: String,
        elementId: Int,
        cmd: [Int],
        locationId: String,
        localMinutesFromMidnight: Int,
        localWeekdays: [Int],
        endpoint: String?,
        partner: String?
    ) {
        appendLog("[Step 2/4] MQTT: bindDeviceSmartCmd(smid=\(smid), elm=\(elementId)) ...")
        sdk.deviceCmdHandler.bindDeviceSmartCmd(
            smid: smid,
            devId: targetDeviceId,
            elm: elementId,
            attrValue: cmd,
            delay: 0
        ) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success:
                    self.appendLog("[Step 2] OK: MQTT bind ACK received")
                    self.scheduleStep3_persistSmartCmd(
                        sdk: sdk,
                        smartUuid: smartUuid,
                        smid: smid,
                        targetDeviceId: targetDeviceId,
                        elementId: elementId,
                        cmd: cmd,
                        locationId: locationId,
                        localMinutesFromMidnight: localMinutesFromMidnight,
                        localWeekdays: localWeekdays,
                        endpoint: endpoint,
                        partner: partner
                    )
                case .failure(let error):
                    self.isLoading = false
                    self.appendLog("[Step 2] FAILED: \(error.localizedDescription)")
                    self.showError("MQTT bindCmd failed: \(error.localizedDescription)")
                    self.rollbackSmartContainer(sdk: sdk, smartUuid: smartUuid, flowName: "Schedule")
                }
            }
        }
    }

    private func scheduleStep3_persistSmartCmd(
        sdk: any RGBIotCore,
        smartUuid: String,
        smid: Int,
        targetDeviceId: String,
        elementId: Int,
        cmd: [Int],
        locationId: String,
        localMinutesFromMidnight: Int,
        localWeekdays: [Int],
        endpoint: String?,
        partner: String?
    ) {
        appendLog("[Step 3/4] REST: POST smartcmd/add ...")
        let cmdEntry: [String: Any] = [
            "cmd": cmd,
            "delay": 0,
            "reversing": 0
        ]
        // TODO: filter should be derived from the cmd device's productCategoryType
        // (legacy: RGBSmartAPI uses device.productCategoryType). Default to 2 for now.
        let smartCmdParams: [String: Any] = [
            "smartId": smartUuid,
            "targetId": targetDeviceId,
            "target": 1,
            "filter": 2, // TODO: derive from device productCategoryType
            "type": 0,
            "cfm": 0,
            "cmds": ["\(elementId)": cmdEntry]
        ]
        sdk.callApiPost("smartcmd/add", params: smartCmdParams, headers: nil) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success:
                    self.appendLog("[Step 3] OK: SmartCmd persisted")
                    self.scheduleStep4_addSchedule(
                        sdk: sdk,
                        smartUuid: smartUuid,
                        smid: smid,
                        locationId: locationId,
                        localMinutesFromMidnight: localMinutesFromMidnight,
                        localWeekdays: localWeekdays,
                        endpoint: endpoint,
                        partner: partner
                    )
                case .failure(let error):
                    self.isLoading = false
                    self.appendLog("[Step 3] FAILED: \(error.localizedDescription)")
                    self.showError("smartcmd/add failed: \(error.localizedDescription)")
                    self.rollbackSmartContainer(sdk: sdk, smartUuid: smartUuid, flowName: "Schedule")
                }
            }
        }
    }

    private func scheduleStep4_addSchedule(
        sdk: any RGBIotCore,
        smartUuid: String,
        smid: Int,
        locationId: String,
        localMinutesFromMidnight: Int,
        localWeekdays: [Int],
        endpoint: String?,
        partner: String?
    ) {
        appendLog("[Step 4/4] REST: POST schedule/add ...")

        // Convert local time + weekdays -> UTC. Mirrors legacy
        // RGBSchedule.convertTimeInCurrentTimeZoneToUTC.
        let (timeUTC, weekdaysUTC) = Self.convertLocalToUTC(
            localMinutes: localMinutesFromMidnight,
            localWeekdays: localWeekdays
        )

        var scheduleParams: [String: Any] = [
            "mode": 0,
            "time": timeUTC,
            "ownerId": smartUuid,
            "ownerType": 11,             // RGBOwnerType.smart
            "locationId": locationId,
            "weekdays": weekdaysUTC,
            "cmd": ["smid": smid]        // Smart-owned schedule: cmd has ONLY smid
        ]
        // Match legacy RGBSchedule: include `endpoint` (MQTT endpoint) and `partner` (partner id)
        // when available. These are sourced from manual UI in the Sample App because the
        // Core SDK does not currently expose public accessors for them.
        if let ep = endpoint, !ep.isEmpty {
            scheduleParams["endpoint"] = ep
        }
        if let p = partner, !p.isEmpty {
            scheduleParams["partner"] = p
        }

        sdk.callApiPost("schedule/add", params: scheduleParams, headers: nil) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success(let data):
                    var detail = ""
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let scheduleUuid = json["uuid"] as? String {
                        self.createdScheduleUuid = scheduleUuid
                        detail = ", scheduleUuid=\(scheduleUuid)"
                    }
                    self.appendLog("[Step 4] OK: Schedule persisted\(detail)")
                    self.appendLog("=== Schedule Created! smid=\(smid) ===")
                    self.lastResult = "Schedule created! smid=\(smid)"
                case .failure(let error):
                    self.appendLog("[Step 4] FAILED: \(error.localizedDescription)")
                    self.showError("schedule/add failed: \(error.localizedDescription)")
                    self.rollbackSmartContainer(sdk: sdk, smartUuid: smartUuid, flowName: "Schedule")
                }
            }
        }
    }

    /// Delete the last created schedule (REST schedule/delete) and its parent Smart.
    func deleteLastSchedule() {
        guard let sdk = IoTAppCore.current else { showError("SDK not initialized"); return }
        guard let scheduleUuid = createdScheduleUuid else {
            showError("No schedule to delete")
            return
        }
        isLoading = true
        lastError = nil
        lastResult = nil
        appendLog("=== Delete Schedule ===")
        appendLog("[Delete 1/2] REST: POST schedule/delete uuid=\(scheduleUuid)")
        sdk.callApiPost("schedule/delete", params: ["uuid": scheduleUuid], headers: nil) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success:
                    self.appendLog("[Delete 1/2] OK")
                    self.createdScheduleUuid = nil
                    // Also delete parent Smart if we created it
                    if let smartUuid = self.createdScheduleSmartUuid, let smid = self.createdSmid {
                        self.appendLog("[Delete 2/2] MQTT removeAnnounce + REST smart delete")
                        sdk.deviceCmdHandler.smartRemoveAnnounce(smid: smid)
                        sdk.callApiPost("smart/delete", params: ["uuid": smartUuid], headers: nil) { delResult in
                            Task { @MainActor in
                                self.isLoading = false
                                switch delResult {
                                case .success:
                                    self.appendLog("[Delete 2/2] OK: Smart deleted")
                                    self.lastResult = "Schedule + Smart deleted"
                                    self.createdScheduleSmartUuid = nil
                                    self.createdSmartUuid = nil
                                    self.createdSmid = nil
                                case .failure(let error):
                                    self.appendLog("[Delete 2/2] FAILED: \(error.localizedDescription)")
                                    self.showError("Smart delete failed: \(error.localizedDescription)")
                                }
                            }
                        }
                    } else {
                        self.isLoading = false
                        self.lastResult = "Schedule deleted"
                    }
                case .failure(let error):
                    self.isLoading = false
                    self.appendLog("[Delete 1/2] FAILED: \(error.localizedDescription)")
                    self.showError("schedule/delete failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Automation Full Flow
    // Flow: REST smart/add (type=2) → MQTT bindTrigger → REST smarttrigger/add
    //       → MQTT bindCmd → REST smartcmd/add

    func runAutomationFlow(
        label: String,
        locationId: String,
        smartSubType: Int,
        triggerDeviceId: String,
        triggerElm: Int,
        condition: Int,
        attrValueCondition: [Int],
        typeTrigger: Int,
        timeCfg: [Int]?,
        timeJob: [Int]?,
        cmdDeviceId: String,
        cmdElm: Int,
        cmdAttrValue: [Int],
        cmdDelay: Int
    ) {
        guard let sdk = IoTAppCore.current else { showError("SDK not initialized"); return }
        guard !locationId.isEmpty else { showError("Location ID is required"); return }
        guard !triggerDeviceId.isEmpty else { showError("Trigger Device ID is required"); return }
        guard !cmdDeviceId.isEmpty else { showError("Command Device ID is required"); return }
        guard !attrValueCondition.isEmpty else { showError("Trigger attr value is required"); return }
        guard !cmdAttrValue.isEmpty else { showError("Command attr value is required"); return }

        isLoading = true
        lastError = nil
        lastResult = nil
        flowLog = []
        appendLog("=== Create Automation Flow ===")

        // Step 1: REST — Create Smart container (type=2 = Automation)
        appendLog("[Step 1/5] REST: POST smart/add (type=2, subType=\(smartSubType)) ...")

        let smartParams: [String: Any] = [
            "label": label,
            "locId": locationId,
            "type": 2,
            "subType": smartSubType
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
                    self.createdAutomationSmartUuid = uuid
                    self.createdAutomationSmid = smid
                    self.createdSmartUuid = uuid
                    self.createdSmid = smid
                    self.appendLog("[Step 1] OK: uuid=\(uuid), smid=\(smid)")

                    self.autoStep2_bindTrigger(
                        sdk: sdk, smid: smid, smartUuid: uuid,
                        smartSubType: smartSubType, locationId: locationId,
                        triggerDeviceId: triggerDeviceId, triggerElm: triggerElm,
                        condition: condition, attrValueCondition: attrValueCondition,
                        typeTrigger: typeTrigger, timeCfg: timeCfg, timeJob: timeJob,
                        cmdDeviceId: cmdDeviceId, cmdElm: cmdElm,
                        cmdAttrValue: cmdAttrValue, cmdDelay: cmdDelay
                    )

                case .failure(let error):
                    self.isLoading = false
                    self.appendLog("[Step 1] FAILED: \(error.localizedDescription)")
                    self.showError("smart/add failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func autoStep2_bindTrigger(
        sdk: any RGBIotCore,
        smid: Int, smartUuid: String, smartSubType: Int, locationId: String,
        triggerDeviceId: String, triggerElm: Int, condition: Int,
        attrValueCondition: [Int], typeTrigger: Int,
        timeCfg: [Int]?, timeJob: [Int]?,
        cmdDeviceId: String, cmdElm: Int, cmdAttrValue: [Int], cmdDelay: Int
    ) {
        appendLog("[Step 2/5] MQTT: bindDeviceSmartTrigger(smid=\(smid), elm=\(triggerElm), cond=\(condition)) ...")

        sdk.deviceCmdHandler.bindDeviceSmartTrigger(
            smid: smid,
            smartSubType: smartSubType,
            devId: triggerDeviceId,
            typeTrigger: typeTrigger,
            elm: triggerElm,
            condition: condition,
            attrValueCondition: attrValueCondition,
            elmExt: nil,
            conditionExt: nil,
            attrValueConditionExt: nil,
            timeCfg: timeCfg,
            timeJob: timeJob,
            cfm: 1
        ) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success:
                    self.appendLog("[Step 2] OK: MQTT bind trigger ACK received")
                    self.autoStep3_persistTrigger(
                        sdk: sdk, smid: smid, smartUuid: smartUuid,
                        locationId: locationId,
                        triggerDeviceId: triggerDeviceId, triggerElm: triggerElm,
                        condition: condition, attrValueCondition: attrValueCondition,
                        typeTrigger: typeTrigger, timeCfg: timeCfg, timeJob: timeJob,
                        cmdDeviceId: cmdDeviceId, cmdElm: cmdElm,
                        cmdAttrValue: cmdAttrValue, cmdDelay: cmdDelay
                    )
                case .failure(let error):
                    self.isLoading = false
                    self.appendLog("[Step 2] FAILED: \(error.localizedDescription)")
                    self.showError("MQTT bindTrigger failed: \(error.localizedDescription)")
                    self.rollbackSmartContainer(sdk: sdk, smartUuid: smartUuid, flowName: "Automation")
                }
            }
        }
    }

    private func autoStep3_persistTrigger(
        sdk: any RGBIotCore,
        smid: Int, smartUuid: String, locationId: String,
        triggerDeviceId: String, triggerElm: Int, condition: Int,
        attrValueCondition: [Int], typeTrigger: Int,
        timeCfg: [Int]?, timeJob: [Int]?,
        cmdDeviceId: String, cmdElm: Int, cmdAttrValue: [Int], cmdDelay: Int
    ) {
        appendLog("[Step 3/5] REST: POST smarttrigger/add ...")

        // mix: trigger device eid low 16 bits packed with count=1
        // Legacy: mix = (device.eid & 0xFFFF) | (count << 16)
        let triggerDevice = devices.first(where: { $0.uuid == triggerDeviceId })
        let triggerEid = triggerDevice?.eid ?? 0
        let newMix = (triggerEid & 0xFFFF) | (1 << 16)

        var params: [String: Any] = [
            "smartId": smartUuid,
            "devId": triggerDeviceId,
            "cfm": 1,
            "elm": triggerElm,
            "condition": condition,
            "value": attrValueCondition,
            "mix": newMix,
            "type": typeTrigger,
            "locId": locationId
        ]
        if let tc = timeCfg {
            params["timeCfg"] = tc
        }
        if let tj = timeJob {
            params["timeJob"] = tj
        }

        sdk.callApiPost("smarttrigger/add", params: params, headers: nil) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success(let data):
                    var detail = ""
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let triggerUuid = json["uuid"] as? String {
                        detail = ", triggerUuid=\(triggerUuid)"
                    }
                    self.appendLog("[Step 3] OK: SmartTrigger persisted\(detail)")
                    self.autoStep4_bindCmd(
                        sdk: sdk, smid: smid, smartUuid: smartUuid,
                        cmdDeviceId: cmdDeviceId, cmdElm: cmdElm,
                        cmdAttrValue: cmdAttrValue, cmdDelay: cmdDelay
                    )
                case .failure(let error):
                    self.isLoading = false
                    self.appendLog("[Step 3] FAILED: \(error.localizedDescription)")
                    self.showError("smarttrigger/add failed: \(error.localizedDescription)")
                    self.rollbackSmartContainer(sdk: sdk, smartUuid: smartUuid, flowName: "Automation")
                }
            }
        }
    }

    private func autoStep4_bindCmd(
        sdk: any RGBIotCore,
        smid: Int, smartUuid: String,
        cmdDeviceId: String, cmdElm: Int, cmdAttrValue: [Int], cmdDelay: Int
    ) {
        appendLog("[Step 4/5] MQTT: bindDeviceSmartCmd(smid=\(smid), elm=\(cmdElm), delay=\(cmdDelay)) ...")

        sdk.deviceCmdHandler.bindDeviceSmartCmd(
            smid: smid,
            devId: cmdDeviceId,
            elm: cmdElm,
            attrValue: cmdAttrValue,
            delay: cmdDelay
        ) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success:
                    self.appendLog("[Step 4] OK: MQTT bind cmd ACK received")
                    self.autoStep5_persistCmd(
                        sdk: sdk, smid: smid, smartUuid: smartUuid,
                        cmdDeviceId: cmdDeviceId, cmdElm: cmdElm,
                        cmdAttrValue: cmdAttrValue, cmdDelay: cmdDelay
                    )
                case .failure(let error):
                    self.isLoading = false
                    self.appendLog("[Step 4] FAILED: \(error.localizedDescription)")
                    self.showError("MQTT bindCmd failed: \(error.localizedDescription)")
                    self.rollbackSmartContainer(sdk: sdk, smartUuid: smartUuid, flowName: "Automation")
                }
            }
        }
    }

    private func autoStep5_persistCmd(
        sdk: any RGBIotCore,
        smid: Int, smartUuid: String,
        cmdDeviceId: String, cmdElm: Int, cmdAttrValue: [Int], cmdDelay: Int
    ) {
        appendLog("[Step 5/5] REST: POST smartcmd/add ...")

        let cmdEntry: [String: Any] = [
            "cmd": cmdAttrValue,
            "delay": cmdDelay,
            "reversing": 0
        ]
        // TODO: filter should be derived from the cmd device's productCategoryType
        // (legacy: RGBSmartAPI uses device.productCategoryType). IoTDevice model
        // does not expose productCategoryType yet, so default to 2 for now.
        let smartCmdParams: [String: Any] = [
            "smartId": smartUuid,
            "targetId": cmdDeviceId,
            "target": 1,
            "filter": 2, // TODO: derive from device productCategoryType
            "type": 0,
            "cfm": 0,
            "cmds": ["\(cmdElm)": cmdEntry]
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
                    self.appendLog("[Step 5] OK: SmartCmd persisted\(detail)")
                    self.appendLog("=== Automation Created! smid=\(smid) ===")
                    self.lastResult = "Automation created! smid=\(smid)"
                case .failure(let error):
                    self.appendLog("[Step 5] FAILED: \(error.localizedDescription)")
                    self.showError("smartcmd/add failed: \(error.localizedDescription)")
                    self.rollbackSmartContainer(sdk: sdk, smartUuid: smartUuid, flowName: "Automation")
                }
            }
        }
    }

    /// Delete the last created automation (REST smart/delete).
    func deleteLastAutomation() {
        guard let sdk = IoTAppCore.current else { showError("SDK not initialized"); return }
        guard let smartUuid = createdAutomationSmartUuid,
              let smid = createdAutomationSmid else {
            showError("No automation to delete")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil
        appendLog("=== Delete Automation ===")
        appendLog("[Delete 1/2] MQTT: smartRemoveAnnounce(smid=\(smid))")
        sdk.deviceCmdHandler.smartRemoveAnnounce(smid: smid)
        appendLog("[Delete 1/2] OK: sent (fire-and-forget)")

        appendLog("[Delete 2/2] REST: POST smart/delete uuid=\(smartUuid)")
        sdk.callApiPost("smart/delete", params: ["uuid": smartUuid], headers: nil) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success:
                    self.appendLog("[Delete 2/2] OK: Automation deleted from cloud")
                    self.lastResult = "Automation deleted"
                    self.createdAutomationSmartUuid = nil
                    self.createdAutomationSmid = nil
                    self.createdSmartUuid = nil
                    self.createdSmid = nil
                case .failure(let error):
                    self.appendLog("[Delete 2/2] FAILED: \(error.localizedDescription)")
                    self.showError("Delete failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Schedule Time Conversion
    // Mirrors legacy RGBSchedule.convertTimeInCurrentTimeZoneToUTC.
    // Input: local minutes-from-midnight + weekdays in 0=Sun..6=Sat (local).
    // Output: UTC minutes-from-midnight + weekdays in 0=Sun..6=Sat (UTC).
    static func convertLocalToUTC(localMinutes: Int, localWeekdays: [Int]) -> (Int, [Int]) {
        let hours = localMinutes / 60
        let mins = localMinutes % 60

        var calLocal = Calendar(identifier: .gregorian)
        calLocal.timeZone = TimeZone.current

        // Compute timeUTC by taking "today at hours:mins" in local TZ, then reading UTC H:M.
        let now = Date()
        var comps = calLocal.dateComponents([.year, .month, .day], from: now)
        comps.hour = hours
        comps.minute = mins
        guard let localDate = calLocal.date(from: comps) else {
            return (localMinutes, localWeekdays)
        }
        var calUTC = Calendar(identifier: .gregorian)
        calUTC.timeZone = TimeZone(identifier: "UTC")!
        let utcComps = calUTC.dateComponents([.hour, .minute], from: localDate)
        let timeUTC = (utcComps.hour ?? 0) * 60 + (utcComps.minute ?? 0)

        // For each local weekday, compute the UTC weekday for the chosen time.
        // Convention: rg uses 0=Sun..6=Sat. Calendar.weekday: 1=Sun..7=Sat.
        // We pick a reference week (this week) and offset to that weekday.
        let todayWeekdayCal = calLocal.component(.weekday, from: now) // 1..7
        let todayRg = todayWeekdayCal - 1  // 0..6

        let utcWeekdays: [Int] = localWeekdays.map { rgLocalDay in
            let dayOffset = rgLocalDay - todayRg
            guard let candidate = calLocal.date(byAdding: .day, value: dayOffset, to: localDate) else {
                return rgLocalDay
            }
            let utcWeekday = calUTC.component(.weekday, from: candidate) // 1..7
            return utcWeekday - 1
        }

        return (timeUTC, utcWeekdays)
    }
}
