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
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/0.0.21/IotCoreIOS-0.0.21.xcframework.zip",
            checksum: "e3d567439ad764bdbc2d6ba3e47187ea21b39ee5f97526d5f5a3b95af1b2a005"
        ),
        .binaryTarget(
            name: "CocoaMQTTBinary",
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/0.0.21/CocoaMQTT-0.0.21.xcframework.zip",
            checksum: "88b0703ade4f496c20518672bc90758135e65b362bd6f575d7fcc6634dd3071d"
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
