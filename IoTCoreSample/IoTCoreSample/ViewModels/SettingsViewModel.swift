//
//  SettingsViewModel.swift
//  IoTCoreSample
//
//  Settings View Model
//

import Foundation
import IotCoreIOS
import Combine

@MainActor
class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    // Account
    @Published var isAuthenticated: Bool = false
    @Published var userEmail: String = ""

    // SDK Configuration
    @Published var selectedEnvironment: SDKEnvironment = .staging
    @Published var appKey: String = ""
    @Published var appSecret: String = ""
    @Published var locationId: String = ""

    // Alerts
    @Published var showingResetAlert = false
    @Published var showingSaveAlert = false
    @Published var showingReinitAlert = false
    @Published var showingLogoutAlert = false

    // Status
    @Published var statusMessage: String?
    @Published var isStatusSuccess: Bool = false

    // MARK: - Computed Properties

    var sdkVersion: String {
        // Return SDK version from bundle or hardcoded
        return "1.0.0"
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var maskedAppKey: String {
        guard appKey.count > 8 else { return appKey }
        let start = appKey.prefix(4)
        let end = appKey.suffix(4)
        return "\(start)...\(end)"
    }

    var authStatusText: String {
        return isAuthenticated ? "Logged In" : "Not Logged In"
    }

    // MARK: - Initialization

    init() {
        loadConfiguration()
        refreshAuthStatus()
    }

    // MARK: - Configuration Management

    func loadConfiguration() {
        let config = SDKConfigurationManager.shared.loadConfiguration()
        selectedEnvironment = config.environment
        appKey = config.appKey
        appSecret = config.appSecret
    }

    func saveConfiguration() {
        let config = SDKConfiguration(
            environment: selectedEnvironment,
            appKey: appKey,
            appSecret: appSecret
        )

        SDKConfigurationManager.shared.saveConfiguration(config)
        showStatus("Configuration saved successfully", success: true)
        showingSaveAlert = true
    }

    func resetToDefault() {
        SDKConfigurationManager.shared.resetToDefault()
        loadConfiguration()
        showStatus("Configuration reset to default", success: true)
    }

    func reinitializeSDK() {
        showStatus("Reinitializing SDK...", success: true)

        let config = SDKConfiguration(
            environment: selectedEnvironment,
            appKey: appKey,
            appSecret: appSecret
        )

        IoTAppCore.config(
            appKey: config.appKey,
            appSecret: config.appSecret,
            isProduction: config.environment.isProduction
        ) { [weak self] result in
            guard let self = self else { return }

            Task { @MainActor in
                switch result {
                case .success:
                    self.showStatus("SDK reinitialized successfully", success: true)
                    // Save configuration after successful initialization
                    SDKConfigurationManager.shared.saveConfiguration(config)

                case .failure(let error):
                    self.showStatus("SDK initialization failed: \(error.localizedDescription)", success: false)
                }
            }
        }
    }

    var hasUnsavedChanges: Bool {
        let current = SDKConfigurationManager.shared.loadConfiguration()
        return selectedEnvironment != current.environment ||
               appKey != current.appKey ||
               appSecret != current.appSecret
    }

    // MARK: - Account Management

    func refreshAuthStatus() {
        isAuthenticated = IoTAppCore.current?.isAuthenticated ?? false
        // Note: Email is typically stored/retrieved from the auth session
        // For now we display a placeholder if authenticated
        if isAuthenticated {
            userEmail = "Authenticated User"
        } else {
            userEmail = ""
        }
    }

    func logout() {
        IoTAppCore.current?.signOut()
        isAuthenticated = false
        userEmail = ""
        showStatus("Logged out successfully", success: true)
    }

    // MARK: - Private Helpers

    private func showStatus(_ message: String, success: Bool) {
        statusMessage = message
        isStatusSuccess = success

        // Auto-clear after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                if statusMessage == message {
                    statusMessage = nil
                }
            }
        }
    }
}
