// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "WALL·E",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "5.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "8.0.0")
    ],
    targets: [
        .target(name: "Bot", dependencies: ["ReactiveSwift"]),
        .target(name: "App", dependencies: ["Bot", "Vapor"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "BotTests", dependencies: ["Bot", "Nimble"])
    ]
)

