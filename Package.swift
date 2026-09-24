// swift-tools-version:5.7
//
// IotCoreIOS SDK - Binary Distribution
// CocoaMQTT is bundled as a pre-built binary alongside the SDK.

import PackageDescription

let package = Package(
    name: "IotCoreIOS",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "IotCoreIOS",
            targets: ["IotCoreIOSWrapper"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "IotCoreIOSBinary",
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/0.0.31/IotCoreIOS-0.0.31.xcframework.zip",
            checksum: "e6ebd01e6a99d8c0e1954ebb5d0b24f79dac89a8246e5c8d4cb69880d5b70d15"
        ),
        .binaryTarget(
            name: "CocoaMQTTBinary",
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/0.0.31/CocoaMQTT-0.0.31.xcframework.zip",
            checksum: "b7601ba6a0db8c4b6970f6ac15bbb81030872ed0f4fef649427e85eb16d78c7e"
        ),
        .target(
            name: "IotCoreIOSWrapper",
            dependencies: [
                "IotCoreIOSBinary",
                "CocoaMQTTBinary"
            ],
            path: "Sources/IotCoreIOSWrapper"
        )
    ]
)
