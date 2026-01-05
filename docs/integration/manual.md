# Manual Integration

This guide explains how to manually integrate IotCoreIOS SDK by downloading and adding the XCFramework to your project.

---

## Requirements

| Requirement | Minimum Version |
|-------------|-----------------|
| iOS | 13.0+ |
| Xcode | 14.0+ |
| Swift | 5.0+ |

---

## Download

### Step 1: Get the XCFramework

1. Go to [Releases](https://github.com/RogoSolutions/IotCoreIOS-Binary/releases)
2. Find the version you want (e.g., `1.0.0`)
3. Download `IotCoreIOS-X.Y.Z.xcframework.zip`

### Step 2: Verify Checksum (Optional but Recommended)

```bash
# Download checksum file
curl -LO https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/1.0.0/IotCoreIOS-1.0.0.xcframework.zip.sha256

# Verify
shasum -a 256 -c IotCoreIOS-1.0.0.xcframework.zip.sha256
```

Expected output: `IotCoreIOS-1.0.0.xcframework.zip: OK`

### Step 3: Extract

```bash
unzip IotCoreIOS-1.0.0.xcframework.zip
```

This creates `IotCoreIOS.xcframework/` directory.

---

## Integration

### Step 1: Add to Xcode Project

1. Open your project in Xcode
2. Drag `IotCoreIOS.xcframework` into your project navigator
3. In the dialog:
   - Check **Copy items if needed**
   - Select **Create groups**
   - Check your app target
4. Click **Finish**

### Step 2: Configure Framework

1. Select your project in the navigator
2. Select your app target
3. Go to **General** tab
4. Scroll to **Frameworks, Libraries, and Embedded Content**
5. Find `IotCoreIOS.xcframework`
6. Set **Embed** to **Embed & Sign**

```
┌─────────────────────────────────────────────────────────────────┐
│ Frameworks, Libraries, and Embedded Content                     │
├─────────────────────────────────────────────────────────────────┤
│ IotCoreIOS.xcframework                        [Embed & Sign ▼]  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 3: Build Settings (if needed)

If you encounter build issues, verify these settings:

1. Go to **Build Settings** tab
2. Search for `Framework Search Paths`
3. Ensure the path to `IotCoreIOS.xcframework` is included

---

## Verification

After installation, verify the SDK is properly integrated:

```swift
import IotCoreIOS

// If this compiles, the SDK is properly integrated
print("IotCoreIOS SDK integrated successfully")
```

Build your project (`Cmd + B`). If it builds without errors, the integration is complete.

---

## Updating

To update to a new version:

1. Download the new version from [Releases](https://github.com/RogoSolutions/IotCoreIOS-Binary/releases)
2. In Xcode, delete the old `IotCoreIOS.xcframework` from your project
3. Add the new `IotCoreIOS.xcframework` following the steps above

---

## XCFramework Structure

The XCFramework contains slices for different platforms:

```
IotCoreIOS.xcframework/
├── Info.plist
├── ios-arm64/                          # iOS Device (arm64)
│   └── IotCoreIOS.framework/
│       ├── IotCoreIOS                  # Binary
│       ├── Info.plist
│       ├── Headers/
│       └── Modules/
└── ios-arm64_x86_64-simulator/         # iOS Simulator (arm64 + x86_64)
    └── IotCoreIOS.framework/
        ├── IotCoreIOS
        ├── Info.plist
        ├── Headers/
        └── Modules/
```

---

## Troubleshooting

### "No such module 'IotCoreIOS'"

1. Verify `IotCoreIOS.xcframework` is in **Frameworks, Libraries, and Embedded Content**
2. Ensure **Embed** is set to **Embed & Sign**
3. Clean build folder: `Cmd + Shift + K`
4. Rebuild: `Cmd + B`

### "Framework not found"

1. Check **Framework Search Paths** in Build Settings
2. Ensure the XCFramework is properly added to the project

### Architecture Issues

The XCFramework supports:
- iOS Device: `arm64`
- iOS Simulator: `arm64` (Apple Silicon) + `x86_64` (Intel)

If you see architecture errors:
1. Ensure you're using the XCFramework (not a regular .framework)
2. Clean derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`

### Code Signing

If you see code signing errors:
1. Select `IotCoreIOS.xcframework` in project navigator
2. In File Inspector, ensure **Target Membership** is checked for your app target
3. Verify **Embed** is set to **Embed & Sign**

See [Troubleshooting Guide](troubleshooting.md) for more issues.

---

## Next Steps

- [Quick Start Guide](../README.md#quick-start)
- [API Documentation](#) (Coming soon)
