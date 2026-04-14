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
                    case .verifyEmail:
                        verifyEmailSection
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
            switch viewModel.signUpStep {
            case .fillForm:
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

            case .verifyEmail:
                TextField("Verification Code", text: $viewModel.signUpVerifyCode)
                    .textInputAutocapitalization(.never)
                    .disabled(viewModel.isLoading)

                Button(action: viewModel.verifySignUpEmail) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Verifying...")
                        } else {
                            Text("Verify Email")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.signUpVerifyCode.isEmpty || viewModel.isLoading)

                Button(action: {
                    viewModel.signUpStep = .fillForm
                    viewModel.errorMessage = nil
                    viewModel.successMessage = nil
                }) {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.isLoading)
            }
        } header: {
            Text("Sign Up")
        } footer: {
            Group {
                switch viewModel.signUpStep {
                case .fillForm:
                    Text("* Required fields. Username and phone are optional.")
                case .verifyEmail:
                    Text("Enter the verification code sent to \(viewModel.signUpEmail).")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Verify Email Section

    private var verifyEmailSection: some View {
        Section {
            TextField("Verification Code", text: $viewModel.verifyEmailCode)
                .textInputAutocapitalization(.never)
                .disabled(viewModel.isLoading)

            Button(action: viewModel.verifyEmail) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Verifying...")
                    } else {
                        Text("Verify Email")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.verifyEmailCode.isEmpty || viewModel.isLoading)
        } header: {
            Text("Verify Email")
        } footer: {
            Text("Enter the verification code sent to your email after sign up.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Forgot Password Section

    private var forgotPasswordSection: some View {
        Section {
            switch viewModel.forgotPasswordStep {
            case .enterEmail:
                TextField("Email", text: $viewModel.forgotEmail)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .disabled(viewModel.isLoading)

                Button(action: viewModel.requestPasswordReset) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Sending...")
                        } else {
                            Text("Send Verification Code")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.forgotEmail.isEmpty || viewModel.isLoading)

            case .enterCode:
                TextField("Verification Code", text: $viewModel.verifyCode)
                    .textInputAutocapitalization(.never)
                    .disabled(viewModel.isLoading)

                SecureField("New Password", text: $viewModel.newPassword)
                    .textContentType(.newPassword)
                    .disabled(viewModel.isLoading)

                SecureField("Confirm New Password", text: $viewModel.confirmNewPassword)
                    .textContentType(.newPassword)
                    .disabled(viewModel.isLoading)

                Button(action: viewModel.resetPassword) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Resetting...")
                        } else {
                            Text("Reset Password")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.verifyCode.isEmpty || viewModel.newPassword.isEmpty || viewModel.isLoading)

                Button(action: {
                    viewModel.forgotPasswordStep = .enterEmail
                    viewModel.errorMessage = nil
                    viewModel.successMessage = nil
                }) {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.isLoading)
            }
        } header: {
            Text("Forgot Password")
        } footer: {
            Group {
                switch viewModel.forgotPasswordStep {
                case .enterEmail:
                    Text("Enter your email to receive a verification code.")
                case .enterCode:
                    Text("Enter the verification code sent to your email and set a new password.")
                }
            }
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
