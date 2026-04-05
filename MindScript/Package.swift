// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MindScript",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.0"),
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "MindScript",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "HotKey", package: "HotKey"),
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/MindScript",
            resources: [
                .process("../../Resources"),
            ]
        ),
        .testTarget(
            name: "MindScriptTests",
            dependencies: ["MindScript"],
            path: "Tests/MindScriptTests"
        ),
    ]
)
