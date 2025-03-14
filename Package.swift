// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "OcaFirmwareImageContainer",
  platforms: [
    .macOS(.v14),
    .iOS(.v17),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to
    // other packages.
    .library(
      name: "OcaFirmwareImageContainer",
      targets: ["OcaFirmwareImageContainer"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/PADL/SwiftOCA", branch: "main"),
    .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "4.0.0"),
    .package(url: "https://github.com/apple/swift-system", from: "1.2.1"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "OcaFirmwareImageContainer",
      dependencies: [
        "SwiftOCA",
        .product(name: "Crypto", package: "swift-crypto"),
        .product(name: "SystemPackage", package: "swift-system")
      ]
    )
  ]
)
