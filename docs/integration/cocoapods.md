# CocoaPods Integration

This guide explains how to integrate IotCoreIOS SDK using CocoaPods.

---

## Requirements

| Requirement | Minimum Version |
|-------------|-----------------|
| iOS | 13.0+ |
| Xcode | 14.0+ |
| CocoaPods | 1.10+ |
| Swift | 5.0+ |

---

## Installation

### Step 1: Install CocoaPods (if not installed)

```bash
sudo gem install cocoapods
```

### Step 2: Create Podfile

If you don't have a Podfile, create one:

```bash
cd /path/to/your/project
pod init
```

### Step 3: Add IotCoreIOS to Podfile

Edit your `Podfile`:

```ruby
platform :ios, '13.0'
use_frameworks!

target 'YourApp' do
  pod 'IotCoreIOS', :podspec => 'https://raw.githubusercontent.com/RogoSolutions/IotCoreIOS-Binary/main/IotCoreIOS.podspec'
end
```

### Step 4: Install

```bash
pod install
```

### Step 5: Open Workspace

**Important:** Always use the `.xcworkspace` file, not `.xcodeproj`:

```bash
open YourApp.xcworkspace
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

### Update to Latest Version

```bash
pod update IotCoreIOS
```

### Update All Pods

```bash
pod update
```

---

## Version Pinning

You can pin to specific versions in your Podfile:

```ruby
# Latest compatible version (recommended)
pod 'IotCoreIOS', :podspec => 'https://raw.githubusercontent.com/RogoSolutions/IotCoreIOS-Binary/main/IotCoreIOS.podspec'

# Specific version (via tag)
pod 'IotCoreIOS', :git => 'https://github.com/RogoSolutions/IotCoreIOS-Binary.git', :tag => '1.0.0'
```

---

## Troubleshooting

### "No such module 'IotCoreIOS'"

1. Make sure you're opening `.xcworkspace` (not `.xcodeproj`)
2. Clean and rebuild:
   ```bash
   pod deintegrate
   pod install
   ```
3. Clean build folder in Xcode: `Cmd + Shift + K`

### Pod Install Failed

```bash
# Update CocoaPods repo
pod repo update

# Try install again
pod install
```

### Architecture Issues

If you see "building for iOS Simulator, but linking framework built for iOS":

1. Ensure you're using the latest podspec
2. Check `Build Active Architecture Only` is set to `NO` for Release
3. Clean derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

### Permission Denied

```bash
sudo pod install
```

Or fix ownership:
```bash
sudo chown -R $(whoami) ~/.cocoapods
```

See [Troubleshooting Guide](troubleshooting.md) for more issues.

---

## Alternative: Private Spec Repo

For enterprise deployments, you can use a private spec repo:

```ruby
# Add private spec repo
source 'https://github.com/RogoSolutions/Specs.git'
source 'https://cdn.cocoapods.org/'

target 'YourApp' do
  pod 'IotCoreIOS', '~> 1.0'
end
```

Contact [dev@rogo.com.vn](mailto:dev@rogo.com.vn) for private spec repo access.

---

## Next Steps

- [Quick Start Guide](../README.md#quick-start)
- [API Documentation](#) (Coming soon)
