//
//  SettingsTabView.swift
//  IoTCoreSample
//
//  Settings Tab - Account, SDK config, Developer tools, About
//

import SwiftUI

struct SettingsTabView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var locationViewModel = LocationViewModel()
    @State private var showingLocationPicker = false

    var body: some View {
        NavigationView {
            List {
                // Account Section
                accountSection

                // Location Section (new)
                locationSection

                // SDK Configuration Section
                sdkConfigurationSection

                // Developer Tools Section
                developerToolsSection

                // About Section
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.refreshAuthStatus()
                locationViewModel.loadActiveLocation()
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationSelectionView(viewModel: locationViewModel)
            }
            .alert("Reinitialize SDK?", isPresented: $viewModel.showingReinitAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reinitialize", role: .destructive) {
                    viewModel.reinitializeSDK()
                }
            } message: {
                Text("The app will reinitialize the SDK with the new configuration. Continue?")
            }
            .alert("Reset to Default?", isPresented: $viewModel.showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    viewModel.resetToDefault()
                }
            } message: {
                Text("This will reset all configuration to default values.")
            }
            .alert("Saved", isPresented: $viewModel.showingSaveAlert) {
                Button("OK") { }
            } message: {
                Text("Configuration saved successfully. Tap 'Reinitialize SDK' to apply changes.")
            }
            .alert("Logout?", isPresented: $viewModel.showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    viewModel.logout()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            // Auth Status Row
            HStack {
                Image(systemName: viewModel.isAuthenticated ? "checkmark.circle.fill" : "person.crop.circle.badge.questionmark")
                    .foregroundColor(viewModel.isAuthenticated ? .green : .orange)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.authStatusText)
                        .font(.headline)
                    if viewModel.isAuthenticated && !viewModel.userEmail.isEmpty {
                        Text(viewModel.userEmail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)

            // Login/Logout Actions
            if viewModel.isAuthenticated {
                Button {
                    viewModel.showingLogoutAlert = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Logout")
                    }
                    .foregroundColor(.red)
                }
            } else {
                NavigationLink(destination: AuthView()) {
                    HStack {
                        Image(systemName: "person.badge.key")
                        Text("Login")
                    }
                }
            }
        } header: {
            Text("Account")
        }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        Section {
            // Active Location Row
            Button {
                showingLocationPicker = true
            } label: {
                HStack {
                    Image(systemName: locationViewModel.hasActiveLocation ? "location.fill" : "location.slash")
                        .foregroundColor(locationViewModel.hasActiveLocation ? .green : .orange)
                        .font(.title2)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active Location")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text(locationViewModel.activeLocationDisplayName)
                            .font(.caption)
                            .foregroundColor(locationViewModel.hasActiveLocation ? .secondary : .orange)
                    }

                    Spacer()

                    // Mesh indicator
                    if let location = locationViewModel.activeLocation,
                       location.meshUuid != nil {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Refresh Button
            Button {
                locationViewModel.fetchLocations()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 30)
                    Text("Refresh Locations")
                }
            }
            .disabled(locationViewModel.isLoading)

            // Status/Error
            if locationViewModel.isLoading {
                HStack {
                    ProgressView()
                        .frame(width: 30)
                    Text("Loading locations...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let error = locationViewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .frame(width: 30)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        } header: {
            Text("Location")
        } footer: {
            Text("Select the active location for device onboarding and control. Location determines mesh network configuration.")
                .font(.caption)
        }
    }

    // MARK: - SDK Configuration Section

    private var sdkConfigurationSection: some View {
        Section {
            // Environment Picker
            Picker("Environment", selection: $viewModel.selectedEnvironment) {
                ForEach(SDKEnvironment.allCases, id: \.self) { env in
                    Text(env.rawValue).tag(env)
                }
            }

            // App Key (masked display)
            HStack {
                Text("App Key")
                    .foregroundColor(.secondary)
                Spacer()
                Text(viewModel.maskedAppKey)
                    .font(.system(.body, design: .monospaced))
            }

            // Expandable App Key Editor
            DisclosureGroup("Edit App Key") {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Enter App Key", text: $viewModel.appKey)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.vertical, 4)
            }

            // App Secret Editor
            DisclosureGroup("Edit App Secret") {
                VStack(alignment: .leading, spacing: 4) {
                    SecureField("Enter App Secret", text: $viewModel.appSecret)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                .padding(.vertical, 4)
            }

            // Location ID
            HStack {
                Text("Location ID")
                    .foregroundColor(.secondary)
                Spacer()
                TextField("Optional", text: $viewModel.locationId)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 150)
            }

            // Action Buttons
            if viewModel.hasUnsavedChanges {
                Button {
                    viewModel.saveConfiguration()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save Changes")
                    }
                }
                .foregroundColor(.blue)
            }

            Button {
                viewModel.showingReinitAlert = true
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Reinitialize SDK")
                }
            }
            .foregroundColor(.orange)

            Button {
                viewModel.showingResetAlert = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Default")
                }
            }
            .foregroundColor(.red)

            // Status Message
            if let message = viewModel.statusMessage {
                HStack {
                    Image(systemName: viewModel.isStatusSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(viewModel.isStatusSuccess ? .green : .red)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(viewModel.isStatusSuccess ? .green : .red)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("SDK Configuration")
        } footer: {
            Text("Configure the SDK environment and credentials. Changes require SDK reinitialization.")
                .font(.caption)
        }
    }

    // MARK: - Developer Tools Section

    private var developerToolsSection: some View {
        Section {
            NavigationLink(destination: RestfulAPITestView()) {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("REST API Tester")
                }
            }

            NavigationLink(destination: DebugLogView()) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(.purple)
                        .frame(width: 24)
                    Text("Debug Logs")
                }
            }

            NavigationLink(destination: DeviceCommandTestView()) {
                HStack {
                    Image(systemName: "command")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    Text("Device Commands")
                }
            }

            NavigationLink(destination: ServiceCallbackDemoView()) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(Color(red: 0.29, green: 0.33, blue: 0.73))
                        .frame(width: 24)
                    Text("Service Callbacks")
                }
            }
        } header: {
            Text("Developer Tools")
        } footer: {
            Text("Tools for testing and debugging SDK functionality.")
                .font(.caption)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            DetailRow(label: "SDK Version", value: viewModel.sdkVersion)
            DetailRow(label: "App Version", value: viewModel.appVersion)

            Link(destination: URL(string: "https://github.com/RogoSolutions/IotCoreIOS")!) {
                HStack {
                    Image(systemName: "book")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Documentation")
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Link(destination: URL(string: "https://github.com/RogoSolutions/IotCoreIOS/issues")!) {
                HStack {
                    Image(systemName: "exclamationmark.bubble")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    Text("Report Issue")
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("About")
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsTabView()
}
