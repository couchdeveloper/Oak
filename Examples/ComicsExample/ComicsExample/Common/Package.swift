// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

// Note: Package Common may be a dependency in Feature packages. Its functions
// must not have side effetcs, since Feautures should not directly or indirectly
// depend on external packages which usually have side effects. That includes
// infrastructure packages - such as API, Settings or ImageLoader, etc.

import PackageDescription

let package = Package(
    name: "Common",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Common",
            targets: ["Common"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Common",
            dependencies: [
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CommonTests",
            dependencies: ["Common"]
        ),
    ]
)
