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
    targets: [
        .executableTarget(
            name: "TypeBack",
            path: "Sources/TypeBack"
        )
    ]
)