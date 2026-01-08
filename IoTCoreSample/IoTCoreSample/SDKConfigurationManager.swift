//
//  SDKConfigurationManager.swift
//  IoTCoreSample
//
//  SDK Configuration Manager
//  Persists SDK configuration to UserDefaults
//
//  NOTE: This is the PUBLIC version for the binary distribution.
//  Credentials should be provided via:
//  1. Environment Variables (IOTCORE_APP_KEY, IOTCORE_APP_SECRET) for CI/development
//  2. Settings UI for end users
//

import Foundation

enum SDKEnvironment: String, CaseIterable {
    case staging = "Staging"
    case production = "Production"

    var isProduction: Bool {
        return self == .production
    }
}

struct SDKConfiguration {
    var environment: SDKEnvironment
    var appKey: String
    var appSecret: String

    /// Default configuration
    /// Reads from environment variables if available, otherwise empty (user must configure)
    static let `default` = SDKConfiguration(
        environment: .staging,
        // IMPORTANT: Set these environment variables or configure in Settings
        // For CI: Set IOTCORE_APP_KEY and IOTCORE_APP_SECRET in GitHub Secrets
        // For development: export IOTCORE_APP_KEY="your_key" && export IOTCORE_APP_SECRET="your_secret"
        appKey: ProcessInfo.processInfo.environment["IOTCORE_APP_KEY"] ?? "",
        appSecret: ProcessInfo.processInfo.environment["IOTCORE_APP_SECRET"] ?? ""
    )

    /// Check if credentials are configured
    var isConfigured: Bool {
        return !appKey.isEmpty && !appSecret.isEmpty
    }
}

class SDKConfigurationManager {

    // MARK: - Singleton

    static let shared = SDKConfigurationManager()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let environment = "sdk.config.environment"
        static let appKey = "sdk.config.appKey"
        static let appSecret = "sdk.config.appSecret"
    }

    // MARK: - Properties

    private let defaults = UserDefaults.standard

    // MARK: - Public API

    func loadConfiguration() -> SDKConfiguration {
        let environmentRawValue = defaults.string(forKey: Keys.environment) ?? SDKEnvironment.staging.rawValue
        let environment = SDKEnvironment(rawValue: environmentRawValue) ?? .staging

        // Try UserDefaults first, then environment variables, then empty
        let appKey = defaults.string(forKey: Keys.appKey).flatMap { $0.isEmpty ? nil : $0 }
            ?? ProcessInfo.processInfo.environment["IOTCORE_APP_KEY"]
            ?? ""
        let appSecret = defaults.string(forKey: Keys.appSecret).flatMap { $0.isEmpty ? nil : $0 }
            ?? ProcessInfo.processInfo.environment["IOTCORE_APP_SECRET"]
            ?? ""

        return SDKConfiguration(
            environment: environment,
            appKey: appKey,
            appSecret: appSecret
        )
    }

    func saveConfiguration(_ config: SDKConfiguration) {
        defaults.set(config.environment.rawValue, forKey: Keys.environment)
        defaults.set(config.appKey, forKey: Keys.appKey)
        defaults.set(config.appSecret, forKey: Keys.appSecret)
        defaults.synchronize()

        print("💾 SDK Configuration saved:")
        print("  Environment: \(config.environment.rawValue)")
        print("  App Key: \(maskSecret(config.appKey))")
        print("  App Secret: \(maskSecret(config.appSecret))")
    }

    func resetToDefault() {
        // Clear UserDefaults, will fall back to environment variables
        defaults.removeObject(forKey: Keys.appKey)
        defaults.removeObject(forKey: Keys.appSecret)
        defaults.set(SDKEnvironment.staging.rawValue, forKey: Keys.environment)
        defaults.synchronize()
        print("🔄 SDK Configuration reset (will use environment variables if set)")
    }

    // MARK: - Private Helpers

    private func maskSecret(_ secret: String) -> String {
        guard secret.count > 8 else { return secret.isEmpty ? "(not set)" : "***" }
        let start = secret.prefix(4)
        let end = secret.suffix(4)
        return "\(start)...\(end)"
    }
}
