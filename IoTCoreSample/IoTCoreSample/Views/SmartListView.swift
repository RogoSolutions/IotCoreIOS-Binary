//
//  SmartListView.swift
//  IoTCoreSample
//
//  Browse and delete Smart entities for the active location.
//

import SwiftUI
import IotCoreIOS

struct SmartListView: View {
    @StateObject private var viewModel = SmartListViewModel()
    @State private var pendingDelete: SmartItem?
    @State private var showDeleteConfirm: Bool = false
    @State private var showCreateSheet: Bool = false
    @State private var isServiceConnected: Bool = false
    @State private var isConnectingService: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                connectServiceBanner

                filterPicker
                    .padding(.horizontal)
                    .padding(.top, 8)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red)
                }

                if let info = viewModel.lastInfo {
                    Text(info)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                content
            }
            .navigationTitle("Smart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.fetch()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet, onDismiss: {
                viewModel.fetch()
            }) {
                NavigationView {
                    SmartTestView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showCreateSheet = false }
                            }
                        }
                }
            }
            .onAppear {
                if viewModel.allSmarts.isEmpty {
                    viewModel.fetch()
                }
                isServiceConnected = IoTAppCore.current?.isMQTTConnected() ?? false
            }
            .alert("Delete Smart?", isPresented: $showDeleteConfirm, presenting: pendingDelete) { item in
                Button("Delete", role: .destructive) {
                    viewModel.delete(item)
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            } message: { item in
                Text("\(item.displayLabel)\nsmid=\(item.smid.map(String.init) ?? "-")\nuuid=\(item.uuid)")
            }
        }
    }

    // MARK: - Connect Service Banner

    private var connectServiceBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("connectService()")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                Text("Required for MQTT operations (bind/unbind)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Circle()
                .fill(isServiceConnected ? Color.green : Color.gray)
                .frame(width: 10, height: 10)

            if isConnectingService {
                ProgressView()
                    .frame(width: 30)
            }

            Toggle("", isOn: Binding(
                get: { isServiceConnected },
                set: { newValue in
                    if newValue && !isServiceConnected {
                        isConnectingService = true
                        IoTAppCore.current?.connectService { result in
                            Task { @MainActor in
                                isConnectingService = false
                                if case .success = result {
                                    isServiceConnected = true
                                }
                            }
                        }
                    }
                }
            ))
            .labelsHidden()
            .disabled(isServiceConnected || isConnectingService)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isServiceConnected ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
    }

    // MARK: - Filter

    private var filterPicker: some View {
        Picker("Type", selection: Binding(
            get: { viewModel.filter },
            set: { viewModel.filter = $0 }
        )) {
            Text("All").tag(SmartType?.none)
            Text("Scenario").tag(SmartType?.some(.scenario))
            Text("Schedule").tag(SmartType?.some(.schedule))
            Text("Automation").tag(SmartType?.some(.automation))
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.allSmarts.isEmpty {
            VStack {
                Spacer()
                ProgressView("Loading…")
                Spacer()
            }
        } else if viewModel.filteredSmarts.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Smart yet")
                .font(.headline)
                .foregroundColor(.secondary)
            if viewModel.currentLocationId == nil {
                Text("No location selected. Open the Devices tab to pick one.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Text("Pull down to refresh after creating a Smart.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(viewModel.filteredSmarts) { item in
                    NavigationLink {
                        SmartDetailView(smart: item) {
                            viewModel.fetch()
                        }
                    } label: {
                        SmartListRow(item: item)
                    }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDelete = item
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                if let locId = viewModel.currentLocationId {
                    Text("Location \(String(locId.prefix(8)))… — \(viewModel.filteredSmarts.count) item(s)")
                } else {
                    Text("\(viewModel.filteredSmarts.count) item(s)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            viewModel.fetch()
        }
    }
}

// MARK: - Row

private struct SmartListRow: View {
    let item: SmartItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(item.displayLabel)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(item.smartType.badge)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.18))
                    .foregroundColor(badgeColor)
                    .clipShape(Capsule())
            }
            HStack(spacing: 12) {
                if let smid = item.smid {
                    Text("smid=\(smid)")
                }
                Text("uuid=\(item.shortUuid)…")
                Spacer()
                if !item.displayCreatedAt.isEmpty {
                    Text(item.displayCreatedAt)
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var badgeColor: Color {
        switch item.smartType {
        case .scenario:   return .blue
        case .schedule:   return .orange
        case .automation: return .purple
        case .unknown:    return .gray
        }
    }
}

#Preview {
    SmartListView()
}
