// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// IotCoreIOS SDK - Binary Distribution
// CocoaMQTT is automatically installed as a transitive dependency.

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
    dependencies: [
        // MQTT library - automatically fetched when app adds SDK
        // This prevents duplicate symbols if app also uses CocoaMQTT
        .package(url: "https://github.com/emqx/CocoaMQTT.git", from: "2.1.0")
    ],
    targets: [
        // Binary target - pre-compiled XCFramework
        // Per closed-source policy, this SDK is distributed as pre-compiled binary
        .binaryTarget(
            name: "IotCoreIOSBinary",
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/0.9.1-test/IotCoreIOS-0.9.1-test.xcframework.zip",
            checksum: "f89d6201a63b568c2b9ff72e6e62d02b87e800b79979dbb279d8e0ef0b80bed9"
        ),
        // Wrapper target links binary with CocoaMQTT dependency
        // When apps add IotCoreIOS, SPM automatically resolves CocoaMQTT
        .target(
            name: "IotCoreIOSWrapper",
            dependencies: [
                "IotCoreIOSBinary",
                .product(name: "CocoaMQTT", package: "CocoaMQTT")
            ],
            path: "Sources/IotCoreIOSWrapper"
        )
    ]
)
