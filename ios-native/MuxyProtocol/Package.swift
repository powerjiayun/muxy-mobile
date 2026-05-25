// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MuxyProtocol",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MuxyProtocol", targets: ["MuxyProtocol"])
    ],
    targets: [
        .target(
            name: "MuxyProtocol",
            path: "Sources/MuxyProtocol",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "MuxyProtocolTests",
            dependencies: ["MuxyProtocol"],
            path: "Tests/MuxyProtocolTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
