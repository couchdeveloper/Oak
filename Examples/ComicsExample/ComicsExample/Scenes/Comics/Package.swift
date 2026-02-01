// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let oakPath = "/Users/agrosam/Developer/Oak Project/Oak 3/Oak"
let commonPath = "/Users/agrosam/Developer/Oak Project/Oak 3/Oak/Examples/ComicsExample/ComicsExample/Common"
let favouritesStoragePath = "/Users/agrosam/Developer/Oak Project/Oak 3/Oak/Examples/ComicsExample/ComicsExample/FavouritesStorage"

// Comics is a "Feature model" - which is a "side effect free" and self-sufficient
// package. It uses concrete mocks to fullfil dependencies which cause side
// effects in production. None of its dependencies must cause side effects,
// either directly or indirectly by using dependencies.
//
// For example, the dependency "FavouritesStorage", when used in development,
// must itself not cause side effects and must not directly depend on modules
// which cause side effects. If its usage is intended to eventually cause side
// effects, IoC must be used within FavouritesStorage to remove the explicit
// dependency and a mock must be used to replace the dependency during
// development.

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
        .package(path: commonPath),
        .package(path: favouritesStoragePath),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Comics",
            dependencies: [
                "Oak",
                "Common",
                "FavouritesStorage"
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
