// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MealDBKit",
    platforms: [
        .iOS(.v17),
        // macOS only so `swift test` runs on CI; the views are made for iPhone and iPad.
        .macOS(.v14),
    ],
    products: [
        .library(name: "MealDBKit", targets: ["MealDBKit"]),
        .library(name: "MealDBUI", targets: ["MealDBUI"]),
    ],
    targets: [
        .target(name: "MealDBKit"),
        .target(name: "MealDBUI", dependencies: ["MealDBKit"]),
        .testTarget(
            name: "MealDBKitTests",
            dependencies: ["MealDBKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
