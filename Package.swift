// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Hairpin",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Hairpin",
            path: "Hairpin/Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        )
    ]
)
