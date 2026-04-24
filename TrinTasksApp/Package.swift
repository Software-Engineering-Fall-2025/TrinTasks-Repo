// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TrinTasks",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // Library: all logic, views, services (no @main)
        .target(
            name: "TrinTasks",
            path: "Sources/TrinTasks",
            exclude: ["App/TrinTasksApp.swift"]
        ),
        // Executable: thin entry point only
        .executableTarget(
            name: "TrinTasksApp",
            dependencies: ["TrinTasks"],
            path: "Sources/TrinTasksApp"
        ),
        // Tests depend on library, not executable
        .testTarget(
            name: "TrinTasksTests",
            dependencies: ["TrinTasks"],
            path: "Tests/TrinTasksTests"
        )
    ]
)
