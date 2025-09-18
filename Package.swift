// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Oak",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .macCatalyst(.v15),
        .tvOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Oak",
            targets: ["Oak"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/swhitty/swift-mutex.git", .upToNextMajor(from: "0.0.5")),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Oak",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            swiftSettings: []
        ),
        .testTarget(
            name: "OakTests",
            dependencies: [
                "Oak",
                .product(name: "Mutex", package: "swift-mutex")
            ],
            path: "Tests/OakTests",
            swiftSettings: []
        ),
        .testTarget(
            name: "OakBenchmarks",
            dependencies: [
                "Oak"
            ],
            path: "Tests/OakBenchmarks",
            swiftSettings: []
        )
    ]
)
