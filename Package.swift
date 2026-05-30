// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LoGGer",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "LoGGer",
            targets: ["LoGGer"]
        ),
    ],
    targets: [
        .target(
            name: "LoGGer"
        ),
        .testTarget(
            name: "LoGGerTests",
            dependencies: ["LoGGer"]
        ),
    ]
)
