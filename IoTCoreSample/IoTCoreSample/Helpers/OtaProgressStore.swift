//
//  OtaProgressStore.swift
//  IoTCoreSample
//
//  Global, observable sink for OTA progress NOTIFY events (T-013).
//
//  The SDK fans out device-pushed OTA progress to a single global
//  `IoTAppOtaDeviceCallback` registered via `setOtaDeviceCallback`. The sample
//  registers `SampleOtaDeviceCallback` once (after SDK init) and routes events
//  into this shared store, which SwiftUI views observe to show live progress.
//
//  Callbacks arrive on the MAIN thread (SDK contract), and this store is
//  @MainActor, so no extra synchronization is needed.
//

import Foundation
import Combine
import IotCoreIOS

/// One observed OTA event (most recent per device drives the UI).
struct OtaProgressEvent: Identifiable, Equatable {
    enum Kind: Equatable {
        case progress(status: Int, percent: Int)
        case success(versionCode: [UInt8])
        case failure(versionCode: [UInt8], errorCode: Int)
    }

    let id = UUID()
    let deviceId: String
    let kind: Kind
    let timestamp: Date

    /// Short, human-readable one-liner for logs / banners.
    var summary: String {
        switch kind {
        case .progress(let status, let percent):
            return "OTA \(deviceId): \(percent)% (status \(status))"
        case .success(let versionCode):
            let v = versionCode.map { String($0) }.joined(separator: ".")
            return "OTA \(deviceId): SUCCESS\(versionCode.isEmpty ? "" : " v\(v)")"
        case .failure(let versionCode, let errorCode):
            let v = versionCode.map { String($0) }.joined(separator: ".")
            return "OTA \(deviceId): FAILED (err \(errorCode))\(versionCode.isEmpty ? "" : " v\(v)")"
        }
    }
}

/// Shared, observable OTA progress store. Register `SampleOtaDeviceCallback` once
/// to feed it.
@MainActor
final class OtaProgressStore: ObservableObject {

    static let shared = OtaProgressStore()

    /// Most recent event per deviceId (drives per-device banners).
    @Published private(set) var latestByDevice: [String: OtaProgressEvent] = [:]

    /// Rolling log of recent events (newest first), capped.
    @Published private(set) var log: [OtaProgressEvent] = []

    private let maxLog = 50

    private init() {}

    func record(_ event: OtaProgressEvent) {
        latestByDevice[event.deviceId] = event
        log.insert(event, at: 0)
        if log.count > maxLog {
            log.removeLast(log.count - maxLog)
        }
        print("📦 \(event.summary)")
    }

    /// Latest event for a device, if any.
    func latest(for deviceId: String) -> OtaProgressEvent? {
        latestByDevice[deviceId]
    }
}

/// SDK OTA callback that forwards to the shared store. Held STRONG by the SDK
/// (via `setOtaDeviceCallback`); the sample also keeps a strong reference in
/// `OtaCallbackInstaller` for clarity.
final class SampleOtaDeviceCallback: IoTAppOtaDeviceCallback {

    // The base class is nonisolated; mark this type's members nonisolated and
    // hop to the MainActor store via `Task { @MainActor in ... }`.

    override nonisolated init() { super.init() }

    nonisolated override func onOtaProgress(deviceId: String, status: Int, otaProgressData: Int) {
        Task { @MainActor in
            OtaProgressStore.shared.record(
                OtaProgressEvent(deviceId: deviceId,
                                 kind: .progress(status: status, percent: otaProgressData),
                                 timestamp: Date())
            )
        }
    }

    nonisolated override func onOtaSuccess(deviceId: String, versionCode: [UInt8]) {
        Task { @MainActor in
            OtaProgressStore.shared.record(
                OtaProgressEvent(deviceId: deviceId,
                                 kind: .success(versionCode: versionCode),
                                 timestamp: Date())
            )
        }
    }

    nonisolated override func onOtaFailure(deviceId: String, versionCode: [UInt8], errorCode: Int) {
        Task { @MainActor in
            OtaProgressStore.shared.record(
                OtaProgressEvent(deviceId: deviceId,
                                 kind: .failure(versionCode: versionCode, errorCode: errorCode),
                                 timestamp: Date())
            )
        }
    }
}

/// Installs the OTA callback exactly once per process.
enum OtaCallbackInstaller {
    /// Strong reference to the registered callback (parity with the SDK's own
    /// strong hold; kept here to make ownership explicit).
    private static var callback: SampleOtaDeviceCallback?
    private static var installed = false

    /// Register the global OTA callback on the live SDK instance. Safe to call
    /// multiple times (no-op after the first successful install).
    static func installIfNeeded() {
        guard !installed else { return }
        guard let sdk = IoTAppCore.current else { return }
        let cb = SampleOtaDeviceCallback()
        sdk.setOtaDeviceCallback(cb)
        callback = cb
        installed = true
        print("🔌 OTA device callback registered")
    }
}
