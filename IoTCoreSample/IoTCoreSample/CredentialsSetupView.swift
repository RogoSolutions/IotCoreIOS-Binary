//
//  CredentialsSetupView.swift
//  IoTCoreSample
//
//  Initial setup view for users to enter SDK credentials
//

import SwiftUI

struct CredentialsSetupView: View {
    @State private var appKey: String = ""
    @State private var appSecret: String = ""
    @State private var selectedEnvironment: SDKEnvironment = .staging
    @State private var showSecret: Bool = false

    var onCredentialsSaved: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section {
                    welcomeHeader
                }
                .listRowBackground(Color.clear)

                Section(header: Text("SDK Credentials")) {
                    TextField("App Key", text: $appKey)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    HStack {
                        if showSecret {
                            TextField("App Secret", text: $appSecret)
                                .textContentType(.none)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("App Secret", text: $appSecret)
                        }

                        Button {
                            showSecret.toggle()
                        } label: {
                            Image(systemName: showSecret ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section(header: Text("Environment")) {
                    Picker("Environment", selection: $selectedEnvironment) {
                        ForEach(SDKEnvironment.allCases, id: \.self) { env in
                            Text(env.rawValue).tag(env)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button(action: saveAndContinue) {
                        HStack {
                            Spacer()
                            Text("Continue")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isValid)
                }

                Section(header: Text("Help")) {
                    Text("Get your App Key and App Secret from the IoT Platform dashboard.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Setup")
            .onAppear(perform: loadExistingCredentials)
        }
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)

            Text("Welcome to IoT Core Sample")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter your SDK credentials to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Validation

    private var isValid: Bool {
        !appKey.trimmingCharacters(in: .whitespaces).isEmpty &&
        !appSecret.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    private func loadExistingCredentials() {
        let config = SDKConfigurationManager.shared.loadConfiguration()
        if !config.appKey.isEmpty {
            appKey = config.appKey
        }
        if !config.appSecret.isEmpty {
            appSecret = config.appSecret
        }
        selectedEnvironment = config.environment
    }

    private func saveAndContinue() {
        let config = SDKConfiguration(
            environment: selectedEnvironment,
            appKey: appKey.trimmingCharacters(in: .whitespaces),
            appSecret: appSecret.trimmingCharacters(in: .whitespaces)
        )
        SDKConfigurationManager.shared.saveConfiguration(config)
        onCredentialsSaved()
    }
}

// MARK: - Preview

#Preview {
    CredentialsSetupView {
        print("Credentials saved!")
    }
}
