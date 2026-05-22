// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MacWorkTimer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MacWorkTimerCore",
            targets: ["MacWorkTimerCore"]
        ),
        .executable(
            name: "MacWorkTimer",
            targets: ["MacWorkTimerApp"]
        )
    ],
    targets: [
        .target(
            name: "MacWorkTimerCore"
        ),
        .executableTarget(
            name: "MacWorkTimerApp",
            dependencies: ["MacWorkTimerCore"]
        ),
        .testTarget(
            name: "MacWorkTimerCoreTests",
            dependencies: ["MacWorkTimerCore"]
        )
    ]
)
