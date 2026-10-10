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
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/0.0.34/IotCoreIOS-0.0.34.xcframework.zip",
            checksum: "f61e671ad42a47a7e25298c2a08c90901424412eef27cabf89436a9de80e787d"
        ),
        .binaryTarget(
            name: "CocoaMQTTBinary",
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/0.0.34/CocoaMQTT-0.0.34.xcframework.zip",
            checksum: "f1470a711c574abdd148ae927ded281c3449fa22f5eca82bea9ccc7094a40489"
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
