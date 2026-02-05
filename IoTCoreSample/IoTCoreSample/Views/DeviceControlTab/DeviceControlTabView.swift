//
//  DeviceControlTabView.swift
//  IoTCoreSample
//
//  Device Control Tab - Device list, detail view, and group control
//

import SwiftUI

struct DeviceControlTabView: View {
    @StateObject private var viewModel = DeviceControlViewModel()
    @State private var showingGroupControl = false
    @State private var expandedGroupIds: Set<String> = []

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Location Tabs
                if !viewModel.locations.isEmpty {
                    locationTabsView
                }

                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if viewModel.devices.isEmpty {
                    emptyStateView
                } else {
                    deviceListView
                }
            }
            .navigationTitle("My Devices")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.fetchDevices()
                        viewModel.fetchLocations()
                        viewModel.fetchGroups()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .sheet(isPresented: $showingGroupControl) {
                GroupControlView(viewModel: viewModel)
            }
            .onAppear {
                if viewModel.devices.isEmpty {
                    viewModel.fetchDevices()
                }
                if viewModel.locations.isEmpty {
                    viewModel.fetchLocations()
                }
                if viewModel.groups.isEmpty {
                    viewModel.fetchGroups()
                }
            }
        }
    }

    // MARK: - Location Tabs View

    private var locationTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" tab
                locationTab(title: "All", locationId: nil)

                // Location tabs
                ForEach(viewModel.locations) { location in
                    locationTab(title: location.displayName, locationId: location.uuid)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func locationTab(title: String, locationId: String?) -> some View {
        let isSelected = viewModel.selectedLocationId == locationId
        let count = viewModel.deviceCount(forLocationId: locationId)

        return Button {
            viewModel.selectLocation(locationId)
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("\(count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading devices...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Error Loading Devices")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                viewModel.fetchDevices()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lightbulb.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Devices Found")
                .font(.headline)

            Text("Add devices through the onboarding flow or pull to refresh.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                viewModel.fetchDevices()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Device List View

    private var deviceListView: some View {
        VStack(spacing: 0) {
            List {
                // Devices grouped by Group/Room
                ForEach(viewModel.devicesByGroup, id: \.groupId) { groupData in
                    Section {
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedGroupIds.contains(groupData.groupId ?? "ungrouped") },
                                set: { isExpanded in
                                    let key = groupData.groupId ?? "ungrouped"
                                    if isExpanded {
                                        expandedGroupIds.insert(key)
                                    } else {
                                        expandedGroupIds.remove(key)
                                    }
                                }
                            )
                        ) {
                            ForEach(groupData.devices) { device in
                                NavigationLink {
                                    DeviceControlDetailView(device: device, viewModel: viewModel)
                                } label: {
                                    DeviceRowView(device: device)
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: groupData.groupId == nil ? "questionmark.folder" : "folder.fill")
                                    .foregroundColor(groupData.groupId == nil ? .secondary : .blue)
                                    .frame(width: 24)

                                Text(groupData.groupName)
                                    .fontWeight(.medium)

                                Spacer()

                                Text("\(groupData.devices.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(10)
                            }
                        }
                    }
                }

                // Group Control Section
                Section {
                    Button {
                        showingGroupControl = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.3.group.fill")
                                .foregroundColor(.purple)
                                .frame(width: 32)

                            Text("Group Control")
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Actions")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .refreshable {
                viewModel.fetchDevices()
                viewModel.fetchGroups()
            }
        }
    }
}

// MARK: - Device Row View

struct DeviceRowView: View {
    let device: IoTDevice

    var body: some View {
        HStack(spacing: 12) {
            // Device Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: device.displayIcon)
                    .font(.title3)
                    .foregroundColor(.blue)
            }

            // Device Info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Product ID Badge
                    if let productId = device.productId {
                        Text(productId.prefix(8) + "...")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }

                    // Device MAC
                    if let mac = device.mac {
                        Text(mac.prefix(12))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Firmware version indicator
            if let firmVer = device.firmVer {
                Text("v\(firmVer)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    DeviceControlTabView()
}
