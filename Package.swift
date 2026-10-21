// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Telex",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Telex",
            targets: ["Telex"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Telex",
            path: "Sources/Telex",
            resources: [.copy("Resources")],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "TelexTests",
            dependencies: ["Telex"],
            path: "Tests/TelexTests"
        )
    ]
)
