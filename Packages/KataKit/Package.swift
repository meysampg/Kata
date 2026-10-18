// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "KataKit",
  platforms: [.iOS(.v26), .macOS(.v15)],
  products: [
    .library(name: "KataSRS", targets: ["KataSRS"]),
    .library(name: "KataCode", targets: ["KataCode"]),
    .library(name: "KataDiagram", targets: ["KataDiagram"]),
    .library(name: "KataCore", targets: ["KataCore"]),
    .library(name: "KataUI", targets: ["KataUI"]),
    .executable(name: "kata-pack", targets: ["kata-pack"])
  ],
  targets: [
    .target(name: "KataSRS"),
    .target(name: "KataCode"),
    .target(name: "KataDiagram"),
    .target(name: "KataCore", dependencies: ["KataSRS", "KataCode", "KataDiagram"]),
    .target(name: "KataUI", dependencies: ["KataCore", "KataSRS", "KataCode", "KataDiagram"]),
    .executableTarget(name: "kata-pack", dependencies: ["KataCore"]),
    .testTarget(name: "KataSRSTests", dependencies: ["KataSRS"]),
    .testTarget(name: "KataCodeTests", dependencies: ["KataCode"]),
    .testTarget(name: "KataDiagramTests", dependencies: ["KataDiagram"]),
    .testTarget(
      name: "KataCoreTests", dependencies: ["KataCore", "KataSRS", "KataDiagram"],
      resources: [.copy("Fixtures")]),
    .testTarget(name: "KataUITests", dependencies: ["KataUI", "KataSRS", "KataCode"]),
    .testTarget(name: "ContentTests", dependencies: ["KataCore"])
  ]
)
