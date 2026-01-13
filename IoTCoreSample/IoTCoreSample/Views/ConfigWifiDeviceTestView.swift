//
//  ConfigWifiDeviceTestView.swift
//  IoTCoreSample
//
//  View for testing Config Wifi Device Handler APIs (BLE onboarding)
//

import SwiftUI
import CoreBluetooth
import IotCoreIOS
// MARK: - Sample Certificates

fileprivate var sampleCertificate: String {
    "MIIFBTCCAu2gAwIBAgIQS6hSk/eaL6JzBkuoBI110DANBgkqhkiG9w0BAQsFADBP\n" +
    "MQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJuZXQgU2VjdXJpdHkgUmVzZWFy\n" +
    "Y2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBYMTAeFw0yNDAzMTMwMDAwMDBa\n" +
    "Fw0yNzAzMTIyMzU5NTlaMDMxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBF\n" +
    "bmNyeXB0MQwwCgYDVQQDEwNSMTAwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK\n" +
    "AoIBAQDPV+XmxFQS7bRH/sknWHZGUCiMHT6I3wWd1bUYKb3dtVq/+vbOo76vACFL\n" +
    "YlpaPAEvxVgD9on/jhFD68G14BQHlo9vH9fnuoE5CXVlt8KvGFs3Jijno/QHK20a\n" +
    "/6tYvJWuQP/py1fEtVt/eA0YYbwX51TGu0mRzW4Y0YCF7qZlNrx06rxQTOr8IfM4\n" +
    "FpOUurDTazgGzRYSespSdcitdrLCnF2YRVxvYXvGLe48E1KGAdlX5jgc3421H5KR\n" +
    "mudKHMxFqHJV8LDmowfs/acbZp4/SItxhHFYyTr6717yW0QrPHTnj7JHwQdqzZq3\n" +
    "DZb3EoEmUVQK7GH29/Xi8orIlQ2NAgMBAAGjgfgwgfUwDgYDVR0PAQH/BAQDAgGG\n" +
    "MB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDATASBgNVHRMBAf8ECDAGAQH/\n" +
    "AgEAMB0GA1UdDgQWBBS7vMNHpeS8qcbDpHIMEI2iNeHI6DAfBgNVHSMEGDAWgBR5\n" +
    "tFnme7bl5AFzgAiIyBpY9umbbjAyBggrBgEFBQcBAQQmMCQwIgYIKwYBBQUHMAKG\n" +
    "Fmh0dHA6Ly94MS5pLmxlbmNyLm9yZy8wEwYDVR0gBAwwCjAIBgZngQwBAgEwJwYD\n" +
    "VR0fBCAwHjAcoBqgGIYWaHR0cDovL3gxLmMubGVuY3Iub3JnLzANBgkqhkiG9w0B\n" +
    "AQsFAAOCAgEAkrHnQTfreZ2B5s3iJeE6IOmQRJWjgVzPw139vaBw1bGWKCIL0vIo\n" +
    "zwzn1OZDjCQiHcFCktEJr59L9MhwTyAWsVrdAfYf+B9haxQnsHKNY67u4s5Lzzfd\n" +
    "u6PUzeetUK29v+PsPmI2cJkxp+iN3epi4hKu9ZzUPSwMqtCceb7qPVxEbpYxY1p9\n" +
    "1n5PJKBLBX9eb9LU6l8zSxPWV7bK3lG4XaMJgnT9x3ies7msFtpKK5bDtotij/l0\n" +
    "GaKeA97pb5uwD9KgWvaFXMIEt8jVTjLEvwRdvCn294GPDF08U8lAkIv7tghluaQh\n" +
    "1QnlE4SEN4LOECj8dsIGJXpGUk3aU3KkJz9icKy+aUgA+2cP21uh6NcDIS3XyfaZ\n" +
    "QjmDQ993ChII8SXWupQZVBiIpcWO4RqZk3lr7Bz5MUCwzDIA359e57SSq5CCkY0N\n" +
    "4B6Vulk7LktfwrdGNVI5BsC9qqxSwSKgRJeZ9wygIaehbHFHFhcBaMDKpiZlBHyz\n" +
    "rsnnlFXCb5s8HKn5LsUgGvB24L7sGNZP2CX7dhHov+YhD+jozLW2p9W4959Bz2Ei\n" +
    "RmqDtmiXLnzqTpXbI+suyCsohKRg6Un0RC47+cpiVwHiXZAW+cn8eiNIjqbVgXLx\n" +
    "KPpdzvvtTnOPlC7SQZSYmdunr3Bf9b77AiC/ZidstK36dRILKz7OA54=\n"
}

struct ConfigWifiDeviceTestView: View {
    @StateObject private var viewModel = ConfigWifiDeviceTestViewModel()
    @StateObject private var discoveryViewModel = DiscoveryViewModel()

    let preSelectedDevice: DiscoveredDevice?

    @State private var showingDeviceSelector = false
    @State private var selectedPeripheral: CBPeripheral?

    @State private var wifiInterfaceNo = "0"
    @State private var wifiScanDuration = "10"
    @State private var selectedSSID = ""
    @State private var wifiPassword = ""

    @State private var deviceLabel = ""
    @State private var deviceDescription = ""

    init(preSelectedDevice: DiscoveredDevice? = nil) {
        self.preSelectedDevice = preSelectedDevice
    }

    var body: some View {
        List {
            // Info Section
            infoSection

            // Connection Section
            connectionSection

            // Device Info Section
            deviceInfoSection

            // Network Connectivity Section
            connectivitySection

            // WiFi Scan Section
            wifiScanSection

            // WiFi Connect Section
            wifiConnectSection

            // Sync to Cloud Section
            syncToCloudSection

            // Device Operations Section
            deviceOperationsSection

            // Results Section
            resultsSection
        }
        .navigationTitle("WiFi Device Config Test")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let device = preSelectedDevice {
                selectedPeripheral = device.peripheral
                deviceLabel = device.displayName
                // Auto-connect when opened from discovery
                viewModel.connect(device: device.device)
            }
        }
        .sheet(isPresented: $showingDeviceSelector) {
            deviceSelectorSheet
        }
        .overlay {
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)

                    if viewModel.syncProgress > 0 && viewModel.syncProgress < 100 {
                        Text("Syncing: \(viewModel.syncProgress)%")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.2))
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Independent Function Testing")
                        .font(.headline)
                }

                Text("Each section below can be tested independently. You don't need to follow a specific order.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if viewModel.isConnected {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Device Connected - All functions available")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 4)
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Connect to device first to test other functions")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Testing Mode")
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        Section {
            if viewModel.isConnected {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Connected to device")
                    Spacer()
                }

                Button {
                    viewModel.disconnect()
                    selectedPeripheral = nil
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Disconnect")
                    }
                    .foregroundColor(.red)
                }
            } else {
                Button {
                    showingDeviceSelector = true
                } label: {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Select Device to Connect")
                    }
                }

                if let peripheral = selectedPeripheral {
                    HStack {
                        Text("Selected:")
                            .foregroundColor(.secondary)
                        Text(peripheral.name ?? "Unknown")
                    }
                }
            }
        } header: {
            Text("1. BLE Connection")
        } footer: {
            Text("Connect to a BLE device via Bluetooth. This is required to access device configuration functions.")
                .font(.caption)
        }
    }

    // MARK: - Device Info Section

    private var deviceInfoSection: some View {
        Section {
            // Display MAC Address (from connect result)
            if let mac = viewModel.deviceMacAddress {
                HStack {
                    Text("MAC Address:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(mac)
                        .fontWeight(.medium)
                }
            }

            // Display Firmware Version (if retrieved)
            if let firmware = viewModel.firmwareVersion {
                HStack {
                    Text("Firmware:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(firmware)
                        .fontWeight(.medium)
                }
            }
        } header: {
            Text("Device Information")
        } footer: {
            Text("View device MAC address and firmware version. MAC is retrieved automatically on connect.")
                .font(.caption)
        }
    }

    // MARK: - Connectivity Section

    private var connectivitySection: some View {
        Section {
            Button {
                viewModel.getNetworkConnectivity()
            } label: {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Get Network Connectivity")
                    Spacer()
                    if viewModel.hasNetworkStatus {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .disabled(!viewModel.isConnected)
        } header: {
            Text("3. Network Status")
        } footer: {
            Text("Get current WiFi and cloud connection status from device. Requires BLE connection.")
                .font(.caption)
        }
    }

    // MARK: - WiFi Scan Section

    private var wifiScanSection: some View {
        Section {
            HStack {
                Text("Interface:")
                    .foregroundColor(.secondary)
                TextField("0", text: $wifiInterfaceNo)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 60)
                    .disabled(!viewModel.isConnected)
            }

            HStack {
                Text("Duration (seconds):")
                    .foregroundColor(.secondary)
                TextField("10", text: $wifiScanDuration)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 60)
                    .disabled(!viewModel.isConnected)
            }

            Button {
                if let infNo = Int(wifiInterfaceNo),
                   let duration = Int(wifiScanDuration) {
                    viewModel.scanWifi(infNo: infNo, seconds: duration)
                }
            } label: {
                HStack {
                    Image(systemName: "wifi")
                    Text("Scan WiFi Networks")
                    Spacer()
                    if !viewModel.scannedNetworks.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .disabled(!viewModel.isConnected)

            if !viewModel.scannedNetworks.isEmpty {
                Text("✅ Found \(viewModel.scannedNetworks.count) network(s)")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        } header: {
            Text("4. WiFi Scan")
        } footer: {
            Text("Scan for available WiFi networks. Device will return list of nearby networks with RSSI and security info.")
                .font(.caption)
        }
    }

    // MARK: - WiFi Connect Section

    private var wifiConnectSection: some View {
        Section {
            if viewModel.scannedNetworks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Or enter manually:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("WiFi SSID", text: $selectedSSID)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disabled(!viewModel.isConnected)
                }
            } else {
                Picker("Select Network", selection: $selectedSSID) {
                    Text("Select...").tag("")
                    ForEach(viewModel.scannedNetworks, id: \.ssid) { network in
                        if let ssid = network.ssid {
                            HStack {
                                Text(ssid)
                                Spacer()
                                Text("\(network.rssi ?? 0) dBm")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(ssid)
                        }
                    }
                }
                .disabled(!viewModel.isConnected)
            }

            SecureField("WiFi Password", text: $wifiPassword)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disabled(!viewModel.isConnected)

            Button {
                if let infNo = Int(wifiInterfaceNo) {
                    viewModel.connectWifi(
                        infNo: infNo,
                        ssid: selectedSSID,
                        password: wifiPassword
                    )
                }
            } label: {
                HStack {
                    Image(systemName: "wifi.circle.fill")
                    Text("Connect to WiFi")
                    Spacer()
                    if viewModel.isWifiConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .disabled(!viewModel.isConnected || selectedSSID.isEmpty)
        } header: {
            Text("5. WiFi Connection")
        } footer: {
            Text("Connect device to WiFi network. You can scan for networks first or enter SSID manually.")
                .font(.caption)
        }
    }

    // MARK: - Sync to Cloud Section

    private var syncToCloudSection: some View {
        Section {
            TextField("Device Label", text: $deviceLabel)
                .textFieldStyle(.roundedBorder)
                .placeholder(when: deviceLabel.isEmpty) {
                    Text("My Smart Light")
                        .foregroundColor(.gray)
                }
                .disabled(!viewModel.isConnected)

            TextField("Description (optional)", text: $deviceDescription)
                .textFieldStyle(.roundedBorder)
                .disabled(!viewModel.isConnected)

            Button {
                viewModel.syncDeviceToCloud(
                    label: deviceLabel,
                    desc: deviceDescription.isEmpty ? nil : deviceDescription
                )
            } label: {
                HStack {
                    Image(systemName: "cloud.fill")
                    Text("Sync to Cloud")
                    Spacer()
                    if viewModel.completedSteps.contains(.syncCloud) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .disabled(!viewModel.isConnected || deviceLabel.isEmpty)

            if viewModel.syncProgress > 0 && viewModel.syncProgress < 100 {
                HStack {
                    ProgressView(value: Double(viewModel.syncProgress), total: 100)
                    Text("\(viewModel.syncProgress)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("6. Cloud Registration")
        } footer: {
            Text("Register the device with cloud backend. Typically done after WiFi connection is successful.")
                .font(.caption)
        }
    }

    // MARK: - Device Operations Section

    private var deviceOperationsSection: some View {
        Section {
            // Device Identify Button
            Button {
                viewModel.requestDeviceIdentify()
            } label: {
                HStack {
                    Image(systemName: "lightbulb.fill")
                    Text("Device Identify")
                    Spacer()
                }
            }
            .disabled(!viewModel.isConnected)

            // HTTPS Certificate
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    viewModel.sendHttpsCertificate(sampleCertificate)
                } label: {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                        Text("Send HTTPS Certificate")
                        Spacer()
                    }
                }
                .disabled(!viewModel.isConnected)

                Text("Sends sample HTTPS cert (\(sampleCertificate.count) bytes)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // MQTT Certificate
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    viewModel.sendMqttCertificate(sampleCertificate)
                } label: {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                        Text("Send MQTT Certificate")
                        Spacer()
                    }
                }
                .disabled(!viewModel.isConnected)

                Text("Sends sample MQTT cert (\(sampleCertificate.count) bytes)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

        } header: {
            Text("7. Device Operations (Testing)")
        } footer: {
            Text("Test certificate transfer and device control operations. These send sample/test data to the device.")
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

    // MARK: - Device Selector Sheet

    private var deviceSelectorSheet: some View {
        NavigationView {
            List {
                Section {
                    if discoveryViewModel.isScanning {
                        HStack {
                            ProgressView()
                            Text("Scanning...")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button {
                            discoveryViewModel.startScanning()
                        } label: {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Start Scanning")
                            }
                        }
                    }
                } header: {
                    Text("BLE Scanning")
                }

                Section {
                    if discoveryViewModel.discoveredDevices.isEmpty {
                        Text("No devices found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(discoveryViewModel.discoveredDevices, id: \.macAddr) { device in
                            Button {
                                selectDevice(device)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(device.macAddr ?? "Unknown")
                                        .font(.headline)

                                    HStack {
                                        if let productId = device.productId {
                                            Text("Product: \(productId)")
                                                .font(.caption)
                                        }

                                        Text("• \(device.rssi) dBm")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Wile Devices (\(discoveryViewModel.discoveredDevices.count))")
                }
            }
            .navigationTitle("Select Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        discoveryViewModel.stopScanning()
                        showingDeviceSelector = false
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func selectDevice(_ device: DiscoveredDevice) {
        selectedPeripheral = device.peripheral
        discoveryViewModel.stopScanning()
        showingDeviceSelector = false

        // Connect to the selected device
        viewModel.connect(device: device.device)
    }
}

//#Preview {
//    NavigationView {
//        ConfigWifiDeviceTestView()
//    }
//}
