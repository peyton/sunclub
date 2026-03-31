// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "SunclubDependencies",
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift.git", exact: "0.31.2"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", exact: "2.30.6"),
        .package(url: "https://github.com/huggingface/swift-transformers", exact: "1.1.9")
    ]
)
