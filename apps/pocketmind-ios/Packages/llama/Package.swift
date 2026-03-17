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
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b8390/llama-b8390-xcframework.zip",
            checksum: "61ec8d7bca70af2d57e39ac7cd145928a6d9c41d7d3f55e26e766be44174eba4"
        )
    ]
)
