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

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
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
            }
        }
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
                // Devices Section
                Section {
                    ForEach(viewModel.devices) { device in
                        NavigationLink {
                            DeviceControlDetailView(device: device, viewModel: viewModel)
                        } label: {
                            DeviceRowView(device: device)
                        }
                    }
                } header: {
                    Text("\(viewModel.devices.count) Device\(viewModel.devices.count == 1 ? "" : "s")")
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
