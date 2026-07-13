//
//  SampleCallbackAdapters.swift
//  IoTCoreSample
//
//  Closure-based adapters that conform to the SDK's method-based callback
//  protocols (Android parity). They let the sample keep its existing
//  Result-style trailing-closure call-sites while satisfying the new
//  per-call protocol callbacks.
//
//  The SDK holds a STRONG reference to the callback per-call (until a terminal
//  event), so creating a fresh adapter inline at the call-site is sufficient —
//  the sample does not need to retain it.
//

import Foundation
import IotCoreIOS

/// Outcome type mirroring `Result` but whose failure payload is a bare `Int`
/// errorCode. The new SDK callbacks surface failures as an `Int`, not an
/// `Error`, and `Result` requires `Failure: Error`, so this enum keeps the
/// sample's `switch result { case .success(let v): case .failure(let errorCode): }`
/// call-sites working with `errorCode` typed as `Int`.
enum SampleResult<Success> {
    case success(Success)
    case failure(Int)
}

// MARK: - IoTAckMsgCallback

/// Adapts `IoTAckMsgCallback.onAckStatus(status:ackData:)` to a closure where
/// success carries the `status` and failure carries the (failure) status as an
/// error code.
///
/// Success = status is a non-failure ACK (`!= RepliedStatusFailure`).
final class AckClosureAdapter: IoTAckMsgCallback {
    private let handler: (SampleResult<Int>) -> Void

    init(_ handler: @escaping (SampleResult<Int>) -> Void) {
        self.handler = handler
    }

    func onAckStatus(status: Int, ackData: Int) {
        if status == IoTAckStatus.RepliedStatusFailure.rawValue {
            handler(.failure(status))
        } else {
            handler(.success(status))
        }
    }
}

// MARK: - IoTApiResultCallback

/// Adapts `IoTApiResultCallback` to a `Result<String, ApiError>`-style closure
/// (response on success; (errorCode, message) on failure).
final class ApiResultClosureAdapter: IoTApiResultCallback {
    private let handler: (Result<String, ApiError>) -> Void

    struct ApiError: Error {
        let errorCode: Int
        let message: String
    }

    init(_ handler: @escaping (Result<String, ApiError>) -> Void) {
        self.handler = handler
    }

    func onResult(_ response: String) { handler(.success(response)) }
    func onError(errorCode: Int, message: String) {
        handler(.failure(ApiError(errorCode: errorCode, message: message)))
    }
}

// MARK: - IoTGetDeviceStateCallback

/// Adapts `IoTGetDeviceStateCallback` to a closure (State on success;
/// errorCode Int on failure).
final class GetDeviceStateClosureAdapter: IoTGetDeviceStateCallback {
    struct State {
        let deviceId: String
        let elementStates: [Int: [Int: [Int]]]
        let timeOffset: Int64
    }

    private let handler: (SampleResult<State>) -> Void

    init(_ handler: @escaping (SampleResult<State>) -> Void) {
        self.handler = handler
    }

    func onResponseState(deviceId: String,
                         elementStates: [Int: [Int: [Int]]],
                         timeOffset: Int64) {
        handler(.success(State(deviceId: deviceId,
                               elementStates: elementStates,
                               timeOffset: timeOffset)))
    }
    func onError(errorCode: Int) { handler(.failure(errorCode)) }
}

// MARK: - IoTSetDeviceCountdownCallback

/// Adapts `IoTSetDeviceCountdownCallback` to a closure (5-field report on
/// success; errorCode Int on failure).
final class SetDeviceCountdownClosureAdapter: IoTSetDeviceCountdownCallback {
    struct Report {
        let elms: [Int]
        let minutes: Int
        let timeStart: Int64
        let attrStart: [Int]
        let attrStop: [Int]
    }

    private let handler: (SampleResult<Report>) -> Void

    init(_ handler: @escaping (SampleResult<Report>) -> Void) {
        self.handler = handler
    }

    func onSuccess(elms: [Int],
                   minutes: Int,
                   timeStart: Int64,
                   attrStart: [Int],
                   attrStop: [Int]) {
        handler(.success(Report(elms: elms,
                                minutes: minutes,
                                timeStart: timeStart,
                                attrStart: attrStart,
                                attrStop: attrStop)))
    }
    func onError(errorCode: Int) { handler(.failure(errorCode)) }
}

// MARK: - IoTSyncDeviceToCloudCallback

/// Adapts `IoTSyncDeviceToCloudCallback` back to the old `(status, error?)`
/// progress shape used by the sample's onboarding flow.
/// - `onProgress(p)`  -> `(p, nil)`
/// - `onResult(_)`    -> `(100, nil)`
/// - `onError(code,_)`-> `(-1, code)`
final class SyncDeviceToCloudClosureAdapter: IoTSyncDeviceToCloudCallback {
    /// (status, errorCode?) — status 0..99 progress, 100 success, -1 error.
    private let handler: (Int, Int?) -> Void

    init(_ handler: @escaping (Int, Int?) -> Void) {
        self.handler = handler
    }

    func onResult(_ response: String) { handler(100, nil) }
    func onError(errorCode: Int, message: String) { handler(-1, errorCode) }
    func onProgress(_ progress: Int) { handler(progress, nil) }
}

// MARK: - IoTSmartBindTriggerCallback / IoTSmartBindCmdCallback

/// Adapts `IoTSmartBindTriggerCallback` (cfm on success; errorCode on failure).
final class SmartBindTriggerClosureAdapter: IoTSmartBindTriggerCallback {
    private let handler: (SampleResult<Int>) -> Void
    init(_ handler: @escaping (SampleResult<Int>) -> Void) { self.handler = handler }
    func onSuccess(cfm: Int) { handler(.success(cfm)) }
    func onError(errorCode: Int) { handler(.failure(errorCode)) }
}

/// Adapts `IoTSmartBindCmdCallback` (cfm on success; errorCode on failure).
final class SmartBindCmdClosureAdapter: IoTSmartBindCmdCallback {
    private let handler: (SampleResult<Int>) -> Void
    init(_ handler: @escaping (SampleResult<Int>) -> Void) { self.handler = handler }
    func onSuccess(cfm: Int) { handler(.success(cfm)) }
    func onError(errorCode: Int) { handler(.failure(errorCode)) }
}
