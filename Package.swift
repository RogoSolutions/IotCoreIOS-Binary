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
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/0.0.5-test/IotCoreIOS-0.0.5-test.xcframework.zip",
            checksum: "7c252e58b2f38f89815633ee94fa69a7a1028d043f8c1993ae173287332c34ff"
        )
    ]
)
