import Foundation
import Testing

@testable import KataCore

#if os(macOS)
  import KataRun
#endif

/// Repo-level checks on `Content/` and the committed `.kpack` files.
enum ContentPaths {
  /// Packages/KataKit/Tests/ContentTests/ContentTests.swift -> repo root.
  static let root: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  static var content: URL { root.appendingPathComponent("Content", isDirectory: true) }
  static var packs: URL { root.appendingPathComponent("Kata/Resources/Packs", isDirectory: true) }
  static var katas: URL { root.appendingPathComponent("KataMac/Resources/Katas", isDirectory: true) }
  static var javaCheck: URL { root.appendingPathComponent("Tools/JavaCheck.java") }
  static var topics: [URL] { PackBuilder.topicDirectories(contentRoot: content) }
}

#if os(macOS)
  enum KataToolchain {
    static let jdk: JDK? = JDKLocator.default(minimum: 21)
  }
#endif

enum JavaToolchain {
  static let isAvailable: Bool = {
    #if os(macOS)
      return JavaCheckRunner.isJavaAvailable
    #else
      return false
    #endif
  }()
}

/// Every registry item must have content; set to `false` while authoring a new batch so
/// registry items without content are tolerated.
let requireAllItems = true

/// Every registry item must have a kata. Stays `false` until the kata batches (P4) finish.
let requireAllKatas = false

@Suite struct ContentValidationTests {
  @Test func contentDirectoryExists() {
    #expect(!ContentPaths.topics.isEmpty, "no topics under \(ContentPaths.content.path)")
  }

  @Test func strictValidationHasNoErrors() {
    for dir in ContentPaths.topics {
      let issues = PackValidator.validate(
        topicDirectory: dir, options: .init(allowMissing: !requireAllItems))
      #expect(issues.errors.isEmpty, "\(dir.lastPathComponent):\n\(issues.errors.map(\.description).joined(separator: "\n"))")
    }
  }

  @Test func designPatternsRegistryIsComplete() throws {
    let dir = ContentPaths.content.appendingPathComponent("topics/design-patterns")
    let topic = try JSONDecoder().decode(Topic.self, from: Data(contentsOf: dir.appendingPathComponent("topic.json")))
    #expect(topic.items.count == 70)
    #expect(topic.path.count == 8)
    #expect(topic.path.flatMap(\.items).count == 70)
    #expect(Dictionary(grouping: topic.items, by: \.category).mapValues(\.count) == [
      "foundations": 8, "creational": 5, "structural": 7, "behavioral": 11,
      "concurrency": 10, "enterprise": 15, "resilience": 14,
    ])
    #expect(topic.items.filter { $0.category == "foundations" }.allSatisfy { topic.template(for: $0) == topic.templates["principle"] })
  }

  @Test func strategyIsAuthoredAndPassesStrictly() {
    let dir = ContentPaths.content.appendingPathComponent("topics/design-patterns")
    let issues = PackValidator.validate(
      topicDirectory: dir, options: .init(allowMissing: true, items: ["strategy"]))
    #expect(issues.errors.isEmpty, "\(issues)")
  }

  @Test func katasValidateStrictly() {
    for dir in ContentPaths.topics {
      let issues = PackValidator.validate(
        topicDirectory: dir,
        options: .init(allowMissing: !requireAllItems, requireAllKatas: requireAllKatas))
      let kataIssues = issues.filter { $0.path.contains("/kata/") || $0.message.contains("kata") }
      #expect(kataIssues.errors.isEmpty, "\(kataIssues.errors.map(\.description).joined(separator: "\n"))")
      #expect(kataIssues.warnings.isEmpty, "\(kataIssues.warnings.map(\.description).joined(separator: "\n"))")
    }
  }

  @Test func strategyHasARefactorKata() throws {
    let dir = ContentPaths.content.appendingPathComponent("topics/design-patterns")
    let pack = try PackBuilder.buildKatas(topicDirectory: dir)
    let kata = try #require(pack.kata(for: "strategy"))
    #expect(kata.kind == .refactor)
    #expect(kata.checks.map(\.kind) == [.behaviour, .behaviour, .behaviour, .behaviour, .design, .design, .design, .design, .design])
    #expect(kata.starter.map(\.name) == ["Checkout.java"])
    #expect(kata.solution.map(\.name) == ["Checkout.java", "DiscountPolicy.java", "Discounts.java"])
  }

  @Test(.enabled(if: requireAllKatas, "enabled once every kata is authored (P4)"))
  func everyItemHasKata() throws {
    for dir in ContentPaths.topics {
      let report = PackBuilder.load(topicDirectory: dir)
      let have = Set(report.katas.map(\.itemId))
      let missing = (report.topic?.items.map(\.id) ?? []).filter { !have.contains($0) }
      #expect(missing.isEmpty, "items without a kata: \(missing)")
    }
  }

  @Test func kkataIsUpToDate() throws {
    for dir in ContentPaths.topics {
      let katas = try PackBuilder.buildKatas(topicDirectory: dir)
      let committed = ContentPaths.katas.appendingPathComponent("\(dir.lastPathComponent).kkata")
      if katas.katas.isEmpty {
        #expect(!FileManager.default.fileExists(atPath: committed.path), "\(committed.lastPathComponent) should not exist")
        continue
      }
      let fresh = try PackBuilder.encodeKatas(katas)
      let data = try Data(contentsOf: committed)
      #expect(data == fresh, "\(committed.lastPathComponent) is stale: run `kata-pack build`")
      let library = try ContentLibrary(
        urls: [ContentPaths.packs.appendingPathComponent("\(dir.lastPathComponent).kpack")],
        kataURLs: [committed])
      #expect(library.kata(ItemKey(topic: dir.lastPathComponent, item: "strategy"))?.kind == .refactor)
    }
  }

  @Test func committedKpackMatchesFreshBuild() throws {
    for dir in ContentPaths.topics {
      let fresh = try PackBuilder.encode(PackBuilder.build(topicDirectory: dir))
      let committed = ContentPaths.packs.appendingPathComponent("\(dir.lastPathComponent).kpack")
      let data = try Data(contentsOf: committed)
      #expect(data == fresh, "\(committed.lastPathComponent) is stale: run `kata-pack build`")
    }
  }

  @Test func committedKpackLoadsThroughContentLibrary() throws {
    let lib = try ContentLibrary(directory: ContentPaths.packs)
    #expect(lib.topics.map(\.id) == ContentPaths.topics.map(\.lastPathComponent))
    let strategy = lib.item(ItemKey(topic: "design-patterns", item: "strategy"))
    #expect(strategy?.item.cards.map(\.role) == ["definition", "implementation", "example", "structure", "tradeoffs", "compare", "sightings"])
    #expect(strategy?.item.exercises.count == 5)
    #expect(lib.search("policy").first?.key.item == "strategy")
  }

  #if os(macOS)
    @Test(.enabled(if: JavaToolchain.isAvailable, "needs a JDK on PATH"))
    func javaCompilesAndRuns() throws {
      var units: [JavaUnit] = []
      for dir in ContentPaths.topics { units += JavaUnits.units(for: try PackBuilder.build(topicDirectory: dir)) }
      #expect(!units.isEmpty)
      let report = try JavaCheckRunner.check(units: units, script: ContentPaths.javaCheck)
      #expect(report.ok, "\(report.failures)")
      #expect(report.units.count == units.count)
      let strategy = report.units.first { $0.name == "strategy--code-Strategy" }
      #expect(strategy?.output == "NONE -> 50.00\nSPRING10 -> 45.00\nWELCOME -> 42.50")
    }

    /// Reference passes every check and the starter fails the way its kind requires, 3 runs each.
    @Test(.enabled(if: KataToolchain.jdk != nil, "needs a JDK 21+"))
    func kataReferencesPassAndStartersFail() async throws {
      let verifier = KataVerifier(runner: KataCheckRunner(), jdk: KataToolchain.jdk!)
      for dir in ContentPaths.topics {
        let report = PackBuilder.load(topicDirectory: dir)
        for kata in report.katas {
          let concurrency = report.topic?.meta(for: kata.itemId)?.category == "concurrency"
          let v = await verifier.verify(kata, runs: 3, concurrency: concurrency)
          #expect(v.ok, "\(kata.itemId): \(v.failures.joined(separator: "\n"))")
          #expect(v.warnings.isEmpty, "\(kata.itemId): \(v.warnings)")
        }
      }
    }

    @Test(.enabled(if: JavaToolchain.isAvailable, "needs a JDK on PATH"))
    func javaCheckDetectsBrokenUnits() throws {
      let units = [
        JavaUnit(name: "bad-compile", files: ["A.java": "class A { int x = ; }\n"], expectedOutput: nil),
        JavaUnit(name: "bad-output", files: ["Main.java": "class Main { public static void main(String[] a) { System.out.println(\"x\"); } }\n"], expectedOutput: "y"),
        JavaUnit(name: "good", files: ["Main.java": "class Main { public static void main(String[] a) { System.out.println(\"x  \"); } }\n"], expectedOutput: "x"),
      ]
      let report = try JavaCheckRunner.check(units: units, script: ContentPaths.javaCheck)
      #expect(!report.ok)
      #expect(Set(report.failures.map(\.name)) == ["bad-compile", "bad-output"])
      #expect(report.units.first { $0.name == "good" }?.ok == true)
    }
  #endif
}
