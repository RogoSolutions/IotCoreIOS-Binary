# Troubleshooting Guide

Common issues and solutions when integrating IotCoreIOS SDK.

---

## Build Errors

### "No such module 'IotCoreIOS'"

**Cause:** The framework is not properly linked to your target.

**Solutions:**

1. **Clean and Rebuild**
   ```
   Cmd + Shift + K (Clean Build Folder)
   Cmd + B (Build)
   ```

2. **Reset Package Cache (SPM)**
   - File > Packages > Reset Package Caches
   - File > Packages > Resolve Package Versions

3. **Reinstall Pod (CocoaPods)**
   ```bash
   pod deintegrate
   pod install
   ```

4. **Verify Framework Linking**
   - Project > Target > General > Frameworks, Libraries, and Embedded Content
   - Ensure `IotCoreIOS.xcframework` is listed with "Embed & Sign"

---

### "Framework not found IotCoreIOS"

**Cause:** Framework search path is incorrect.

**Solutions:**

1. **Check Framework Search Paths**
   - Project > Target > Build Settings
   - Search for "Framework Search Paths"
   - Ensure the path containing `IotCoreIOS.xcframework` is listed

2. **For CocoaPods:** Make sure you're opening `.xcworkspace`, not `.xcodeproj`

---

### "Building for iOS Simulator, but linking framework built for iOS"

**Cause:** Architecture mismatch between build target and framework.

**Solutions:**

1. **Verify XCFramework Structure**
   The XCFramework should contain both simulator and device slices:
   ```
   IotCoreIOS.xcframework/
   ├── ios-arm64/                        # Device
   └── ios-arm64_x86_64-simulator/       # Simulator
   ```

2. **Clean Derived Data**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

3. **Check Build Settings**
   - `EXCLUDED_ARCHS` should not exclude required architectures
   - For M1/M2 Macs: Ensure Rosetta is not forcing x86_64 only

---

### "Duplicate symbols" or "Multiple commands produce"

**Cause:** SDK is linked multiple times.

**Solutions:**

1. Remove duplicate framework references
2. If using both SPM and CocoaPods, choose one method only
3. Check sub-dependencies aren't also including the framework

---

## Runtime Errors

### App Crashes on Launch with Framework Error

**Cause:** Framework not properly embedded.

**Solutions:**

1. **Check Embed Setting**
   - Project > Target > General > Frameworks, Libraries, and Embedded Content
   - Set IotCoreIOS.xcframework to "Embed & Sign"

2. **Verify on Device**
   - Simulator may hide some embedding issues
   - Test on real device to verify

---

### CoreBluetooth Permission Error

**Cause:** Missing Bluetooth usage description in Info.plist.

**Solution:**

Add to your `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to communicate with IoT devices</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to communicate with IoT devices</string>
```

---

## Installation Issues

### Swift Package Manager: Checksum Mismatch

**Cause:** Downloaded binary doesn't match expected checksum.

**Solutions:**

1. Reset package cache:
   - File > Packages > Reset Package Caches

2. Check network connection (corrupted download)

3. Verify you're using the correct package version

---

### CocoaPods: Pod Install Hangs

**Cause:** Network issues or corrupted cache.

**Solutions:**

```bash
# Clear CocoaPods cache
pod cache clean --all

# Update repo
pod repo update

# Reinstall
pod install
```

---

### CocoaPods: Permission Denied

**Cause:** File permission issues.

**Solutions:**

```bash
# Fix ownership
sudo chown -R $(whoami) ~/.cocoapods
sudo chown -R $(whoami) ~/Library/Caches/CocoaPods

# Retry
pod install
```

---

## Version Compatibility

### Minimum iOS Version Error

**Cause:** Project deployment target is lower than SDK requirement.

**Solution:**

Update your project's iOS Deployment Target to 13.0 or higher:
- Project > Target > General > Minimum Deployments > iOS 13.0

Or use availability checks:
```swift
if #available(iOS 13.0, *) {
    // Use IotCoreIOS
} else {
    // Fallback for older iOS
}
```

---

### Swift Version Mismatch

**Cause:** Project Swift version incompatible with SDK.

**Solution:**

1. Check your Swift version:
   - Project > Target > Build Settings > Swift Language Version

2. Set to Swift 5.0 or higher

---

## Version Compatibility Matrix

| SDK Version | iOS Min | Swift | Xcode | Notes |
|-------------|---------|-------|-------|-------|
| 1.0.x | 13.0 | 5.0+ | 14.0+ | Initial release |

---

## Getting Help

If you're still experiencing issues:

1. **Check Release Notes**: [Releases](https://github.com/RogoSolutions/IotCoreIOS-Binary/releases)

2. **Contact Support**: [dev@rogo.com.vn](mailto:dev@rogo.com.vn)

When reporting issues, please include:
- Xcode version
- iOS deployment target
- Integration method (SPM/CocoaPods/Manual)
- Full error message
- Steps to reproduce
