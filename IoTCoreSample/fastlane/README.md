# Fastlane Configuration for IoTCoreSample

This directory contains Fastlane configuration for automated builds and TestFlight deployment.

## Prerequisites

- **Fastlane**: Install with `brew install fastlane`
- **Xcode**: 15.0 or later
- **Apple Developer Account**: Required for TestFlight deployment
- **Code Signing**: Distribution certificate and provisioning profile

## Quick Start

### 1. Setup Environment

```bash
# Copy the template
cp fastlane/.env.default fastlane/.env

# Edit with your credentials
nano fastlane/.env
```

### 2. Available Lanes

| Lane | Description | Code Signing |
|------|-------------|--------------|
| `build_test` | Build for simulator | No |
| `build_sample` | Build signed IPA | Yes |
| `release_testflight` | Build and upload to TestFlight | Yes |
| `test` | Run unit tests | No |
| `bump_version` | Increment version number | No |

### 3. Running Lanes

```bash
cd IoTCoreSample

# Build for simulator (no signing required)
fastlane build_test

# Build signed IPA (requires certificates)
fastlane build_sample

# Upload to TestFlight
fastlane release_testflight
```

## Environment Variables

### Required for TestFlight

| Variable | Description |
|----------|-------------|
| `APPLE_ID` | Apple Developer Account email |
| `TEAM_ID` | Apple Developer Team ID |

### Optional (Recommended for CI)

| Variable | Description |
|----------|-------------|
| `APP_STORE_CONNECT_API_KEY_ID` | API Key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | API Issuer ID |
| `APP_STORE_CONNECT_API_KEY_PATH` | Path to .p8 key file |

## CI/CD Integration

For GitHub Actions, set these secrets in your repository:

1. Go to Settings > Secrets and variables > Actions
2. Add the following secrets:
   - `APPLE_ID` - Apple Developer Account email
   - `TEAM_ID` - Apple Developer Team ID
   - `APP_STORE_CONNECT_API_KEY_ID` (optional, recommended for CI)
   - `APP_STORE_CONNECT_API_ISSUER_ID` (optional, recommended for CI)
   - `APP_STORE_CONNECT_API_KEY` (optional - .p8 file content)

> **Note:** `IOTCORE_APP_KEY` and `IOTCORE_APP_SECRET` are NOT needed for CI builds.
> Users configure their own SDK credentials in the app's Settings screen.

## Code Signing

### Manual Signing (Single Machine)

1. Export distribution certificate from Keychain Access
2. Import on build machine:
   ```bash
   security import certificate.p12 -k ~/Library/Keychains/login.keychain-db
   ```
3. Download provisioning profile from Apple Developer Portal
4. Copy to: `~/Library/MobileDevice/Provisioning Profiles/`

### Automatic with Match (Recommended for Teams)

```bash
# Setup (one-time)
fastlane match init
fastlane match appstore

# Sync on CI
fastlane match appstore --readonly
```

## Troubleshooting

### "Code signing is required"
- Ensure distribution certificate is installed
- Verify provisioning profile is in place
- Check `TEAM_ID` environment variable

### "Authentication failed"
- Verify `APPLE_ID` is correct
- For 2FA accounts, use App-Specific Password or API Key
- Check App Store Connect access permissions

### "Build number already exists"
- Our lanes use timestamp-based build numbers
- If manually uploading, increment build number first

## Files

| File | Purpose |
|------|---------|
| `Fastfile` | Lane definitions |
| `Appfile` | App configuration (bundle ID, team) |
| `.env.default` | Environment variable template |
| `.env` | Your local configuration (gitignored) |

## More Information

- [Fastlane Documentation](https://docs.fastlane.tools/)
- [Code Signing Guide](https://docs.fastlane.tools/codesigning/getting-started/)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
