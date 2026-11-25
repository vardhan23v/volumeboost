// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "VolumeBoost",
    platforms: [.macOS("14.2")],
    targets: [.executableTarget(name: "VolumeBoost", path: "Sources/VolumeBoost")]
)
