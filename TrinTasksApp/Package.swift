// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TrinTasks",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "TrinTasks",
            path: "Sources/TrinTasks",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "TrinTasksTests",
            dependencies: ["TrinTasks"],
            path: "Tests/TrinTasksTests"
        )
    ]
)
