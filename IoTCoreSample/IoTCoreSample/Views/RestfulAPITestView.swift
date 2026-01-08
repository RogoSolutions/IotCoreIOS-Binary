//
//  RestfulAPITestView.swift
//  IoTCoreSample
//
//  View for testing RESTful APIs
//

import SwiftUI

struct RestfulAPITestView: View {
    @StateObject private var viewModel = RestfulAPITestViewModel()

    @State private var deviceId = ""
    @State private var locationId = ""

    var body: some View {
        List {
            // Predefined APIs Section
            predefinedAPIsSection

            // Get Device Section
            getDeviceSection

            // Get Location Devices Section
            getLocationDevicesSection

            // Custom API Section
            customAPISection

            // Results Section
            resultsSection
        }
        .navigationTitle("RESTful APIs")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
    }

    // MARK: - Predefined APIs Section

    private var predefinedAPIsSection: some View {
        Section {
            Button {
                viewModel.getUserDevices()
            } label: {
                HStack {
                    Image(systemName: "list.bullet")
                    Text("Get User Devices")
                }
            }

            // Product Models with Dev/Prod toggle
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $viewModel.isSupportProductDevelopment) {
                    HStack {
                        Image(systemName: viewModel.isSupportProductDevelopment ? "hammer.fill" : "shippingbox.fill")
                            .foregroundColor(viewModel.isSupportProductDevelopment ? .orange : .blue)
                        Text(viewModel.isSupportProductDevelopment ? "Development" : "Production")
                            .font(.subheadline)
                    }
                }
                .tint(.orange)

                Button {
                    viewModel.getSupportProductModels()
                } label: {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                        Text("Get Product Models")
                        Spacer()
                        Text(viewModel.isSupportProductDevelopment ? "(Dev)" : "(Prod)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Predefined APIs")
        }
    }

    // MARK: - Get Device Section

    private var getDeviceSection: some View {
        Section {
            TextField("Device ID", text: $deviceId)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)

            Button {
                viewModel.getDevice(deviceId: deviceId)
            } label: {
                HStack {
                    Image(systemName: "lightbulb")
                    Text("Get Device")
                }
            }
            .disabled(deviceId.isEmpty)
        } header: {
            Text("Get Device by ID")
        }
    }

    // MARK: - Get Location Devices Section

    private var getLocationDevicesSection: some View {
        Section {
            TextField("Location ID", text: $locationId)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)

            Button {
                viewModel.getLocationDevices(locationId: locationId)
            } label: {
                HStack {
                    Image(systemName: "location")
                    Text("Get Location Devices")
                }
            }
            .disabled(locationId.isEmpty)
        } header: {
            Text("Get Location Devices")
        }
    }

    // MARK: - Custom API Section

    private var customAPISection: some View {
        Section {
            // HTTP Method Picker
            Picker("Method", selection: $viewModel.selectedMethod) {
                ForEach(RestfulAPITestViewModel.HTTPMethod.allCases, id: \.self) { method in
                    Text(method.rawValue).tag(method)
                }
            }

            // Path
            VStack(alignment: .leading, spacing: 4) {
                Text("Path")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("/api/v1/...", text: $viewModel.customPath)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            // Params (JSON)
            VStack(alignment: .leading, spacing: 4) {
                Text("Params (JSON)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $viewModel.customParams)
                    .frame(height: 100)
                    .font(.system(.body, design: .monospaced))
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }

            Button {
                viewModel.callCustomAPI()
            } label: {
                HStack {
                    Image(systemName: "paperplane")
                    Text("Send Request")
                }
            }
        } header: {
            Text("Custom API Call")
        } footer: {
            Text("Enter path and params (JSON format). Leave params empty for GET requests.")
                .font(.caption)
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        Section {
            if let error = viewModel.lastError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.vertical, 4)
            }

            if let result = viewModel.lastResult {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Response")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Copy") {
                            UIPasteboard.general.string = result
                        }
                        .font(.caption)
                    }

                    ScrollView {
                        Text(result)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 300)
                }
            }

            if viewModel.lastError != nil || viewModel.lastResult != nil {
                Button("Clear Results") {
                    viewModel.clearResults()
                }
                .foregroundColor(.orange)
            }
        } header: {
            Text("Results")
        }
    }
}

#Preview {
    NavigationView {
        RestfulAPITestView()
    }
}
