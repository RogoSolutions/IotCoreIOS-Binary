//
//  MQTTStatusViewModel.swift
//  IoTCoreSample
//
//  ViewModel for displaying MQTT connection status and events.
//  Listens to internal SDK notifications for MQTT state changes.
//

import Foundation
import Combine
import IotCoreIOS

// MARK: - MQTT Event Model

/// Represents a single MQTT event for display in the UI.
struct MQTTEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: MQTTEventType
    let description: String
    let deviceEid: String?

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

/// Type of MQTT event.
enum MQTTEventType: String {
    case connectionStateChange = "Connection"
    case messageReceived = "Message"
    case connectServiceCall = "ConnectService"

    var icon: String {
        switch self {
        case .connectionStateChange:
            return "antenna.radiowaves.left.and.right"
        case .messageReceived:
            return "envelope.fill"
        case .connectServiceCall:
            return "play.circle.fill"
        }
    }
}

// MARK: - ViewModel

@MainActor
class MQTTStatusViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Current MQTT connection state description.
    @Published var connectionState: String = "Unknown"

    /// List of recent MQTT events (newest first).
    @Published var events: [MQTTEvent] = []

    /// Whether MQTT is currently connected.
    @Published var isConnected: Bool = false

    /// Whether the user is authenticated with the SDK.
    @Published var isAuthenticated: Bool = false

    /// Whether connectService is currently being called.
    @Published var isConnecting: Bool = false

    /// Last error message from connectService call.
    @Published var lastError: String?

    /// Whether connectService has been called in this session.
    @Published var connectServiceCalled: Bool = false

    // MARK: - Private Properties

    /// Maximum number of events to keep in the list.
    private let maxEvents = 50

    /// Cancellables for Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    /// Connection status icon name.
    var connectionStatusIcon: String {
        switch connectionState.lowercased() {
        case "ready":
            return "checkmark.circle.fill"
        case "connecting":
            return "arrow.clockwise.circle.fill"
        case "disconnected":
            return "xmark.circle.fill"
        default:
            if connectionState.lowercased().contains("error") {
                return "exclamationmark.triangle.fill"
            }
            return "questionmark.circle.fill"
        }
    }

    /// Connection status color name (for SwiftUI).
    var connectionStatusColorName: String {
        switch connectionState.lowercased() {
        case "ready":
            return "green"
        case "connecting":
            return "yellow"
        case "disconnected":
            return "gray"
        default:
            if connectionState.lowercased().contains("error") {
                return "red"
            }
            return "gray"
        }
    }

    /// Whether there are any events to display.
    var hasEvents: Bool {
        !events.isEmpty
    }

    /// Status explanation text for the user.
    var statusExplanation: String {
        if !isAuthenticated {
            return "Not authenticated. Please log in first, then call connectService()."
        } else if !connectServiceCalled {
            return "Authenticated but connectService() not called. Tap 'Connect Service' to initiate MQTT connection."
        } else if connectionState == "Unknown" {
            return "connectService() was called but MQTT state is unknown. This may indicate:\n- Backend did not return MQTT hosts in appInfo\n- MQTT configuration is missing\n- Connection is still initializing"
        } else if isConnected {
            return "MQTT is connected and ready to receive messages."
        } else {
            return "MQTT state: \(connectionState)"
        }
    }

    /// Whether the connect button should be enabled.
    var canConnect: Bool {
        isAuthenticated && !isConnecting
    }

    // MARK: - Initialization

    init() {
        setupNotificationObservers()
        refreshAuthStatus()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// Clear all events from the list.
    func clearEvents() {
        events.removeAll()
    }

    /// Add a simulated event for testing.
    func addSimulatedConnectionEvent(state: String) {
        let event = MQTTEvent(
            timestamp: Date(),
            type: .connectionStateChange,
            description: "State changed to: \(state)",
            deviceEid: nil
        )
        addEvent(event)
        updateConnectionState(state)
    }

    /// Add a simulated message event for testing.
    func addSimulatedMessageEvent() {
        let deviceEid = "dev_\(UUID().uuidString.prefix(8))"
        let event = MQTTEvent(
            timestamp: Date(),
            type: .messageReceived,
            description: "Device \(deviceEid): cmdType=1",
            deviceEid: deviceEid
        )
        addEvent(event)
    }

    /// Refresh the authentication status from SDK.
    func refreshAuthStatus() {
        isAuthenticated = IoTAppCore.current?.isAuthenticated ?? false
    }

    /// Call connectService() on the SDK to initiate MQTT connection.
    func callConnectService() {
        guard canConnect else {
            lastError = "Cannot connect: \(isAuthenticated ? "already connecting" : "not authenticated")"
            return
        }

        isConnecting = true
        lastError = nil

        // Log the call as an event
        let callEvent = MQTTEvent(
            timestamp: Date(),
            type: .connectServiceCall,
            description: "Calling connectService()...",
            deviceEid: nil
        )
        addEvent(callEvent)

        IoTAppCore.current?.connectService { [weak self] result in
            Task { @MainActor [weak self] in
                self?.isConnecting = false
                self?.connectServiceCalled = true

                switch result {
                case .success(let success):
                    let resultEvent = MQTTEvent(
                        timestamp: Date(),
                        type: .connectServiceCall,
                        description: "connectService() completed: \(success ? "success" : "partial")",
                        deviceEid: nil
                    )
                    self?.addEvent(resultEvent)

                case .failure(let error):
                    self?.lastError = error.localizedDescription
                    let errorEvent = MQTTEvent(
                        timestamp: Date(),
                        type: .connectServiceCall,
                        description: "connectService() failed: \(error.localizedDescription)",
                        deviceEid: nil
                    )
                    self?.addEvent(errorEvent)
                }
            }
        }
    }

    // MARK: - Private Methods

    /// Set up notification observers for MQTT events.
    private func setupNotificationObservers() {
        // Observe connection state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConnectionStateChange(_:)),
            name: Notification.Name("RGBMQTTConnectionStateDidChange"),
            object: nil
        )

        // Observe message received
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMessageReceived(_:)),
            name: Notification.Name("RGBMQTTMessageReceived"),
            object: nil
        )

        print("[MQTTStatus] Notification observers set up")
    }

    @objc private func handleConnectionStateChange(_ notification: Notification) {
        guard let stateString = notification.userInfo?["connectionState"] as? String else {
            return
        }

        Task { @MainActor [weak self] in
            self?.updateConnectionState(stateString)

            let event = MQTTEvent(
                timestamp: Date(),
                type: .connectionStateChange,
                description: "State: \(stateString)",
                deviceEid: nil
            )
            self?.addEvent(event)
        }
    }

    @objc private func handleMessageReceived(_ notification: Notification) {
        let message = notification.userInfo?["message"] as? String ?? "Unknown message"
        let deviceEid = notification.userInfo?["deviceEid"] as? String

        Task { @MainActor [weak self] in
            let event = MQTTEvent(
                timestamp: Date(),
                type: .messageReceived,
                description: message,
                deviceEid: deviceEid
            )
            self?.addEvent(event)
        }
    }

    private func updateConnectionState(_ state: String) {
        connectionState = state
        isConnected = state.lowercased() == "ready"
    }

    private func addEvent(_ event: MQTTEvent) {
        // Insert at the beginning (newest first)
        events.insert(event, at: 0)

        // Limit the number of events
        if events.count > maxEvents {
            events.removeLast()
        }
    }
}
