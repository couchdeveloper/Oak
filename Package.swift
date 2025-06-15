// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Oak",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .macCatalyst(.v15),
        .tvOS(.v12),
    ],
    products: [
        .library(
            name: "Oak",
            targets: [ModuleName.oak]
        ),
    ],
    dependencies: [],
    targets: [
        .oak,
        .testTarget(
            name: Test.oak,
            dependencies: [.oak]
        ),
    ]
)

enum ModuleName {
    static let oak = "Oak"
}

enum Test {
    static let oak = "OakTests"
}

extension Target.Dependency {
    static var oak: Target.Dependency {
        .target(name: ModuleName.oak)
    }
}

extension Target {
    static var oak: Target {
        .target(name: ModuleName.oak)
    }
}
