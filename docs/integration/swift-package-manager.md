# Swift Package Manager Integration

This guide explains how to integrate IotCoreIOS SDK using Swift Package Manager (SPM).

---

## Requirements

| Requirement | Minimum Version |
|-------------|-----------------|
| iOS | 13.0+ |
| Xcode | 14.0+ |
| Swift | 5.7+ |

---

## Installation

### Option 1: Using Xcode UI (Recommended)

1. Open your project in Xcode

2. Go to **File > Add Package Dependencies...** (or **File > Add Packages...** in older Xcode)

3. In the search field, enter:
   ```
   https://github.com/RogoSolutions/IotCoreIOS-Binary.git
   ```

4. Configure version rules:
   - **Dependency Rule**: Up to Next Major Version
   - **From**: `1.0.0`

5. Click **Add Package**

6. Select your app target and click **Add Package**

### Option 2: Using Package.swift

If you're building a Swift package, add to your `Package.swift`:

```swift
// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "YourPackage",
    platforms: [
        .iOS(.v13)
    ],
    dependencies: [
        .package(
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary.git",
            from: "1.0.0"
        )
    ],
    targets: [
        .target(
            name: "YourTarget",
            dependencies: ["IotCoreIOS"]
        )
    ]
)
```

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

### Via Xcode UI

1. Select your project in the navigator
2. Go to **Package Dependencies** tab
3. Right-click on `IotCoreIOS-Binary`
4. Select **Update Package**

### Via Command Line

```bash
swift package update
```

---

## Version Selection

| Rule | Description |
|------|-------------|
| **Up to Next Major** | `1.0.0` to `< 2.0.0` - Recommended |
| **Up to Next Minor** | `1.0.0` to `< 1.1.0` - More conservative |
| **Exact Version** | Only `1.0.0` - Maximum stability |

---

## Troubleshooting

### "No such module 'IotCoreIOS'"

1. Clean build folder: **Product > Clean Build Folder** (`Cmd + Shift + K`)
2. Reset package cache: **File > Packages > Reset Package Caches**
3. Rebuild: `Cmd + B`

### Package Resolution Failed

1. Check your internet connection
2. Verify the repository URL is correct
3. Try: **File > Packages > Resolve Package Versions**

### Checksum Mismatch

This indicates the downloaded binary doesn't match the expected checksum. This could be:
- Network issue during download
- Corrupted cache

Solution:
1. **File > Packages > Reset Package Caches**
2. Re-resolve packages

See [Troubleshooting Guide](troubleshooting.md) for more issues.

---

## Next Steps

- [Quick Start Guide](../README.md#quick-start)
- [API Documentation](#) (Coming soon)
