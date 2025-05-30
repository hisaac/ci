// swift-tools-version: 6.1

import PackageDescription

let package = Package(
	name: "configulator",
	platforms: [
		.macOS(.v15),
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
		.package(url: "https://github.com/swiftlang/swift-subprocess.git", branch: "main"),
	],
	targets: [
		.executableTarget(
			name: "configulator",
			dependencies: [
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
				.product(name: "Subprocess", package: "swift-subprocess"),
			]
		),
	]
)
