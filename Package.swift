// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenAudio",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "OpenAudio", targets: ["OpenAudio"])],
    targets: [
        .target(name: "AudioDSP", path: "Sources/OpenAudio/Audio/DSP", publicHeadersPath: "include", linkerSettings: [.linkedFramework("CoreAudio"), .linkedFramework("AudioToolbox")]),
        .executableTarget(name: "OpenAudio", dependencies: ["AudioDSP"], exclude: ["Audio/DSP", "Audio/SUBSYSTEM.md", "Control/SUBSYSTEM.md", "UI/SUBSYSTEM.md", "Listening/SUBSYSTEM.md"], swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
