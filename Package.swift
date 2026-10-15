// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RadixCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "RadixCore", targets: ["RadixCore"])],
    targets: [
        .target(name: "RadixCore", path: "Sources/Core"),
        .testTarget(name: "RadixCoreTests", dependencies: ["RadixCore"], path: "Tests/RadixCoreTests")
    ]
)
