// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tabby",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6")
    ],
    targets: [
        .executableTarget(
            name: "Tabby",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Tabby"
        )
    ]
)
