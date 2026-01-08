# IoTCoreSample

Sample application demonstrating the IotCoreIOS SDK integration.

## Requirements

- iOS 13.0+
- Xcode 14.0+
- IotCoreIOS SDK (included via Swift Package Manager)

## Setup

### 1. Configure Credentials

The app requires valid SDK credentials to function. You can provide them in two ways:

#### Option A: Environment Variables (Recommended for development/CI)

```bash
export IOTCORE_APP_KEY="your_app_key"
export IOTCORE_APP_SECRET="your_app_secret"
```

Then run the app from Xcode or command line.

#### Option B: In-App Configuration

1. Launch the app
2. Go to Settings tab
3. Enter your App Key and App Secret
4. Save configuration

### 2. Build and Run

```bash
# Open the project
open IoTCoreSample.xcodeproj

# Or build from command line
xcodebuild build -scheme IoTCoreSample -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Features Demonstrated

- **Device Discovery**: BLE scanning for IoT devices
- **WiFi Provisioning**: Configure device WiFi credentials
- **Device Control**: Send commands to connected devices
- **Onboarding Flow**: Complete device setup workflow

## Project Structure

```
IoTCoreSample/
├── App/
│   ├── IoTCoreSampleApp.swift    # App entry point
│   └── ContentView.swift         # Main tab view
├── Models/                       # Data models
├── ViewModels/                   # MVVM view models
├── Views/                        # SwiftUI views
│   ├── OnboardingTab/
│   ├── DeviceControlTab/
│   └── SettingsTab/
└── Extensions/                   # Utility extensions
```

## License

Proprietary - Rogo Solutions. All rights reserved.
