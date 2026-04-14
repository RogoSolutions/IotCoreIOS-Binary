//
//  SmartDetailViewModel.swift
//  IoTCoreSample
//
//  ViewModel for SmartDetailView — loads a Smart's cmds + (for type=1) its
//  owning schedule, and performs field-level updates using SDK primitives.
//
//  Scope (per T-041 Phase 2):
//    - Scenario (type=0): edit label + cmds
//    - Schedule (type=1): edit label + cmds + schedule time/weekdays
//    - Automation (type=2): edit label ONLY (cmd/trigger edit disabled —
//      requires SDK upgrade T-034).
//
//  This ViewModel only composes existing SDK primitives:
//    - callApiGet("smartcmd/get"), callApiGet("schedule/getAll")
//    - callApiPost("smart/update" | "smartcmd/update" | "schedule/update")
//    - deviceCmdHandler.unbindDeviceSmartCmd / bindDeviceSmartCmd
//
//  It does NOT introduce any new public SDK API.
//

import Foundation
import Combine
import IotCoreIOS

// MARK: - Draft Models

/// Local draft of a single SmartCmd row (one element of one target device).
/// We keep one (elementId, cmd) pair per draft because legacy `cmds` dict is
/// usually single-entry per smartcmd row and the UI only lets the user pick
/// one element at a time.
struct SmartCmdDraft: Identifiable, Hashable {
    /// `uuid` of the persisted smartcmd row (REST `smartcmd/update` key).
    let uuid: String
    /// `smartId` from the server — same for all cmds under the Smart.
    let smartId: String
    /// Device uuid this cmd targets. Read-only in the edit UI.
    let targetId: String
    /// `filter` = productCategoryType int from server.
    let filter: Int
    /// Element id (string key in the `cmds` dict, e.g. "0").
    var elementId: Int
    /// Current cmd value — e.g. [1, 1] for ON, [1, 0] for OFF (ACT_ONOFF).
    var cmd: [Int]
    /// Delay in seconds.
    var delay: Int
    /// Reversing flag.
    var reversing: Int

    /// Snapshot of the server value so we can compute diffs.
    let original: Snapshot

    var id: String { "\(uuid)#\(original.elementId)" }

    struct Snapshot: Hashable {
        let elementId: Int
        let cmd: [Int]
        let delay: Int
    }

    var isDirty: Bool {
        original.elementId != elementId
            || original.cmd != cmd
            || original.delay != delay
    }

    /// Simple ON/OFF display for [1, x] cmds.
    var displayAction: String {
        if cmd.count >= 2, cmd[0] == 1 {
            return cmd[1] == 1 ? "ON" : "OFF"
        }
        return cmd.map(String.init).joined(separator: ",")
    }
}

// MARK: - Trigger Row (display + add/edit/delete)

/// Representation of a SmartTrigger row attached to an Automation.
/// Stores all fields needed for display, edit, and REST persistence.
struct SmartTriggerRow: Identifiable, Hashable {
    let uuid: String
    let smartId: String
    let sourceId: String      // device uuid that triggers (REST field: devId)
    let smid: Int?
    let summary: String       // pre-formatted display string

    // Editable fields
    var elm: Int
    var condition: Int
    var attrValueCondition: [Int]   // REST field: "value"
    var typeTrigger: Int            // REST field: "type" — OWNER(0) / EXT(1)
    var cfm: Int
    var mix: Int
    var locId: String

    // Optional fields
    var elmExt: Int?
    var conditionExt: Int?
    var attrValueConditionExt: [Int]?  // REST field: "valueExt"
    var timeCfg: [Int]?
    var timeJob: [Int]?

    var id: String { uuid }

    // MARK: - mix increment (mirrors legacy RGBSmartTrigger.getUpdateMix)
    /// Increments the count portion (bytes 2-3) of the 4-byte packed `mix` int.
    static func incrementMix(_ oldMix: Int) -> Int {
        let b0 = UInt8((oldMix >> 0) & 0xFF)
        let b1 = UInt8((oldMix >> 8) & 0xFF)
        let countLo = UInt8((oldMix >> 16) & 0xFF)
        let countHi = UInt8((oldMix >> 24) & 0xFF)
        let count = UInt16(countHi) << 8 | UInt16(countLo)
        let newCount = count &+ 1
        let newCountLo = UInt8(newCount & 0xFF)
        let newCountHi = UInt8((newCount >> 8) & 0xFF)
        return Int(b0) | (Int(b1) << 8) | (Int(newCountLo) << 16) | (Int(newCountHi) << 24)
    }
}

// MARK: - ViewModel

@MainActor
final class SmartDetailViewModel: ObservableObject {

    // MARK: Inputs

    let smart: SmartItem

    // MARK: Published — editable drafts

    @Published var draftLabel: String
    @Published var draftCmds: [SmartCmdDraft] = []

    // Automation triggers (read-only display + delete only)
    @Published var triggers: [SmartTriggerRow] = []

    // Device list for "Add Command" sheet (loaded on demand)
    @Published var availableDevices: [IoTDevice] = []
    @Published var isLoadingDevices: Bool = false

    // Inline activity log (mutating ops: add cmd, delete cmd, delete trigger)
    @Published var opLog: [String] = []
    @Published var isMutating: Bool = false

    // Schedule-only
    @Published var draftHour: Int = 0
    @Published var draftMinute: Int = 0
    /// Weekdays in LOCAL timezone, 0=Sun..6=Sat.
    @Published var draftWeekdays: Set<Int> = []

    // MARK: Published — status

    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    @Published var saveLog: [String] = []
    @Published var didSaveSuccessfully: Bool = false

    // MARK: Private — originals (server snapshot) for dirty tracking

    private let originalLabel: String
    private var originalHour: Int = 0
    private var originalMinute: Int = 0
    private var originalWeekdays: Set<Int> = []
    /// Full schedule row as returned by `schedule/getAll` — we echo it on update
    /// so we don't drop unknown fields.
    private var originalScheduleRow: [String: Any]?

    // MARK: Dirty flags

    var isLabelDirty: Bool { draftLabel != originalLabel }

    var dirtyCmds: [SmartCmdDraft] { draftCmds.filter { $0.isDirty } }

    var isScheduleDirty: Bool {
        guard smart.smartType == .schedule else { return false }
        return draftHour != originalHour
            || draftMinute != originalMinute
            || draftWeekdays != originalWeekdays
    }

    var hasAnyDirty: Bool {
        isLabelDirty || !dirtyCmds.isEmpty || isScheduleDirty
    }

    var canEditCmds: Bool {
        smart.smartType == .scenario || smart.smartType == .schedule || smart.smartType == .automation
    }

    var canEditSchedule: Bool { smart.smartType == .schedule }

    // MARK: Init

    init(smart: SmartItem) {
        self.smart = smart
        let label = smart.label ?? ""
        self.draftLabel = label
        self.originalLabel = label
    }

    // MARK: - Load

    /// Load cmds (+ schedule row for type=1) from the cloud.
    func loadDetail() async {
        guard let sdk = IoTAppCore.current else {
            errorMessage = "SDK not initialized"
            return
        }
        isLoading = true
        errorMessage = nil

        // 1) Load all smartcmd and filter by smartId.
        do {
            let cmds = try await fetchSmartCmds(sdk: sdk, smartUuid: smart.uuid)
            self.draftCmds = cmds
        } catch {
            self.errorMessage = "Load smartcmd failed: \(error.localizedDescription)"
            self.isLoading = false
            return
        }

        // 1b) For Automation, also load triggers (read-only).
        if smart.smartType == .automation {
            do {
                self.triggers = try await fetchSmartTriggers(sdk: sdk, smartUuid: smart.uuid)
            } catch {
                self.errorMessage = "Load triggers failed: \(error.localizedDescription)"
            }
        }

        // 2) For schedule, load schedule/getAll and filter by ownerId == smart.uuid.
        if smart.smartType == .schedule {
            do {
                if let row = try await fetchScheduleRow(sdk: sdk, ownerId: smart.uuid) {
                    originalScheduleRow = row
                    // time is UTC minutes-from-midnight; convert to LOCAL for display.
                    let timeUTC = (row["time"] as? Int) ?? 0
                    let weekdaysUTC = (row["weekdays"] as? [Int]) ?? []
                    let (localMinutes, localWeekdays) = Self.convertUTCToLocal(
                        timeUTC: timeUTC,
                        weekdaysUTC: weekdaysUTC
                    )
                    self.originalHour = localMinutes / 60
                    self.originalMinute = localMinutes % 60
                    self.originalWeekdays = Set(localWeekdays)
                    self.draftHour = self.originalHour
                    self.draftMinute = self.originalMinute
                    self.draftWeekdays = self.originalWeekdays
                }
            } catch {
                self.errorMessage = "Load schedule failed: \(error.localizedDescription)"
            }
        }

        self.isLoading = false
    }

    private func fetchSmartCmds(sdk: any RGBIotCore, smartUuid: String) async throws -> [SmartCmdDraft] {
        let data: Data = try await withCheckedThrowingContinuation { cont in
            sdk.callApiGet("smartcmd/get", params: nil, headers: nil) { result in
                switch result {
                case .success(let d): cont.resume(returning: d)
                case .failure(let e): cont.resume(throwing: e)
                }
            }
        }
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        var drafts: [SmartCmdDraft] = []
        for row in arr {
            guard let smartId = row["smartId"] as? String, smartId == smartUuid else { continue }
            guard let uuid = row["uuid"] as? String else { continue }
            let targetId = (row["targetId"] as? String) ?? ""
            let filter = (row["filter"] as? Int) ?? 0
            guard let cmds = row["cmds"] as? [String: Any] else { continue }
            // Each row may contain one or more element entries; emit one draft per entry.
            for (elmKey, value) in cmds {
                guard let elmId = Int(elmKey),
                      let entry = value as? [String: Any] else { continue }
                let cmdArr = (entry["cmd"] as? [Int]) ?? []
                let delay = (entry["delay"] as? Int) ?? 0
                let reversing = (entry["reversing"] as? Int) ?? 0
                let snap = SmartCmdDraft.Snapshot(elementId: elmId, cmd: cmdArr, delay: delay)
                drafts.append(SmartCmdDraft(
                    uuid: uuid,
                    smartId: smartId,
                    targetId: targetId,
                    filter: filter,
                    elementId: elmId,
                    cmd: cmdArr,
                    delay: delay,
                    reversing: reversing,
                    original: snap
                ))
            }
        }
        return drafts
    }

    private func fetchScheduleRow(sdk: any RGBIotCore, ownerId: String) async throws -> [String: Any]? {
        let data: Data = try await withCheckedThrowingContinuation { cont in
            sdk.callApiGet("schedule/getAll", params: nil, headers: nil) { result in
                switch result {
                case .success(let d): cont.resume(returning: d)
                case .failure(let e): cont.resume(throwing: e)
                }
            }
        }
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        return arr.first { ($0["ownerId"] as? String) == ownerId }
    }

    // MARK: - Save

    /// Confirmation summary (plain text) of pending changes.
    func changesSummary() -> String {
        var lines: [String] = []
        if isLabelDirty {
            lines.append("- Label: \"\(originalLabel)\" -> \"\(draftLabel)\"")
        }
        for d in dirtyCmds {
            lines.append("- Cmd \(d.uuid.prefix(8))… elm \(d.original.elementId)->\(d.elementId), \(d.original.cmd)->\(d.cmd), delay \(d.original.delay)s->\(d.delay)s")
        }
        if isScheduleDirty {
            let oldDays = originalWeekdays.sorted().map(String.init).joined(separator: ",")
            let newDays = draftWeekdays.sorted().map(String.init).joined(separator: ",")
            lines.append(String(format: "- Schedule: %02d:%02d [%@] -> %02d:%02d [%@]",
                                originalHour, originalMinute, oldDays,
                                draftHour, draftMinute, newDays))
        }
        return lines.isEmpty ? "No changes." : lines.joined(separator: "\n")
    }

    /// Run updates sequentially: label -> cmds -> schedule. Stops on first error.
    func save() async {
        guard hasAnyDirty else { return }
        guard IoTAppCore.current != nil else {
            errorMessage = "SDK not initialized"
            return
        }

        isSaving = true
        errorMessage = nil
        saveLog = []
        didSaveSuccessfully = false

        do {
            if isLabelDirty {
                appendLog("[Label] POST smart/update …")
                try await updateLabel()
                appendLog("[Label] OK")
            }

            for draft in dirtyCmds {
                appendLog("[Cmd \(draft.uuid.prefix(8))…] unbind -> bind -> REST …")
                try await updateCmd(draft)
                appendLog("[Cmd \(draft.uuid.prefix(8))…] OK")
            }

            if isScheduleDirty {
                appendLog("[Schedule] POST schedule/update …")
                try await updateSchedule()
                appendLog("[Schedule] OK")
            }

            appendLog("=== Save complete ===")
            didSaveSuccessfully = true
        } catch {
            appendLog("FAILED: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    // MARK: - Individual update steps

    private func updateLabel() async throws {
        guard let sdk = IoTAppCore.current else {
            throw NSError(domain: "SmartDetail", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "SDK not initialized"])
        }
        let params: [String: Any] = [
            "uuid": smart.uuid,
            "label": draftLabel
        ]
        _ = try await restPost(sdk: sdk, path: "smart/update", params: params)
    }

    private func updateCmd(_ draft: SmartCmdDraft) async throws {
        guard let sdk = IoTAppCore.current else {
            throw NSError(domain: "SmartDetail", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "SDK not initialized"])
        }
        guard let smid = smart.smid else {
            throw NSError(domain: "SmartDetail", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing smid on smart row"])
        }

        // 1) MQTT unbind (old binding)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            sdk.deviceCmdHandler.unbindDeviceSmartCmd(smid: smid, devId: draft.targetId) { result in
                switch result {
                case .success: cont.resume()
                case .failure(let e): cont.resume(throwing: e)
                }
            }
        }

        // 2) MQTT bind (new element + cmd)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            sdk.deviceCmdHandler.bindDeviceSmartCmd(
                smid: smid,
                devId: draft.targetId,
                elm: draft.elementId,
                attrValue: draft.cmd,
                delay: draft.delay
            ) { result in
                switch result {
                case .success: cont.resume()
                case .failure(let e): cont.resume(throwing: e)
                }
            }
        }

        // 3) REST smartcmd/update
        let cmdEntry: [String: Any] = [
            "cmd": draft.cmd,
            "delay": draft.delay,
            "reversing": draft.reversing
        ]
        let params: [String: Any] = [
            "uuid": draft.uuid,
            "smartId": draft.smartId,
            "targetId": draft.targetId,
            "filter": draft.filter,
            "cfm": 0,   // legacy hard-codes 0
            "cmds": ["\(draft.elementId)": cmdEntry]
        ]
        _ = try await restPost(sdk: sdk, path: "smartcmd/update", params: params)
    }

    private func updateSchedule() async throws {
        guard let sdk = IoTAppCore.current else {
            throw NSError(domain: "SmartDetail", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "SDK not initialized"])
        }
        guard var row = originalScheduleRow else {
            throw NSError(domain: "SmartDetail", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No schedule row loaded"])
        }

        // Local -> UTC using the same helper as Create flow.
        let localMinutes = draftHour * 60 + draftMinute
        let (timeUTC, weekdaysUTC) = SmartTestViewModel.convertLocalToUTC(
            localMinutes: localMinutes,
            localWeekdays: draftWeekdays.sorted()
        )
        row["time"] = timeUTC
        row["weekdays"] = weekdaysUTC

        // RGBSchedule update expects the full row; we echo everything we loaded
        // plus the two changed fields. Drop any fields that JSONSerialization
        // cannot encode (should be none — the row came from JSON).
        _ = try await restPost(sdk: sdk, path: "schedule/update", params: row)
    }

    // MARK: - Helpers

    private func restPost(sdk: any RGBIotCore, path: String, params: [String: Any]) async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            sdk.callApiPost(path, params: params, headers: nil) { result in
                switch result {
                case .success(let d): cont.resume(returning: d)
                case .failure(let e): cont.resume(throwing: e)
                }
            }
        }
    }

    private func appendLog(_ s: String) {
        saveLog.append(s)
        print("SmartDetail: \(s)")
    }

    // MARK: - Add / Delete Cmd (composes existing primitives)

    /// Load user devices for the "Add Command" picker.
    func loadDevicesIfNeeded() {
        guard let sdk = IoTAppCore.current, availableDevices.isEmpty, !isLoadingDevices else { return }
        isLoadingDevices = true
        sdk.callApiGetUserDevices { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoadingDevices = false
                if case .success(let data) = result,
                   let parsed = try? JSONDecoder().decode([IoTDevice].self, from: data) {
                    self.availableDevices = parsed
                }
            }
        }
    }

    /// Element ids for a device, mirroring SmartTestViewModel.elementIds.
    func elementIds(for device: IoTDevice) -> [Int] {
        if let infos = device.elementInfos {
            return infos.keys.compactMap { Int($0) }.sorted()
        }
        return device.elementIds ?? [0]
    }

    /// Add a new SmartCmd to this Smart (Scenario or Schedule):
    /// MQTT bindDeviceSmartCmd -> REST POST smartcmd/add. On success, append to draftCmds.
    func addCmd(targetDeviceId: String, elementId: Int, onOffValue: Int, delay: Int) async {
        guard canEditCmds else { return }
        guard let sdk = IoTAppCore.current else {
            errorMessage = "SDK not initialized"; return
        }
        guard let smid = smart.smid else {
            errorMessage = "Missing smid"; return
        }

        isMutating = true
        errorMessage = nil
        let cmd = [1, onOffValue]  // ACT_ONOFF
        appendOpLog("[AddCmd] MQTT bindDeviceSmartCmd elm=\(elementId) ...")

        do {
            // 1) MQTT bind
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                sdk.deviceCmdHandler.bindDeviceSmartCmd(
                    smid: smid, devId: targetDeviceId, elm: elementId,
                    attrValue: cmd, delay: delay
                ) { result in
                    switch result {
                    case .success: cont.resume()
                    case .failure(let e): cont.resume(throwing: e)
                    }
                }
            }
            appendOpLog("[AddCmd] MQTT bind OK")

            // 2) REST smartcmd/add (body shape mirrors SmartTestViewModel.step3_persistSmartCmd)
            let cmdEntry: [String: Any] = [
                "cmd": cmd,
                "delay": delay,
                "reversing": 0
            ]
            // TODO: filter should be derived from the cmd device's productCategoryType
            // (legacy: RGBSmartAPI uses device.productCategoryType). Default to 2 for now.
            let params: [String: Any] = [
                "smartId": smart.uuid,
                "targetId": targetDeviceId,
                "target": 1,
                "filter": 2, // TODO: derive from device productCategoryType
                "type": 0,
                "cfm": 0,
                "cmds": ["\(elementId)": cmdEntry]
            ]
            let data = try await restPost(sdk: sdk, path: "smartcmd/add", params: params)
            appendOpLog("[AddCmd] REST smartcmd/add OK")

            // 3) Parse uuid from response and append to local list
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let newUuid = (json?["uuid"] as? String) ?? UUID().uuidString
            let snap = SmartCmdDraft.Snapshot(elementId: elementId, cmd: cmd, delay: delay)
            let draft = SmartCmdDraft(
                uuid: newUuid,
                smartId: smart.uuid,
                targetId: targetDeviceId,
                filter: 2, // TODO: derive from device productCategoryType
                elementId: elementId,
                cmd: cmd,
                delay: delay,
                reversing: 0,
                original: snap
            )
            self.draftCmds.append(draft)
        } catch {
            appendOpLog("[AddCmd] FAILED: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isMutating = false
    }

    /// Delete a SmartCmd row: MQTT unbind -> REST POST smartcmd/delete {"uuid": ...}.
    func deleteCmd(_ draft: SmartCmdDraft) async {
        guard let sdk = IoTAppCore.current else { errorMessage = "SDK not initialized"; return }
        guard let smid = smart.smid else { errorMessage = "Missing smid"; return }
        isMutating = true
        errorMessage = nil
        appendOpLog("[DeleteCmd \(draft.uuid.prefix(8))…] MQTT unbind ...")
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                sdk.deviceCmdHandler.unbindDeviceSmartCmd(smid: smid, devId: draft.targetId) { result in
                    switch result {
                    case .success: cont.resume()
                    case .failure(let e): cont.resume(throwing: e)
                    }
                }
            }
            appendOpLog("[DeleteCmd] MQTT unbind OK")
            _ = try await restPost(sdk: sdk, path: "smartcmd/delete", params: ["uuid": draft.uuid])
            appendOpLog("[DeleteCmd] REST smartcmd/delete OK")
            self.draftCmds.removeAll { $0.id == draft.id }
        } catch {
            appendOpLog("[DeleteCmd] FAILED: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        isMutating = false
    }

    // MARK: - Triggers (Automation): load + delete

    private func fetchSmartTriggers(sdk: any RGBIotCore, smartUuid: String) async throws -> [SmartTriggerRow] {
        let data: Data = try await withCheckedThrowingContinuation { cont in
            sdk.callApiGet("smarttrigger/get", params: nil, headers: nil) { result in
                switch result {
                case .success(let d): cont.resume(returning: d)
                case .failure(let e): cont.resume(throwing: e)
                }
            }
        }
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        var rows: [SmartTriggerRow] = []
        for row in arr {
            guard let smartId = row["smartId"] as? String, smartId == smartUuid else { continue }
            guard let uuid = row["uuid"] as? String else { continue }
            // REST field is "devId"; legacy code stored it as sourceId in some places
            let sourceId = (row["devId"] as? String) ?? (row["sourceId"] as? String) ?? ""
            let smid = row["smid"] as? Int
            let elm = (row["elm"] as? Int) ?? 0
            let condition = (row["condition"] as? Int) ?? 2
            let value = (row["value"] as? [Int]) ?? []
            let typeTrigger = (row["type"] as? Int) ?? 0
            let cfm = (row["cfm"] as? Int) ?? 0
            let mix = (row["mix"] as? Int) ?? 0
            let locId = (row["locId"] as? String) ?? ""
            let elmExt = row["elmExt"] as? Int
            let conditionExt = row["conditionExt"] as? Int
            let valueExt = row["valueExt"] as? [Int]
            let timeCfg = row["timeCfg"] as? [Int]
            let timeJob = row["timeJob"] as? [Int]

            // Build a compact summary from present fields for display.
            var bits: [String] = []
            bits.append("type=\(typeTrigger)")
            bits.append("elm=\(elm)")
            bits.append("cond=\(condition)")
            if !value.isEmpty { bits.append("val=\(value)") }
            let summary = bits.joined(separator: " ")

            rows.append(SmartTriggerRow(
                uuid: uuid, smartId: smartId, sourceId: sourceId, smid: smid,
                summary: summary,
                elm: elm, condition: condition, attrValueCondition: value,
                typeTrigger: typeTrigger, cfm: cfm, mix: mix, locId: locId,
                elmExt: elmExt, conditionExt: conditionExt,
                attrValueConditionExt: valueExt,
                timeCfg: timeCfg, timeJob: timeJob
            ))
        }
        return rows
    }

    /// Delete a SmartTrigger: MQTT unbindDeviceSmartTrigger -> REST POST smarttrigger/delete.
    func deleteTrigger(_ row: SmartTriggerRow) async {
        guard let sdk = IoTAppCore.current else { errorMessage = "SDK not initialized"; return }
        guard let smid = smart.smid ?? row.smid else { errorMessage = "Missing smid"; return }
        isMutating = true
        errorMessage = nil
        appendOpLog("[DeleteTrigger \(row.uuid.prefix(8))…] MQTT unbind ...")
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                sdk.deviceCmdHandler.unbindDeviceSmartTrigger(smid: smid, devId: row.sourceId) { result in
                    switch result {
                    case .success: cont.resume()
                    case .failure(let e): cont.resume(throwing: e)
                    }
                }
            }
            appendOpLog("[DeleteTrigger] MQTT unbind OK")
            _ = try await restPost(sdk: sdk, path: "smarttrigger/delete", params: ["uuid": row.uuid])
            appendOpLog("[DeleteTrigger] REST smarttrigger/delete OK")
            self.triggers.removeAll { $0.uuid == row.uuid }
        } catch {
            appendOpLog("[DeleteTrigger] FAILED: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        isMutating = false
    }

    /// Add a new SmartTrigger to this Automation:
    /// MQTT bindDeviceSmartTrigger -> REST POST smarttrigger/add.
    func addTrigger(
        devId: String,
        smartSubType: Int,
        typeTrigger: Int,
        elm: Int,
        condition: Int,
        attrValueCondition: [Int],
        elmExt: Int?,
        conditionExt: Int?,
        attrValueConditionExt: [Int]?,
        timeCfg: [Int]?,
        timeJob: [Int]?,
        cfm: Int
    ) async {
        guard let sdk = IoTAppCore.current else { errorMessage = "SDK not initialized"; return }
        guard let smid = smart.smid else { errorMessage = "Missing smid"; return }

        isMutating = true
        errorMessage = nil
        appendOpLog("[AddTrigger] MQTT bindDeviceSmartTrigger elm=\(elm) ...")

        do {
            // 1) MQTT bind
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                sdk.deviceCmdHandler.bindDeviceSmartTrigger(
                    smid: smid,
                    smartSubType: smartSubType,
                    devId: devId,
                    typeTrigger: typeTrigger,
                    elm: elm,
                    condition: condition,
                    attrValueCondition: attrValueCondition,
                    elmExt: elmExt,
                    conditionExt: conditionExt,
                    attrValueConditionExt: attrValueConditionExt,
                    timeCfg: timeCfg,
                    timeJob: timeJob,
                    cfm: cfm
                ) { result in
                    switch result {
                    case .success: cont.resume()
                    case .failure(let e): cont.resume(throwing: e)
                    }
                }
            }
            appendOpLog("[AddTrigger] MQTT bind OK")

            // 2) REST smarttrigger/add (body matches legacy RGBSmartAPI.addSmartTrigger)
            let locId = smart.locId ?? ""
            // mix: trigger device eid low 16 bits packed with count=1
            // Legacy: mix = (device.eid & 0xFFFF) | (count << 16)
            let triggerDevice = availableDevices.first(where: { $0.uuid == devId })
            let triggerEid = triggerDevice?.eid ?? 0
            let newMix = (triggerEid & 0xFFFF) | (1 << 16)

            var params: [String: Any] = [
                "smartId": smart.uuid,
                "devId": devId,
                "cfm": cfm,
                "elm": elm,
                "condition": condition,
                "value": attrValueCondition,
                "mix": newMix,
                "type": typeTrigger,
                "locId": locId
            ]
            if let ext = attrValueConditionExt {
                params["valueExt"] = ext
            }
            if let e = elmExt {
                params["elmExt"] = e
            }
            if let c = conditionExt {
                params["conditionExt"] = c
            }
            if let tc = timeCfg {
                params["timeCfg"] = tc
            }
            if let tj = timeJob {
                params["timeJob"] = tj
            }

            let data = try await restPost(sdk: sdk, path: "smarttrigger/add", params: params)
            appendOpLog("[AddTrigger] REST smarttrigger/add OK")

            // 3) Parse uuid from response and append to local list
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let newUuid = (json?["uuid"] as? String) ?? UUID().uuidString

            var bits: [String] = []
            bits.append("type=\(typeTrigger)")
            bits.append("elm=\(elm)")
            bits.append("cond=\(condition)")
            if !attrValueCondition.isEmpty { bits.append("val=\(attrValueCondition)") }
            let summary = bits.joined(separator: " ")

            let newRow = SmartTriggerRow(
                uuid: newUuid, smartId: smart.uuid, sourceId: devId, smid: smid,
                summary: summary,
                elm: elm, condition: condition, attrValueCondition: attrValueCondition,
                typeTrigger: typeTrigger, cfm: cfm, mix: newMix, locId: locId,
                elmExt: elmExt, conditionExt: conditionExt,
                attrValueConditionExt: attrValueConditionExt,
                timeCfg: timeCfg, timeJob: timeJob
            )
            self.triggers.append(newRow)
        } catch {
            appendOpLog("[AddTrigger] FAILED: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isMutating = false
    }

    /// Edit an existing SmartTrigger:
    /// MQTT unbind old -> MQTT bind new (cfm+1) -> REST POST smarttrigger/update.
    func editTrigger(
        existingRow: SmartTriggerRow,
        devId: String,
        smartSubType: Int,
        typeTrigger: Int,
        elm: Int,
        condition: Int,
        attrValueCondition: [Int],
        elmExt: Int?,
        conditionExt: Int?,
        attrValueConditionExt: [Int]?,
        timeCfg: [Int]?,
        timeJob: [Int]?
    ) async {
        guard let sdk = IoTAppCore.current else { errorMessage = "SDK not initialized"; return }
        guard let smid = smart.smid ?? existingRow.smid else { errorMessage = "Missing smid"; return }

        isMutating = true
        errorMessage = nil
        let newCfm = existingRow.cfm + 1
        let newMix = SmartTriggerRow.incrementMix(existingRow.mix)
        let sameDevice = (devId == existingRow.sourceId)

        appendOpLog("[EditTrigger \(existingRow.uuid.prefix(8))...] MQTT unbind ...")

        do {
            // 1) MQTT unbind old
            do {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    sdk.deviceCmdHandler.unbindDeviceSmartTrigger(smid: smid, devId: existingRow.sourceId) { result in
                        switch result {
                        case .success: cont.resume()
                        case .failure(let e): cont.resume(throwing: e)
                        }
                    }
                }
                appendOpLog("[EditTrigger] MQTT unbind OK")
            } catch {
                // Legacy tolerance: same-device unbind failure is tolerated (WiLe firmware bug)
                if sameDevice {
                    appendOpLog("[EditTrigger] MQTT unbind failed (same device — tolerated): \(error.localizedDescription)")
                } else {
                    throw error
                }
            }

            // 2) MQTT bind new
            appendOpLog("[EditTrigger] MQTT bindDeviceSmartTrigger elm=\(elm) ...")
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                sdk.deviceCmdHandler.bindDeviceSmartTrigger(
                    smid: smid,
                    smartSubType: smartSubType,
                    devId: devId,
                    typeTrigger: typeTrigger,
                    elm: elm,
                    condition: condition,
                    attrValueCondition: attrValueCondition,
                    elmExt: elmExt,
                    conditionExt: conditionExt,
                    attrValueConditionExt: attrValueConditionExt,
                    timeCfg: timeCfg,
                    timeJob: timeJob,
                    cfm: newCfm
                ) { result in
                    switch result {
                    case .success: cont.resume()
                    case .failure(let e): cont.resume(throwing: e)
                    }
                }
            }
            appendOpLog("[EditTrigger] MQTT bind OK")

            // 3) REST smarttrigger/update (body matches legacy RGBSmartAPI.updateSmartTrigger)
            let locId = existingRow.locId.isEmpty ? (smart.locId ?? "") : existingRow.locId
            var params: [String: Any] = [
                "uuid": existingRow.uuid,
                "smartId": existingRow.smartId,
                "devId": devId,
                "cfm": newCfm,
                "elm": elm,
                "condition": condition,
                "value": attrValueCondition,
                "mix": newMix,
                "type": typeTrigger,
                "locId": locId
            ]
            if let ext = attrValueConditionExt {
                params["valueExt"] = ext
            }
            if let e = elmExt {
                params["elmExt"] = e
            }
            if let c = conditionExt {
                params["conditionExt"] = c
            }
            if let tc = timeCfg, tc.count >= 1 {
                params["timeCfg"] = tc
            }
            if let tj = timeJob, tj.count >= 2 {
                params["timeJob"] = tj
            }

            _ = try await restPost(sdk: sdk, path: "smarttrigger/update", params: params)
            appendOpLog("[EditTrigger] REST smarttrigger/update OK")

            // 4) Update local row
            if let idx = self.triggers.firstIndex(where: { $0.uuid == existingRow.uuid }) {
                var bits: [String] = []
                bits.append("type=\(typeTrigger)")
                bits.append("elm=\(elm)")
                bits.append("cond=\(condition)")
                if !attrValueCondition.isEmpty { bits.append("val=\(attrValueCondition)") }
                let summary = bits.joined(separator: " ")

                self.triggers[idx] = SmartTriggerRow(
                    uuid: existingRow.uuid, smartId: existingRow.smartId,
                    sourceId: devId, smid: smid,
                    summary: summary,
                    elm: elm, condition: condition, attrValueCondition: attrValueCondition,
                    typeTrigger: typeTrigger, cfm: newCfm, mix: newMix, locId: locId,
                    elmExt: elmExt, conditionExt: conditionExt,
                    attrValueConditionExt: attrValueConditionExt,
                    timeCfg: timeCfg, timeJob: timeJob
                )
            }
        } catch {
            appendOpLog("[EditTrigger] FAILED: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isMutating = false
    }

    private func appendOpLog(_ s: String) {
        opLog.append(s)
        print("SmartDetail: \(s)")
    }

    // MARK: - Time conversion helpers

    /// Inverse of `SmartTestViewModel.convertLocalToUTC`.
    /// Takes a UTC minutes-from-midnight + UTC weekdays (0=Sun..6=Sat)
    /// and returns LOCAL minutes-from-midnight + LOCAL weekdays.
    static func convertUTCToLocal(timeUTC: Int, weekdaysUTC: [Int]) -> (Int, [Int]) {
        let hours = timeUTC / 60
        let mins = timeUTC % 60

        var calUTC = Calendar(identifier: .gregorian)
        calUTC.timeZone = TimeZone(identifier: "UTC")!

        let now = Date()
        var comps = calUTC.dateComponents([.year, .month, .day], from: now)
        comps.hour = hours
        comps.minute = mins
        guard let utcDate = calUTC.date(from: comps) else {
            return (timeUTC, weekdaysUTC)
        }
        var calLocal = Calendar(identifier: .gregorian)
        calLocal.timeZone = TimeZone.current
        let localComps = calLocal.dateComponents([.hour, .minute], from: utcDate)
        let timeLocal = (localComps.hour ?? 0) * 60 + (localComps.minute ?? 0)

        let todayUTCWeekday = calUTC.component(.weekday, from: now) - 1  // 0..6

        let localWeekdays: [Int] = weekdaysUTC.map { rgUtcDay in
            let dayOffset = rgUtcDay - todayUTCWeekday
            guard let candidate = calUTC.date(byAdding: .day, value: dayOffset, to: utcDate) else {
                return rgUtcDay
            }
            let localWeekday = calLocal.component(.weekday, from: candidate) // 1..7
            return localWeekday - 1
        }

        return (timeLocal, localWeekdays)
    }
}
