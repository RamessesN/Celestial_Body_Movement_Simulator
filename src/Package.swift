// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "GravitySim",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GravitySim",
            path: "Sources/GravitySim",
            resources: [.process("Resources")]
        )
    ]
)
