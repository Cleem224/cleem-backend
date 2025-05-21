// swift-tools-version:5.5

let package = Package(
    name: "Cleem",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "Cleem",
            targets: ["Cleem"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.10.0")),
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", .upToNextMajor(from: "7.0.0")),
    ],
    targets: [
        .target(
            name: "Cleem",
            dependencies: [
                "Alamofire",
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")
            ],
            path: "Cleem"
        ),
        .testTarget(
            name: "CleemTests",
            dependencies: ["Cleem"],
            path: "CleemTests"
        ),
    ]
) 