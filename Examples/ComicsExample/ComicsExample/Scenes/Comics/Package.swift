// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let oakPath = "/Users/agrosam/Developer/Oak Project/Oak 3/Oak"

let package = Package(
    name: "Comics",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Comics",
            targets: ["Comics"]
        ),
    ],
    dependencies: [
        .package(path: oakPath), // adjust the path as needed
        .package(url: "https://github.com/kean/Nuke.git", from: "12.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Comics",
            dependencies: [
                "Oak",
                "Nuke"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "ComicsTests",
            dependencies: ["Comics"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ]
)

