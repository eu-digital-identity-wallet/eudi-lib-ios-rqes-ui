// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "EudiRQESUi",
  platforms: [.iOS(.v17)],
  products: [
    .library(
      name: "EudiRQESUi",
      targets: ["EudiRQESUi"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/Swinject/Swinject.git",
      from: "2.9.1"
    ),
    .package(
      url: "https://github.com/eu-digital-identity-wallet/eudi-lib-ios-rqes-kit.git",
      exact: "0.7.0"
    ),
    .package(
      url: "https://github.com/Brightify/Cuckoo.git",
      from: "2.1.0"
    ),
    .package(
      url: "https://github.com/eu-digital-identity-wallet/SwiftCopyableMacro.git",
      from: "0.0.4"
    ),
  ],
  targets: [
    .target(
      name: "EudiRQESUi",
      dependencies: [
        "Swinject",
        .product(
          name: "RqesKit",
          package: "eudi-lib-ios-rqes-kit"
        ),
        .product(
          name: "Copyable",
          package: "SwiftCopyableMacro"
        )
      ],
      path: "./Sources",
      resources: [
        .process("Resources")
      ]
    ),
    .testTarget(
      name: "EudiRQESUiTests",
      dependencies: [
        "EudiRQESUi",
        .product(
          name: "Cuckoo",
          package: "Cuckoo"
        ),
      ],
      path: "./Tests"
    ),
  ]
)
