// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DataDemo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DataDemo", targets: ["DataDemo"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.29.0"),
        .package(url: "https://github.com/swiftpackages/DotEnv.git", from: "3.0.0")
    ],
    targets: [
        .executableTarget(
            name: "DataDemo",
            dependencies: [
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "DotEnv", package: "DotEnv")
            ]
        )
    ]
)
