// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NoodlePet",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NoodlePet", targets: ["NoodlePet"])
    ],
    targets: [
        .executableTarget(
            name: "NoodlePet",
            path: "Sources/NoodlePet"
        )
    ]
)
