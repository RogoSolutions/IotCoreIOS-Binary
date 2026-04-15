//
//  AuthViewModel.swift
//  IoTCoreSample
//
//  Authentication ViewModel
//

import SwiftUI
import IotCoreIOS
import Combine

/// Authentication mode for switching between Login, Sign Up, and Forgot Password
enum AuthMode: String, CaseIterable, Identifiable {
    case login = "Login"
    case signUp = "Sign Up"
    case verifyEmail = "Verify"
    case forgotPassword = "Forgot"

    var id: String { rawValue }
}

/// Step in the forgot password flow
enum ForgotPasswordStep {
    case enterEmail
    case enterCode
}

/// Step in the sign up flow
enum SignUpStep {
    case fillForm
    case verifyEmail
}

/// Login type for switching between Email, Username, and Token login
enum LoginType: String, CaseIterable, Identifiable {
    case email = "Email"
    case username = "Username"
    case token = "Token"

    var id: String { rawValue }
}

@MainActor
class AuthViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var authMode: AuthMode = .login
    @Published var loginType: LoginType = .email
    @Published var email = ""
    @Published var username = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Token login field
    @Published var customToken: String = ""

    // Sign Up fields
    @Published var signUpEmail: String = ""
    @Published var signUpUsername: String = ""
    @Published var signUpPhone: String = ""
    @Published var signUpPassword: String = ""
    @Published var signUpConfirmPassword: String = ""
    @Published var signUpStep: SignUpStep = .fillForm
    @Published var signUpVerifyCode: String = ""

    // Verify Email fields
    @Published var verifyEmailCode: String = ""

    // Forgot Password fields
    @Published var forgotEmail: String = ""
    @Published var forgotPasswordStep: ForgotPasswordStep = .enterEmail
    @Published var verifyCode: String = ""
    @Published var newPassword: String = ""
    @Published var confirmNewPassword: String = ""

    // MARK: - Computed Properties

    var canLogin: Bool {
        switch loginType {
        case .email:
            return !email.isEmpty && !password.isEmpty && !isLoading
        case .username:
            return !username.isEmpty && !password.isEmpty && !isLoading
        case .token:
            return !customToken.isEmpty && !isLoading
        }
    }

    var canSignUp: Bool {
        !signUpEmail.isEmpty && !signUpPassword.isEmpty &&
        signUpPassword == signUpConfirmPassword && !isLoading
    }

    var statusMessage: String {
        if isAuthenticated {
            return "✅ Logged In"
        } else {
            return "🔒 Not Logged In"
        }
    }

    // MARK: - Initialization

    init() {
        checkAuthStatus()
    }

    // MARK: - Actions

    func checkAuthStatus() {
        isAuthenticated = IoTAppCore.current?.isAuthenticated ?? false
    }

    func login() {
        guard canLogin else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        switch loginType {
        case .email:
            IoTAppCore.current?.loginWithEmail(
                email: email,
                password: password
            ) { [weak self] result in
                self?.handleLoginResult(result)
            }
        case .username:
            IoTAppCore.current?.loginWithUsername(
                username: username,
                password: password
            ) { [weak self] result in
                self?.handleLoginResult(result)
            }
        case .token:
            IoTAppCore.current?.loginWithToken(
                loginToken: customToken
            ) { [weak self] result in
                self?.handleLoginResult(result)
            }
        }
    }

    private func handleLoginResult(_ result: Result<Void, Error>) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false

            switch result {
            case .success:
                self?.isAuthenticated = true
                self?.successMessage = "Login successful!"
                self?.password = ""  // Clear password

            case .failure(let error):
                if let iotError = error as? IotCoreError,
                   case IotCoreError.unauthorized(let reason) = iotError {
                    self?.errorMessage = "\(reason)"
                } else {
                    self?.errorMessage = "\(error)"
                }
            }
        }
    }

    func logout() {
        IoTAppCore.current?.signOut { [weak self] _ in
            self?.isAuthenticated = false
            self?.successMessage = "Logged out successfully"
            self?.password = ""
        }
    }

    func signUp() {
        guard canSignUp else { return }
        guard signUpPassword == signUpConfirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        IoTAppCore.current?.signUp(
            email: signUpEmail,
            username: signUpUsername.isEmpty ? nil : signUpUsername,
            phoneNumber: signUpPhone.isEmpty ? nil : signUpPhone,
            password: signUpPassword
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.successMessage = "Sign up successful! Check your email for verification code."
                    self?.signUpStep = .verifyEmail
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func verifySignUpEmail() {
        guard !signUpVerifyCode.isEmpty else {
            errorMessage = "Please enter verification code"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        IoTAppCore.current?.updatePasswordOrVerifyAccount(otp: signUpVerifyCode, pwd: nil) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.successMessage = "Email verified! You can now login."
                    self?.authMode = .login
                    self?.signUpStep = .fillForm
                    self?.clearSignUpFields()
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func clearSignUpFields() {
        signUpEmail = ""
        signUpUsername = ""
        signUpPhone = ""
        signUpPassword = ""
        signUpConfirmPassword = ""
        signUpVerifyCode = ""
    }

    func verifyEmail() {
        guard !verifyEmailCode.isEmpty else {
            errorMessage = "Please enter verification code"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        IoTAppCore.current?.updatePasswordOrVerifyAccount(otp: verifyEmailCode, pwd: nil) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.successMessage = "Email verified! You can now login."
                    self?.authMode = .login
                    self?.verifyEmailCode = ""
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    func requestPasswordReset() {
        guard !forgotEmail.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        isLoading = true
        errorMessage = nil
        successMessage = nil

        IoTAppCore.current?.forgotPassword(email: forgotEmail) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.successMessage = "Verification code sent to your email."
                    self?.forgotPasswordStep = .enterCode
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func resetPassword() {
        guard !verifyCode.isEmpty else {
            errorMessage = "Please enter verification code"
            return
        }
        guard !newPassword.isEmpty else {
            errorMessage = "Please enter new password"
            return
        }
        guard newPassword == confirmNewPassword else {
            errorMessage = "Passwords do not match"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        IoTAppCore.current?.updatePasswordOrVerifyAccount(otp: verifyCode, pwd: newPassword) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.successMessage = "Password reset successful! Please login with your new password."
                    self?.authMode = .login
                    self?.forgotPasswordStep = .enterEmail
                    self?.clearForgotPasswordFields()
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func clearForgotPasswordFields() {
        forgotEmail = ""
        verifyCode = ""
        newPassword = ""
        confirmNewPassword = ""
    }
}
