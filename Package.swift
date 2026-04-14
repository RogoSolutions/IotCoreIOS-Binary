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
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/0.0.3/IotCoreIOS-0.0.3.xcframework.zip",
            checksum: "c33123abd0df3f338da5a519cbf45dcf637b57ac7d643d184144159325f10ddf"
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
