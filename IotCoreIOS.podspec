Pod::Spec.new do |s|
  s.name             = 'IotCoreIOS'
  s.version          = '0.9.1-test'
  s.summary          = 'iOS SDK for IoT device management'
  s.description      = <<-DESC
    IotCoreIOS provides BLE discovery, WiFi provisioning, and multi-transport
    device communication for IoT applications. Features include:
    - BLE device scanning and discovery
    - WiFi network provisioning for IoT devices
    - Multi-transport architecture (BLE, MQTT, Bonjour)
    - Secure device communication
  DESC

  s.homepage         = 'https://github.com/RogoSolutions/IotCoreIOS-Binary'
  s.license          = { :type => 'Proprietary', :text => 'Copyright (c) Rogo Solutions. All rights reserved.' }
  s.author           = { 'Rogo Solutions' => 'dev@rogo.com.vn' }

  # Binary distribution - NO source code
  # XCFramework is downloaded from GitHub Releases
  s.source           = {
    :http => "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/#{s.version}/IotCoreIOS-#{s.version}.xcframework.zip"
  }

  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'

  # CRITICAL: Vendored framework only - NO source_files
  # This ensures no source code is distributed
  s.vendored_frameworks = 'IotCoreIOS.xcframework'

  # System frameworks required by the SDK
  s.frameworks       = 'Foundation', 'CoreBluetooth'

  # Per ADR-012: CocoaMQTT is a transitive dependency
  # Automatically installed with `pod install`
  # This prevents duplicate symbols if app also uses CocoaMQTT
  s.dependency 'CocoaMQTT', '~> 2.1'

  # Build settings for compatibility
  s.pod_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => ''  # Include all simulator architectures
  }
  s.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => ''
  }
end
