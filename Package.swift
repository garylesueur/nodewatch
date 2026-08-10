// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NodeWatch",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NodeWatch", targets: ["NodeWatch"]),
        .library(name: "NodeWatchCore", targets: ["NodeWatchCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.2"),
    ],
    targets: [
        .target(
            name: "NodeWatchCore",
            path: "Sources/NodeWatchCore"
        ),
        .executableTarget(
            name: "NodeWatch",
            dependencies: [
                "NodeWatchCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/NodeWatch"
        ),
        .testTarget(
            name: "NodeWatchTests",
            dependencies: [
                "NodeWatchCore",
            ],
            path: "Tests/NodeWatchTests"
        ),
    ]
)
