//
//  AuthViewModel.swift
//  IoTCoreSample
//
//  Authentication ViewModel
//

import SwiftUI
import IotCoreIOS
import Combine

@MainActor
class AuthViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // MARK: - Computed Properties

    var canLogin: Bool {
        !email.isEmpty && !password.isEmpty && !isLoading
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

        IoTAppCore.current?.loginWithEmail(
            email: email,
            password: password
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success:
                    self?.isAuthenticated = true
                    self?.successMessage = "Login successful!"
                    self?.password = ""  // Clear password

                case .failure(let error):
                    if case IotCoreError.unauthorized(let reason) = error {
                        self?.errorMessage = "\(reason)"
                    } else {
                        self?.errorMessage = "\(error)"
                    }
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

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
