// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RoutenplanerLogic",
    platforms: [.iOS(.v16), .macOS(.v12)],
    products: [
        .library(name: "RoutenplanerLogic", targets: ["RoutenplanerLogic"]),
    ],
    targets: [
        .target(name: "RoutenplanerLogic"),
        .testTarget(name: "RoutenplanerLogicTests", dependencies: ["RoutenplanerLogic"]),
    ]
)
