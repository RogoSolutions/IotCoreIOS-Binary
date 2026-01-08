//
//  LocationSelectionView.swift
//  IoTCoreSample
//
//  View for selecting and managing user locations
//

import SwiftUI
import IotCoreIOS

struct LocationSelectionView: View {
    @ObservedObject var viewModel: LocationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Active Location Banner
                if let activeLocation = viewModel.activeLocation {
                    activeLocationBanner(activeLocation)
                }

                // Location List
                locationListContent
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.fetchLocations()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .onAppear {
                if viewModel.locations.isEmpty {
                    viewModel.fetchLocations()
                }
            }
        }
    }

    // MARK: - Active Location Banner

    private func activeLocationBanner(_ location: Location) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Active Location")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(location.displayName)
                    .font(.subheadline.bold())
            }

            Spacer()

            if let meshAddr = location.meshAddress {
                Text("Mesh: \(meshAddr)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
    }

    // MARK: - Location List Content

    @ViewBuilder
    private var locationListContent: some View {
        if viewModel.isLoading {
            loadingView
        } else if let error = viewModel.errorMessage {
            errorView(error)
        } else if viewModel.locations.isEmpty {
            emptyStateView
        } else {
            locationList
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading locations...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Error Loading Locations")
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") {
                viewModel.fetchLocations()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            Text("No Locations Found")
                .font(.headline)

            Text("Create a location in the main app to get started")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Refresh") {
                viewModel.fetchLocations()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var locationList: some View {
        List {
            ForEach(viewModel.locations) { location in
                locationRow(location)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectLocation(location)
                    }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Location Row

    private func locationRow(_ location: Location) -> some View {
        let isActive = viewModel.activeLocation?.uuid == location.uuid

        return HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(isActive ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: isActive ? "checkmark.circle.fill" : "location.fill")
                    .foregroundColor(isActive ? .green : .blue)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(location.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(isActive ? .green : .primary)

                if !location.description.isEmpty {
                    Text(location.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Mesh Info
                HStack(spacing: 8) {
                    if location.meshUuid != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.caption2)
                            Text("BLE Mesh")
                                .font(.caption2)
                        }
                        .foregroundColor(.purple)
                    }

                    if let meshAddr = location.meshAddress {
                        Text("Addr: \(meshAddr)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func selectLocation(_ location: Location) {
        viewModel.setActiveLocation(location)
        dismiss()
    }
}

// MARK: - Compact Location Card (for embedding)

struct ActiveLocationCard: View {
    @ObservedObject var viewModel: LocationViewModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(viewModel.hasActiveLocation ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: viewModel.hasActiveLocation ? "location.fill" : "location.slash")
                        .foregroundColor(viewModel.hasActiveLocation ? .green : .orange)
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.activeLocationDisplayName)
                        .font(.subheadline.bold())
                        .foregroundColor(viewModel.hasActiveLocation ? .primary : .orange)
                }

                Spacer()

                // Mesh indicator
                if let location = viewModel.activeLocation,
                   location.meshUuid != nil {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundColor(.purple)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    LocationSelectionView(viewModel: LocationViewModel())
}
