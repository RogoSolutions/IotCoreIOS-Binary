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
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/0.0.19/IotCoreIOS-0.0.19.xcframework.zip",
            checksum: "078c5f534cc0b2932885152591e4c2e9211e2e16fb475ae95bbf67ecc36ae570"
        ),
        .binaryTarget(
            name: "CocoaMQTTBinary",
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/0.0.19/CocoaMQTT-0.0.19.xcframework.zip",
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
