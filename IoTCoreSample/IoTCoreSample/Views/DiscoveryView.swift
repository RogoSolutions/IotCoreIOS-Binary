//
//  DiscoveryView.swift
//  IoTCoreSample
//
//  BLE Device Discovery UI
//

import SwiftUI

struct DiscoveryView: View {
    @StateObject private var viewModel = DiscoveryViewModel()
    @State private var sheetState: SheetState?

    enum SheetState: Identifiable {
        case deviceDetail(DiscoveredDevice)
        case deviceConfig(DiscoveredDevice)

        var id: String {
            switch self {
            case .deviceDetail(let device):
                return "detail-\(device.id)"
            case .deviceConfig(let device):
                return "config-\(device.id)"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Scan Controls
                scanControlsSection

                // Error Message
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                // Device List
                if viewModel.filteredDevices.isEmpty {
                    emptyStateView
                } else {
                    deviceListView
                }
            }
            .navigationTitle("Device Discovery")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $sheetState) { state in
                switch state {
                case .deviceDetail(let device):
                    DeviceDetailView(
                        device: device,
                        onAddDevice: {
                            // Transition directly to config sheet
                            sheetState = .deviceConfig(device)
                        }
                    )
                case .deviceConfig(let device):
                    NavigationView {
                        ConfigWifiDeviceTestView(preSelectedDevice: device)
                    }
                }
            }
        }
    }

    // MARK: - Scan Controls

    private var scanControlsSection: some View {
        VStack(spacing: 16) {
            // Scan Button
            if viewModel.isScanning {
                Button(action: viewModel.stopScanning) {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Stop Scanning")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            } else {
                Button(action: viewModel.startScanning) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Start Scanning")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }

            // Stats
            if viewModel.isScanning || !viewModel.discoveredDevices.isEmpty {
                HStack(spacing: 20) {
                    statItem(
                        icon: "antenna.radiowaves.left.and.right",
                        label: "Devices",
                        value: "\(viewModel.filteredDevices.count)/\(viewModel.discoveredDevices.count)"
                    )

                    Divider()
                        .frame(height: 30)

                    if viewModel.isScanning {
                        // Show remaining time when scanning
                        statItem(
                            icon: "timer",
                            label: "Remaining",
                            value: "\(viewModel.remainingScanTime)s"
                        )
                    } else {
                        statItem(
                            icon: "clock",
                            label: "Duration",
                            value: String(format: "%.1fs", viewModel.scanDuration)
                        )
                    }

                    Spacer()

                    if !viewModel.discoveredDevices.isEmpty {
                        Button(action: viewModel.clearResults) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Filter Picker
            if !viewModel.discoveredDevices.isEmpty {
                filterPicker
            }
        }
        .padding()
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DeviceTypeFilter.allCases, id: \.self) { filter in
                    filterButton(filter)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func filterButton(_ filter: DeviceTypeFilter) -> some View {
        let isSelected = viewModel.selectedFilter == filter
        let count: Int = {
            switch filter {
            case .all: return viewModel.discoveredDevices.count
            case .wile: return viewModel.wileDevices.count
            case .mesh: return viewModel.meshDevices.count
            case .unknown: return viewModel.unknownDevices.count
            }
        }()

        return Button {
            viewModel.selectedFilter = filter
        } label: {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text("\(filter.rawValue) (\(count))")
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }

    private func statItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
            Button(action: { viewModel.errorMessage = nil }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.red)
        .transition(.move(edge: .top))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Devices Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap 'Start Scanning' to discover nearby IoT devices")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Device List

    private var deviceListView: some View {
        List {
            ForEach(viewModel.filteredDevices) { device in
                DeviceRow(device: device)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        sheetState = .deviceDetail(device)
                    }
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: DiscoveredDevice

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(device.type.color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: device.type.icon)
                    .font(.title3)
                    .foregroundColor(device.type.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.headline)

                HStack(spacing: 8) {
                    // Type Badge
                    Text(device.type.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(device.type.color.opacity(0.2))
                        .foregroundColor(device.type.color)
                        .cornerRadius(4)

                    // Category Badge
                    if let category = device.categoryName {
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }

                    // MAC
                    if let mac = device.macAddr {
                        Text(mac)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // RSSI Indicator
            VStack(alignment: .trailing, spacing: 4) {
                // Signal Bars
                HStack(spacing: 2) {
                    ForEach(1...4, id: \.self) { bar in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(bar <= device.signalBars ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 4, height: CGFloat(bar * 4))
                    }
                }

                Text("\(device.rssi) dBm")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Device Detail View

struct DeviceDetailView: View {
    let device: DiscoveredDevice
    let onAddDevice: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Device Information") {
                    DetailRow(label: "Name", value: device.displayName)
                    DetailRow(label: "Type", value: device.type.rawValue)
                    if let category = device.categoryName {
                        DetailRow(label: "Category", value: category)
                    }
                    if let mac = device.macAddr {
                        DetailRow(label: "MAC Address", value: mac)
                    }
                    if let productId = device.productId {
                        DetailRow(label: "Product ID", value: productId)
                    }
                }

                Section("Signal") {
                    DetailRow(label: "RSSI", value: "\(device.rssi) dBm")
                    DetailRow(label: "Signal Strength", value: device.signalStrength)
                    DetailRow(label: "Signal Bars", value: String(repeating: "▂", count: device.signalBars) + String(repeating: "▁", count: 4 - device.signalBars))
                }

                Section("Metadata") {
                    DetailRow(label: "Last Seen", value: formatDate(device.lastSeen))
                    if let data = device.advertisementData {
                        DetailRow(label: "Data Size", value: "\(data.count) bytes")
                    }
                }

                Section {
                    Button {
                        // No dismiss() needed - SwiftUI will handle sheet transition
                        onAddDevice()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Configure & Add Device")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Device Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview
//
//#Preview {
//    DiscoveryView()
//}
