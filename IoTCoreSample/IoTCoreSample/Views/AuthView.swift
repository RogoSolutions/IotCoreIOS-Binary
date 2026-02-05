//
//  AuthView.swift
//  IoTCoreSample
//
//  Authentication UI
//

import SwiftUI

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        NavigationView {
            Form {
                // Status Section
                statusSection

                // Auth Mode Picker (only show when not authenticated)
                if !viewModel.isAuthenticated {
                    authModePicker
                }

                // Content based on auth mode
                if !viewModel.isAuthenticated {
                    switch viewModel.authMode {
                    case .login:
                        loginSection
                    case .signUp:
                        signUpSection
                    case .forgotPassword:
                        forgotPasswordSection
                    }
                }

                // Logout Section
                if viewModel.isAuthenticated {
                    logoutSection
                }

                // Messages
                if let success = viewModel.successMessage {
                    successBanner(success)
                }

                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }
            }
            .navigationTitle("Authentication")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Auth Mode Picker

    private var authModePicker: some View {
        Section {
            Picker("Mode", selection: $viewModel.authMode) {
                ForEach(AuthMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section {
            HStack {
                Text("Authentication Status")
                    .foregroundColor(.secondary)
                Spacer()
                Text(viewModel.statusMessage)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.isAuthenticated ? .green : .orange)
            }

            if viewModel.isAuthenticated {
                HStack {
                    Text("User Email")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.email.isEmpty ? "N/A" : viewModel.email)
                        .fontWeight(.medium)
                }
            }
        } header: {
            Text("Status")
        }
    }

    // MARK: - Login Section

    private var loginSection: some View {
        Section {
            // Login type picker
            Picker("Login with", selection: $viewModel.loginType) {
                ForEach(LoginType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            // Show appropriate input based on login type
            if viewModel.loginType == .email {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .disabled(viewModel.isLoading)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .disabled(viewModel.isLoading)
            } else if viewModel.loginType == .username {
                TextField("Username", text: $viewModel.username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .disabled(viewModel.isLoading)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .disabled(viewModel.isLoading)
            } else if viewModel.loginType == .token {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Token")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: $viewModel.customToken)
                        .frame(height: 100)
                        .font(.system(.body, design: .monospaced))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .disabled(viewModel.isLoading)
                }
            }

            Button(action: viewModel.login) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Logging in...")
                    } else {
                        Text("Login")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.canLogin)
        } header: {
            Text("Login")
        } footer: {
            if viewModel.loginType == .token {
                Text("Paste a custom token from your auth provider (Firebase, social login, etc.)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Use your IoT platform credentials to authenticate.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Sign Up Section

    private var signUpSection: some View {
        Section {
            TextField("Email *", text: $viewModel.signUpEmail)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .disabled(viewModel.isLoading)

            TextField("Username (optional)", text: $viewModel.signUpUsername)
                .textInputAutocapitalization(.never)
                .disabled(viewModel.isLoading)

            TextField("Phone (optional)", text: $viewModel.signUpPhone)
                .keyboardType(.phonePad)
                .disabled(viewModel.isLoading)

            SecureField("Password *", text: $viewModel.signUpPassword)
                .textContentType(.newPassword)
                .disabled(viewModel.isLoading)

            SecureField("Confirm Password *", text: $viewModel.signUpConfirmPassword)
                .textContentType(.newPassword)
                .disabled(viewModel.isLoading)

            Button(action: viewModel.signUp) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Signing up...")
                    } else {
                        Text("Create Account")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.canSignUp)
        } header: {
            Text("Sign Up")
        } footer: {
            Text("* Required fields. Username and phone are optional.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Forgot Password Section

    private var forgotPasswordSection: some View {
        Section {
            // SDK Status Banner
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text("SDK APIs for password reset are not yet implemented")
                    .font(.caption)
            }
            .padding(.vertical, 4)

            TextField("Email", text: $viewModel.forgotEmail)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)

            Button(action: viewModel.requestPasswordReset) {
                Text("Send Reset Link")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
        } header: {
            Text("Forgot Password")
        } footer: {
            Text("Enter your email to receive a password reset link. This feature will be available once the SDK API is implemented.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Logout Section

    private var logoutSection: some View {
        Section {
            Button(action: viewModel.logout) {
                HStack {
                    Spacer()
                    Text("Logout")
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Success Banner

    private func successBanner(_ message: String) -> some View {
        Section {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(message)
                    .font(.subheadline)
                Spacer()
                Button(action: viewModel.clearMessages) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        Section {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.red)
                Spacer()
                Button(action: viewModel.clearMessages) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Preview

#Preview {
    AuthView()
}
