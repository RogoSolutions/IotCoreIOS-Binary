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
    /// Raw query-string appended to the URL, e.g. "a=1&b=2"
    @Published var customUrlParam: String = ""
    /// Raw request body sent verbatim (POST/PATCH/UPDATE/DELETE), e.g. a JSON string
    @Published var customBody: String = ""
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

        sdk.callApiGetUserDevices(completion: ApiResultClosureAdapter { [weak self] result in
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
        })
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

        sdk.callApiGetSupportProductModel(isSupportProductDevelopment: isDev, completion: ApiResultClosureAdapter { [weak self] result in
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
        })
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

        sdk.callApiGetLocationDevices(locationId: locationId, completion: ApiResultClosureAdapter { [weak self] result in
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
        })
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

        sdk.callApiGetDevice(deviceId: deviceId, completion: ApiResultClosureAdapter { [weak self] result in
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
        })
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

        // Raw query-string + raw body (Android-parity, String-based)
        let urlParam: String? = customUrlParam.isEmpty ? nil : customUrlParam
        let body: String? = customBody.isEmpty ? nil : customBody

        print("📡 Calling custom API: \(selectedMethod.rawValue) \(customPath)")
        print("   urlParam: \(urlParam ?? "<none>")")
        print("   body: \(body ?? "<none>")")

        // Protocol callbacks are per-call objects, so build a fresh adapter for
        // each method via this closure body.
        let onResult: (Result<String, ApiResultClosureAdapter.ApiError>) -> Void = { [weak self] result in
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
            sdk.callApiGet(customPath, urlParam: urlParam, headers: nil, completion: ApiResultClosureAdapter(onResult))
        case .post:
            sdk.callApiPost(customPath, urlParam: urlParam, headers: nil, body: body, completion: ApiResultClosureAdapter(onResult))
        case .patch:
            sdk.callApiPatch(customPath, urlParam: urlParam, headers: nil, body: body, completion: ApiResultClosureAdapter(onResult))
        case .update:
            sdk.callApiUpdate(customPath, urlParam: urlParam, headers: nil, body: body, completion: ApiResultClosureAdapter(onResult))
        case .delete:
            sdk.callApiDelete(customPath, urlParam: urlParam, headers: nil, body: body, completion: ApiResultClosureAdapter(onResult))
        }
    }

    // MARK: - Private Helpers

    private func handleSuccess(_ response: String, apiName: String) {
        print("✅ \(apiName) success: \(response.count) chars")

        // Try to parse as JSON for pretty printing
        let data = Data(response.utf8)
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            lastResult = prettyString
        } else {
            lastResult = response
        }
    }

    private func handleError(_ error: ApiResultClosureAdapter.ApiError, apiName: String) {
        print("❌ \(apiName) error: code=\(error.errorCode) \(error.message)")
        showError("\(apiName) failed (code \(error.errorCode)): \(error.message)")
    }

    private func showError(_ message: String) {
        lastError = message
    }

    func clearResults() {
        lastResult = nil
        lastError = nil
    }
}
