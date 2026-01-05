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
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/0.0.2-test/IotCoreIOS-0.0.2-test.xcframework.zip",
            checksum: "1802ea36e33955361e2e4c62caf161a7c0b7bbd0a74e5c6a11be663a69b65161"
        )
    ]
)
