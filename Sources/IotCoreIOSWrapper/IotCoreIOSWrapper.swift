// IotCoreIOSWrapper.swift
// Re-exports IotCoreIOS binary and links CocoaMQTT dependency.
//
// This wrapper target exists to:
// 1. Link the pre-compiled IotCoreIOS.xcframework binary
// 2. Automatically resolve CocoaMQTT as a transitive dependency
//
// Apps using this SDK will get CocoaMQTT automatically via SPM.

@_exported import IotCoreIOS
