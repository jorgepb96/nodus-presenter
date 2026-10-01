// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PresenterCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v11)],
    products: [.library(name: "PresenterCore", targets: ["PresenterCore"])],
    targets: [
        .target(name: "PresenterCore", path: "Core", resources: [.process("Resources")]),
        .testTarget(name: "PresenterCoreTests", dependencies: ["PresenterCore"], path: "Tests/Core")
    ],
    swiftLanguageModes: [.v5]
)
