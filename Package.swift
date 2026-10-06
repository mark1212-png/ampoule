// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Ampoule",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "AmpouleCore", targets: ["AmpouleCore"]),
        .library(name: "AmpouleVZ", targets: ["AmpouleVZ"]),
        .library(name: "AmpouleAppModel", targets: ["AmpouleAppModel"]),
        .executable(name: "ampoule", targets: ["AmpouleCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(name: "AmpouleCore"),
        .target(name: "AmpouleVZ", dependencies: ["AmpouleCore"]),
        .target(name: "AmpouleAppModel", dependencies: ["AmpouleCore", "AmpouleVZ"]),
        .executableTarget(
            name: "AmpouleCLI",
            dependencies: [
                "AmpouleCore",
                "AmpouleVZ",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "AmpouleCoreTests", dependencies: ["AmpouleCore"]),
        .testTarget(name: "AmpouleVZTests", dependencies: ["AmpouleVZ"]),
        .testTarget(name: "AmpouleAppModelTests", dependencies: ["AmpouleAppModel"]),
    ]
)
