// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var swiftSettings : [SwiftSetting] = [
    .unsafeFlags(["-Rmodule-loading"]),
    .enableUpcomingFeature("MemberImportVisibility"),
    .define("USE_PACKAGE"),
]


let package = Package(
    name: "benchmarks",
    platforms: [.macOS(.v15), .iOS(.v16)],
    products: [
        .library(
            name: "oak_benchmark",
            targets: ["oak_benchmark"]
        ),
    ],

    dependencies: [
        .package(path: "../../Oak"),
        .package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .target(
            name: "oak_benchmark",
            dependencies: [
                .byName(name: "Oak")
            ]
        ),

        .executableTarget(
            name: "benchmark",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                .byName(name: "Oak")
            ],
            path: "Benchmarks/benchmark",
            // swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark"),
            ]
        ),
    ]
)
