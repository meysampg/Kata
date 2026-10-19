import Foundation
import KataSRS
import Testing

@testable import KataCore

enum KataFixtures {
  static let testSource = """
    import kata.*;
    class DemoTest {
        @Check(id = "same-totals") void a() { }
        @Check(id = "stays-positive", timeoutMs = 500) void b() { }
        @Check(id = "has-interface", kind = Kind.DESIGN) void c() { }
        @Check(id = "no-branching", kind = Kind.DESIGN,
               repeat = 2) void d() { }
    }

    """

  static func good() -> Kata {
    Kata(
      itemId: "alpha", kind: .refactor, title: "Take the branches out", minutes: 20,
      task: [.lead("Remove the branches."), .paragraph("Keep `Demo.run` working.")],
      starter: [KataFile(name: "Demo.java", source: "final class Demo {\n    int run() { return 1; }\n}\n")],
      solution: [
        KataFile(name: "Demo.java", source: "final class Demo {\n    int run() { return 1; }\n}\n"),
        KataFile(name: "Rule.java", source: "interface Rule {\n    int apply(int x);\n}\n"),
      ],
      tests: [KataFile(name: "DemoTest.java", source: testSource)],
      checks: [
        KataCheckSpec(id: "same-totals", kind: .behaviour, title: "Same totals"),
        KataCheckSpec(id: "stays-positive", kind: .behaviour, title: "Stays positive"),
        KataCheckSpec(id: "has-interface", kind: .design, title: "Has an interface"),
        KataCheckSpec(id: "no-branching", kind: .design, title: "No branching"),
      ],
      hints: [
        [.paragraph("Find what varies.")], [.paragraph("Name it.")],
        [.paragraph("Then:"), .code(language: "java", lines: ["interface Rule { }"])],
      ])
  }

  static func issues(_ edit: (inout Kata) -> Void) throws -> [ValidationIssue] {
    var k = good()
    edit(&k)
    let topic = try Fixtures.miniPack().topic
    return KataValidator.validate(katas: [k], topic: topic)
  }

  /// A scratch copy of the mini topic with a kata directory for `alpha`.
  static func scratchTopic(
    manifest: String? = nil, edit: (URL) throws -> Void = { _ in }
  ) throws -> URL {
    let dir = try Fixtures.scratchCopy()
    let kata = dir.appendingPathComponent("items/alpha/kata", isDirectory: true)
    let fm = FileManager.default
    for sub in ["starter", "solution", "tests"] {
      try fm.createDirectory(at: kata.appendingPathComponent(sub), withIntermediateDirectories: true)
    }
    let g = good()
    for (sub, files) in [("starter", g.starter), ("solution", g.solution), ("tests", g.tests)] {
      for f in files { try f.source.write(to: kata.appendingPathComponent("\(sub)/\(f.name)"), atomically: true, encoding: .utf8) }
    }
    let json = manifest ?? """
      {
        "kind": "refactor", "title": "Take the branches out", "minutes": 20,
        "task": [{"type": "lead", "text": "Remove the branches."}, {"type": "p", "text": "Keep `Demo.run` working."}],
        "starter": ["Demo.java"], "solution": ["Demo.java", "Rule.java"], "tests": ["DemoTest.java"],
        "checks": [
          {"id": "same-totals", "kind": "behaviour", "title": "Same totals"},
          {"id": "stays-positive", "kind": "behaviour", "title": "Stays positive"},
          {"id": "has-interface", "kind": "design", "title": "Has an interface"},
          {"id": "no-branching", "kind": "design", "title": "No branching"}],
        "hints": [[{"type": "p", "text": "Find what varies."}], [{"type": "p", "text": "Name it."}],
          [{"type": "p", "text": "Then:"}, {"type": "code", "language": "java", "lines": ["interface Rule { }"]}]]
      }
      """
    try json.write(to: kata.appendingPathComponent("kata.json"), atomically: true, encoding: .utf8)
    try edit(kata)
    return dir
  }
}

@Suite struct KataModelTests {
  @Test func embeddedFormRoundTripsAndEncodesReproducibly() throws {
    var k = KataFixtures.good()
    k.readOnly = ["Demo.java"]
    k.stressRuns = 20
    k.starterCompiles = false
    let pack = KataPack(topicId: "mini-topic", katas: [k])
    let a = try PackBuilder.encodeKatas(pack)
    let b = try PackBuilder.encodeKatas(pack)
    #expect(a == b)
    let decoded = try JSONDecoder().decode(KataPack.self, from: a)
    #expect(decoded == pack)
    #expect(decoded.kata(for: "alpha")?.effectiveStressRuns == 20)
    #expect(String(decoding: a, as: UTF8.self).contains("\"starterCompiles\":false"))
  }

  @Test func defaultsAreNotEncoded() throws {
    let data = try PackBuilder.encodeKatas(KataPack(topicId: "t", katas: [KataFixtures.good()]))
    let text = String(decoding: data, as: UTF8.self)
    #expect(!text.contains("starterCompiles") && !text.contains("stressRuns") && !text.contains("readOnly"))
    #expect(KataFixtures.good().effectiveStressRuns == 5)
    #expect(KataFixtures.good().timeoutSeconds == 10)
  }

  @Test func strictDecodingRejectsUnknownKeysAndKinds() throws {
    let dir = try KataFixtures.scratchTopic(
      manifest: """
        {"kind": "refactor", "title": "T", "minutes": 20, "task": [], "starter": [], "solution": [], "tests": [],
         "checks": [], "hints": [], "difficulty": 3}
        """)
    let r = PackBuilder.load(topicDirectory: dir)
    #expect(r.issues.hasError(containing: "Unknown key(s): difficulty"))
    #expect(r.katas.isEmpty)

    let dir2 = try KataFixtures.scratchTopic(
      manifest: """
        {"kind": "rewrite", "title": "T", "minutes": 20, "task": [], "starter": [], "solution": [], "tests": [],
         "checks": [], "hints": []}
        """)
    #expect(!PackBuilder.load(topicDirectory: dir2).issues.errors.isEmpty)

    let embedded = #"{"topicId":"t","katas":[],"extra":1}"#
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(KataPack.self, from: Data(embedded.utf8)) }
  }

  @Test func blocksInTheTaskAreStrictToo() throws {
    let dir = try KataFixtures.scratchTopic(
      manifest: """
        {"kind": "fix", "title": "T", "minutes": 20, "task": [{"type": "p", "text": "x", "colour": "red"}],
         "starter": ["Demo.java"], "solution": ["Demo.java"], "tests": ["DemoTest.java"], "checks": [], "hints": []}
        """)
    #expect(PackBuilder.load(topicDirectory: dir).issues.hasError(containing: "Unknown key(s): colour"))
  }
}

@Suite struct KataLoaderTests {
  @Test func loadsAndEmbedsFiles() throws {
    let dir = try KataFixtures.scratchTopic()
    let r = PackBuilder.load(topicDirectory: dir)
    #expect(r.issues.errors.isEmpty, "\(r.issues)")
    let k = try #require(r.katas.first)
    #expect(k == KataFixtures.good())
    let all = PackValidator.validate(topicDirectory: dir)
    #expect(all.errors.isEmpty, "\(all)")
    #expect(try PackBuilder.buildKatas(topicDirectory: dir).katas.count == 1)
  }

  @Test func itemsWithoutKataLoadNone() throws {
    let r = PackBuilder.load(topicDirectory: Fixtures.miniTopic)
    #expect(r.katas.isEmpty)
    #expect(try PackBuilder.buildKatas(topicDirectory: Fixtures.miniTopic).katas.isEmpty)
  }

  @Test func strayAndMissingFilesAreErrors() throws {
    let stray = try KataFixtures.scratchTopic { kata in
      try "class Extra {}".write(to: kata.appendingPathComponent("starter/Extra.java"), atomically: true, encoding: .utf8)
      try "x".write(to: kata.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
    }
    let issues = PackBuilder.load(topicDirectory: stray).issues
    #expect(issues.hasError(containing: "not listed in kata.json starter"))
    #expect(issues.hasError(containing: "unexpected entry in kata/"))

    let missing = try KataFixtures.scratchTopic { kata in
      try FileManager.default.removeItem(at: kata.appendingPathComponent("solution/Rule.java"))
    }
    #expect(PackBuilder.load(topicDirectory: missing).issues.hasError(containing: "listed in kata.json but cannot be read"))
  }

  @Test func listedNamesMustBePlainJavaFiles() throws {
    let dir = try KataFixtures.scratchTopic(
      manifest: """
        {"kind": "fix", "title": "T", "minutes": 20, "task": [{"type": "p", "text": "x"}],
         "starter": ["../Demo.java", "Readme.md"], "solution": [], "tests": [], "checks": [], "hints": []}
        """)
    let issues = PackBuilder.load(topicDirectory: dir).issues
    #expect(issues.filter { $0.message.contains("plain name ending in .java") }.count == 2)
  }

  @Test func kkataBytesAreReproducible() throws {
    let dir = try KataFixtures.scratchTopic()
    let a = try PackBuilder.encodeKatas(PackBuilder.buildKatas(topicDirectory: dir))
    let b = try PackBuilder.encodeKatas(PackBuilder.buildKatas(topicDirectory: dir))
    #expect(a == b)
  }

  @Test func kpackIsUnaffectedByKatas() throws {
    let dir = try KataFixtures.scratchTopic()
    let with = try PackBuilder.encode(PackBuilder.build(topicDirectory: dir))
    let without = try PackBuilder.encode(PackBuilder.build(topicDirectory: Fixtures.miniTopic))
    #expect(with == without)
  }

  @Test func libraryExposesKatasByItem() throws {
    let pack = try Fixtures.miniPack()
    let lib = ContentLibrary(packs: [pack], kataPacks: [KataPack(topicId: pack.topic.id, katas: [KataFixtures.good()])])
    #expect(lib.kata(ItemKey(topic: pack.topic.id, item: "alpha"))?.title == "Take the branches out")
    #expect(lib.kata(ItemKey(topic: pack.topic.id, item: "beta")) == nil)
    #expect(ContentLibrary(packs: [pack]).katas.isEmpty)
  }
}

@Suite struct KataValidatorTests {
  @Test func goodKataHasNoErrors() throws {
    let issues = try KataFixtures.issues { _ in }
    #expect(issues.isEmpty, "\(issues)")
  }

  @Test func headerLimits() throws {
    #expect(try KataFixtures.issues { $0.title = String(repeating: "x", count: 61) }.hasError(containing: "title has 61"))
    #expect(try KataFixtures.issues { $0.minutes = 5 }.hasError(containing: "minutes 5"))
    #expect(try KataFixtures.issues { $0.minutes = 41 }.hasError(containing: "minutes 41"))
    #expect(try KataFixtures.issues { $0.timeoutSeconds = 31 }.hasError(containing: "timeoutSeconds 31"))
    #expect(try KataFixtures.issues { $0.stressRuns = 0 }.hasError(containing: "stressRuns 0"))
    #expect(try KataFixtures.issues { $0.starterCompiles = false }.hasError(containing: "only allowed for implement"))
    #expect(try KataFixtures.issues { $0.title = " " }.hasError(containing: "empty title"))
  }

  @Test func taskAndHintLimits() throws {
    let long = Array(repeating: "word", count: 181).joined(separator: " ")
    #expect(try KataFixtures.issues { $0.task = [.paragraph(long)] }.hasError(containing: "task has 181 words"))
    #expect(try KataFixtures.issues { $0.hints.removeLast() }.hasError(containing: "exactly 3 hints"))
    let wordy = Array(repeating: "word", count: 51).joined(separator: " ")
    #expect(try KataFixtures.issues { $0.hints[0] = [.paragraph(wordy)] }.hasError(containing: "hint 1 has 51 words"))
    #expect(try KataFixtures.issues { $0.hints[0] = [.code(language: "java", lines: ["x"])] }.hasError(containing: "hint 1 has a code block"))
    let tall = Array(repeating: "x();", count: 11)
    #expect(try KataFixtures.issues { $0.hints[2] = [.code(language: "java", lines: tall)] }.hasError(containing: "hint 3 code has 11 lines"))
    #expect(try KataFixtures.issues { $0.hints[1] = [] }.hasError(containing: "hint 2 is empty"))
  }

  @Test func kataLinksMustResolve() throws {
    #expect(try KataFixtures.issues { $0.task = [.paragraph("See [Ghost](kata:ghost).")] }.hasError(containing: "kata:ghost"))
    #expect(try KataFixtures.issues { $0.hints[0] = [.paragraph("See [Beta](kata:beta).")] }.isEmpty)
  }

  @Test func fileLimits() throws {
    let many = String(repeating: "int x;\n", count: 121)
    #expect(try KataFixtures.issues { $0.starter[0].source = many }.hasError(containing: "121 lines (max 120)"))
    let manySolution = String(repeating: "int x;\n", count: 151)
    #expect(try KataFixtures.issues { $0.solution[1].source = manySolution }.hasError(containing: "151 lines (max 150)"))
    let wide = "// " + String(repeating: "x", count: 90) + "\n"
    #expect(try KataFixtures.issues { $0.starter[0].source = wide }.hasWarning(containing: "exceed 80 columns"))
    let tooWide = "// " + String(repeating: "x", count: 98) + "\n"
    #expect(try KataFixtures.issues { $0.starter[0].source = tooWide }.hasError(containing: "exceed 100 columns"))
    #expect(try KataFixtures.issues { $0.starter[0].source += "public class Demo2 {}\n" }.hasError(containing: "must not be public"))
  }

  @Test func exitIsForbidden() throws {
    #expect(try KataFixtures.issues { $0.starter[0].source += "// x\nclass E { void f() { System.exit(1); } }\n" }.hasError(containing: "System.exit"))
    #expect(try KataFixtures.issues { $0.solution[0].source += "class E { void f() { Runtime.getRuntime().halt(1); } }\n" }.hasError(containing: "System.exit"))
  }

  @Test func readOnlyRules() throws {
    #expect(try KataFixtures.issues { $0.readOnly = ["Ghost.java"] }.hasError(containing: "not a starter file"))
    #expect(try KataFixtures.issues {
      $0.readOnly = ["Demo.java"]
      $0.solution[0].source = "final class Demo { int run() { return 2; } }\n"
    }.hasError(containing: "identical in starter and solution"))
    #expect(try KataFixtures.issues { $0.readOnly = ["Demo.java"] }.isEmpty)
  }

  @Test func testsMustNotRedeclareSolutionTypes() throws {
    #expect(try KataFixtures.issues { $0.tests[0].source += "interface Rule {}\n" }.hasError(containing: "declares type Rule"))
  }

  @Test func checkRules() throws {
    #expect(try KataFixtures.issues { $0.checks[1].id = "Not Kebab" }.hasError(containing: "not kebab-case"))
    #expect(try KataFixtures.issues {
      $0.checks[1].id = "same-totals"
      $0.tests[0].source = $0.tests[0].source.replacingOccurrences(of: "stays-positive", with: "same-totals")
    }.hasError(containing: "duplicate check id"))
    #expect(try KataFixtures.issues { $0.checks.swapAt(0, 1) }.hasError(containing: "do not match the @Check ids"))
    #expect(try KataFixtures.issues { $0.checks[2].kind = .behaviour }.hasError(containing: "is behaviour in kata.json but design in the test"))
    #expect(try KataFixtures.issues { $0.checks[1].title = "" }.hasError(containing: "empty title"))
  }

  @Test func kindSpecificMinimums() throws {
    // refactor: 2 behaviour + 2 design
    let oneDesign = try KataFixtures.issues {
      $0.checks.removeLast()
      $0.tests[0].source = KataFixtures.testSource.replacingOccurrences(of: "@Check(id = \"no-branching\", kind = Kind.DESIGN,\n           repeat = 2) void d() { }", with: "")
    }
    #expect(oneDesign.hasError(containing: "at least 2 design checks"))
    // implement: >= 4 checks in total
    let few = try KataFixtures.issues {
      $0.kind = .implement
      $0.checks.removeLast()
      $0.tests[0].source = KataFixtures.testSource.replacingOccurrences(of: "@Check(id = \"no-branching\", kind = Kind.DESIGN,\n           repeat = 2) void d() { }", with: "")
    }
    #expect(few.hasError(containing: "at least 4 checks"))
    // fix: >= 1 behaviour
    let designOnly = try KataFixtures.issues {
      $0.kind = .fix
      $0.checks = $0.checks.filter { $0.kind == .design }
      $0.tests[0].source = KataFixtures.testSource
        .replacingOccurrences(of: "@Check(id = \"same-totals\") void a() { }", with: "")
        .replacingOccurrences(of: "@Check(id = \"stays-positive\", timeoutMs = 500) void b() { }", with: "")
    }
    #expect(designOnly.hasError(containing: "at least 1 behaviour check"))
    let implementOK = try KataFixtures.issues { $0.kind = .implement }
    #expect(implementOK.isEmpty, "\(implementOK)")
  }

  @Test func implementKatasMayHaveANonCompilingStarter() throws {
    #expect(try KataFixtures.issues { $0.kind = .implement; $0.starterCompiles = false }.isEmpty)
  }

  @Test func requireAllKatasFlag() throws {
    let topic = try Fixtures.miniPack().topic
    let lenient = KataValidator.validate(katas: [KataFixtures.good()], topic: topic, options: .init())
    #expect(lenient.isEmpty)
    let strict = KataValidator.validate(
      katas: [KataFixtures.good()], topic: topic, options: .init(requireAllKatas: true))
    #expect(strict.hasError(containing: "registry item has no kata/"))
    #expect(strict.filter { $0.path.hasSuffix("/beta") }.count == 1)
  }

  @Test func unknownItemAndDuplicates() throws {
    let topic = try Fixtures.miniPack().topic
    var ghost = KataFixtures.good()
    ghost.itemId = "ghost"
    #expect(KataValidator.validate(katas: [ghost], topic: topic).hasError(containing: "not in the registry"))
    #expect(KataValidator.validate(katas: [KataFixtures.good(), KataFixtures.good()], topic: topic).hasError(containing: "duplicate kata"))
  }

  @Test func exerciseIdKataIsReserved() throws {
    let pack = try Fixtures.miniPack().editingItem("alpha") { item in
      item.exercises[0].id = "kata"
    }
    #expect(PackValidator.validate(pack: pack).hasError(containing: "reserved"))
  }

  @Test func checkIdExtractionFollowsSourceOrderAndKinds() {
    let found = KataValidator.checkIds(in: KataFixtures.testSource)
    #expect(found.map(\.id) == ["same-totals", "stays-positive", "has-interface", "no-branching"])
    #expect(found.map(\.kind) == [.behaviour, .behaviour, .design, .design])
  }
}

@Suite struct KataGraderTests {
  func suggest(_ hints: Int = 0, revealed: Bool = false, minutes: Double = 10, min: Int = 20, runs: Int = 1) -> Rating {
    KataGrader.suggest(hints: hints, revealed: revealed, activeMillis: Int(minutes * 60_000), minutes: min, runs: runs)
  }

  @Test func revealedOrThreeHintsIsAgain() {
    #expect(suggest(0, revealed: true) == .again)
    #expect(suggest(3) == .again)
    #expect(suggest(1, revealed: true, minutes: 1) == .again)
  }

  @Test func someHintsIsHard() {
    #expect(suggest(1, minutes: 1) == .hard)
    #expect(suggest(2, minutes: 1) == .hard)
  }

  @Test func noHintsIsEasyGoodOrHardByTimeAndRuns() {
    #expect(suggest(minutes: 12, runs: 3) == .easy)  // exactly 0.6 x 20
    #expect(suggest(minutes: 12.1, runs: 1) == .good)
    #expect(suggest(minutes: 5, runs: 4) == .good)  // fast but too many runs
    #expect(suggest(minutes: 30, runs: 1) == .good)  // exactly 1.5 x 20
    #expect(suggest(minutes: 30.1, runs: 1) == .hard)
    #expect(suggest(minutes: 0, runs: 0) == .easy)
  }
}

@Suite struct KataQueueTests {
  var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
  }
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  func key(_ s: String) -> ItemKey { ItemKey(topic: "t", item: s) }
  func card(_ s: String, dueHoursAgo: Double, reviewedHoursAgo: Double? = nil) -> KataCardSnapshot {
    KataCardSnapshot(
      item: key(s), due: now.addingTimeInterval(-dueHoursAgo * 3600),
      lastReview: reviewedHoursAgo.map { now.addingTimeInterval(-$0 * 3600) })
  }

  @Test func defaultIsTwoPerDay() {
    #expect(KataQueue().katasPerDay == 2)
  }

  @Test func dueFirstMostOverdueFirstThenNewCappedAtTwo() {
    let q = KataQueue(calendar: cal)
    let cards = [card("a", dueHoursAgo: 5), card("b", dueHoursAgo: 50), card("c", dueHoursAgo: -10)]
    #expect(q.build(cards: cards, newCandidates: [key("x")], now: now) == [key("b"), key("a")])
    #expect(q.build(cards: [card("c", dueHoursAgo: -10)], newCandidates: [key("x"), key("y"), key("x")], now: now) == [key("x"), key("y")])
    #expect(q.build(cards: [card("a", dueHoursAgo: 1)], newCandidates: [key("x"), key("y")], now: now) == [key("a"), key("x")])
  }

  @Test func katasDoneTodayUseUpTheBudget() {
    let q = KataQueue(calendar: cal)
    let one = [card("done", dueHoursAgo: -24, reviewedHoursAgo: 0.1), card("a", dueHoursAgo: 3)]
    #expect(q.build(cards: one, newCandidates: [key("x")], now: now) == [key("a")])
    let two = one + [card("done2", dueHoursAgo: -24, reviewedHoursAgo: 0.2)]
    #expect(q.build(cards: two, newCandidates: [key("x")], now: now).isEmpty)
  }

  @Test func enrolledItemsAreNotNewAndLimitIsConfigurable() {
    let q = KataQueue(katasPerDay: 4, calendar: cal)
    let out = q.build(cards: [card("a", dueHoursAgo: -1)], newCandidates: [key("a"), key("b"), key("c"), key("d"), key("e"), key("f")], now: now)
    #expect(out == [key("b"), key("c"), key("d"), key("e")])
    #expect(KataQueue(katasPerDay: 0).build(cards: [], newCandidates: [key("a")], now: now).isEmpty)
  }
}
