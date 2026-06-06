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
    dependencies: [],
    targets: [
        .executableTarget(
            name: "TypeBack",
            dependencies: [],
            path: "Sources/TypeBack"
        )
    ]
)
