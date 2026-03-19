// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SunclubDependencies",
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift.git", exact: "0.25.6"),
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", exact: "2.25.7"),
        .package(url: "https://github.com/huggingface/swift-transformers", exact: "0.1.24"),
    ]
)
