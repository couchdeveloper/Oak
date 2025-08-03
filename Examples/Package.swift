// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Examples",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .macCatalyst(.v15),
        .tvOS(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Examples",
            targets: ["Examples"]
        )
    ],
    dependencies: [
        .package(name: "Oak", path: "../../Oak")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Examples",
            dependencies: [
                "Oak"
            ]
        ),
        .testTarget(
            name: "ExamplesTests",
            dependencies: ["Examples"]
        )
    ]
)
