// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DownloadModels",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "DownloadModels",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "."
        ),
    ]
)
