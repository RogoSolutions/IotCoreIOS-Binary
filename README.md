# IotCoreIOS SDK

[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-compatible-brightgreen.svg)](https://cocoapods.org/)
[![iOS 13.0+](https://img.shields.io/badge/iOS-13.0+-blue.svg)](https://developer.apple.com/ios/)
[![Swift 5.0+](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org/)

iOS SDK for IoT device management with BLE discovery, WiFi provisioning, and multi-transport architecture.

---

## Features

- **BLE Scanning & Discovery** - Scan and discover Wile/Mesh IoT devices
- **WiFi Provisioning** - Configure WiFi credentials on IoT devices
- **Multi-Transport Architecture** - Support for BLE, MQTT, and Bonjour transports
- **Secure Communication** - Encrypted device communication

---

## Requirements

| Requirement | Minimum Version |
|-------------|-----------------|
| iOS | 13.0+ |
| Xcode | 14.0+ |
| Swift | 5.0+ |

---

## Installation

### Swift Package Manager (Recommended)

#### Using Xcode

1. Open your project in Xcode
2. Go to **File > Add Package Dependencies...**
3. Enter the repository URL:
   ```
   https://github.com/RogoSolutions/IotCoreIOS-Binary.git
   ```
4. Select version rule (e.g., "Up to Next Major Version" from `1.0.0`)
5. Click **Add Package**
6. Select your target and click **Add Package**

#### Using Package.swift

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/RogoSolutions/IotCoreIOS-Binary.git", from: "1.0.0")
]
```

Then add to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["IotCoreIOS"]
)
```

### CocoaPods

Add to your `Podfile`:

```ruby
platform :ios, '13.0'
use_frameworks!

target 'YourApp' do
  pod 'IotCoreIOS', '~> 1.0'
end
```

Then run:

```bash
pod install
```

Open the `.xcworkspace` file (not `.xcodeproj`).

### Manual Installation

1. Download the latest release from [Releases](https://github.com/RogoSolutions/IotCoreIOS-Binary/releases)
2. Extract `IotCoreIOS-X.Y.Z.xcframework.zip`
3. Drag `IotCoreIOS.xcframework` into your Xcode project
4. Select **Copy items if needed**
5. In your target's **General** tab, ensure `IotCoreIOS.xcframework` shows **Embed & Sign**

---

## Quick Start

```swift
import IotCoreIOS

// Initialize SDK
let sdk = IotCoreIOS.shared

// Start BLE scanning
sdk.startScanning { device in
    print("Found device: \(device.name)")
}
```

For detailed usage, see the [Integration Guides](docs/integration/).

---

## Documentation

- [Swift Package Manager Guide](docs/integration/swift-package-manager.md)
- [CocoaPods Guide](docs/integration/cocoapods.md)
- [Manual Integration Guide](docs/integration/manual.md)
- [Troubleshooting](docs/integration/troubleshooting.md)

---

## Version History

| Version | Release Date | Notes |
|---------|--------------|-------|
| 0.0.1 | 2026-01-05 | Initial pre-release (core features in development) |

---

## Support

For issues and feature requests, please contact [dev@rogo.com.vn](mailto:dev@rogo.com.vn).

---

## License

Proprietary - Rogo Solutions. All rights reserved.

This SDK is distributed as a pre-compiled binary. Source code is not available for distribution.
