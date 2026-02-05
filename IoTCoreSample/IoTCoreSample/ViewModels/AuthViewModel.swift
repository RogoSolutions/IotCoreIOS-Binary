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
    case forgotPassword = "Forgot Password"

    var id: String { rawValue }
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

    // Forgot Password fields
    @Published var forgotEmail: String = ""

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
        IoTAppCore.current?.signOut()
        isAuthenticated = false
        successMessage = "Logged out successfully"
        password = ""
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
                    self?.successMessage = "Sign up successful! Please login."
                    self?.authMode = .login
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
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    func requestPasswordReset() {
        // SDK API not yet implemented - show message
        errorMessage = "Password reset is not yet available. SDK API is under development."
    }
}
