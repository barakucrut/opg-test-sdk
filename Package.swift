// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OjirePaySDK",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "OjirePaySDK",
            targets: ["OjirePaySDK"]
        ),
    ],
    targets: [
        .target(
            name: "OjirePaySDK",
            path: "Sources/OjirePaySDK"
        ),
        .testTarget(
            name: "OjirePaySDKTests",
            dependencies: ["OjirePaySDK"],
            path: "Tests"
        )
    ]
)
