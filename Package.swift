// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Futures",
    platforms: [.iOS(.v11), .macOS(.v10_12)],

    products: [
        .library(
            name: "Futures",
            targets: ["Futures"]
        ),
    ],

    dependencies: [
        .package(name: "swift-collections",
                 url: "https://github.com/apple/swift-collections.git",
                 from: "0.0.7")
    ],

    targets: [
        .target(
            name: "Futures",
            dependencies: [
                .product(name: "Collections", package: "swift-collections")
            ]
        ),

        .testTarget(
            name: "FuturesTests",
            dependencies: ["Futures"]
        ),
    ]
)
