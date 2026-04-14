//
//  RestfulAPITestViewModel.swift
//  IoTCoreSample
//
//  ViewModel for testing RESTful APIs
//

import Foundation
import IotCoreIOS
import Combine

@MainActor
class RestfulAPITestViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var lastResult: String?
    @Published var lastError: String?

    @Published var customPath: String = "/api/v1/devices"
    @Published var customParams: String = ""
    @Published var selectedMethod: HTTPMethod = .get
    @Published var isSupportProductDevelopment: Bool = false

    enum HTTPMethod: String, CaseIterable {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case update = "UPDATE"
        case delete = "DELETE"
    }

    // MARK: - Predefined API Tests

    func getUserDevices() {
        guard let sdk = IoTAppCore.current else {
            showError("SDK not initialized")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil

        print("📡 Calling getUserDevices...")

        sdk.callApiGetUserDevices { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let data):
                    self.handleSuccess(data, apiName: "getUserDevices")

                case .failure(let error):
                    self.handleError(error, apiName: "getUserDevices")
                }
            }
        }
    }

    func getSupportProductModels() {
        guard let sdk = IoTAppCore.current else {
            showError("SDK not initialized")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil

        let isDev = isSupportProductDevelopment
        print("📡 Calling getSupportProductModel (isDev: \(isDev))...")

        sdk.callApiGetSupportProductModel(isSupportProductDevelopment: isDev) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let data):
                    self.handleSuccess(data, apiName: "getSupportProductModel")

                case .failure(let error):
                    self.handleError(error, apiName: "getSupportProductModel")
                }
            }
        }
    }

    func getLocationDevices(locationId: String) {
        guard let sdk = IoTAppCore.current else {
            showError("SDK not initialized")
            return
        }

        guard !locationId.isEmpty else {
            showError("Location ID is required")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil

        print("📡 Calling getLocationDevices with locationId: \(locationId)")

        sdk.callApiGetLocationDevices(locationId: locationId) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let data):
                    self.handleSuccess(data, apiName: "getLocationDevices")

                case .failure(let error):
                    self.handleError(error, apiName: "getLocationDevices")
                }
            }
        }
    }

    func getDevice(deviceId: String) {
        guard let sdk = IoTAppCore.current else {
            showError("SDK not initialized")
            return
        }

        guard !deviceId.isEmpty else {
            showError("Device ID is required")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil

        print("📡 Calling getDevice with deviceId: \(deviceId)")

        sdk.callApiGetDevice(deviceId: deviceId) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let data):
                    self.handleSuccess(data, apiName: "getDevice")

                case .failure(let error):
                    self.handleError(error, apiName: "getDevice")
                }
            }
        }
    }

    // MARK: - Custom API Call

    func callCustomAPI() {
        guard let sdk = IoTAppCore.current else {
            showError("SDK not initialized")
            return
        }

        isLoading = true
        lastError = nil
        lastResult = nil

        // Parse params
        var params: [String: Any]? = nil
        if !customParams.isEmpty {
            if let data = customParams.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                params = json
            } else {
                showError("Invalid JSON parameters")
                isLoading = false
                return
            }
        }

        print("📡 Calling custom API: \(selectedMethod.rawValue) \(customPath)")
        print("   Params: \(params ?? [:])")

        let completion: IoTApiResultCallback = { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let data):
                    self.handleSuccess(data, apiName: "Custom API")

                case .failure(let error):
                    self.handleError(error, apiName: "Custom API")
                }
            }
        }

        switch selectedMethod {
        case .get:
            sdk.callApiGet(customPath, params: params, headers: nil, completion: completion)
        case .post:
            sdk.callApiPost(customPath, params: params, headers: nil, completion: completion)
        case .patch:
            sdk.callApiPatch(customPath, params: params, headers: nil, completion: completion)
        case .update:
            sdk.callApiUpdate(customPath, params: params, headers: nil, completion: completion)
        case .delete:
            sdk.callApiDelete(customPath, params: params, headers: nil, completion: completion)
        }
    }

    // MARK: - Private Helpers

    private func handleSuccess(_ data: Data, apiName: String) {
        print("✅ \(apiName) success: \(data.count) bytes")

        // Try to parse as JSON for pretty printing
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            lastResult = prettyString
        } else if let string = String(data: data, encoding: .utf8) {
            lastResult = string
        } else {
            lastResult = "Binary data: \(data.count) bytes"
        }
    }

    private func handleError(_ error: Error, apiName: String) {
        print("❌ \(apiName) error: \(error.localizedDescription)")
        showError("\(apiName) failed: \(error.localizedDescription)")
    }

    private func showError(_ message: String) {
        lastError = message
    }

    func clearResults() {
        lastResult = nil
        lastError = nil
    }
}
