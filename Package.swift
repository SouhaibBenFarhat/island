// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Island",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic (snippets, placeholders, persistence, panel geometry) —
        // no AppKit, so it stays unit-testable.
        .target(
            name: "IslandCore",
            path: "Sources/IslandCore"
        ),
        .executableTarget(
            name: "Island",
            dependencies: ["IslandCore"],
            path: "Sources/Island"
        ),
        .testTarget(
            name: "IslandCoreTests",
            dependencies: ["IslandCore"],
            path: "Tests/IslandCoreTests"
        ),
    ]
)
