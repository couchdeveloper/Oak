// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let localSettingsPath = "/Users/agrosam/Developer/Oak Project/Settings"

let package = Package(
    name: "AppSettings",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AppSettings",
            targets: ["AppSettings"]),
    ],
    dependencies: [
        // .package(url: "https://github.com/couchdeveloper/Settings.git", from: "0.2.0"),
        .package(path: localSettingsPath)
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AppSettings",
            dependencies: [
                .product(name: "Settings", package: "Settings"),
                .product(name: "SettingsMock", package: "Settings"),
            ]),
        .testTarget(
            name: "AppSettingsTests",
            dependencies: ["AppSettings"]
        ),
    ]
)
