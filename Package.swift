// swift-tools-version: 5.7.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VCIClient",
    platforms: [
        .iOS(.v14),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "VCIClient",
            targets: ["VCIClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/valpackett/SwiftCBOR", .upToNextMajor(from: "0.5.0")),
        .package(url: "https://github.com/mosip/inji-openid4vp-ios-swift", branch: "develop")
    ],
    targets: [
        .target(
            name: "VCIClient",
            dependencies: [
                "SwiftCBOR",
                .product(name: "OpenID4VP", package: "inji-openid4vp-ios-swift"),
                "OpenID4VPBridge"
            ]
        ),
        .testTarget(
            name: "VCIClientTests",
            dependencies: [
                "VCIClient",
                "SwiftCBOR",
                .product(name: "OpenID4VP", package: "inji-openid4vp-ios-swift")
            ]
        ),
        .target(
                name: "OpenID4VPBridge",
                dependencies: [
                    .product(name: "OpenID4VP", package: "inji-openid4vp-ios-swift")
                ]
            )
    ]
)
