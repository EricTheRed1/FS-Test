// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FreeSpaceMonitor",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "FreeSpaceMonitor",
            targets: ["FreeSpaceMonitorApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "FreeSpaceMonitorApp",
            path: "Sources/FreeSpaceMonitorApp"
        )
    ]
)
