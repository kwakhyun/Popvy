// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Popvy",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Popvy", targets: ["Popvy"])],
    targets: [
        .executableTarget(name: "Popvy"),
        .testTarget(name: "PopvyTests", dependencies: ["Popvy"])
    ]
)
