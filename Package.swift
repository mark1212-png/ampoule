// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Ampoule",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "AmpouleCore", targets: ["AmpouleCore"]),
        .executable(name: "ampoule", targets: ["AmpouleCLI"]),
    ],
    targets: [
        .target(name: "AmpouleCore"),
        .executableTarget(name: "AmpouleCLI", dependencies: ["AmpouleCore"]),
        .testTarget(name: "AmpouleCoreTests", dependencies: ["AmpouleCore"]),
    ]
)
