// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Trimlet",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Trimlet", targets: ["Trimlet"]),
        .executable(name: "TrimletCoreChecks", targets: ["TrimletCoreChecks"])
    ],
    targets: [
        .target(
            name: "TrimletCore",
            path: "Sources/TrimletCore"
        ),
        .executableTarget(
            name: "Trimlet",
            dependencies: ["TrimletCore"],
            path: "Sources/Trimlet"
        ),
        .executableTarget(
            name: "TrimletCoreChecks",
            dependencies: ["TrimletCore"],
            path: "Checks/TrimletCoreChecks"
        )
    ]
)
