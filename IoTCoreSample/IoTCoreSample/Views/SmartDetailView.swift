//
//  SmartDetailView.swift
//  IoTCoreSample
//
//  Edit a Smart entity per type:
//    - Scenario: label + cmds
//    - Schedule: label + cmds + schedule time/weekdays
//    - Automation: label + cmds + triggers
//

import SwiftUI
import IotCoreIOS

struct SmartDetailView: View {
    @StateObject private var viewModel: SmartDetailViewModel
    @Environment(\.dismiss) private var dismiss

    /// Called on successful save so the list view can refresh.
    var onSaved: (() -> Void)?

    @State private var showConfirm = false
    @State private var editingCmd: SmartCmdDraft?
    @State private var showAddCmdSheet: Bool = false
    @State private var pendingDeleteCmd: SmartCmdDraft?
    @State private var pendingDeleteTrigger: SmartTriggerRow?
    @State private var showAddTriggerSheet: Bool = false
    @State private var editingTrigger: SmartTriggerRow?

    private static let weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    init(smart: SmartItem, onSaved: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: SmartDetailViewModel(smart: smart))
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            headerSection
            labelSection

            if viewModel.smart.smartType == .automation {
                triggersSection
            }

            if viewModel.canEditCmds {
                cmdsSection
            }

            if !viewModel.opLog.isEmpty {
                opLogSection
            }

            if viewModel.canEditSchedule {
                scheduleSection
            }

            if !viewModel.saveLog.isEmpty {
                saveLogSection
            }

            if let err = viewModel.errorMessage {
                Section {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Edit Smart")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    showConfirm = true
                }
                .disabled(!viewModel.hasAnyDirty || viewModel.isSaving)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Discard") { dismiss() }
                    .disabled(viewModel.isSaving)
            }
        }
        .overlay {
            if viewModel.isLoading || viewModel.isSaving || viewModel.isMutating {
                ProgressView(viewModel.isSaving ? "Saving…" : (viewModel.isMutating ? "Working…" : "Loading…"))
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
        .task {
            await viewModel.loadDetail()
        }
        .alert("Save changes?", isPresented: $showConfirm) {
            Button("Save", role: .none) {
                Task {
                    await viewModel.save()
                    if viewModel.didSaveSuccessfully {
                        onSaved?()
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.changesSummary())
        }
        .alert("Delete command?", isPresented: Binding(
            get: { pendingDeleteCmd != nil },
            set: { if !$0 { pendingDeleteCmd = nil } }
        ), presenting: pendingDeleteCmd) { draft in
            Button("Delete", role: .destructive) {
                let d = draft
                pendingDeleteCmd = nil
                Task { await viewModel.deleteCmd(d) }
            }
            Button("Cancel", role: .cancel) { pendingDeleteCmd = nil }
        } message: { draft in
            Text("elm \(draft.elementId) on target \(draft.targetId.prefix(8))…")
        }
        .alert("Delete trigger?", isPresented: Binding(
            get: { pendingDeleteTrigger != nil },
            set: { if !$0 { pendingDeleteTrigger = nil } }
        ), presenting: pendingDeleteTrigger) { row in
            Button("Delete", role: .destructive) {
                let r = row
                pendingDeleteTrigger = nil
                Task { await viewModel.deleteTrigger(r) }
            }
            Button("Cancel", role: .cancel) { pendingDeleteTrigger = nil }
        } message: { row in
            Text("source \(row.sourceId.prefix(8))…")
        }
        .sheet(isPresented: $showAddCmdSheet, onDismiss: {}) {
            AddCmdSheet(viewModel: viewModel) { device, elementId, onOff, delay in
                showAddCmdSheet = false
                Task {
                    await viewModel.addCmd(
                        targetDeviceId: device.uuid ?? "",
                        elementId: elementId,
                        onOffValue: onOff,
                        delay: delay
                    )
                }
            }
        }
        .sheet(item: $editingCmd) { draft in
            CmdEditSheet(
                draft: draft,
                onSave: { updated in
                    if let idx = viewModel.draftCmds.firstIndex(where: { $0.id == updated.id }) {
                        viewModel.draftCmds[idx] = updated
                    }
                    editingCmd = nil
                },
                onCancel: { editingCmd = nil }
            )
        }
        .sheet(isPresented: $showAddTriggerSheet) {
            TriggerSheet(viewModel: viewModel, existingTrigger: nil) { params in
                showAddTriggerSheet = false
                Task {
                    await viewModel.addTrigger(
                        devId: params.devId,
                        smartSubType: params.smartSubType,
                        typeTrigger: params.typeTrigger,
                        elm: params.elm,
                        condition: params.condition,
                        attrValueCondition: params.attrValueCondition,
                        elmExt: params.elmExt,
                        conditionExt: params.conditionExt,
                        attrValueConditionExt: params.attrValueConditionExt,
                        timeCfg: params.timeCfg,
                        timeJob: params.timeJob,
                        cfm: params.cfm
                    )
                }
            }
        }
        .sheet(item: $editingTrigger) { trigger in
            TriggerSheet(viewModel: viewModel, existingTrigger: trigger) { params in
                editingTrigger = nil
                Task {
                    await viewModel.editTrigger(
                        existingRow: trigger,
                        devId: params.devId,
                        smartSubType: params.smartSubType,
                        typeTrigger: params.typeTrigger,
                        elm: params.elm,
                        condition: params.condition,
                        attrValueCondition: params.attrValueCondition,
                        elmExt: params.elmExt,
                        conditionExt: params.conditionExt,
                        attrValueConditionExt: params.attrValueConditionExt,
                        timeCfg: params.timeCfg,
                        timeJob: params.timeJob
                    )
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            HStack {
                Text(viewModel.smart.smartType.displayName)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
                Spacer()
                if let smid = viewModel.smart.smid {
                    Text("smid=\(smid)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Text("uuid: \(viewModel.smart.uuid)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
    }

    private var labelSection: some View {
        Section("Label") {
            TextField("Label", text: $viewModel.draftLabel)
                .textInputAutocapitalization(.sentences)
        }
    }

    private var triggersSection: some View {
        Section("Triggers (\(viewModel.triggers.count))") {
            if viewModel.triggers.isEmpty {
                Text("No triggers").font(.caption).foregroundColor(.secondary)
            } else {
                ForEach(viewModel.triggers) { row in
                    Button {
                        editingTrigger = row
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("source \(row.sourceId.prefix(8))...")
                                    .font(.caption.bold())
                                Text(row.summary)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("uuid \(row.uuid.prefix(8))... cfm=\(row.cfm)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDeleteTrigger = row
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            Button {
                viewModel.loadDevicesIfNeeded()
                showAddTriggerSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Trigger")
                }
            }
        }
    }

    private var opLogSection: some View {
        Section("Activity") {
            ForEach(Array(viewModel.opLog.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var cmdsSection: some View {
        Section("Commands (\(viewModel.draftCmds.count))") {
            if viewModel.draftCmds.isEmpty {
                Text("No commands").font(.caption).foregroundColor(.secondary)
            } else {
                ForEach(viewModel.draftCmds) { draft in
                    Button {
                        editingCmd = draft
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("elm \(draft.elementId)")
                                        .font(.caption.bold())
                                    Text(draft.displayAction)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Color.green.opacity(0.15))
                                        .foregroundColor(.green)
                                        .clipShape(Capsule())
                                    if draft.isDirty {
                                        Text("modified")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                                Text("target=\(String(draft.targetId.prefix(8)))… delay=\(draft.delay)s")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDeleteCmd = draft
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            Button {
                viewModel.loadDevicesIfNeeded()
                showAddCmdSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Command")
                }
            }
        }
    }

    private var scheduleSection: some View {
        Section("Schedule (local time)") {
            HStack {
                Text("Time")
                Spacer()
                Picker("Hour", selection: $viewModel.draftHour) {
                    ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(width: 70, height: 90)
                .clipped()
                Text(":")
                Picker("Minute", selection: $viewModel.draftMinute) {
                    ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(width: 70, height: 90)
                .clipped()
            }
            ForEach(0..<7, id: \.self) { day in
                Toggle(Self.weekdayLabels[day], isOn: Binding(
                    get: { viewModel.draftWeekdays.contains(day) },
                    set: { newVal in
                        if newVal {
                            viewModel.draftWeekdays.insert(day)
                        } else {
                            viewModel.draftWeekdays.remove(day)
                        }
                    }
                ))
            }
        }
    }

    private var saveLogSection: some View {
        Section("Save log") {
            ForEach(Array(viewModel.saveLog.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Cmd Edit Sheet

private struct CmdEditSheet: View {
    @State var draft: SmartCmdDraft
    let onSave: (SmartCmdDraft) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Target (read-only)") {
                    Text(draft.targetId)
                        .font(.caption)
                        .textSelection(.enabled)
                    Text("Cmd row uuid: \(draft.uuid)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Section("Element") {
                    Stepper("Element ID: \(draft.elementId)", value: $draft.elementId, in: 0...32)
                }

                Section("Action (ACT_ONOFF)") {
                    Picker("Action", selection: Binding(
                        get: { (draft.cmd.count >= 2 && draft.cmd[0] == 1) ? draft.cmd[1] : 0 },
                        set: { newVal in draft.cmd = [1, newVal] }
                    )) {
                        Text("OFF").tag(0)
                        Text("ON").tag(1)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Delay") {
                    Stepper("Delay: \(draft.delay)s", value: $draft.delay, in: 0...3600)
                }
            }
            .navigationTitle("Edit Command")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") { onSave(draft) }
                }
            }
        }
    }
}

// MARK: - Add Cmd Sheet

private struct AddCmdSheet: View {
    @ObservedObject var viewModel: SmartDetailViewModel
    let onSave: (IoTDevice, Int, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDeviceId: String?
    @State private var elementId: Int = 0
    @State private var onOff: Int = 1
    @State private var delay: Int = 0

    private var selectedDevice: IoTDevice? {
        viewModel.availableDevices.first { ($0.uuid ?? "") == selectedDeviceId }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Target Device") {
                    if viewModel.isLoadingDevices && viewModel.availableDevices.isEmpty {
                        ProgressView("Loading devices…")
                    } else if viewModel.availableDevices.isEmpty {
                        Text("No devices").foregroundColor(.secondary).font(.caption)
                    } else {
                        Picker("Device", selection: $selectedDeviceId) {
                            Text("— Select —").tag(String?.none)
                            ForEach(viewModel.availableDevices, id: \.id) { dev in
                                Text(dev.displayName).tag(Optional(dev.uuid ?? ""))
                            }
                        }
                    }
                }

                if let dev = selectedDevice {
                    Section("Element") {
                        let ids = viewModel.elementIds(for: dev)
                        if ids.isEmpty {
                            Stepper("Element ID: \(elementId)", value: $elementId, in: 0...32)
                        } else {
                            Picker("Element", selection: $elementId) {
                                ForEach(ids, id: \.self) { Text("\($0)").tag($0) }
                            }
                        }
                    }
                }

                Section("Action (ACT_ONOFF)") {
                    Picker("Action", selection: $onOff) {
                        Text("OFF").tag(0)
                        Text("ON").tag(1)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Delay") {
                    Stepper("Delay: \(delay)s", value: $delay, in: 0...3600)
                }
            }
            .navigationTitle("Add Command")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        guard let dev = selectedDevice else { return }
                        onSave(dev, elementId, onOff, delay)
                    }
                    .disabled(selectedDevice == nil)
                }
            }
            .onAppear {
                if let ids = selectedDevice.map({ viewModel.elementIds(for: $0) }), let first = ids.first {
                    elementId = first
                }
            }
        }
    }
}

// MARK: - Trigger Sheet Params

/// Parameters collected by the TriggerSheet, passed to add/edit trigger.
private struct TriggerSheetParams {
    let devId: String
    let smartSubType: Int
    let typeTrigger: Int
    let elm: Int
    let condition: Int
    let attrValueCondition: [Int]
    let elmExt: Int?
    let conditionExt: Int?
    let attrValueConditionExt: [Int]?
    let timeCfg: [Int]?
    let timeJob: [Int]?
    let cfm: Int
}

// MARK: - Trigger Sheet (Add / Edit)

private struct TriggerSheet: View {
    @ObservedObject var viewModel: SmartDetailViewModel
    /// nil = add mode; non-nil = edit mode (pre-fill from existing row).
    let existingTrigger: SmartTriggerRow?
    let onSave: (TriggerSheetParams) -> Void

    @Environment(\.dismiss) private var dismiss

    // Device
    @State private var selectedDeviceId: String?

    // Core fields
    @State private var elm: Int = 0
    @State private var condition: Int = 2        // default EQUAL
    @State private var attrValueText: String = "" // comma-separated ints
    @State private var typeTrigger: Int = 0       // OWNER
    @State private var cfm: Int = 1
    @State private var smartSubType: Int = 0      // MIX_OR

    // EXT fields (optional, toggled)
    @State private var showExtFields: Bool = false
    @State private var elmExt: Int = 0
    @State private var conditionExt: Int = 2
    @State private var attrValueExtText: String = ""

    // Optional time fields
    @State private var timeCfgText: String = ""
    @State private var timeJobText: String = ""

    private var isEditMode: Bool { existingTrigger != nil }

    private static let conditionOptions: [(Int, String)] = [
        (1, "ANY (1)"),
        (2, "EQUAL (2)"),
        (3, "IN (3)"),
        (4, "BETWEEN (4)"),
        (5, "LESS_THAN (5)"),
        (6, "LESS_EQUAL (6)"),
        (7, "GREATER_THAN (7)"),
        (8, "GREATER_EQUAL (8)")
    ]

    private static let subTypeOptions: [(Int, String)] = [
        (0, "MIX_OR (0)"),
        (64, "STAIR_SWITCH (64)"),
        (65, "NOTIFICATION (65)"),
        (66, "MOTION (66)"),
        (67, "NO_MOTION_SIM (67)"),
        (68, "NO_MOTION (68)"),
        (69, "DOOR (69)"),
        (70, "SELF_REVERSE (70)"),
        (128, "SMART_AC (128)")
    ]

    private var selectedDevice: IoTDevice? {
        viewModel.availableDevices.first { ($0.uuid ?? "") == selectedDeviceId }
    }

    private func parseIntArray(_ text: String) -> [Int]? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        return parts.isEmpty ? nil : parts
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Source Device") {
                    if viewModel.isLoadingDevices && viewModel.availableDevices.isEmpty {
                        ProgressView("Loading devices...")
                    } else if viewModel.availableDevices.isEmpty {
                        Text("No devices").foregroundColor(.secondary).font(.caption)
                    } else {
                        Picker("Device", selection: $selectedDeviceId) {
                            Text("-- Select --").tag(String?.none)
                            ForEach(viewModel.availableDevices, id: \.id) { dev in
                                Text(dev.displayName).tag(Optional(dev.uuid ?? ""))
                            }
                        }
                    }
                }

                Section("Smart Sub Type") {
                    Picker("Sub Type", selection: $smartSubType) {
                        ForEach(Self.subTypeOptions, id: \.0) { val, label in
                            Text(label).tag(val)
                        }
                    }
                }

                Section("Type Trigger") {
                    Picker("Type", selection: $typeTrigger) {
                        Text("OWNER (0)").tag(0)
                        Text("EXT (1)").tag(1)
                    }
                    .pickerStyle(.segmented)
                }

                if let dev = selectedDevice {
                    Section("Element") {
                        let ids = viewModel.elementIds(for: dev)
                        if ids.isEmpty {
                            Stepper("Element ID: \(elm)", value: $elm, in: 0...255)
                        } else {
                            Picker("Element", selection: $elm) {
                                ForEach(ids, id: \.self) { Text("\($0)").tag($0) }
                            }
                        }
                    }
                }

                Section("Condition") {
                    Picker("Condition", selection: $condition) {
                        ForEach(Self.conditionOptions, id: \.0) { val, label in
                            Text(label).tag(val)
                        }
                    }
                }

                Section("Attr Value (comma-separated ints)") {
                    TextField("e.g. 1,1 or 8,0", text: $attrValueText)
                        .keyboardType(.numbersAndPunctuation)
                    Text("Format: attrType,value1,value2,...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Section("CFM") {
                    Stepper("CFM: \(cfm)", value: $cfm, in: 0...9999)
                }

                // EXT fields toggle
                Section {
                    Toggle("Add EXT trigger fields", isOn: $showExtFields)
                }

                if showExtFields {
                    Section("EXT Element") {
                        Stepper("elmExt: \(elmExt)", value: $elmExt, in: 0...255)
                    }
                    Section("EXT Condition") {
                        Picker("conditionExt", selection: $conditionExt) {
                            ForEach(Self.conditionOptions, id: \.0) { val, label in
                                Text(label).tag(val)
                            }
                        }
                    }
                    Section("EXT Attr Value (comma-separated)") {
                        TextField("e.g. 1,0", text: $attrValueExtText)
                            .keyboardType(.numbersAndPunctuation)
                    }
                }

                Section("Time Config (optional, comma-separated)") {
                    TextField("timeCfg", text: $timeCfgText)
                        .keyboardType(.numbersAndPunctuation)
                }

                Section("Time Job (optional, comma-separated)") {
                    TextField("timeJob", text: $timeJobText)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            .navigationTitle(isEditMode ? "Edit Trigger" : "Add Trigger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditMode ? "Apply" : "Add") {
                        guard let devId = selectedDeviceId, !devId.isEmpty else { return }
                        let attrValue = parseIntArray(attrValueText) ?? []
                        let params = TriggerSheetParams(
                            devId: devId,
                            smartSubType: smartSubType,
                            typeTrigger: typeTrigger,
                            elm: elm,
                            condition: condition,
                            attrValueCondition: attrValue,
                            elmExt: showExtFields ? elmExt : nil,
                            conditionExt: showExtFields ? conditionExt : nil,
                            attrValueConditionExt: showExtFields ? parseIntArray(attrValueExtText) : nil,
                            timeCfg: parseIntArray(timeCfgText),
                            timeJob: parseIntArray(timeJobText),
                            cfm: cfm
                        )
                        onSave(params)
                    }
                    .disabled(selectedDeviceId == nil || selectedDeviceId?.isEmpty == true)
                }
            }
            .onAppear {
                viewModel.loadDevicesIfNeeded()
                prefillFromExisting()
            }
        }
    }

    private func prefillFromExisting() {
        guard let t = existingTrigger else { return }
        selectedDeviceId = t.sourceId
        elm = t.elm
        condition = t.condition
        attrValueText = t.attrValueCondition.map(String.init).joined(separator: ",")
        typeTrigger = t.typeTrigger
        cfm = t.cfm
        smartSubType = viewModel.smart.subType ?? 0

        if t.elmExt != nil || t.conditionExt != nil || t.attrValueConditionExt != nil {
            showExtFields = true
            elmExt = t.elmExt ?? 0
            conditionExt = t.conditionExt ?? 2
            attrValueExtText = (t.attrValueConditionExt ?? []).map(String.init).joined(separator: ",")
        }
        if let tc = t.timeCfg {
            timeCfgText = tc.map(String.init).joined(separator: ",")
        }
        if let tj = t.timeJob {
            timeJobText = tj.map(String.init).joined(separator: ",")
        }
    }
}
