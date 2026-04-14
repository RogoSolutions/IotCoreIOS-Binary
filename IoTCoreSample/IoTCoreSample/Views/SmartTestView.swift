//
//  SmartTestView.swift
//  IoTCoreSample
//
//  View for testing Smart Automation APIs
//

import SwiftUI
import IotCoreIOS

struct SmartTestView: View {
    @StateObject private var viewModel = SmartTestViewModel()

    // Scenario creation params
    @State private var scenarioLabel = "test-scenario"
    @State private var locationId = ""
    @State private var selectedDeviceIndex: Int? = nil
    @State private var selectedElementId: Int = 0
    @State private var cmdAction = 0  // 0=OFF, 1=ON
    @State private var cmdDelay = "3"

    // Manual MQTT params
    @State private var smid = ""
    @State private var smartUuid = ""

    @State private var selectedTab = 0

    // Automation flow params
    @State private var autoLabel = "Test Automation"
    @State private var autoSmartSubType: Int = 0
    @State private var autoTriggerDeviceIndex: Int? = nil
    @State private var autoTriggerElm: Int = 0
    @State private var autoCondition: Int = 2       // EQUAL
    @State private var autoTriggerAttrVal = "8,1"   // EVT_MOTION=ON
    @State private var autoTypeTrigger: Int = 0     // OWNER
    @State private var autoTimeCfg = ""
    @State private var autoTimeJob = ""
    @State private var autoCmdDeviceIndex: Int? = nil
    @State private var autoCmdElm: Int = 0
    @State private var autoCmdAction: Int = 1       // ON
    @State private var autoCmdAttrVal = ""          // custom attr value (overrides ON/OFF)
    @State private var autoCmdDelay = "0"
    @State private var isServiceConnected = false
    @State private var isConnectingService = false

    // Schedule flow params
    @State private var scheduleLabel = "Test Schedule"
    @State private var scheduleDeviceIndex: Int? = nil
    @State private var scheduleElementId: Int = 0
    @State private var scheduleOnOff: Int = 1  // 0=OFF, 1=ON
    @State private var scheduleTime: Date = {
        var c = DateComponents(); c.hour = 8; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()
    // 0=Sun..6=Sat
    @State private var scheduleWeekdays: Set<Int> = [1, 2, 3, 4, 5]
    // Legacy RGBSchedule fields. SDK does not currently expose public accessors;
    // PO can paste these manually for testing parity with the legacy app.
    @State private var scheduleEndpoint: String = ""
    @State private var schedulePartner: String = ""
    @State private var scheduleEndpointFromSDK: Bool = false
    @State private var schedulePartnerFromSDK: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Connect Service toggle
            connectServiceBanner

            // Tab picker
            Picker("Mode", selection: $selectedTab) {
                Text("Scenario").tag(0)
                Text("Schedule").tag(1)
                Text("Automation").tag(3)
                Text("MQTT").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            if selectedTab == 0 {
                scenarioFlowView
            } else if selectedTab == 1 {
                scheduleFlowView
            } else if selectedTab == 3 {
                automationFlowView
            } else {
                mqttPrimitivesView
            }
        }
        .navigationTitle("Smart Automation")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .onAppear {
            if locationId.isEmpty {
                locationId = IoTAppCore.current?.getAppLocation() ?? ""
            }
            if viewModel.devices.isEmpty {
                viewModel.fetchDevices()
            }
            isServiceConnected = IoTAppCore.current?.isMQTTConnected() ?? false
            // Auto-populate Schedule endpoint/partner from SDK public APIs
            if scheduleEndpoint.isEmpty, let ep = IoTAppCore.current?.mqttEndpoint {
                scheduleEndpoint = ep
                scheduleEndpointFromSDK = true
            }
            if schedulePartner.isEmpty, let pid = IoTAppCore.current?.partnerId {
                schedulePartner = pid
                schedulePartnerFromSDK = true
            }
        }
    }

    // MARK: - Connect Service Banner

    private var connectServiceBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("connectService()")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                Text("Required for MQTT operations")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isConnectingService {
                ProgressView()
                    .frame(width: 30)
            }

            Toggle("", isOn: Binding(
                get: { isServiceConnected },
                set: { newValue in
                    if newValue && !isServiceConnected {
                        isConnectingService = true
                        IoTAppCore.current?.connectService { result in
                            Task { @MainActor in
                                isConnectingService = false
                                if case .success = result {
                                    isServiceConnected = true
                                }
                            }
                        }
                    }
                }
            ))
            .labelsHidden()
            .disabled(isServiceConnected || isConnectingService)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isServiceConnected ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
    }

    // MARK: - Scenario Flow View

    private var scenarioFlowView: some View {
        List {
            scenarioInputSection
            scenarioActionsSection
            flowLogSection
            resultSection
        }
    }

    private var selectedDevice: IoTDevice? {
        guard let idx = selectedDeviceIndex, idx < viewModel.devices.count else { return nil }
        return viewModel.devices[idx]
    }

    private var availableElements: [Int] {
        guard let device = selectedDevice else { return [0] }
        return viewModel.elementIds(for: device)
    }

    private var scenarioInputSection: some View {
        Section {
            HStack {
                Text("Label")
                    .frame(width: 70, alignment: .leading)
                TextField("Scenario name", text: $scenarioLabel)
                    .textFieldStyle(.roundedBorder)
            }

            // Location
            HStack {
                Text("Location")
                    .frame(width: 70, alignment: .leading)
                TextField("Location ID", text: $locationId)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
            }

            // Device Picker (auto-select first element on change)
            if viewModel.isLoadingDevices {
                HStack {
                    ProgressView().frame(width: 20)
                    Text("Loading devices...").foregroundColor(.secondary)
                }
            } else if viewModel.devices.isEmpty {
                Button {
                    viewModel.fetchDevices()
                } label: {
                    Label("Load Devices", systemImage: "arrow.clockwise")
                }
            } else {
                Picker("Device", selection: $selectedDeviceIndex) {
                    Text("Select device").tag(nil as Int?)
                    ForEach(Array(viewModel.devices.enumerated()), id: \.offset) { index, device in
                        HStack {
                            Text(device.displayName)
                            if let mac = device.mac {
                                Text("(\(mac.prefix(8)))").foregroundColor(.secondary)
                            }
                        }.tag(index as Int?)
                    }
                }
                .onChange(of: selectedDeviceIndex) { _ in
                    // Auto-select first element when device changes
                    selectedElementId = availableElements.first ?? 0
                }

                // Show selected device info
                if let device = selectedDevice {
                    HStack {
                        Text("UUID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(device.uuid ?? "—")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            // Element Picker
            if selectedDevice != nil {
                Picker("Element", selection: $selectedElementId) {
                    ForEach(availableElements, id: \.self) { elmId in
                        let label = selectedDevice?.elementInfos?["\(elmId)"]?.label
                        Text(label != nil ? "\(elmId) — \(label!)" : "Element \(elmId)")
                            .tag(elmId)
                    }
                }
            }

            // Command
            Picker("Command", selection: $cmdAction) {
                Text("OFF (turn off)").tag(0)
                Text("ON (turn on)").tag(1)
            }

            HStack {
                Text("Delay")
                    .frame(width: 70, alignment: .leading)
                TextField("seconds", text: $cmdDelay)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }
        } header: {
            HStack {
                Text("Scenario Parameters")
                Spacer()
                Button {
                    viewModel.fetchDevices()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
            }
        } footer: {
            Text("Delay=wait before execution (seconds).")
        }
    }

    private var scenarioActionsSection: some View {
        Section {
            // Create Scenario (full flow)
            Button {
                guard let device = selectedDevice,
                      let deviceUuid = device.uuid else { return }
                let cmd = [1, cmdAction]  // [ACT_ONOFF, value]
                let delay = Int(cmdDelay) ?? 0
                viewModel.createScenario(
                    label: scenarioLabel,
                    locationId: locationId,
                    targetDeviceId: deviceUuid,
                    elementId: selectedElementId,
                    cmd: cmd,
                    delay: delay
                )
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("Create Scenario")
                            .fontWeight(.medium)
                        Text("REST add → MQTT bind → REST persist")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(selectedDevice == nil || locationId.isEmpty)

            // Activate
            Button {
                if let smid = viewModel.createdSmid ?? Int(smid) {
                    viewModel.activeSmart(smid: smid)
                }
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.green)
                    Text("Activate Smart")
                    Spacer()
                    if let smid = viewModel.createdSmid {
                        Text("smid=\(smid)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(viewModel.createdSmid == nil && Int(smid) == nil)

            // Delete Scenario
            Button {
                if let uuid = viewModel.createdSmartUuid,
                   let sid = viewModel.createdSmid {
                    viewModel.deleteScenario(smartUuid: uuid, smid: sid)
                }
            } label: {
                HStack {
                    Image(systemName: "trash.circle.fill")
                        .foregroundColor(.red)
                    VStack(alignment: .leading) {
                        Text("Delete Scenario")
                        Text("MQTT announce → REST delete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(viewModel.createdSmartUuid == nil)

            // Manual smid/uuid input
            DisclosureGroup("Manual smid/uuid") {
                HStack {
                    Text("smid")
                        .frame(width: 50, alignment: .leading)
                    TextField("e.g. 578", text: $smid)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("uuid")
                        .frame(width: 50, alignment: .leading)
                    TextField("Smart UUID", text: $smartUuid)
                        .autocapitalization(.none)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                }

                Button {
                    if let sid = Int(smid) {
                        viewModel.activeSmart(smid: sid)
                    }
                } label: {
                    Label("Activate (manual smid)", systemImage: "play")
                }
                .disabled(Int(smid) == nil)

                Button {
                    if let sid = Int(smid), !smartUuid.isEmpty {
                        viewModel.deleteScenario(smartUuid: smartUuid, smid: sid)
                    }
                } label: {
                    Label("Delete (manual uuid)", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .disabled(Int(smid) == nil || smartUuid.isEmpty)
            }
        } header: {
            Text("Actions")
        }
    }

    private var flowLogSection: some View {
        Section {
            if viewModel.flowLog.isEmpty {
                Text("No operations yet. Create a scenario to see the flow.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(Array(viewModel.flowLog.enumerated()), id: \.offset) { _, log in
                    Text(log)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(log.contains("FAILED") ? .red : log.contains("OK") ? .green : .primary)
                }

                Button {
                    viewModel.flowLog = []
                } label: {
                    Label("Clear Log", systemImage: "trash")
                        .font(.caption)
                }
            }
        } header: {
            Text("Flow Log")
        }
    }

    // MARK: - Schedule Flow View

    private static let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var scheduleSelectedDevice: IoTDevice? {
        guard let idx = scheduleDeviceIndex, idx < viewModel.devices.count else { return nil }
        return viewModel.devices[idx]
    }

    private var scheduleAvailableElements: [Int] {
        guard let device = scheduleSelectedDevice else { return [0] }
        return viewModel.elementIds(for: device)
    }

    private var scheduleFlowView: some View {
        List {
            scheduleInputSection
            scheduleActionsSection
            flowLogSection
            resultSection
        }
    }

    private var scheduleInputSection: some View {
        Section {
            HStack {
                Text("Label").frame(width: 80, alignment: .leading)
                TextField("Schedule name", text: $scheduleLabel)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Location").frame(width: 80, alignment: .leading)
                TextField("Location ID", text: $locationId)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
            }

            if viewModel.isLoadingDevices {
                HStack { ProgressView().frame(width: 20); Text("Loading devices...").foregroundColor(.secondary) }
            } else if viewModel.devices.isEmpty {
                Button { viewModel.fetchDevices() } label: {
                    Label("Load Devices", systemImage: "arrow.clockwise")
                }
            } else {
                Picker("Device", selection: $scheduleDeviceIndex) {
                    Text("Select device").tag(nil as Int?)
                    ForEach(Array(viewModel.devices.enumerated()), id: \.offset) { index, device in
                        Text(device.displayName).tag(index as Int?)
                    }
                }
                .onChange(of: scheduleDeviceIndex) { _ in
                    scheduleElementId = scheduleAvailableElements.first ?? 0
                }
            }

            if scheduleSelectedDevice != nil {
                Picker("Element", selection: $scheduleElementId) {
                    ForEach(scheduleAvailableElements, id: \.self) { elmId in
                        let label = scheduleSelectedDevice?.elementInfos?["\(elmId)"]?.label
                        Text(label != nil ? "\(elmId) — \(label!)" : "Element \(elmId)")
                            .tag(elmId)
                    }
                }
            }

            Picker("Action", selection: $scheduleOnOff) {
                Text("OFF").tag(0)
                Text("ON").tag(1)
            }

            DatePicker("Time", selection: $scheduleTime, displayedComponents: .hourAndMinute)

            VStack(alignment: .leading, spacing: 6) {
                Text("Weekdays").font(.caption).foregroundColor(.secondary)
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { day in
                        let isOn = scheduleWeekdays.contains(day)
                        Button {
                            if isOn { scheduleWeekdays.remove(day) }
                            else { scheduleWeekdays.insert(day) }
                        } label: {
                            Text(Self.weekdayNames[day])
                                .font(.caption2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(isOn ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(isOn ? .white : .primary)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Text("Endpoint").frame(width: 80, alignment: .leading)
                TextField("MQTT endpoint (optional)", text: $scheduleEndpoint)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .onChange(of: scheduleEndpoint) { _ in scheduleEndpointFromSDK = false }
                if scheduleEndpointFromSDK {
                    Text("(from SDK)").font(.caption2).foregroundColor(.secondary)
                }
            }
            HStack {
                Text("Partner").frame(width: 80, alignment: .leading)
                TextField("Partner ID (optional)", text: $schedulePartner)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .onChange(of: schedulePartner) { _ in schedulePartnerFromSDK = false }
                if schedulePartnerFromSDK {
                    Text("(from SDK)").font(.caption2).foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Schedule Parameters")
        } footer: {
            Text("Time is in local timezone. SDK converts to UTC before sending. Sun=0..Sat=6.\nendpoint/partner mirror the legacy RGBSchedule body; leave blank if backend tolerates omission.")
        }
    }

    private var scheduleActionsSection: some View {
        Section {
            Button {
                guard let device = scheduleSelectedDevice, let devUuid = device.uuid else { return }
                let comps = Calendar.current.dateComponents([.hour, .minute], from: scheduleTime)
                let localMinutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
                viewModel.runScheduleFlow(
                    label: scheduleLabel,
                    locationId: locationId,
                    targetDeviceId: devUuid,
                    elementId: scheduleElementId,
                    onOffValue: scheduleOnOff,
                    localMinutesFromMidnight: localMinutes,
                    localWeekdays: Array(scheduleWeekdays).sorted(),
                    endpoint: scheduleEndpoint.isEmpty ? nil : scheduleEndpoint,
                    partner: schedulePartner.isEmpty ? nil : schedulePartner
                )
            } label: {
                HStack {
                    Image(systemName: "calendar.badge.plus").foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("Run Schedule Flow").fontWeight(.medium)
                        Text("smart/add → bindCmd → smartcmd/add → schedule/add")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .disabled(scheduleSelectedDevice == nil || locationId.isEmpty || scheduleWeekdays.isEmpty)

            Button {
                viewModel.deleteLastSchedule()
            } label: {
                HStack {
                    Image(systemName: "trash.circle.fill").foregroundColor(.red)
                    Text("Delete Last Schedule")
                    Spacer()
                    if let id = viewModel.createdScheduleUuid {
                        Text(String(id.prefix(8))).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .disabled(viewModel.createdScheduleUuid == nil)
        } header: {
            Text("Actions")
        }
    }

    // MARK: - Automation Flow View

    private static let smartSubTypes: [(label: String, value: Int)] = [
        ("MIX_OR", 0),
        ("STAIR_SWITCH", 64),
        ("NOTIFICATION", 65),
        ("MOTION", 66),
        ("NO_MOTION_SIM", 67),
        ("NO_MOTION", 68),
        ("DOOR_SENSOR", 69),
        ("SELF_REVERSE", 70),
        ("SMART_AC", 128)
    ]

    private static let conditionTypes: [(label: String, value: Int)] = [
        ("ANY", 1),
        ("EQUAL", 2),
        ("IN", 3),
        ("BETWEEN", 4),
        ("LESS_THAN", 5),
        ("LESS_EQUAL", 6),
        ("GREATER_THAN", 7),
        ("GREATER_EQUAL", 8)
    ]

    private var autoTriggerDevice: IoTDevice? {
        guard let idx = autoTriggerDeviceIndex, idx < viewModel.devices.count else { return nil }
        return viewModel.devices[idx]
    }

    private var autoTriggerElements: [Int] {
        guard let device = autoTriggerDevice else { return [0] }
        return viewModel.elementIds(for: device)
    }

    private var autoCmdDevice: IoTDevice? {
        guard let idx = autoCmdDeviceIndex, idx < viewModel.devices.count else { return nil }
        return viewModel.devices[idx]
    }

    private var autoCmdElements: [Int] {
        guard let device = autoCmdDevice else { return [0] }
        return viewModel.elementIds(for: device)
    }

    private var automationFlowView: some View {
        List {
            autoInputSection
            autoTriggerSection
            autoCmdSection
            autoActionsSection
            flowLogSection
            resultSection
        }
    }

    private var autoInputSection: some View {
        Section {
            HStack {
                Text("Label").frame(width: 80, alignment: .leading)
                TextField("Automation name", text: $autoLabel)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Location").frame(width: 80, alignment: .leading)
                TextField("Location ID", text: $locationId)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
            }
            Picker("Sub Type", selection: $autoSmartSubType) {
                ForEach(Self.smartSubTypes, id: \.value) { item in
                    Text("\(item.label) (\(item.value))").tag(item.value)
                }
            }
        } header: {
            HStack {
                Text("Automation Parameters")
                Spacer()
                Button { viewModel.fetchDevices() } label: {
                    Image(systemName: "arrow.clockwise").font(.caption)
                }
            }
        }
    }

    private var autoTriggerSection: some View {
        Section {
            // Trigger device picker
            if viewModel.isLoadingDevices {
                HStack { ProgressView().frame(width: 20); Text("Loading...").foregroundColor(.secondary) }
            } else if viewModel.devices.isEmpty {
                Button { viewModel.fetchDevices() } label: {
                    Label("Load Devices", systemImage: "arrow.clockwise")
                }
            } else {
                Picker("Trigger Device", selection: $autoTriggerDeviceIndex) {
                    Text("Select device").tag(nil as Int?)
                    ForEach(Array(viewModel.devices.enumerated()), id: \.offset) { index, device in
                        Text(device.displayName).tag(index as Int?)
                    }
                }
                .onChange(of: autoTriggerDeviceIndex) { _ in
                    autoTriggerElm = autoTriggerElements.first ?? 0
                }
            }

            if autoTriggerDevice != nil {
                Picker("Element", selection: $autoTriggerElm) {
                    ForEach(autoTriggerElements, id: \.self) { elmId in
                        let label = autoTriggerDevice?.elementInfos?["\(elmId)"]?.label
                        Text(label != nil ? "\(elmId) — \(label!)" : "Element \(elmId)")
                            .tag(elmId)
                    }
                }
            }

            Picker("Condition", selection: $autoCondition) {
                ForEach(Self.conditionTypes, id: \.value) { item in
                    Text("\(item.label) (\(item.value))").tag(item.value)
                }
            }

            HStack {
                Text("Attr Value").frame(width: 80, alignment: .leading)
                TextField("comma-separated ints (e.g. 8,1)", text: $autoTriggerAttrVal)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
            }

            Picker("Type Trigger", selection: $autoTypeTrigger) {
                Text("OWNER (0)").tag(0)
                Text("EXT (1)").tag(1)
            }
            .pickerStyle(.segmented)

            HStack {
                Text("timeCfg").frame(width: 80, alignment: .leading)
                TextField("optional, comma-separated ints", text: $autoTimeCfg)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
            }
            HStack {
                Text("timeJob").frame(width: 80, alignment: .leading)
                TextField("optional, comma-separated ints", text: $autoTimeJob)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
            }
        } header: {
            Text("Trigger")
        } footer: {
            Text("Attr Value example: 8,1 = EVT_MOTION=ON")
        }
    }

    private var autoCmdSection: some View {
        Section {
            if !viewModel.devices.isEmpty {
                Picker("Cmd Device", selection: $autoCmdDeviceIndex) {
                    Text("Select device").tag(nil as Int?)
                    ForEach(Array(viewModel.devices.enumerated()), id: \.offset) { index, device in
                        Text(device.displayName).tag(index as Int?)
                    }
                }
                .onChange(of: autoCmdDeviceIndex) { _ in
                    autoCmdElm = autoCmdElements.first ?? 0
                }
            }

            if autoCmdDevice != nil {
                Picker("Element", selection: $autoCmdElm) {
                    ForEach(autoCmdElements, id: \.self) { elmId in
                        let label = autoCmdDevice?.elementInfos?["\(elmId)"]?.label
                        Text(label != nil ? "\(elmId) — \(label!)" : "Element \(elmId)")
                            .tag(elmId)
                    }
                }
            }

            Picker("Action", selection: $autoCmdAction) {
                Text("OFF").tag(0)
                Text("ON").tag(1)
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Custom Attr").frame(width: 80, alignment: .leading)
                TextField("override ON/OFF (e.g. 1,1)", text: $autoCmdAttrVal)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
            }

            HStack {
                Text("Delay").frame(width: 80, alignment: .leading)
                TextField("0", text: $autoCmdDelay)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }
        } header: {
            Text("Command")
        } footer: {
            Text("Custom Attr overrides ON/OFF picker if non-empty. Format: comma-separated ints.")
        }
    }

    private var autoActionsSection: some View {
        Section {
            Button {
                guard let triggerDev = autoTriggerDevice, let triggerDevUuid = triggerDev.uuid else { return }
                guard let cmdDev = autoCmdDevice, let cmdDevUuid = cmdDev.uuid else { return }

                let triggerAttr = parseIntArray(autoTriggerAttrVal) ?? []
                let cmdAttr: [Int]
                if let custom = parseIntArray(autoCmdAttrVal), !custom.isEmpty {
                    cmdAttr = custom
                } else {
                    cmdAttr = [1, autoCmdAction]  // [ACT_ONOFF, value]
                }
                let delay = Int(autoCmdDelay) ?? 0
                let timeCfgArr = parseIntArray(autoTimeCfg)
                let timeJobArr = parseIntArray(autoTimeJob)

                viewModel.runAutomationFlow(
                    label: autoLabel,
                    locationId: locationId,
                    smartSubType: autoSmartSubType,
                    triggerDeviceId: triggerDevUuid,
                    triggerElm: autoTriggerElm,
                    condition: autoCondition,
                    attrValueCondition: triggerAttr,
                    typeTrigger: autoTypeTrigger,
                    timeCfg: timeCfgArr,
                    timeJob: timeJobArr,
                    cmdDeviceId: cmdDevUuid,
                    cmdElm: autoCmdElm,
                    cmdAttrValue: cmdAttr,
                    cmdDelay: delay
                )
            } label: {
                HStack {
                    Image(systemName: "bolt.circle.fill").foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("Run Automation Flow").fontWeight(.medium)
                        Text("smart/add -> bindTrigger -> smarttrigger/add -> bindCmd -> smartcmd/add")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .disabled(autoTriggerDevice == nil || autoCmdDevice == nil || locationId.isEmpty
                      || autoTriggerAttrVal.trimmingCharacters(in: .whitespaces).isEmpty)

            Button {
                viewModel.deleteLastAutomation()
            } label: {
                HStack {
                    Image(systemName: "trash.circle.fill").foregroundColor(.red)
                    Text("Delete Last Automation")
                    Spacer()
                    if let uuid = viewModel.createdAutomationSmartUuid {
                        Text(String(uuid.prefix(8))).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .disabled(viewModel.createdAutomationSmartUuid == nil)
        } header: {
            Text("Actions")
        }
    }

    // MARK: - MQTT Primitives View

    private var mqttPrimitivesView: some View {
        List {
            mqttInputSection
            mqttTriggerSection
            mqttCmdSection
            mqttTriggerModeSection
            mqttRemoveSection
            resultSection
        }
    }

    @State private var mqttSmid = "1"
    @State private var mqttDeviceId = ""
    @State private var mqttElm = "0"
    @State private var mqttTypeTrigger = "2"
    @State private var mqttCondition = "2"
    @State private var mqttTriggerAttrVal = "[1, 1]"
    @State private var mqttCmdAttrVal = "[1, 1]"
    @State private var mqttCmdDelay = "0"
    @State private var mqttTimeCfg = ""
    @State private var mqttTriggerEnabled = true

    private var mqttInputSection: some View {
        Section {
            HStack {
                Text("SMID").frame(width: 70, alignment: .leading)
                TextField("Smart ID", text: $mqttSmid)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Device").frame(width: 70, alignment: .leading)
                TextField("Device MAC/UUID", text: $mqttDeviceId)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)
            }
        } header: {
            Text("MQTT Parameters")
        }
    }

    private var mqttTriggerSection: some View {
        Section {
            HStack {
                Text("Element").frame(width: 70, alignment: .leading)
                TextField("0", text: $mqttElm).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Type").frame(width: 70, alignment: .leading)
                TextField("Trigger type", text: $mqttTypeTrigger).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Condition").frame(width: 70, alignment: .leading)
                TextField("2=EQUAL", text: $mqttCondition).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("AttrVal").frame(width: 70, alignment: .leading)
                TextField("[attrType, value]", text: $mqttTriggerAttrVal).textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("TimeCfg").frame(width: 70, alignment: .leading)
                TextField("optional", text: $mqttTimeCfg).textFieldStyle(.roundedBorder)
            }
            Button {
                guard let id = Int(mqttSmid), let elm = Int(mqttElm),
                      let typ = Int(mqttTypeTrigger), let cond = Int(mqttCondition),
                      let attr = parseIntArray(mqttTriggerAttrVal) else { return }
                viewModel.bindSmartTrigger(smid: id, devId: mqttDeviceId, typeTrigger: typ, elm: elm, condition: cond, attrValueCondition: attr, timeCfg: parseIntArray(mqttTimeCfg))
            } label: {
                Label("Bind Trigger", systemImage: "link.badge.plus").foregroundColor(.blue)
            }
            Button {
                guard let id = Int(mqttSmid) else { return }
                viewModel.unbindSmartTrigger(smid: id, devId: mqttDeviceId)
            } label: {
                Label("Unbind Trigger", systemImage: "link.badge.minus").foregroundColor(.orange)
            }
        } header: {
            Text("Smart Trigger")
        } footer: {
            Text("Condition: 1=ANY, 2=EQUAL, 3=IN, 4=BETWEEN, 5=LESS, 7=GREATER")
        }
    }

    private var mqttCmdSection: some View {
        Section {
            HStack {
                Text("AttrVal").frame(width: 70, alignment: .leading)
                TextField("[attr, value]", text: $mqttCmdAttrVal).textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Delay").frame(width: 70, alignment: .leading)
                TextField("0", text: $mqttCmdDelay).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
            }
            Button {
                guard let id = Int(mqttSmid), let elm = Int(mqttElm),
                      let attr = parseIntArray(mqttCmdAttrVal) else { return }
                viewModel.bindSmartCmd(smid: id, devId: mqttDeviceId, elm: elm, attrValue: attr, delay: Int(mqttCmdDelay))
            } label: {
                Label("Bind Command", systemImage: "bolt.badge.plus").foregroundColor(.blue)
            }
            Button {
                guard let id = Int(mqttSmid) else { return }
                viewModel.unbindSmartCmd(smid: id, devId: mqttDeviceId)
            } label: {
                Label("Unbind Command", systemImage: "bolt.badge.minus").foregroundColor(.orange)
            }
        } header: {
            Text("Smart Command")
        }
    }

    private var mqttTriggerModeSection: some View {
        Section {
            Toggle("Enabled", isOn: $mqttTriggerEnabled)
            Button {
                guard let id = Int(mqttSmid) else { return }
                viewModel.setSmartTriggerMode(smid: id, smartType: 0, enabled: mqttTriggerEnabled, disableMinutes: nil)
            } label: {
                Label("Set Trigger Mode", systemImage: mqttTriggerEnabled ? "checkmark.circle" : "xmark.circle")
            }
            Button {
                guard let id = Int(mqttSmid) else { return }
                viewModel.getSmartTriggerMode(smid: id)
            } label: {
                Label("Get Trigger Mode", systemImage: "questionmark.circle").foregroundColor(.purple)
            }
        } header: {
            Text("Trigger Mode")
        }
    }

    private var mqttRemoveSection: some View {
        Section {
            Button {
                guard let id = Int(mqttSmid) else { return }
                viewModel.smartRemoveAnnounce(smid: id)
            } label: {
                Label("Remove Announce", systemImage: "trash.circle").foregroundColor(.red)
            }
        } header: {
            Text("Smart Remove")
        }
    }

    // MARK: - Common

    private var resultSection: some View {
        Section {
            if let result = viewModel.lastResult {
                HStack(alignment: .top) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text(result).font(.system(.body, design: .monospaced))
                }
            }
            if let error = viewModel.lastError {
                HStack(alignment: .top) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                    Text(error).font(.system(.body, design: .monospaced)).foregroundColor(.red)
                }
            }
            if viewModel.lastResult == nil && viewModel.lastError == nil {
                Text("No results yet.").foregroundColor(.secondary).font(.subheadline)
            }
        } header: {
            Text("Results")
        }
    }

    // MARK: - Helpers

    private func parseIntArray(_ string: String) -> [Int]? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let cleaned = trimmed.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
        let parts = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var result: [Int] = []
        for part in parts {
            guard let val = Int(part) else { return nil }
            result.append(val)
        }
        return result.isEmpty ? nil : result
    }
}

#Preview {
    NavigationView { SmartTestView() }
}
