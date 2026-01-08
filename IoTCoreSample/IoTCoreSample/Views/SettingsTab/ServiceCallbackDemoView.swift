//
//  ServiceCallbackDemoView.swift
//  IoTCoreSample
//
//  View for demonstrating SDK service callbacks: onCloudEvent, onDeviceStateReport, onDeviceLogAttrReport
//

import SwiftUI

struct ServiceCallbackDemoView: View {
    @StateObject private var viewModel = ServiceCallbackDemoViewModel()
    @State private var showingFilterSheet = false
    @State private var showingSimulateSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Status Header
            statusHeader

            // Filter Bar
            filterBar

            // Event List or Empty State
            if viewModel.hasEvents {
                eventListView
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Service Callbacks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingSimulateSheet = true
                    } label: {
                        Label("Simulate Event", systemImage: "plus.circle")
                    }

                    Button(role: .destructive) {
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
        .onAppear {
            viewModel.startListening()
        }
        .onDisappear {
            viewModel.stopListening()
        }
        .sheet(isPresented: $showingFilterSheet) {
            filterSheet
        }
        .sheet(isPresented: $showingSimulateSheet) {
            simulateSheet
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        VStack(spacing: 8) {
            HStack {
                // Status Indicator
                Circle()
                    .fill(viewModel.isListening ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)

                Text(viewModel.callbackRegistrationStatus)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                // Toggle Button
                Button {
                    if viewModel.isListening {
                        viewModel.stopListening()
                    } else {
                        viewModel.startListening()
                    }
                } label: {
                    Text(viewModel.isListening ? "Stop" : "Start")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Error Message
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
            }

            // Event Counts
            HStack(spacing: 16) {
                ForEach(ServiceCallbackEventType.allCases) { type in
                    eventCountBadge(type: type, count: viewModel.eventCounts[type] ?? 0)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    private func eventCountBadge(type: ServiceCallbackEventType, count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.caption)
                .foregroundColor(colorForType(type))
            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(colorForType(type).opacity(0.15))
        .cornerRadius(8)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All Filter
                filterChip(
                    title: "All",
                    icon: "list.bullet",
                    isSelected: viewModel.selectedFilter == nil
                ) {
                    viewModel.setFilter(nil)
                }

                // Type Filters
                ForEach(ServiceCallbackEventType.allCases) { type in
                    filterChip(
                        title: type.rawValue,
                        icon: type.icon,
                        isSelected: viewModel.selectedFilter == type,
                        color: colorForType(type)
                    ) {
                        viewModel.setFilter(type)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    private func filterChip(
        title: String,
        icon: String,
        isSelected: Bool,
        color: Color = .blue,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isSelected ? color : .secondary)
            .cornerRadius(16)
        }
    }

    // MARK: - Event List View

    private var eventListView: some View {
        List {
            ForEach(viewModel.filteredEvents) { event in
                EventRowView(event: event)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Listening for events...")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Service callback events will appear here when received from the SDK.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if !viewModel.isListening {
                Button {
                    viewModel.startListening()
                } label: {
                    Label("Start Listening", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Filter Sheet

    private var filterSheet: some View {
        NavigationView {
            List {
                Button {
                    viewModel.setFilter(nil)
                    showingFilterSheet = false
                } label: {
                    HStack {
                        Text("All Events")
                        Spacer()
                        if viewModel.selectedFilter == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }

                ForEach(ServiceCallbackEventType.allCases) { type in
                    Button {
                        viewModel.setFilter(type)
                        showingFilterSheet = false
                    } label: {
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(colorForType(type))
                            Text(type.rawValue)
                            Spacer()
                            if viewModel.selectedFilter == type {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingFilterSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Simulate Sheet

    private var simulateSheet: some View {
        NavigationView {
            List {
                Section {
                    ForEach(ServiceCallbackEventType.allCases) { type in
                        Button {
                            viewModel.addSimulatedEvent(type: type)
                            showingSimulateSheet = false
                        } label: {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(colorForType(type))
                                    .frame(width: 24)
                                Text(type.rawValue)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                } header: {
                    Text("Select Event Type")
                } footer: {
                    Text("Simulated events help test the UI without real device connections.")
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
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func colorForType(_ type: ServiceCallbackEventType) -> Color {
        switch type {
        case .cloudEvent:
            return .blue
        case .deviceStateReport:
            return .green
        case .deviceLogAttrReport:
            return .purple
        }
    }
}

// MARK: - Event Row View

struct EventRowView: View {
    let event: ServiceCallbackEvent
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row
            HStack(alignment: .top) {
                // Type Icon
                Image(systemName: event.type.icon)
                    .font(.title3)
                    .foregroundColor(colorForType(event.type))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    // Type and Time
                    HStack {
                        Text(event.type.rawValue)
                            .font(.headline)
                        Spacer()
                        Text(event.formattedTimestamp)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Device ID if available
                    if let deviceId = event.deviceId {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Device: \(deviceId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            // Payload (expandable)
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text("Payload")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Text(event.payload)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = event.payload
                            } label: {
                                Label("Copy Payload", systemImage: "doc.on.doc")
                            }
                        }
                }
            }
            .padding(.leading, 32)
        }
        .padding(.vertical, 8)
    }

    private func colorForType(_ type: ServiceCallbackEventType) -> Color {
        switch type {
        case .cloudEvent:
            return .blue
        case .deviceStateReport:
            return .green
        case .deviceLogAttrReport:
            return .purple
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ServiceCallbackDemoView()
    }
}
