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

                // Login Section
                if !viewModel.isAuthenticated {
                    loginSection
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
            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .disabled(viewModel.isLoading)

            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .disabled(viewModel.isLoading)

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
            Text("Use your IoT platform credentials to authenticate.")
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
