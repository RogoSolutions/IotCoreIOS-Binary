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
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/0.0.4-test/IotCoreIOS-0.0.4-test.xcframework.zip",
            checksum: "d137322c8e5b5b8c59904fd98b6095f82868b820c527de667e54844d72c79888"
        )
    ]
)
