// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GoldenRetriever",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "GoldenRetrieverCore",
            targets: ["GoldenRetrieverCore"]
        ),
        .executable(
            name: "GoldenRetrieverApp",
            targets: ["GoldenRetrieverApp"]
        )
    ],
    targets: [
        .target(
            name: "GoldenRetrieverCore"
        ),
        .executableTarget(
            name: "GoldenRetrieverApp",
            dependencies: ["GoldenRetrieverCore"],
            resources: [
                .process("Resources/Animation")
            ]
        ),
        .testTarget(
            name: "GoldenRetrieverCoreTests",
            dependencies: ["GoldenRetrieverCore"]
        ),
        .testTarget(
            name: "GoldenRetrieverAppTests",
            dependencies: ["GoldenRetrieverApp", "GoldenRetrieverCore"]
        )
    ]
)
