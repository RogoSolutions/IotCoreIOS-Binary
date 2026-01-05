// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IotCoreIOS",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "IotCoreIOS",
            targets: ["IotCoreIOS"]
        )
    ],
    targets: [
        // IMPORTANT: Binary target only - NO source code distribution
        // Per closed-source policy, this SDK is distributed as pre-compiled XCFramework
        .binaryTarget(
            name: "IotCoreIOS",
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/0.0.1-e2e-test/IotCoreIOS-0.0.1-e2e-test.xcframework.zip",
            checksum: "9075a6179950aad997b8afb951b74e36f4c1ec7a83cb845ede66c2f44b1a0dd8"
        )
    ]
)
