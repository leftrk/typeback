// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TypeBack",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TypeBack", targets: ["TypeBack"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "TypeBack",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/TypeBack"
        )
    ]
)