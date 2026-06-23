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
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/0.0.13/IotCoreIOS-0.0.13.xcframework.zip",
            checksum: "b02140382a09d9501d997667871e1c2df00d9a739aaeb8764f8a8354565ef654"
        ),
        .binaryTarget(
            name: "CocoaMQTTBinary",
            url: "https://github.com/RogoSolutions/IotCoreIOS-Binary/releases/download/0.0.13/CocoaMQTT-0.0.13.xcframework.zip",
            checksum: "fba11b0aca75cb1d67df099421cb86682376f2cf2e84793d7741c2af48477a68"
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
