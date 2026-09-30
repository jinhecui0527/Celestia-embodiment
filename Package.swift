// swift-tools-version:5.9
// Builds the platform-independent core (channels, local life, gateway contract,
// SSE parser, mock gateway) so it can be tested with `swift test` on macOS or Linux.
// The iPad app itself is built from Celestia.xcodeproj, which compiles the same files.
import PackageDescription

let package = Package(
    name: "CelestiaCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CelestiaCore", targets: ["CelestiaCore"]),
    ],
    targets: [
        .target(name: "CelestiaCore", path: "Celestia/Core"),
        .testTarget(name: "CelestiaCoreTests", dependencies: ["CelestiaCore"], path: "Tests/CelestiaCoreTests"),
    ]
)
