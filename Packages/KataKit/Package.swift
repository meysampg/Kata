// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "KataKit",
  platforms: [.iOS(.v26), .macOS(.v26)],
  products: [
    .library(name: "KataSRS", targets: ["KataSRS"]),
    .library(name: "KataCode", targets: ["KataCode"]),
    .library(name: "KataDiagram", targets: ["KataDiagram"]),
    .library(name: "KataCore", targets: ["KataCore"]),
    .library(name: "KataUI", targets: ["KataUI"]),
    .library(name: "KataStore", targets: ["KataStore"]),
    .library(name: "KataRun", targets: ["KataRun"]),
    .executable(name: "kata-pack", targets: ["kata-pack"])
  ],
  targets: [
    .target(name: "KataSRS"),
    .target(name: "KataCode"),
    .target(name: "KataDiagram"),
    .target(name: "KataCore", dependencies: ["KataSRS", "KataCode", "KataDiagram"]),
    .target(name: "KataUI", dependencies: ["KataCore", "KataSRS", "KataCode", "KataDiagram"]),
    .target(name: "KataStore", dependencies: ["KataCore", "KataSRS"]),
    // macOS only: spawns a JDK. Never link it into the iOS app.
    .target(name: "KataRun", dependencies: ["KataCore"], resources: [.copy("Harness")]),
    .executableTarget(name: "kata-pack", dependencies: ["KataCore", "KataRun"]),
    .testTarget(name: "KataSRSTests", dependencies: ["KataSRS"]),
    .testTarget(name: "KataCodeTests", dependencies: ["KataCode"]),
    .testTarget(name: "KataDiagramTests", dependencies: ["KataDiagram"]),
    .testTarget(
      name: "KataCoreTests", dependencies: ["KataCore", "KataSRS", "KataDiagram"],
      resources: [.copy("Fixtures")]),
    .testTarget(name: "KataStoreTests", dependencies: ["KataStore", "KataCore", "KataSRS"]),
    .testTarget(name: "KataUITests", dependencies: ["KataUI", "KataSRS", "KataCode"]),
    .testTarget(
      name: "KataRunTests", dependencies: ["KataRun", "KataCore"],
      resources: [.copy("Fixtures")]),
    .testTarget(
      name: "ContentTests",
      dependencies: [
        "KataCore",
        .target(name: "KataRun", condition: .when(platforms: [.macOS]))
      ])
  ]
)
