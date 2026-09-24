//
//  PhoneAuthViewModel.swift
//  IoTCoreSample
//
//  Manual test harness for the phone-number auth (OTP) primitives
//  (Trello 260810-1, phase-26 Y07F4cc0 / Android core 1.0.3.38). Each action
//  calls EXACTLY one Core function so the PO can exercise them individually and
//  read the raw result (success / errorCode Int).
//
//  Notes:
//   - The Core does NOT normalize the phone number; whatever string is typed is
//     passed straight through, so the PO can verify E.164 handling (2103) etc.
//   - Passwordless sign-in, Sign-up and Forgot-password use DIFFERENT OTPs and
//     are kept as separate field groups on purpose.
//   - Uses the phase-26 reason-driven primitives (`otpRequestSendVerifyCode`,
//     `otpRequestSignInByVerifyCode`); the three deprecated functions are not
//     called here.
//

import SwiftUI
import IotCoreIOS
import Combine

@MainActor
final class PhoneAuthViewModel: ObservableObject {

    /// OTP delivery channel picker (`nil` = let the project choose).
    enum ChannelChoice: String, CaseIterable, Identifiable {
        case auto, sms, zalo
        var id: String { rawValue }
        var channel: IoTOtpChannel? {
            switch self {
            case .auto: return nil
            case .sms:  return .sms
            case .zalo: return .zalo
            }
        }
    }

    // MARK: - Passwordless sign-in fields
    @Published var signInPhone: String = "+84"
    @Published var signInOtp: String = ""
    @Published var signInChannel: ChannelChoice = .auto

    // MARK: - Sign-up flow fields
    @Published var signUpPhone: String = "+84"
    @Published var signUpUsername: String = ""
    @Published var signUpPassword: String = ""
    @Published var signUpOtp: String = ""

    // MARK: - Login fields
    @Published var loginPhone: String = "+84"
    @Published var loginPassword: String = ""

    // MARK: - Forgot-password flow fields
    @Published var forgotPhone: String = "+84"
    @Published var forgotOtp: String = ""
    @Published var forgotNewPassword: String = ""

    // MARK: - Shared UI state
    @Published var isLoading = false
    @Published var isAuthenticated = false
    @Published var successMessage: String?
    @Published var errorMessage: String?
    /// Last numeric errorCode returned by the Core (nil on success). Shown raw
    /// so the PO can match it against the spec table (2100–2125, 1101, …).
    @Published var lastErrorCode: Int?
    /// Name of the last invoked function (for the result panel).
    @Published var lastAction: String?

    // MARK: - Init

    init() {
        refreshAuthStatus()
    }

    func refreshAuthStatus() {
        isAuthenticated = IoTAppCore.current?.isAuthenticated ?? false
    }

    func clearMessages() {
        successMessage = nil
        errorMessage = nil
        lastErrorCode = nil
        lastAction = nil
    }

    // MARK: - Passwordless sign-in (phase-26)

    func requestSignInCode() {
        begin("otpRequestSendVerifyCode(.signin)")
        IoTAppCore.current?.otpRequestSendVerifyCode(
            phoneNumber: signInPhone,
            reason: "signin",
            channel: signInChannel.channel
        ) { [weak self] result in
            self?.finish(result, action: "otpRequestSendVerifyCode(.signin)",
                         success: "Sign-in code requested (2122 = wait for cooldown).")
        }
    }

    func verifySignInCode() {
        begin("otpRequestSignInByVerifyCode(.signin)")
        IoTAppCore.current?.otpRequestSignInByVerifyCode(
            phoneNumber: signInPhone,
            otp: signInOtp,
            reason: "signin"
        ) { [weak self] result in
            self?.finish(result, action: "otpRequestSignInByVerifyCode(.signin)",
                         success: "Verified — session established (check Auth status).") { vm in
                vm.signInOtp = ""
                vm.refreshAuthStatus()
            }
        }
    }

    // MARK: - Sign-up flow

    func requestSignUpCode() {
        begin("otpRequestSignUpCode")
        IoTAppCore.current?.otpRequestSignUpCode(
            phoneNumber: signUpPhone,
            username: signUpUsername.isEmpty ? nil : signUpUsername,
            password: signUpPassword
        ) { [weak self] result in
            self?.finish(result, action: "otpRequestSignUpCode",
                         success: "Signup code requested (SMS sent if number valid).")
        }
    }

    func resendSignUpCode() {
        begin("otpRequestSendVerifyCode(.signup)")
        IoTAppCore.current?.otpRequestSendVerifyCode(
            phoneNumber: signUpPhone,
            reason: "signup"
        ) { [weak self] result in
            self?.finish(result, action: "otpRequestSendVerifyCode(.signup)",
                         success: "Resend requested (wait 30s between sends).")
        }
    }

    func verifySignUpCode() {
        begin("otpRequestSignInByVerifyCode(.signup)")
        IoTAppCore.current?.otpRequestSignInByVerifyCode(
            phoneNumber: signUpPhone,
            otp: signUpOtp,
            reason: "signup"
        ) { [weak self] result in
            self?.finish(result, action: "otpRequestSignInByVerifyCode(.signup)",
                         success: "Verified — account created. Session only if the backend returned a token (see Auth status).") { vm in
                vm.refreshAuthStatus()
            }
        }
    }

    // MARK: - Login

    func loginWithPhone() {
        begin("loginWithPhone")
        IoTAppCore.current?.loginWithPhone(
            phoneNumber: loginPhone,
            password: loginPassword
        ) { [weak self] result in
            self?.finish(result, action: "loginWithPhone",
                         success: "Login successful.") { vm in
                vm.loginPassword = ""
                vm.refreshAuthStatus()
            }
        }
    }

    func logout() {
        IoTAppCore.current?.signOut { [weak self] _ in
            DispatchQueue.main.async {
                self?.successMessage = "Logged out."
                self?.errorMessage = nil
                self?.lastErrorCode = nil
                self?.lastAction = "signOut"
                self?.refreshAuthStatus()
            }
        }
    }

    // MARK: - Forgot-password flow

    func requestForgotCode() {
        begin("otpRequestSendVerifyCode(.forgotPassword)")
        IoTAppCore.current?.otpRequestSendVerifyCode(
            phoneNumber: forgotPhone,
            reason: "forgot-password"
        ) { [weak self] result in
            self?.finish(result, action: "otpRequestSendVerifyCode(.forgotPassword)",
                         success: "Forgot-password code requested (always succeeds by design).")
        }
    }

    func setNewPassword() {
        begin("otpRequestSetNewPwd")
        IoTAppCore.current?.otpRequestSetNewPwd(
            phoneNumber: forgotPhone,
            otp: forgotOtp,
            newPassword: forgotNewPassword
        ) { [weak self] result in
            self?.finish(result, action: "otpRequestSetNewPwd",
                         success: "Password changed. Session only if the backend returned a token (see Auth status).") { vm in
                vm.forgotNewPassword = ""
                vm.refreshAuthStatus()
            }
        }
    }

    // MARK: - Helpers

    private func begin(_ action: String) {
        isLoading = true
        successMessage = nil
        errorMessage = nil
        lastErrorCode = nil
        lastAction = action
    }

    /// Central result mapping — always hops to the main queue (parity with
    /// AuthViewModel), records the raw Int errorCode, and runs an optional
    /// success side-effect.
    private func finish(_ result: RequestStatus,
                        action: String,
                        success: String,
                        onSuccess: ((PhoneAuthViewModel) -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            self.lastAction = action
            switch result {
            case .success:
                self.successMessage = success
                self.errorMessage = nil
                self.lastErrorCode = nil
                onSuccess?(self)
            case .failure(let errorCode):
                self.errorMessage = "\(action) failed — error code \(errorCode)"
                self.successMessage = nil
                self.lastErrorCode = errorCode
            }
        }
    }
}
