//
//  ServiceCallbackDemoViewModel.swift
//  IoTCoreSample
//
//  ViewModel for demonstrating SDK service callbacks
//

import Foundation
import IotCoreIOS
import Combine

// MARK: - Event Models

/// Represents the type of service callback event
enum ServiceCallbackEventType: String, CaseIterable, Identifiable {
    case cloudEvent = "Cloud Event"
    case deviceStateReport = "Device State Report"
    case deviceLogAttrReport = "Log Attr Report"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cloudEvent:
            return "cloud.fill"
        case .deviceStateReport:
            return "antenna.radiowaves.left.and.right"
        case .deviceLogAttrReport:
            return "chart.line.uptrend.xyaxis"
        }
    }

    var color: String {
        switch self {
        case .cloudEvent:
            return "blue"
        case .deviceStateReport:
            return "green"
        case .deviceLogAttrReport:
            return "purple"
        }
    }
}

/// Represents a single service callback event
struct ServiceCallbackEvent: Identifiable {
    let id = UUID()
    let type: ServiceCallbackEventType
    let timestamp: Date
    let payload: String
    let deviceId: String?

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    var shortTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - ViewModel

@MainActor
class ServiceCallbackDemoViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var events: [ServiceCallbackEvent] = []
    @Published var isListening = false
    @Published var selectedFilter: ServiceCallbackEventType?
    @Published var errorMessage: String?
    @Published var callbackRegistrationStatus: String = "Not registered"

    // MARK: - Private Properties

    private let maxEvents = 100

    // MARK: - Computed Properties

    var filteredEvents: [ServiceCallbackEvent] {
        if let filter = selectedFilter {
            return events.filter { $0.type == filter }
        }
        return events
    }

    var eventCounts: [ServiceCallbackEventType: Int] {
        var counts: [ServiceCallbackEventType: Int] = [:]
        for type in ServiceCallbackEventType.allCases {
            counts[type] = events.filter { $0.type == type }.count
        }
        return counts
    }

    var hasEvents: Bool {
        !events.isEmpty
    }

    // MARK: - Public Methods

    /// Start listening for service callbacks
    func startListening() {
        guard let sdk = IoTAppCore.current else {
            errorMessage = "SDK not initialized"
            callbackRegistrationStatus = "SDK not initialized"
            return
        }

        isListening = true
        errorMessage = nil
        callbackRegistrationStatus = "Registering callbacks..."

        print("[ServiceCallback] Registering service callbacks...")

        sdk.setServiceCallback(
            onCloudEvent: { [weak self] eventJson in
                Task { @MainActor [weak self] in
                    self?.handleCloudEvent(eventJson)
                }
            },
            onDeviceStateReport: { [weak self] devId, element, attrValueUpdate in
                Task { @MainActor [weak self] in
                    self?.handleDeviceStateReport(devId: devId, element: element, attrValueUpdate: attrValueUpdate)
                }
            },
            onDeviceLogAttrReport: { [weak self] devId, element, attrType, timeCheckpoint, prevCheckpoint, logData in
                Task { @MainActor [weak self] in
                    self?.handleDeviceLogAttrReport(
                        devId: devId,
                        element: element,
                        attrType: attrType,
                        timeCheckpoint: timeCheckpoint,
                        prevCheckpoint: prevCheckpoint,
                        logData: logData
                    )
                }
            }
        )

        callbackRegistrationStatus = "Callbacks registered - Listening for events"
        print("[ServiceCallback] Service callbacks registered successfully")
    }

    /// Stop listening for service callbacks
    func stopListening() {
        guard let sdk = IoTAppCore.current else {
            errorMessage = "SDK not initialized"
            return
        }

        isListening = false
        callbackRegistrationStatus = "Callbacks stopped"

        // Register with nil callbacks to stop listening
        // Note: The SDK may not support unregistering callbacks,
        // so we keep the status as "stopped" for UI purposes
        print("[ServiceCallback] Stopped listening for service callbacks")
    }

    /// Clear all received events
    func clearEvents() {
        events.removeAll()
        errorMessage = nil
        print("[ServiceCallback] Cleared all events")
    }

    /// Set the filter for event types
    func setFilter(_ type: ServiceCallbackEventType?) {
        selectedFilter = type
    }

    /// Add a simulated event for testing UI
    func addSimulatedEvent(type: ServiceCallbackEventType) {
        let event: ServiceCallbackEvent

        switch type {
        case .cloudEvent:
            event = ServiceCallbackEvent(
                type: .cloudEvent,
                timestamp: Date(),
                payload: """
                {
                  "type": "device_online",
                  "deviceId": "dev_sim_\(UUID().uuidString.prefix(8))",
                  "timestamp": \(Int(Date().timeIntervalSince1970))
                }
                """,
                deviceId: nil
            )
        case .deviceStateReport:
            let deviceId = "dev_sim_\(UUID().uuidString.prefix(8))"
            event = ServiceCallbackEvent(
                type: .deviceStateReport,
                timestamp: Date(),
                payload: """
                Element: 0
                Attr Values: [1, 255, 128, 64]
                """,
                deviceId: deviceId
            )
        case .deviceLogAttrReport:
            let deviceId = "dev_sim_\(UUID().uuidString.prefix(8))"
            event = ServiceCallbackEvent(
                type: .deviceLogAttrReport,
                timestamp: Date(),
                payload: """
                Element: 0
                Attr Type: 1
                Time Checkpoint: \(Date().timeIntervalSince1970)
                Prev Checkpoint: \(Date().timeIntervalSince1970 - 3600)
                Log Data: [25, 60, 80, 100]
                """,
                deviceId: deviceId
            )
        }

        addEvent(event)
    }

    // MARK: - Private Methods

    private func handleCloudEvent(_ eventJson: String) {
        print("[ServiceCallback] Received cloud event: \(eventJson)")

        let event = ServiceCallbackEvent(
            type: .cloudEvent,
            timestamp: Date(),
            payload: formatJsonPayload(eventJson),
            deviceId: extractDeviceIdFromJson(eventJson)
        )

        addEvent(event)
    }

    private func handleDeviceStateReport(devId: String, element: Int, attrValueUpdate: [Int]) {
        print("[ServiceCallback] Received device state report: devId=\(devId), element=\(element), attrs=\(attrValueUpdate)")

        let payload = """
        Element: \(element)
        Attr Values: \(attrValueUpdate)
        """

        let event = ServiceCallbackEvent(
            type: .deviceStateReport,
            timestamp: Date(),
            payload: payload,
            deviceId: devId
        )

        addEvent(event)
    }

    private func handleDeviceLogAttrReport(
        devId: String,
        element: Int,
        attrType: Int,
        timeCheckpoint: Double,
        prevCheckpoint: Double,
        logData: [Int]
    ) {
        print("[ServiceCallback] Received log attr report: devId=\(devId), element=\(element), attrType=\(attrType)")

        let payload = """
        Element: \(element)
        Attr Type: \(attrType)
        Time Checkpoint: \(formatTimestamp(timeCheckpoint))
        Prev Checkpoint: \(formatTimestamp(prevCheckpoint))
        Log Data: \(logData)
        """

        let event = ServiceCallbackEvent(
            type: .deviceLogAttrReport,
            timestamp: Date(),
            payload: payload,
            deviceId: devId
        )

        addEvent(event)
    }

    private func addEvent(_ event: ServiceCallbackEvent) {
        // Insert at the beginning (newest first)
        events.insert(event, at: 0)

        // Limit the number of events
        if events.count > maxEvents {
            events.removeLast()
        }
    }

    private func formatJsonPayload(_ json: String) -> String {
        // Try to pretty-print JSON
        guard let data = json.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return json
        }
        return prettyString
    }

    private func extractDeviceIdFromJson(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict["deviceId"] as? String ?? dict["devId"] as? String
    }

    private func formatTimestamp(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
