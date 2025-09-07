// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GranolaLocal",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GranolaLocal", targets: ["GranolaLocal"])
    ],
    dependencies: [
        // WhisperKit for local transcription
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.8.0"),
        // OpenAI Swift for GPT integration
        .package(url: "https://github.com/MacPaw/OpenAI.git", from: "0.2.5")
    ],
    targets: [
        .executableTarget(
            name: "GranolaLocal",
            dependencies: [
                "WhisperKit",
                "OpenAI"
            ],
            path: "Sources/GranolaLocal"
        ),
        .testTarget(
            name: "GranolaLocalTests",
            dependencies: ["GranolaLocal"],
            path: "Tests/GranolaLocalTests"
        )
    ]
)
