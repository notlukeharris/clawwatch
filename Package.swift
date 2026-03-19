// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClawWatch",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ClawWatch",
            path: "Sources/ClawWatch"
        )
    ]
)
