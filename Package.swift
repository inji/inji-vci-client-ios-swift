// swift-tools-version: 5.7.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VCIClient",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "VCIClient",
            targets: ["VCIClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/valpackett/SwiftCBOR", .upToNextMajor(from: "0.5.0")),
        .package(url: "https://github.com/tw-mosip/inji-openid4vp-ios-swift", revision: "90fca098987558b79b7e3f5b1efc1047fb3124f2")
    ],
    targets: [
        .target(
            name: "VCIClient",
            dependencies: [
                "SwiftCBOR",
                .product(name: "InjiOpenID4VP", package: "inji-openid4vp-ios-swift")
            ]
        ),
        .testTarget(
            name: "VCIClientTests",
            dependencies: [
                "VCIClient",
                "SwiftCBOR",
                .product(name: "InjiOpenID4VP", package: "inji-openid4vp-ios-swift")
            ]
        ),
    ]
)
