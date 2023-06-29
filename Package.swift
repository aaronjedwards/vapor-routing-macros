// swift-tools-version: 5.9
import CompilerPluginSupport
import PackageDescription

import PackageDescription

let package = Package(
    name: "VaporRoutingMacros",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "VaporRoutingMacros",
            targets: ["VaporRoutingMacros"]),
        .executable(
            name: "VaporRoutingMacrosExample",
            targets: ["VaporRoutingMacrosExample"]
        ),
        .executable(
          name: "ControllerDiscoveryCLI",
          targets: ["ControllerDiscoveryCLI"]),
        .plugin(
          name: "ControllerDiscoveryPlugin",
          targets: ["ControllerDiscoveryPlugin"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-syntax",
            branch: "main"
        ),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.76.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.2"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .macro(
            name: "VaporRoutingMacrosMacros",
            dependencies: [
                .product(
                    name: "SwiftSyntaxMacros",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftCompilerPlugin",
                    package: "swift-syntax"
                ),
            ]
        ),
        .executableTarget(
            name: "VaporRoutingMacrosExample",
            dependencies: [
                "VaporRoutingMacros",
                    .product(name: "Vapor", package: "vapor")
            ],
            plugins: [
                .plugin(name: "ControllerDiscoveryPlugin")
            ]
        ),
        .target(
            name: "VaporRoutingMacros", dependencies: [
                .product(name: "Vapor", package: "vapor"),
                "VaporRoutingMacrosMacros"
            ]),
        .testTarget(
            name: "VaporRoutingMacrosTests",
            dependencies: [
                "VaporRoutingMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]),
        .executableTarget(
              name: "ControllerDiscoveryCLI",
              dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "Vapor", package: "Vapor"),
              ]),

            .testTarget(
              name: "ControllerDiscoveryCLITests",
              dependencies: [
                "ControllerDiscoveryCLI"
              ]),

            .plugin(
              name: "ControllerDiscoveryPlugin",
              capability: .buildTool(),
              dependencies: [
                "ControllerDiscoveryCLI"
              ]),
    ]
)
