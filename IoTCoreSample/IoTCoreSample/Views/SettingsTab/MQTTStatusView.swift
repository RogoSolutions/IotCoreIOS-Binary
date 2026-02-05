//
//  MQTTStatusView.swift
//  IoTCoreSample
//
//  View for displaying MQTT connection status and recent events.
//  Accessible from Settings -> Developer Tools -> MQTT Status.
//

import SwiftUI

struct MQTTStatusView: View {
    @StateObject private var viewModel = MQTTStatusViewModel()
    @State private var showingSimulateSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Connection Status Header
            connectionStatusHeader

            // Debug Info Section
            debugInfoSection

            // Event List or Empty State
            if viewModel.hasEvents {
                eventListView
            } else {
                emptyStateView
            }
        }
        .navigationTitle("MQTT Status")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        viewModel.refreshAuthStatus()
                    } label: {
                        Label("Refresh Status", systemImage: "arrow.clockwise")
                    }

                    Button {
                        showingSimulateSheet = true
                    } label: {
                        Label("Simulate Event", systemImage: "plus.circle")
                    }

                    Button {
                        viewModel.clearEvents()
                    } label: {
                        Label("Clear Events", systemImage: "trash")
                    }
                    .disabled(!viewModel.hasEvents)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingSimulateSheet) {
            simulateSheet
        }
        .onAppear {
            viewModel.refreshAuthStatus()
        }
    }

    // MARK: - Connection Status Header

    private var connectionStatusHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Status Icon
                Image(systemName: viewModel.connectionStatusIcon)
                    .font(.system(size: 32))
                    .foregroundColor(connectionStatusColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("MQTT Connection")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(viewModel.connectionState)
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                Spacer()

                // Connect Service Button
                Button {
                    viewModel.callConnectService()
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(viewModel.isConnecting ? "Connecting..." : "Connect")
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(viewModel.canConnect ? Color.blue : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!viewModel.canConnect)
            }

            // Status Explanation Text
            HStack(alignment: .top) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(viewModel.statusExplanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }

            // Error message if any
            if let error = viewModel.lastError {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)

                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    private var connectionStatusColor: Color {
        switch viewModel.connectionStatusColorName {
        case "green":
            return .green
        case "yellow":
            return .yellow
        case "red":
            return .red
        default:
            return .gray
        }
    }

    // MARK: - Debug Info Section

    private var debugInfoSection: some View {
        VStack(spacing: 0) {
            // Auth Status Row
            HStack {
                Image(systemName: viewModel.isAuthenticated ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle.badge.xmark")
                    .font(.body)
                    .foregroundColor(viewModel.isAuthenticated ? .green : .orange)
                    .frame(width: 24)

                Text("Authentication")
                    .font(.subheadline)

                Spacer()

                Text(viewModel.isAuthenticated ? "Logged In" : "Not Logged In")
                    .font(.subheadline)
                    .foregroundColor(viewModel.isAuthenticated ? .green : .orange)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()
                .padding(.leading, 48)

            // ConnectService Called Row
            HStack {
                Image(systemName: viewModel.connectServiceCalled ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundColor(viewModel.connectServiceCalled ? .green : .gray)
                    .frame(width: 24)

                Text("connectService() Called")
                    .font(.subheadline)

                Spacer()

                Text(viewModel.connectServiceCalled ? "Yes" : "No")
                    .font(.subheadline)
                    .foregroundColor(viewModel.connectServiceCalled ? .green : .secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()
                .padding(.leading, 48)

            // MQTT State Row
            HStack {
                Image(systemName: viewModel.connectionStatusIcon)
                    .font(.body)
                    .foregroundColor(connectionStatusColor)
                    .frame(width: 24)

                Text("MQTT State")
                    .font(.subheadline)

                Spacer()

                Text(viewModel.connectionState)
                    .font(.subheadline)
                    .foregroundColor(connectionStatusColor)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Event List View

    private var eventListView: some View {
        List {
            Section {
                ForEach(viewModel.events) { event in
                    MQTTEventRow(event: event)
                }
            } header: {
                HStack {
                    Text("Recent Events")
                    Spacer()
                    Text("\(viewModel.events.count) events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No MQTT Events")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Text("To test MQTT connection:")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 8) {
                    Label("1. Log in to the app", systemImage: viewModel.isAuthenticated ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundColor(viewModel.isAuthenticated ? .green : .secondary)

                    Label("2. Tap 'Connect' button above", systemImage: viewModel.connectServiceCalled ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundColor(viewModel.connectServiceCalled ? .green : .secondary)

                    Label("3. If backend has MQTT hosts, connection will establish", systemImage: "circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("Note: If your backend does not return rgbMqttHosts in appInfo, MQTT will not connect and the state will remain 'Unknown'.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Simulate Sheet

    private var simulateSheet: some View {
        NavigationView {
            List {
                Section {
                    Button {
                        viewModel.addSimulatedConnectionEvent(state: "Ready")
                        showingSimulateSheet = false
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text("Connected (Ready)")
                                .foregroundColor(.primary)
                        }
                    }

                    Button {
                        viewModel.addSimulatedConnectionEvent(state: "Connecting")
                        showingSimulateSheet = false
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 24)
                            Text("Connecting")
                                .foregroundColor(.primary)
                        }
                    }

                    Button {
                        viewModel.addSimulatedConnectionEvent(state: "Disconnected")
                        showingSimulateSheet = false
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            Text("Disconnected")
                                .foregroundColor(.primary)
                        }
                    }
                } header: {
                    Text("Connection State Events")
                }

                Section {
                    Button {
                        viewModel.addSimulatedMessageEvent()
                        showingSimulateSheet = false
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Device Message")
                                .foregroundColor(.primary)
                        }
                    }
                } header: {
                    Text("Message Events")
                } footer: {
                    Text("Simulated events help test the UI without real MQTT connections.")
                        .font(.caption)
                }
            }
            .navigationTitle("Simulate Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingSimulateSheet = false
                    }
                }
            }
        }
    }
}

// MARK: - MQTT Event Row

struct MQTTEventRow: View {
    let event: MQTTEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Event Type Icon
            Image(systemName: event.type.icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                // Timestamp and Type
                HStack {
                    Text(event.type.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text(event.formattedTimestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Description
                Text(event.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Device EID if available
                if let deviceEid = event.deviceEid {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(deviceEid)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        switch event.type {
        case .connectionStateChange:
            return .orange
        case .messageReceived:
            return .blue
        case .connectServiceCall:
            return .purple
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        MQTTStatusView()
    }
}
