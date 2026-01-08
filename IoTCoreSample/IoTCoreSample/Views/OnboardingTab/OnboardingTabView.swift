//
//  OnboardingTabView.swift
//  IoTCoreSample
//
//  Onboarding Tab - Step-by-step wizard for device onboarding
//  Flow: Discovery -> Select Device -> Connect -> Network Status -> WiFi Config -> Cloud Sync
//

import SwiftUI
import IotCoreIOS
import CoreBluetooth

struct OnboardingTabView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @StateObject private var discoveryViewModel = DiscoveryViewModel()
    @StateObject private var locationViewModel = LocationViewModel()
    @StateObject private var groupViewModel = GroupViewModel()
    @State private var showingLocationPicker = false
    @State private var showingGroupPicker = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Location Selection Card (always visible)
                locationSelectionCard
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Step Indicator Header
                stepIndicatorHeader

                Divider()

                // Step Content
                stepContentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                // Navigation Buttons
                navigationButtonsView
            }
            .navigationTitle("Device Onboarding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.currentStep != .discovery {
                        Button("Reset") {
                            resetOnboarding()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationSelectionView(viewModel: locationViewModel)
            }
            .sheet(isPresented: $showingGroupPicker) {
                GroupSelectionSheet(
                    groupViewModel: groupViewModel,
                    locationId: locationViewModel.activeLocation?.uuid
                )
            }
            .onAppear {
                locationViewModel.loadActiveLocation()
                groupViewModel.fetchGroups()
            }
            .onChange(of: locationViewModel.activeLocation) { _ in
                // Clear group selection when location changes
                groupViewModel.clearSelection()
            }
        }
    }

    // MARK: - Location Selection Card

    private var locationSelectionCard: some View {
        ActiveLocationCard(viewModel: locationViewModel) {
            showingLocationPicker = true
        }
    }

    // MARK: - Step Indicator Header

    private var stepIndicatorHeader: some View {
        VStack(spacing: 12) {
            // Step dots
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    stepDot(for: step)
                }
            }

            // Current step info
            HStack {
                Image(systemName: viewModel.currentStep.icon)
                    .foregroundColor(.accentColor)
                Text("Step \(viewModel.currentStep.rawValue) of \(OnboardingStep.totalSteps)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(viewModel.currentStep.title)
                .font(.headline)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private func stepDot(for step: OnboardingStep) -> some View {
        let isCurrentStep = step == viewModel.currentStep
        let isCompleted = viewModel.completedSteps.contains(step)
        let isPastStep = step.rawValue < viewModel.currentStep.rawValue

        return Button {
            // Allow tapping to go back to completed steps
            if isCompleted || isPastStep {
                viewModel.goToStep(step)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isCurrentStep ? Color.accentColor : (isCompleted || isPastStep ? Color.green : Color(.systemGray4)))
                    .frame(width: 24, height: 24)

                if isCompleted && !isCurrentStep {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                } else {
                    Text("\(step.rawValue)")
                        .font(.caption2.bold())
                        .foregroundColor(isCurrentStep || isCompleted || isPastStep ? .white : .gray)
                }
            }
        }
        .disabled(!isCompleted && !isPastStep && !isCurrentStep)
    }

    // MARK: - Step Content View

    @ViewBuilder
    private var stepContentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Error banner if present
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                // Step-specific content
                switch viewModel.currentStep {
                case .discovery:
                    discoveryStepView
                case .selectDevice:
                    selectDeviceStepView
                case .connect:
                    connectStepView
                case .networkStatus:
                    networkStatusStepView
                case .wifiConfig:
                    wifiConfigStepView
                case .cloudSync:
                    cloudSyncStepView
                }
            }
            .padding()
        }
    }

    // MARK: - Step 1: Discovery

    private var discoveryStepView: some View {
        VStack(spacing: 20) {
            // Subtitle
            Text(viewModel.currentStep.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Scan Button
            if discoveryViewModel.isScanning {
                Button {
                    discoveryViewModel.stopScanning()
                } label: {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Stop Scanning")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            } else {
                Button {
                    discoveryViewModel.startScanning()
                } label: {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Start Scanning")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }

            // Error from discovery
            if let error = discoveryViewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // Stats
            if discoveryViewModel.isScanning || !discoveryViewModel.discoveredDevices.isEmpty {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(discoveryViewModel.filteredDevices.count)/\(discoveryViewModel.discoveredDevices.count)")
                            .font(.title2.bold())
                        Text("Devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()
                        .frame(height: 40)

                    VStack(spacing: 4) {
                        if discoveryViewModel.isScanning {
                            Text("\(discoveryViewModel.remainingScanTime)s")
                                .font(.title2.bold())
                            Text("Remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(String(format: "%.1fs", discoveryViewModel.scanDuration))
                                .font(.title2.bold())
                            Text("Duration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !discoveryViewModel.discoveredDevices.isEmpty {
                        Spacer()
                        Button {
                            discoveryViewModel.clearResults()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Filter Picker
            if !discoveryViewModel.discoveredDevices.isEmpty {
                deviceFilterPicker
            }

            // Discovered Devices List
            if discoveryViewModel.filteredDevices.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)

                    Text("No Devices Found")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Tap 'Start Scanning' to discover nearby IoT devices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Discovered Devices")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)

                    Text("Tap a device to select and connect")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(discoveryViewModel.filteredDevices) { device in
                        Button {
                            // Select device, stop scanning, and go directly to Connect step
                            discoveryViewModel.stopScanning()
                            viewModel.selectDevice(device)
                            // Mark discovery and selectDevice steps as completed to allow navigation
                            viewModel.completedSteps.insert(.discovery)
                            viewModel.completedSteps.insert(.selectDevice)
                            viewModel.currentStep = .connect
                        } label: {
                            discoveredDeviceRow(device)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Device Filter Picker

    private var deviceFilterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DeviceTypeFilter.allCases, id: \.self) { filter in
                    deviceFilterButton(filter)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func deviceFilterButton(_ filter: DeviceTypeFilter) -> some View {
        let isSelected = discoveryViewModel.selectedFilter == filter
        let count: Int = {
            switch filter {
            case .all: return discoveryViewModel.discoveredDevices.count
            case .wile: return discoveryViewModel.wileDevices.count
            case .mesh: return discoveryViewModel.meshDevices.count
            case .unknown: return discoveryViewModel.unknownDevices.count
            }
        }()

        return Button {
            discoveryViewModel.selectedFilter = filter
        } label: {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text("\(filter.rawValue) (\(count))")
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }

    private func discoveredDeviceRow(_ device: DiscoveredDevice) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(device.type.color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: device.type.icon)
                    .foregroundColor(device.type.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.subheadline.bold())

                HStack(spacing: 6) {
                    Text(device.type.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(device.type.color.opacity(0.2))
                        .foregroundColor(device.type.color)
                        .cornerRadius(4)

                    if let mac = device.macAddr {
                        Text(mac)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Signal
            VStack(alignment: .trailing, spacing: 2) {
                signalBars(device.signalBars)
                Text("\(device.rssi) dBm")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func signalBars(_ bars: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1...4, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 1)
                    .fill(bar <= bars ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(bar * 4))
            }
        }
    }

    // MARK: - Step 2: Select Device

    private var selectDeviceStepView: some View {
        VStack(spacing: 20) {
            Text(viewModel.currentStep.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let selected = viewModel.selectedDevice {
                // Selected device card
                VStack(spacing: 12) {
                    HStack {
                        Text("Selected Device")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Change") {
                            viewModel.clearSelection()
                        }
                        .font(.subheadline)
                    }

                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 60, height: 60)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.green)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(selected.displayName)
                                .font(.headline)
                            if let mac = selected.macAddr {
                                Text(mac)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(selected.type.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(selected.type.color.opacity(0.2))
                                .foregroundColor(selected.type.color)
                                .cornerRadius(4)
                        }

                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                // Device selection list
                if discoveryViewModel.discoveredDevices.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)

                        Text("No Devices Available")
                            .font(.headline)

                        Text("Go back to Discovery step to scan for devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select a device to configure:")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)

                        ForEach(discoveryViewModel.discoveredDevices) { device in
                            Button {
                                viewModel.selectDevice(device)
                            } label: {
                                selectableDeviceRow(device)
                            }
                        }
                    }
                }
            }
        }
    }

    private func selectableDeviceRow(_ device: DiscoveredDevice) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(device.type.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: device.type.icon)
                    .foregroundColor(device.type.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)

                if let mac = device.macAddr {
                    Text(mac)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Step 3: Connect (Placeholder)

    private var connectStepView: some View {
        VStack(spacing: 24) {
            Text(viewModel.currentStep.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Selected device info
            if let device = viewModel.selectedDevice {
                VStack(spacing: 8) {
                    Text("Connecting to:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(device.displayName)
                        .font(.headline)
                    if let mac = device.macAddr {
                        Text(mac)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            if viewModel.isConnected {
                // Connected state
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("Connected Successfully")
                        .font(.headline)
                        .foregroundColor(.green)

                    if let mac = viewModel.deviceMacAddress {
                        Text("MAC: \(mac)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 20)
            } else {
                // Connect button
                Button {
                    viewModel.connectToDevice()
                } label: {
                    HStack {
                        Image(systemName: "link")
                        Text("Connect to Device")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                // Placeholder info
                placeholderInfoCard(
                    icon: "info.circle",
                    title: "BLE Connection",
                    description: "This step establishes a Bluetooth Low Energy connection with the selected device. Once connected, you can configure the device's network settings."
                )
            }
        }
    }

    // MARK: - Step 4: Network Status (Placeholder)

    private var networkStatusStepView: some View {
        VStack(spacing: 24) {
            Text(viewModel.currentStep.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if viewModel.hasNetworkStatus {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("Network Status Retrieved")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 20)
            } else {
                Button {
                    viewModel.checkNetworkStatus()
                } label: {
                    HStack {
                        Image(systemName: "network")
                        Text("Check Network Status")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                placeholderInfoCard(
                    icon: "info.circle",
                    title: "Network Connectivity",
                    description: "This step queries the device's current network connectivity status, including WiFi connection state and cloud connection status."
                )
            }
        }
    }

    // MARK: - Step 5: WiFi Config

    private var wifiConfigStepView: some View {
        VStack(spacing: 24) {
            Text(viewModel.currentStep.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if viewModel.isWifiConnected {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("WiFi Connected")
                        .font(.headline)
                        .foregroundColor(.green)

                    Text(viewModel.selectedSSID)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            } else {
                // Manual WiFi input (always visible)
                VStack(alignment: .leading, spacing: 12) {
                    Text("WiFi Credentials")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)

                    TextField("WiFi SSID (Network Name)", text: $viewModel.selectedSSID)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    SecureField("WiFi Password", text: $viewModel.wifiPassword)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        viewModel.connectToWifi()
                    } label: {
                        HStack {
                            Image(systemName: "wifi.circle.fill")
                            Text("Connect to WiFi")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.selectedSSID.isEmpty ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.selectedSSID.isEmpty)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Divider with "OR" text
                HStack {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                    Text("OR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                }
                .padding(.vertical, 8)

                // Scan button
                Button {
                    viewModel.scanWifi()
                } label: {
                    HStack {
                        Image(systemName: "wifi")
                        Text("Scan for WiFi Networks")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                // Network selection (if scanned)
                if !viewModel.scannedNetworks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available Networks:")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)

                        ForEach(viewModel.scannedNetworks, id: \.ssid) { network in
                            if let ssid = network.ssid {
                                Button {
                                    viewModel.selectedSSID = ssid
                                } label: {
                                    HStack {
                                        Image(systemName: viewModel.selectedSSID == ssid ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(viewModel.selectedSSID == ssid ? .green : .gray)
                                        Text(ssid)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(network.rssi ?? 0) dBm")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 6: Cloud Sync

    private var cloudSyncStepView: some View {
        VStack(spacing: 24) {
            Text(viewModel.currentStep.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if viewModel.completedSteps.contains(.cloudSync) {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)

                    Text("Device Onboarded Successfully!")
                        .font(.title2.bold())
                        .foregroundColor(.green)

                    Text(viewModel.deviceLabel)
                        .font(.headline)

                    Text("Your device is now registered with the cloud and ready to use.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        resetOnboarding()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Onboard Another Device")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.top, 20)
                }
                .padding(.vertical, 20)
            } else {
                // Location Warning if not set
                if !locationViewModel.hasActiveLocation {
                    locationRequiredWarning
                }

                // Active Location Info
                if let location = locationViewModel.activeLocation {
                    activeLocationInfoCard(location)
                }

                // Device label input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Device Label")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)

                    TextField("My Smart Device", text: $viewModel.deviceLabel)
                        .textFieldStyle(.roundedBorder)
                }

                // Group selection (optional)
                groupSelectionCard

                // Sync progress
                if viewModel.syncProgress > 0 && viewModel.syncProgress < 100 {
                    VStack(spacing: 8) {
                        ProgressView(value: Double(viewModel.syncProgress), total: 100)
                        Text("Syncing: \(viewModel.syncProgress)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                Button {
                    syncToCloudWithLocation()
                } label: {
                    HStack {
                        Image(systemName: "cloud.fill")
                        Text("Sync to Cloud")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSyncToCloud ? Color.accentColor : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canSyncToCloud)

                placeholderInfoCard(
                    icon: "info.circle",
                    title: "Cloud Registration",
                    description: "This final step registers the device with the cloud backend, allowing you to control it remotely from anywhere."
                )
            }
        }
    }

    // MARK: - Cloud Sync Helpers

    private var canSyncToCloud: Bool {
        !viewModel.deviceLabel.isEmpty && locationViewModel.hasActiveLocation
    }

    private var locationRequiredWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Location Required")
                    .font(.subheadline.bold())
                    .foregroundColor(.orange)
                Text("Please select a location before syncing to cloud")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Select") {
                showingLocationPicker = true
            }
            .font(.subheadline.bold())
            .foregroundColor(.accentColor)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    private func activeLocationInfoCard(_ location: Location) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
                Text("Syncing to: \(location.displayName)")
                    .font(.subheadline.bold())
                Spacer()
            }

            if location.meshUuid != nil {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundColor(.purple)
                    Text("BLE Mesh configured")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let meshAddr = location.meshAddress {
                        Text("Next addr: \(meshAddr)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    private func syncToCloudWithLocation() {
        guard let location = locationViewModel.activeLocation else {
            viewModel.errorMessage = "Please select a location first"
            return
        }

        // Use mesh keys from the active location and optional group
        viewModel.syncToCloudWithMeshConfig(
            meshUuid: location.meshUuid,
            meshNwkKeys: location.meshNetworkKeys,
            meshAppKeys: location.meshAppKeys,
            groupId: groupViewModel.selectedGroup?.uuid,
            groupElementId: groupViewModel.selectedGroup?.groupElementId
        )
    }

    // MARK: - Group Selection Card

    private var groupSelectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Add to Group")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)

                Text("(Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button {
                showingGroupPicker = true
            } label: {
                HStack {
                    Image(systemName: groupViewModel.hasSelectedGroup ? "folder.fill" : "folder")
                        .foregroundColor(groupViewModel.hasSelectedGroup ? .blue : .gray)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        if let group = groupViewModel.selectedGroup {
                            Text(group.displayName)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            if !group.description.isEmpty {
                                Text(group.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("No group selected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Tap to select a room/group")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if groupViewModel.hasSelectedGroup {
                        Button {
                            groupViewModel.clearSelection()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtonsView: some View {
        HStack(spacing: 16) {
            // Back button
            if viewModel.canGoBack {
                Button {
                    viewModel.goToPreviousStep()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }

            // Next/Finish button
            if !viewModel.isLastStep || !viewModel.completedSteps.contains(.cloudSync) {
                Button {
                    if viewModel.isLastStep {
                        // Already handled in cloudSyncStepView
                    } else {
                        viewModel.goToNextStep()
                    }
                } label: {
                    HStack {
                        Text(viewModel.nextButtonTitle)
                        if !viewModel.isLastStep {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canGoNext ? Color.accentColor : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!viewModel.canGoNext)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Helper Views

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.red)
        .cornerRadius(12)
    }

    private func placeholderInfoCard(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.subheadline.bold())
            }
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            if viewModel.syncProgress > 0 && viewModel.syncProgress < 100 {
                Text("Syncing: \(viewModel.syncProgress)%")
                    .foregroundColor(.white)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Actions

    private func resetOnboarding() {
        viewModel.resetOnboarding()
        discoveryViewModel.clearResults()
        discoveryViewModel.stopScanning()
    }
}

// MARK: - Preview

#Preview {
    OnboardingTabView()
}

// MARK: - Group Selection Sheet

struct GroupSelectionSheet: View {
    @ObservedObject var groupViewModel: GroupViewModel
    let locationId: String?
    @Environment(\.dismiss) private var dismiss

    var filteredGroups: [DeviceGroup] {
        groupViewModel.groups(forLocationId: locationId)
    }

    var body: some View {
        NavigationView {
            List {
                // No group option
                Button {
                    groupViewModel.clearSelection()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "minus.circle")
                            .foregroundColor(.gray)
                            .frame(width: 30)

                        Text("No Group")
                            .foregroundColor(.primary)

                        Spacer()

                        if groupViewModel.selectedGroup == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }

                // Group list
                if filteredGroups.isEmpty {
                    if groupViewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.largeTitle)
                                .foregroundColor(.gray)

                            Text("No groups found")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if locationId != nil {
                                Text("No groups in this location")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    }
                } else {
                    ForEach(filteredGroups) { group in
                        Button {
                            groupViewModel.selectGroup(group)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: group.isRoom ? "door.left.hand.open" : "folder.fill")
                                    .foregroundColor(group.isRoom ? .blue : .orange)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.displayName)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)

                                    HStack(spacing: 8) {
                                        if !group.description.isEmpty {
                                            Text(group.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        if let elementId = group.elementId {
                                            Text("ID: \(elementId)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color(.systemGray5))
                                                .cornerRadius(4)
                                        }
                                    }
                                }

                                Spacer()

                                if groupViewModel.selectedGroup?.uuid == group.uuid {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }

                // Error message
                if let error = groupViewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Select Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        groupViewModel.fetchGroups()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(groupViewModel.isLoading)
                }
            }
        }
    }
}
