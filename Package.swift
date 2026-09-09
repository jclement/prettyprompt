// swift-tools-version:5.9
import PackageDescription

// The logic lives in a library so it can be unit-tested and rendered offscreen;
// `prettyprompt` is a thin entry point around it. build-app.sh wraps the
// executable in a real .app bundle — the bundle is what lets a shell-invoked
// prompt take keyboard focus and float above full-screen apps (DESIGN.md §2).
let package = Package(
    name: "prettyprompt",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "prettyprompt", targets: ["prettyprompt"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "PrettyPromptKit",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .executableTarget(
            name: "prettyprompt",
            dependencies: ["PrettyPromptKit"]),
        // Development only — renders the themes to PNG for the README and for
        // eyeballing a design change without launching a window. Never shipped.
        .executableTarget(
            name: "gallery",
            dependencies: ["PrettyPromptKit"]),
        .testTarget(
            name: "PrettyPromptKitTests",
            dependencies: ["PrettyPromptKit"])
    ]
)
