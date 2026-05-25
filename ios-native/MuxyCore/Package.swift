// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MuxyCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MuxyCore", targets: ["MuxyCore"])
    ],
    dependencies: [
        .package(path: "../MuxyProtocol")
    ],
    targets: [
        .target(
            name: "MuxyCore",
            dependencies: ["MuxyProtocol"],
            path: "Sources/MuxyCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "MuxyCoreTests",
            dependencies: ["MuxyCore"],
            path: "Tests/MuxyCoreTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
