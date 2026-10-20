import Foundation
import KataCore
import KataRun
import KataSRS
import KataStore
import Testing

@testable import KataMac

/// Returns a canned report, so flows that do not need a JDK run anywhere.
private struct FakeChecker: KataChecking {
  var allPass: Bool

  func run(files: [KataFile], kata: Kata) async throws -> KataReport {
    var lines = [#"{"type":"compile","ok":true,"diagnostics":[]}"#]
    for (i, c) in kata.checks.enumerated() {
      let pass = allPass || c.kind == .behaviour
      lines.append(
        #"{"type":"check","id":"\#(c.id)","kind":"\#(c.kind.rawValue)","status":"\#(pass ? "pass" : "fail")","message":"x\#(i)","millis":1}"#)
    }
    lines.append(#"{"type":"done","millis":5}"#)
    return KataReport.parse(ndjson: lines.joined(separator: "\n"))
  }
}

private let haveJDK = JDKLocator.default(minimum: 21) != nil

@MainActor
struct KataSessionModelTests {
  static let key = MacAppModelTests.strategy

  /// A model, its Strategy kata and a clock the test can move.
  final class Clock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
  }

  static func makeSession(
    model: MacAppModel, checker: any KataChecking, clock: Clock = Clock(), root: URL? = nil
  ) -> KataSessionModel {
    let kata = model.library.kata(key)!
    return KataSessionModel(
      key: key, kata: kata, store: model.store, settings: model.settings, checker: checker,
      workspaceRoot: { root ?? FileManager.default.temporaryDirectory.appendingPathComponent("kata-ws-\(UUID().uuidString)") },
      clock: { clock.now })
  }

  static func realChecker(_ model: MacAppModel) -> JavaKataChecker { JavaKataChecker(toolchain: model.toolchain) }

  // MARK: Without a JDK

  @Test func hintLadderLowersTheSuggestedRating() async throws {
    let model = MacAppModelTests.makeModel()
    for (hints, expected) in [(0, Rating.easy), (1, .hard), (2, .hard), (3, .again)] {
      let s = Self.makeSession(model: model, checker: FakeChecker(allPass: true))
      for _ in 0..<hints {
        s.requestHint()
        #expect(s.confirmation == .hint)
        s.confirmation = nil
        s.revealNextHint()
      }
      await s.run()
      #expect(s.passed)
      #expect(s.suggestedRating == expected, "hints: \(hints)")
      #expect(s.hintsRemaining == 3 - hints)
    }
  }

  @Test func revealingTheSolutionSuggestsAgain() async {
    let model = MacAppModelTests.makeModel()
    let s = Self.makeSession(model: model, checker: FakeChecker(allPass: true))
    s.revealSolution()
    #expect(s.aside == .revealed && s.solutionRevealed)
    s.copySolutionIntoEditor()
    #expect(s.files["DiscountPolicy.java"] != nil)
    await s.run()
    #expect(s.suggestedRating == .again)
  }

  @Test func failingChecksDoNotPass() async {
    let model = MacAppModelTests.makeModel()
    let s = Self.makeSession(model: model, checker: FakeChecker(allPass: false))
    await s.run()
    #expect(!s.passed && s.suggestedRating == nil)
    #expect(s.report?.passedCount == 4)
    #expect(s.rate(.good) == nil)
    #expect(model.store.kataCards().isEmpty)
  }

  @Test func ratingCreatesTheCardAndLogsTheAttempt() async throws {
    let model = MacAppModelTests.makeModel()
    let clock = Clock()
    let s = Self.makeSession(model: model, checker: FakeChecker(allPass: true), clock: clock)
    clock.now += 60
    await s.run()
    clock.now += 60
    let result = try #require(s.rate(.good))
    #expect(result.card.due > clock.now)
    let cards = model.store.kataCards()
    #expect(cards.count == 1 && cards[0].key == ProgressStore.kataCardKey(Self.key))
    let attempts = model.store.kataAttempts(for: Self.key)
    #expect(attempts.count == 1 && attempts[0].rating == .good && attempts[0].runCount == 1)
    #expect(attempts[0].activeMillis == 120_000 || attempts[0].activeMillis == 60_000)
    #expect(model.store.lastPassedSolution(Self.key) != nil)
    // The kata card never enters the iOS-style review queue.
    #expect(model.reviewQueue(now: clock.now + 400 * 86_400).isEmpty)
  }

  @Test func idleGapsDoNotCountAsWorkingTime() {
    let model = MacAppModelTests.makeModel()
    let clock = Clock()
    let s = Self.makeSession(model: model, checker: FakeChecker(allPass: true), clock: clock)
    clock.now += 30
    s.noteActivity()
    clock.now += 3_600
    s.noteActivity()
    clock.now += 10
    s.noteActivity()
    #expect(s.activeMillis == 40_000)
  }

  @Test func draftAutosavesAfterOneSecond() async throws {
    let model = MacAppModelTests.makeModel()
    let s = Self.makeSession(model: model, checker: FakeChecker(allPass: true))
    s.setSource("// edited\n", for: "Checkout.java")
    #expect(model.store.kataDraft(Self.key) == nil)
    // The save is debounced by about a second; poll so a busy machine doesn't flake.
    let deadline = ContinuousClock.now + .seconds(10)
    while model.store.kataDraft(Self.key) == nil, ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(100))
    }
    #expect(model.store.kataDraft(Self.key)?["Checkout.java"] == "// edited\n")
    // A new session resumes from the draft.
    let again = Self.makeSession(model: model, checker: FakeChecker(allPass: true))
    #expect(again.files["Checkout.java"] == "// edited\n")
    again.resetToStarter()
    #expect(again.files["Checkout.java"] == again.kata.starter[0].source)
  }

  @Test func reviewStartsFromTheStarterAndHidesThePreviousSolution() async throws {
    let model = MacAppModelTests.makeModel()
    let clock = Clock()
    let first = Self.makeSession(model: model, checker: FakeChecker(allPass: true), clock: clock)
    first.replaceFiles(first.kata.solution)
    await first.run()
    _ = first.rate(.good)
    first.flushDraft()
    #expect(!first.isReview)

    // Not due yet: a new session continues from the draft and may show the previous solution.
    let notDue = Self.makeSession(model: model, checker: FakeChecker(allPass: true), clock: clock)
    #expect(!notDue.isReview && notDue.canShowPrevious)

    #expect(model.store.setKataDue(Self.key, to: clock.now - 1))
    let review = Self.makeSession(model: model, checker: FakeChecker(allPass: true), clock: clock)
    #expect(review.isReview)
    #expect(review.files["Checkout.java"] == review.kata.starter[0].source)
    #expect(review.fileNames == ["Checkout.java"])
    #expect(!review.canShowPrevious)
    review.replaceFiles(review.kata.solution)
    await review.run()
    #expect(review.passed && review.canShowPrevious)
  }

  @Test func dueNowMakesTheKataOfferedAgain() async throws {
    let model = MacAppModelTests.makeModel()
    model.store.markStudied(Self.key)
    let s = Self.makeSession(model: model, checker: FakeChecker(allPass: true))
    await s.run()
    _ = s.rate(.easy)
    #expect(model.dueKatas().isEmpty)
    #expect(model.store.setKataDue(Self.key, to: .now - 60))
    // Done today, so the daily cap still applies; tomorrow it is offered.
    #expect(model.dueKatas(now: .now + 86_400) == [Self.key])
  }

  @Test func noJDKIsAnEmptyStateNotAFailure() async {
    struct NoJDK: KataChecking {
      func run(files: [KataFile], kata: Kata) async throws -> KataReport { throw KataCheckError.noJDK }
    }
    let model = MacAppModelTests.makeModel()
    let s = Self.makeSession(model: model, checker: NoJDK())
    await s.run()
    #expect(s.phase == .noJDK && s.report == nil && !s.passed)
  }

  @Test func rangeOfLineSkipsIndentation() {
    let r = KataSessionModel.range(ofLine: 2, in: "a\n    bc;\nd")
    #expect(r == NSRange(location: 6, length: 3))
    #expect(KataSessionModel.range(ofLine: 9, in: "a") == nil)
  }

  @Test func addedFilesAreOnlyAllowedForNonFixKatas() {
    let model = MacAppModelTests.makeModel()
    let s = Self.makeSession(model: model, checker: FakeChecker(allPass: true))
    #expect(s.addFile(named: "Discounts") == nil && s.fileNames.last == "Discounts.java")
    #expect(s.addFile(named: "Discounts.java") != nil)
    #expect(s.addFile(named: "1bad") != nil)
    s.removeFile("Discounts.java")
    s.removeFile("Checkout.java")  // starter files stay
    #expect(s.fileNames == ["Checkout.java"])
  }

  // MARK: With the real runner

  @Test(.enabled(if: haveJDK)) func strategyEndToEnd() async throws {
    let model = MacAppModelTests.makeModel()
    let s = Self.makeSession(model: model, checker: Self.realChecker(model))
    await s.run()
    let starter = try #require(s.report)
    #expect(starter.compileOK == true)
    #expect(starter.checks.filter { $0.kind == .behaviour }.allSatisfy { $0.passed })
    #expect(starter.checks.filter { $0.kind == .design }.allSatisfy { !$0.passed })
    #expect(!s.passed)
    // A failed design check points into the learner's file.
    #expect(!s.diagnostics(for: "Checkout.java").isEmpty)

    s.replaceFiles(s.kata.solution)
    await s.run()
    #expect(s.passed, "\(String(describing: s.report?.checks.filter { !$0.passed }))")
    #expect(s.report?.passedCount == 9)
    let result = try #require(s.rate(s.suggestedRating ?? .good))
    #expect(result.card.due > .now)
    #expect(model.store.kataCards().count == 1)
  }

  @Test(.enabled(if: haveJDK)) func compileErrorsCarryARangeTheEditorCanJumpTo() async throws {
    let model = MacAppModelTests.makeModel()
    let s = Self.makeSession(model: model, checker: Self.realChecker(model))
    let broken = s.kata.starter[0].source.replacingOccurrences(of: "BigDecimal result;", with: "BigDecimal result = nope;")
    s.setSource(broken, for: "Checkout.java")
    await s.run()
    let report = try #require(s.report)
    #expect(report.compileOK == false)
    let d = try #require(report.errors.first)
    #expect(d.file == "Checkout.java" && d.message.contains("nope"))
    let range = try #require(d.range(in: broken))
    #expect((broken as NSString).substring(with: range) == "nope")
    #expect(s.diagnostics(for: "Checkout.java").contains { $0.range == range })
    s.jump(to: d)
    #expect(s.reveal?.range == range)
    // Editing hides the now-stale markers until the next run.
    s.setSource(broken + " ", for: "Checkout.java")
    #expect(s.diagnostics(for: "Checkout.java").isEmpty)
  }

  @Test(.enabled(if: haveJDK)) func anInfiniteLoopIsReportedAsATimeoutAndTheUIStaysResponsive() async throws {
    let model = MacAppModelTests.makeModel()
    let s = Self.makeSession(model: model, checker: Self.realChecker(model))
    let looping = s.kata.starter[0].source.replacingOccurrences(
      of: "BigDecimal result;", with: "BigDecimal result;\n        if (code != null) { while (true) { } }")
    s.setSource(looping, for: "Checkout.java")
    var ticks = 0
    let ticker = Task { @MainActor in
      while !Task.isCancelled {
        ticks += 1
        try? await Task.sleep(for: .milliseconds(50))
      }
    }
    let began = ContinuousClock.now
    await s.run()
    ticker.cancel()
    let elapsed = ContinuousClock.now - began
    let report = try #require(s.report)
    let timedOut = report.checks.filter { $0.status == .timeout }
    #expect(!timedOut.isEmpty)
    #expect(timedOut.allSatisfy { $0.millis <= 2_000 + 1_000 })
    #expect(elapsed < .seconds(13), "the whole run stays inside the kill limit")
    #expect(ticks > 20, "the main actor kept running during the check")
    #expect(!s.passed)
  }

  @Test(.enabled(if: haveJDK)) func systemExitIsReported() async throws {
    let model = MacAppModelTests.makeModel()
    let s = Self.makeSession(model: model, checker: Self.realChecker(model))
    let exiting = s.kata.starter[0].source.replacingOccurrences(of: "BigDecimal result;", with: "BigDecimal result;\n        System.exit(3);")
    s.setSource(exiting, for: "Checkout.java")
    await s.run()
    let report = try #require(s.report)
    #expect(report.diagnostics.contains { $0.isPolicyViolation && $0.file == "Checkout.java" })
    #expect(report.checks.allSatisfy { !$0.passed } || report.checks.isEmpty)
    #expect(!s.passed)
  }

  @Test(.enabled(if: haveJDK)) func savingInAnIDERerunsTheChecks() async throws {
    let model = MacAppModelTests.makeModel()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("kata-ide-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let s = Self.makeSession(model: model, checker: Self.realChecker(model), root: root)
    await s.startIDEMode(ide: nil, launch: false)
    #expect(s.mode == .ide)
    let src = s.sourceDirectory
    #expect(FileManager.default.fileExists(atPath: src.appendingPathComponent("Checkout.java").path))
    #expect(FileManager.default.fileExists(atPath: s.workspaceDirectory.appendingPathComponent(".idea/modules.xml").path))
    #expect(FileManager.default.fileExists(atPath: s.workspaceDirectory.appendingPathComponent(".vscode/settings.json").path))
    #expect(!s.isEditable("Checkout.java"), "the built-in editor is a read-only mirror in IDE mode")

    // The "IDE" saves the reference solution (one atomic write, two plain ones).
    try await Task.sleep(for: .milliseconds(300))
    for f in s.kata.solution {
      try f.source.write(to: src.appendingPathComponent(f.name), atomically: f.name == "Checkout.java", encoding: .utf8)
    }
    let began = ContinuousClock.now
    while !s.passed, ContinuousClock.now - began < .seconds(20) { try await Task.sleep(for: .milliseconds(100)) }
    #expect(s.passed, "a save in the IDE re-ran the checks and they passed")
    #expect(s.files["Discounts.java"] != nil, "files created in the IDE show up as tabs")
    #expect(s.runCount >= 1)

    s.leaveIDEMode()
    #expect(s.mode == .builtIn && s.isEditable("Checkout.java"))
  }
}
