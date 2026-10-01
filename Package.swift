// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PresenterCore",
    platforms: [.iOS(.v18), .macOS(.v11)],
    products: [.library(name: "PresenterCore", targets: ["PresenterCore"])],
    targets: [
        .target(name: "PresenterCore", path: "Core"),
        .testTarget(name: "PresenterCoreTests", dependencies: ["PresenterCore"], path: "Tests/Core")
    ],
    swiftLanguageModes: [.v5]
)
