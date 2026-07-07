//
//  ConcurrentStateTestViewModel.swift
//  IoTCoreSample
//
//  Harness to reproduce + verify Bug 2: crash when calling getDeviceState
//  (and optionally checkDeviceSoftwareVersion) for many devices concurrently.
//
//  This file lives ONLY in the sample app. It does NOT touch SDK production code.
//  It exercises the PUBLIC SDK API:
//    - IoTAppCore.callApiGetUserDevices(completion:)                         (device list)
//    - deviceCmdHandler.getDeviceState(devId:timeOut:completion:)            (Bug 2 target)
//    - deviceCmdHandler.checkDeviceSoftwareVersion(devId:completion:)        (detail-screen combo)
//
//  Concurrency model:
//    - The harness FIRES calls from many threads simultaneously
//      (DispatchQueue.concurrentPerform) to maximize race pressure on the SDK.
//    - The harness itself is thread-safe: all mutable counters/logs are guarded
//      by an NSLock, and all @Published mutations are hopped to the main thread.
//      The harness never introduces a race of its own — any crash originates in
//      the SDK path under test.
//

import Foundation
import IotCoreIOS
import Combine

final class ConcurrentStateTestViewModel: ObservableObject {

    // MARK: - A single callback log row (UI)

    struct CallbackLine: Identifiable {
        let id = UUID()
        let text: String
    }

    // MARK: - Published (UI) state — mutated on main thread only

    @Published var devices: [IoTDevice] = []
    @Published var isLoadingDevices = false
    @Published var deviceLoadError: String?

    /// Number of stress rounds. Each round fires one concurrent burst across all devices.
    @Published var roundsText: String = "5"
    /// If on, also fires checkDeviceSoftwareVersion concurrently (detail-screen combo).
    @Published var includeFirmwareCheck: Bool = false

    @Published var isRunning = false
    @Published var statusText = "Idle"

    @Published var totalFired = 0
    @Published var completedCount = 0
    @Published var successCount = 0
    @Published var errorCount = 0
    @Published var expectedCount = 0

    /// Set to true when a run completes fully with no crash.
    @Published var passedNoCrash = false

    /// Newest-first callback log for the UI (capped).
    @Published var logLines: [CallbackLine] = []

    // MARK: - Thread-safe internal accumulators (NSLock-guarded)

    private let lock = NSLock()
    private var _total = 0
    private var _completed = 0
    private var _success = 0
    private var _error = 0
    private var _expected = 0

    private let maxUILogLines = 400

    // MARK: - Device List

    func loadDevices() {
        guard let sdk = IoTAppCore.current else {
            deviceLoadError = "SDK not initialized"
            return
        }
        isLoadingDevices = true
        deviceLoadError = nil

        sdk.callApiGetUserDevices(completion: ApiResultClosureAdapter { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoadingDevices = false
                switch result {
                case .success(let response):
                    do {
                        let parsed = try JSONDecoder().decode([IoTDevice].self, from: Data(response.utf8))
                        self.devices = parsed
                        self.statusText = "Loaded \(parsed.count) devices"
                    } catch {
                        self.deviceLoadError = "Parse failed: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    self.deviceLoadError = "Fetch devices failed (code \(error.errorCode)): \(error.message)"
                }
            }
        })
    }

    // MARK: - Stress Run

    /// Fire `rounds` concurrent bursts of getDeviceState (and optionally
    /// checkDeviceSoftwareVersion) across ALL loaded devices.
    func fireConcurrent() {
        guard IoTAppCore.current != nil else {
            statusText = "SDK not initialized"
            return
        }
        let deviceIds = devices.map { $0.id }
        guard !deviceIds.isEmpty else {
            statusText = "No devices to test — load devices first"
            return
        }
        guard !isRunning else { return }

        let rounds = max(1, Int(roundsText.trimmingCharacters(in: .whitespaces)) ?? 1)
        let includeFw = includeFirmwareCheck
        let callsPerDevice = includeFw ? 2 : 1
        let expected = rounds * deviceIds.count * callsPerDevice

        // Reset counters (main thread) + internal accumulators (locked).
        resetCounters(expected: expected)
        isRunning = true
        passedNoCrash = false
        statusText = "Running \(expected) concurrent calls…"
        appendLog("▶️ START rounds=\(rounds) devices=\(deviceIds.count) includeFw=\(includeFw) expected=\(expected)")

        // Fire from a background thread so the main thread stays responsive.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            for round in 0..<rounds {
                // concurrentPerform dispatches iterations across the global pool,
                // so all device calls in a round are FIRED simultaneously — the
                // exact condition that triggers Bug 2.
                DispatchQueue.concurrentPerform(iterations: deviceIds.count) { idx in
                    let devId = deviceIds[idx]
                    self.callGetState(devId: devId, round: round)
                    if includeFw {
                        self.callFirmware(devId: devId, round: round)
                    }
                }
            }
        }
    }

    // MARK: - Individual SDK calls

    private func callGetState(devId: String, round: Int) {
        guard let sdk = IoTAppCore.current else { return }
        bumpTotal()
        sdk.deviceCmdHandler.getDeviceState(
            devId: devId,
            timeOut: 10,
            completion: GetDeviceStateClosureAdapter { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let state):
                    let elements = state.elementStates.keys.sorted()
                    self.record(success: true, kind: "state", devId: devId,
                                detail: "elements=\(elements)")
                case .failure(let code):
                    self.record(success: false, kind: "state", devId: devId,
                                detail: "code=\(code)")
                }
            }
        )
    }

    private func callFirmware(devId: String, round: Int) {
        guard let sdk = IoTAppCore.current else { return }
        bumpTotal()
        sdk.deviceCmdHandler.checkDeviceSoftwareVersion(devId: devId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let info):
                self.record(success: true, kind: "fw", devId: devId,
                            detail: "ver=\(info.softwareVersion)")
            case .failure(let code):
                self.record(success: false, kind: "fw", devId: devId,
                            detail: "code=\(code)")
            }
        }
    }

    // MARK: - Thread-safe recording

    private func bumpTotal() {
        lock.lock(); _total += 1; let t = _total; lock.unlock()
        DispatchQueue.main.async { [weak self] in self?.totalFired = t }
    }

    private func record(success: Bool, kind: String, devId: String, detail: String) {
        lock.lock()
        _completed += 1
        if success { _success += 1 } else { _error += 1 }
        let done = _completed
        let ok = _success
        let err = _error
        let exp = _expected
        lock.unlock()

        let icon = success ? "✅" : "❌"
        let line = "\(icon) [\(kind)] \(shortId(devId)) \(detail)"
        print("[ConcurrentStateTest] \(line) — thread=\(Thread.isMainThread ? "main" : "bg")")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.completedCount = done
            self.successCount = ok
            self.errorCount = err
            self.pushLog(line)
            if done >= exp {
                self.isRunning = false
                self.passedNoCrash = true
                self.statusText = "PASS (no crash) — \(done) callbacks: \(ok) ok / \(err) err"
                self.pushLog("🏁 DONE \(done)/\(exp) → PASS (no crash)")
            }
        }
    }

    // MARK: - Helpers

    private func resetCounters(expected: Int) {
        lock.lock()
        _total = 0; _completed = 0; _success = 0; _error = 0; _expected = expected
        lock.unlock()
        totalFired = 0
        completedCount = 0
        successCount = 0
        errorCount = 0
        expectedCount = expected
        logLines.removeAll()
    }

    func clearLog() {
        logLines.removeAll()
        statusText = "Idle"
        totalFired = 0
        completedCount = 0
        successCount = 0
        errorCount = 0
        expectedCount = 0
        passedNoCrash = false
    }

    /// Append a log line from any thread (hops to main).
    private func appendLog(_ line: String) {
        print("[ConcurrentStateTest] \(line)")
        DispatchQueue.main.async { [weak self] in self?.pushLog(line) }
    }

    /// Must be called on the main thread.
    private func pushLog(_ line: String) {
        logLines.insert(CallbackLine(text: line), at: 0)
        if logLines.count > maxUILogLines {
            logLines.removeLast(logLines.count - maxUILogLines)
        }
    }

    private func shortId(_ id: String) -> String {
        id.count <= 10 ? id : "…" + id.suffix(8)
    }
}
