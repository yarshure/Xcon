// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.
//AEADCrypto.swift:12:8: error: no such module 'Sodium'
import PackageDescription

let package = Package(
    name: "Xcon",
    platforms: [
        .macOS(.v10_11), .iOS(.v12),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "Xcon",
            targets: ["Xcon"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
	.package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0"),
        .package(url: "https://github.com/yarshure/XSocket",  .branch("SwiftPM")),
        .package(url: "https://github.com/networkextension/libkcp.git",  .branch("SwiftPM")),
	.package(url: "https://github.com/tristanhimmelman/ObjectMapper", .branch("master")),
	.package(url: "https://github.com/yarshure/XFoundation", .branch("Package")),
    .package(url:"http://github.com/networkextension/DarwinCore.git",.branch("SwiftPM")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Xcon",
            dependencies: ["SwiftyJSON","XSocket","ObjectMapper","XFoundation","DarwinCore"],
            //path:"Xcon",
            exclude:["Xcon/kcp/KCP.swift","SnappyHelper.swif"],
            cSettings: [
                .headerSearchPath("../libsodium-1.0.18-RELEASE/libsodium-osx/include"),
            ],
            linkerSettings:[
                .linkedFramework("libsodium-1.0.18-RELEASE/libsodium-osx/lib/libsodium.23.dylib", .when(platforms: [.macOS,.iOS], configuration: .debug)),
                .linkedFramework("Sodium", .when(platforms: [.macOS,.iOS], configuration: .release)),
        ]),
        .testTarget(
            name: "XconTests",
            dependencies: ["Xcon"]),
        
    ],
    cxxLanguageStandard: .cxx11
)
