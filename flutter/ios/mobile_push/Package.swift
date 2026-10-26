// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "mobile_push",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "mobile-push", targets: ["mobile_push"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/SallaApp/mobile-push-ios-sdk.git", exact: "1.0.4")
    ],
    targets: [
        .target(
            name: "mobile_push",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "SallaPush", package: "mobile-push-ios-sdk")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
