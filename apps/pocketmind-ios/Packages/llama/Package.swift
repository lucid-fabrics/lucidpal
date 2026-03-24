// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "llama",
    products: [
        .library(name: "llama", targets: ["llama"])
    ],
    targets: [
        .binaryTarget(
            name: "llama",
            path: "llama.xcframework"
        )
    ]
)
