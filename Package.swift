// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "WALL-E",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.90.0"),
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "6.0.0"),
        .package(url: "https://github.com/Babylonhealth/ReactiveFeedback", from: "0.7.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "8.0.2"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.3.0")
    ],
    targets: [
        .target(name: "Bot", dependencies: ["ReactiveSwift", "ReactiveFeedback", "CryptoSwift"]),
        .target(name: "App", dependencies: ["Bot", "Vapor"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "BotTests", dependencies: ["Bot", "Nimble"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)
