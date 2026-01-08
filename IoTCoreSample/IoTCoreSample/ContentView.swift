//
//  ContentView.swift
//  IoTCoreSample
//
//  Main Tab Navigation
//

import SwiftUI
import IotCoreIOS

struct ContentView: View {
    @State private var sdkInitialized = false
    @State private var initializationError: String?
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if sdkInitialized {
                mainTabView
            } else if let error = initializationError {
                errorView(error)
            } else {
                initializingView
            }
        }
        .task {
            initializeSDK()
        }
    }

    // MARK: - Main Tab View

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            // Onboarding Tab - Complete device setup flow
            OnboardingTabView()
                .tabItem {
                    Label("Onboarding", systemImage: "plus.circle.fill")
                }
                .tag(0)

            // Device Control Tab - Device management and control
            DeviceControlTabView()
                .tabItem {
                    Label("Devices", systemImage: "house.fill")
                }
                .tag(1)

            // Settings Tab - SDK config, auth, API testing, debug tools
            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }

    // MARK: - Initializing View

    private var initializingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Initializing IoT Core SDK...")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Please wait")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Initialization Failed")
                .font(.title2)
                .fontWeight(.semibold)

            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") {
                initializationError = nil
                initializeSDK()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - SDK Initialization

    private func initializeSDK() {
        print("Initializing IoT Core SDK...")

        // Load saved configuration
        let config = SDKConfigurationManager.shared.loadConfiguration()
        print("Using configuration:")
        print("   Environment: \(config.environment.rawValue)")
        print("   App Key: \(config.appKey)")

        IoTAppCore.config(
            appKey: config.appKey,
            appSecret: config.appSecret,
            isProduction: config.environment.isProduction
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("IoT Core SDK initialized successfully")
                    sdkInitialized = true

                    // Check auth status
                    if IoTAppCore.current?.isAuthenticated == true {
                        print("User is authenticated")
                    } else {
                        print("User is not authenticated")
                    }

                case .failure(let error):
                    print("SDK initialization failed: \(error)")
                    initializationError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
