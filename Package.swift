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
            checksum: "c0ace145f20ce0fcff8eaea34c68f3d61079d94f163d90e9a35e801d3ae51176"
        )
    ]
)
