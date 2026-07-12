// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "afkick",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "afkick", targets: ["afkick"]),
        .library(name: "AFKickCore", targets: ["AFKickCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.10.0"),
    ],
    targets: [
        // Pure, hardware-free logic: kick policy state machine, camera matching,
        // launchd plist rendering. Fully unit-tested.
        .target(
            name: "AFKickCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Vendored UVC control classes from jtfrey/uvc-util (MIT).
        // Manual retain/release code, so ARC must be off. unsafeFlags means
        // this package builds as a tool (root package) but can't be consumed
        // as an SPM dependency — acceptable for a CLI.
        .target(
            name: "UVCKit",
            publicHeadersPath: "include",
            cSettings: [.unsafeFlags(["-fno-objc-arc"])]
        ),
        .executableTarget(
            name: "afkick",
            dependencies: [
                "AFKickCore",
                "UVCKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "AFKickCoreTests",
            dependencies: [
                "AFKickCore",
                .product(name: "Testing", package: "swift-testing"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
