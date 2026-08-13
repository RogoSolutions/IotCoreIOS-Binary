//
//  PhoneAuthView.swift
//  IoTCoreSample
//
//  Manual test screen for the 6 phone-number auth (OTP) primitives
//  (Trello 260810-1). Each button invokes exactly one Core function.
//
//  No NavigationView wrapper here — this screen is pushed from AuthView, so it
//  inherits the existing navigation context.
//

import SwiftUI

struct PhoneAuthView: View {
    @StateObject private var viewModel = PhoneAuthViewModel()

    var body: some View {
        Form {
            statusSection
            signUpSection
            loginSection
            forgotSection
            resultSection
        }
        .navigationTitle("Phone Auth")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.refreshAuthStatus() }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            HStack {
                Text("Auth status").foregroundColor(.secondary)
                Spacer()
                Text(viewModel.isAuthenticated ? "✅ Logged In" : "🔒 Not Logged In")
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.isAuthenticated ? .green : .orange)
            }
            if viewModel.isAuthenticated {
                Button(role: .destructive, action: viewModel.logout) {
                    Text("Logout")
                }
                .disabled(viewModel.isLoading)
            }
        } header: {
            Text("Status")
        } footer: {
            Text("Enter phone in E.164 (+84…). OTP is 6 digits, valid 5 min. Wait 30s between SMS sends. Password ≥ 6 chars. The Core does NOT normalize the number.")
                .font(.caption)
        }
    }

    // MARK: - Sign-up

    private var signUpSection: some View {
        Section {
            TextField("Phone (+84…)", text: $viewModel.signUpPhone)
                .keyboardType(.phonePad)
                .textInputAutocapitalization(.never)
                .disabled(viewModel.isLoading)

            SecureField("Password (≥6)", text: $viewModel.signUpPassword)
                .disabled(viewModel.isLoading)

            actionButton("Request signup code", systemImage: "paperplane",
                         disabled: viewModel.signUpPhone.isEmpty || viewModel.signUpPassword.isEmpty,
                         action: viewModel.requestSignUpCode)

            actionButton("Resend code", systemImage: "arrow.clockwise",
                         disabled: viewModel.signUpPhone.isEmpty,
                         action: viewModel.resendSignUpCode)

            TextField("OTP (6 digits)", text: $viewModel.signUpOtp)
                .keyboardType(.numberPad)
                .disabled(viewModel.isLoading)

            actionButton("Verify signup", systemImage: "checkmark.seal",
                         disabled: viewModel.signUpPhone.isEmpty || viewModel.signUpOtp.isEmpty,
                         action: viewModel.verifySignUpCode)
        } header: {
            Text("1 · Sign-up flow")
        } footer: {
            Text("otpRequestSignUpCode → (otpRequestResendSignUpCode) → otpVerifySignUpCode. Account is created only after Verify succeeds.")
                .font(.caption)
        }
    }

    // MARK: - Login

    private var loginSection: some View {
        Section {
            TextField("Phone (+84…)", text: $viewModel.loginPhone)
                .keyboardType(.phonePad)
                .textInputAutocapitalization(.never)
                .disabled(viewModel.isLoading)

            SecureField("Password", text: $viewModel.loginPassword)
                .disabled(viewModel.isLoading)

            actionButton("Login with phone", systemImage: "person.badge.key",
                         disabled: viewModel.loginPhone.isEmpty || viewModel.loginPassword.isEmpty,
                         action: viewModel.loginWithPhone)
        } header: {
            Text("2 · Login")
        } footer: {
            Text("loginWithPhone. Token is kept internally by the Core (never returned to the app). Not-verified accounts return 2112.")
                .font(.caption)
        }
    }

    // MARK: - Forgot password

    private var forgotSection: some View {
        Section {
            TextField("Phone (+84…)", text: $viewModel.forgotPhone)
                .keyboardType(.phonePad)
                .textInputAutocapitalization(.never)
                .disabled(viewModel.isLoading)

            actionButton("Request forgot code", systemImage: "paperplane",
                         disabled: viewModel.forgotPhone.isEmpty,
                         action: viewModel.requestForgotCode)

            TextField("OTP (6 digits)", text: $viewModel.forgotOtp)
                .keyboardType(.numberPad)
                .disabled(viewModel.isLoading)

            SecureField("New password (≥6)", text: $viewModel.forgotNewPassword)
                .disabled(viewModel.isLoading)

            actionButton("Set new password", systemImage: "key",
                         disabled: viewModel.forgotPhone.isEmpty || viewModel.forgotOtp.isEmpty || viewModel.forgotNewPassword.isEmpty,
                         action: viewModel.setNewPassword)
        } header: {
            Text("3 · Forgot password")
        } footer: {
            Text("otpRequestForgotPwdCode → otpRequestSetNewPwd. The request always reports success even for unregistered numbers. The 'no account' reset case surfaces as error code 400.")
                .font(.caption)
        }
    }

    // MARK: - Result panel

    private var resultSection: some View {
        Section {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                    Text("Calling \(viewModel.lastAction ?? "…")…")
                        .foregroundColor(.secondary)
                }
            }
            if let action = viewModel.lastAction, !viewModel.isLoading {
                HStack {
                    Text("Last call").foregroundColor(.secondary)
                    Spacer()
                    Text(action).font(.system(.body, design: .monospaced))
                }
            }
            if let success = viewModel.successMessage {
                Label(success, systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
            if let code = viewModel.lastErrorCode {
                HStack {
                    Text("errorCode (Int)").foregroundColor(.secondary)
                    Spacer()
                    Text("\(code)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            }
            if viewModel.lastAction != nil {
                Button("Clear result", action: viewModel.clearMessages)
            }
        } header: {
            Text("Result")
        }
    }

    // MARK: - Reusable button

    private func actionButton(_ title: String,
                              systemImage: String,
                              disabled: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disabled(disabled || viewModel.isLoading)
    }
}

#Preview {
    NavigationView { PhoneAuthView() }
}
