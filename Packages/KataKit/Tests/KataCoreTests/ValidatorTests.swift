import Foundation
import KataDiagram
import Testing

@testable import KataCore

@Suite struct ValidatorTests {
  let pack: Pack
  init() throws { pack = try Fixtures.miniPack() }

  func validate(_ p: Pack, _ o: ValidationOptions = .init()) -> [ValidationIssue] {
    PackValidator.validate(pack: p, options: o)
  }

  @Test func miniTopicHasNoErrors() {
    let issues = PackValidator.validate(topicDirectory: Fixtures.miniTopic)
    #expect(issues.errors.isEmpty, "\(issues)")
    // only the intentional single-row comparison warnings
    #expect(issues.warnings.allSatisfy { $0.message.contains("comparison has 1 rows") }, "\(issues.warnings)")
  }

  // MARK: Directory-level problems

  @Test func unknownKeyIsReported() {
    let issues = PackValidator.validate(topicDirectory: Fixtures.broken("unknown-key"))
    #expect(issues.hasError(containing: "Unknown key(s): colour"))
  }

  @Test func unclosedMarkerIsReported() {
    let issues = PackValidator.validate(topicDirectory: Fixtures.broken("bad-markers"))
    #expect(issues.hasError(containing: "never closed"))
  }

  @Test func registryAndDirectoriesMustMatch() {
    let dir = Fixtures.broken("orphan-and-missing")
    let strict = PackValidator.validate(topicDirectory: dir)
    #expect(strict.hasError(containing: "registry item has no items/missing/"))
    #expect(strict.hasError(containing: "items/stray is not in the topic registry"))
    let lenient = PackValidator.validate(topicDirectory: dir, options: .init(allowMissing: true))
    #expect(!lenient.hasError(containing: "registry item has no"))
    #expect(lenient.hasError(containing: "items/stray is not in the topic registry"))
  }

  @Test func topicIdMustMatchDirectory() throws {
    let dir = try Fixtures.scratchCopy()
    try Fixtures.edit(dir.appendingPathComponent("topic.json")) {
      $0.replacingOccurrences(of: "\"id\": \"mini-topic\"", with: "\"id\": \"other\"")
    }
    #expect(PackValidator.validate(topicDirectory: dir).hasError(containing: "does not match directory"))
  }

  @Test func itemIdMustMatchDirectory() throws {
    let dir = try Fixtures.scratchCopy()
    try Fixtures.edit(dir.appendingPathComponent("items/beta/item.json")) {
      $0.replacingOccurrences(of: "\"id\": \"beta\",\n  \"cards\"", with: "\"id\": \"gamma\",\n  \"cards\"")
    }
    #expect(PackValidator.validate(topicDirectory: dir).hasError(containing: "does not match directory"))
  }

  @Test func itemsFilterRestrictsItemChecks() throws {
    let dir = try Fixtures.scratchCopy()
    try Fixtures.edit(dir.appendingPathComponent("items/beta/item.json")) {
      $0.replacingOccurrences(of: "\"difficulty\"", with: "\"difficulty\"")  // no-op, keep valid JSON
    }
    let broken = pack.editingItem("beta") { $0.exercises.removeAll { $0.kind == .recall } }
    #expect(validate(broken).hasError(containing: "missing required exercise"))
    #expect(!validate(broken, .init(items: ["alpha"])).hasError(containing: "missing required exercise"))
    #expect(validate(broken, .init(items: ["nope"])).hasError(containing: "not in the topic registry"))
  }

  // MARK: Topic rules

  @Test func idsMustBeKebabCaseAndUnique() {
    let p = pack.editingTopic {
      $0.items[0].id = "Alpha_One"
      $0.items[1].id = "Alpha_One"
    }
    let issues = validate(p, .init(allowMissing: true))
    #expect(issues.hasError(containing: "not kebab-case"))
    #expect(issues.hasError(containing: "duplicate item id"))
  }

  @Test func registryFieldRules() {
    let p = pack.editingTopic {
      $0.items[0].difficulty = 4
      $0.items[0].category = "nope"
      $0.items[1].intent = " "
      $0.items[1].title = ""
    }
    let issues = validate(p, .init(allowMissing: true))
    #expect(issues.hasError(containing: "difficulty 4"))
    #expect(issues.hasError(containing: "unknown category"))
    #expect(issues.hasError(containing: "empty intent"))
    #expect(issues.hasError(containing: "empty title"))
  }

  @Test func templatesAndCategoriesMustResolve() {
    let p = pack.editingTopic {
      $0.templates["full"]!.roles.append("ghost")
      $0.categories[1].template = "none"
    }
    let issues = validate(p, .init(allowMissing: true))
    #expect(issues.hasError(containing: "unknown role 'ghost'"))
    #expect(issues.hasError(containing: "unknown template 'none'"))
  }

  @Test func pathMustContainEveryItemExactlyOnce() {
    var p = pack.editingTopic { $0.path[1].items = ["alpha"] }
    var issues = validate(p)
    #expect(issues.hasError(containing: "item 'beta' is missing from the path"))
    #expect(issues.hasError(containing: "item 'alpha' appears 2 times"))
    p = pack.editingTopic { $0.path[0].items.append("ghost") }
    issues = validate(p)
    #expect(issues.hasError(containing: "unknown item 'ghost'"))
  }

  // MARK: Cards

  @Test func cardsMustMatchTemplate() {
    var p = pack.editingItem("alpha") { $0.cards.removeAll { $0.role == "tradeoffs" } }
    #expect(validate(p).hasError(containing: "missing card for required role 'tradeoffs'"))

    p = pack.editingItem("alpha") { $0.cards.swapAt(0, 1) }
    #expect(validate(p).hasError(containing: "out of order"))

    p = pack.editingItem("alpha") { $0.cards.append($0.cards[0]) }
    #expect(validate(p).hasError(containing: "duplicate card role"))

    // optional role may be absent in beta (it is), unknown roles may not appear
    p = pack.editingItem("beta") {
      $0.cards.append(Card(role: "mystery", content: .text(blocks: [.lead("x")])))
    }
    let issues = validate(p)
    #expect(issues.hasError(containing: "'mystery' is not part of the item's template"))
    #expect(issues.hasError(containing: "'mystery' is not defined by the topic"))
  }

  @Test func optionalRoleIsAcceptedWhenPresent() {
    let alphaStructure = pack.item("alpha")!.cards.first { $0.role == "structure" }!
    let p = pack.editingItem("beta") { $0.cards.insert(alphaStructure, at: 2) }
    #expect(validate(p).errors.isEmpty)
  }

  @Test func cardTypeMustMatchRoleType() {
    let p = pack.editingItem("beta") {
      $0.cards[0] = Card(role: "definition", content: .lists([ListGroup(title: "t", tone: .info, items: ["a", "b"])]))
    }
    #expect(validate(p).hasError(containing: "does not match role type"))
  }

  func editingCode(_ id: ItemID = "alpha", _ body: (inout CodeCard) -> Void) -> Pack {
    pack.editingItem(id) { item in
      let i = item.cards.firstIndex { $0.role == "implementation" }!
      guard case .code(var code) = item.cards[i].content else { return }
      body(&code)
      item.cards[i].content = .code(code)
    }
  }

  @Test func walkthroughRegionsMustExist() {
    let p = editingCode { $0.walkthrough[0].region = "ghost" }
    #expect(validate(p).hasError(containing: "region 'ghost' does not exist"))
  }

  @Test func walkthroughStepCount() {
    #expect(validate(editingCode { $0.walkthrough = Array($0.walkthrough.prefix(2)) }).hasError(containing: "2 steps"))
    #expect(validate(editingCode { c in c.walkthrough = Array(repeating: c.walkthrough[0], count: 8) }).hasError(containing: "8 steps"))
  }

  @Test func regionsMustNotOverlap() {
    let p = editingCode { $0.regions["impl"] = LineRange(start: 2, end: 6) }
    #expect(validate(p).hasError(containing: "overlap"))
  }

  @Test func regionsMustLieInsideSource() {
    let p = editingCode { $0.regions["use"] = LineRange(start: 10, end: 99) }
    #expect(validate(p).hasError(containing: "outside the source"))
  }

  @Test func codeSizeLimits() {
    let long = (0..<71).map { "int a\($0);" }.joined(separator: "\n")
    #expect(validate(editingCode { $0.source = long; $0.regions = ["iface": .init(start: 1, end: 1), "impl": .init(start: 2, end: 2), "use": .init(start: 3, end: 3)] }).hasWarning(containing: "71 lines"))
    let longer = (0..<91).map { "int a\($0);" }.joined(separator: "\n")
    #expect(validate(editingCode { $0.source = longer }).hasError(containing: "91 lines"))
  }

  @Test func codeColumnLimits() {
    let warn = editingCode { $0.source += "\n" + String(repeating: "x", count: 81) }
    #expect(validate(warn).hasWarning(containing: "81 columns"))
    let err = editingCode { $0.source += "\n" + String(repeating: "x", count: 101) }
    #expect(validate(err).hasError(containing: "101 columns"))
  }

  @Test func diagramLinterIssuesSurface() {
    let p = pack.editingItem("alpha") { item in
      let i = item.cards.firstIndex { $0.role == "structure" }!
      guard case .diagram(var ds) = item.cards[i].content, case .classDiagram(var cd) = ds[0] else { return }
      cd.edges.append(.init(from: "p", to: "ghost", rel: .association))
      cd.nodes[1].col = 0; cd.nodes[1].row = 0  // same cell as node 0
      ds[0] = .classDiagram(cd)
      item.cards[i].content = .diagram(diagrams: ds)
    }
    let issues = validate(p)
    #expect(issues.hasError(containing: "edge to unknown node 'ghost'"))
    #expect(issues.hasError(containing: "share cell"))
  }

  @Test func comparisonRefsMustResolveAndNotBeSelf() {
    func edit(_ ref: String) -> Pack {
      pack.editingItem("alpha") { item in
        let i = item.cards.firstIndex { $0.role == "compare" }!
        item.cards[i].content = .comparison(rows: [ComparisonRow(ref: ref, relation: .alternative, difference: "d")])
      }
    }
    #expect(validate(edit("ghost")).hasError(containing: "comparison ref 'ghost'"))
    #expect(validate(edit("alpha")).hasError(containing: "item itself"))
  }

  @Test func kataLinksMustResolve() {
    let p = pack.editingItem("beta") { item in
      item.cards[0].content = .text(blocks: [.paragraph("See [Ghost](kata:ghost) and [Alpha](kata:alpha).")])
    }
    let issues = validate(p)
    #expect(issues.hasError(containing: "kata:ghost"))
    #expect(!issues.hasError(containing: "kata:alpha"))
  }

  @Test func textLimitsWarn() {
    let words = Array(repeating: "word", count: 26).joined(separator: " ")
    let p = pack.editingItem("beta") { $0.cards[0].content = .text(blocks: [.lead(words)]) }
    #expect(validate(p).hasWarning(containing: "lead is 26 words"))
    let big = Array(repeating: "word", count: 91).joined(separator: " ")
    let q = pack.editingItem("beta") { $0.cards[0].content = .text(blocks: [.paragraph(big)]) }
    #expect(validate(q).hasWarning(containing: "body is 91 words"))
    let r = pack.editingItem("beta") {
      let i = $0.cards.firstIndex { $0.role == "sightings" }!
      $0.cards[i].content = .references(entries: [Reference(origin: "JDK", name: "n", detail: "d")])
    }
    #expect(validate(r).hasWarning(containing: "references has 1 entries"))
  }

  // MARK: Exercises

  func editingExercise(_ id: String, item: ItemID = "alpha", _ body: (inout Exercise) -> Void) -> Pack {
    pack.editingItem(item) { it in
      let i = it.exercises.firstIndex { $0.id == id }!
      body(&it.exercises[i])
    }
  }

  @Test func requiredExerciseKinds() {
    #expect(validate(pack.editingItem("beta") { $0.exercises.removeAll { $0.kind == .identify } }).hasError(containing: "identify"))
    #expect(validate(pack.editingItem("beta") { $0.exercises.removeAll { $0.kind == .reorder } }).hasError(containing: "tapLine | reorder"))
    // tapLine alone satisfies the tapLine|reorder group
    #expect(!validate(pack.editingItem("alpha") { $0.exercises.removeAll { $0.kind == .reorder } }).hasError(containing: "missing required exercise"))
  }

  @Test func optionRules() {
    func options(_ id: String, _ f: (inout [ExerciseOption]) -> Void) -> Pack {
      editingExercise(id) { ex in
        switch ex.body {
        case .identify(let l, var o): f(&o); ex.body = .identify(lines: l, options: o)
        case .choose(let s, var o): f(&o); ex.body = .choose(scenario: s, options: o)
        default: break
        }
      }
    }
    #expect(validate(options("spot-1") { $0[1].correct = true }).hasError(containing: "2 correct options"))
    #expect(validate(options("spot-1") { $0[0].correct = false }).hasError(containing: "0 correct options"))
    #expect(validate(options("spot-1") { $0.removeLast() }).hasError(containing: "2 options"))
    #expect(validate(options("pick-1") { $0.append(.init(text: "extra", why: "w")); $0.append(.init(text: "extra2", why: "w")) }).hasError(containing: "6 options"))
    #expect(validate(options("spot-1") { $0[1].why = "" }).hasError(containing: "has no why"))
    #expect(validate(options("spot-1") { $0[1].ref = "ghost" }).hasError(containing: "option ref 'ghost'"))
    #expect(validate(options("spot-1") { $0[2].ref = "alpha" }).hasError(containing: "exactly one of ref or text"))
    #expect(validate(options("pick-1") { $0[0].ref = "beta"; $0[1].ref = "alpha" }).hasWarning(containing: "not this item"))
  }

  @Test func tapLineFlawLinesInRange() {
    func flaw(_ lines: [Int]) -> Pack {
      editingExercise("flaw-1") { ex in
        if case .tapLine(let l, _, let e) = ex.body { ex.body = .tapLine(lines: l, flawLines: lines, explanation: e) }
      }
    }
    #expect(validate(flaw([4])).hasError(containing: "flawLine 4 is out of range"))
    #expect(validate(flaw([0])).hasError(containing: "flawLine 0 is out of range"))
    #expect(validate(flaw([])).hasError(containing: "no flawLines"))
  }

  @Test func reorderBlockRules() {
    func blocks(_ b: [[String]]) -> Pack {
      editingExercise("order-1") { ex in
        if case .reorder(_, let e) = ex.body { ex.body = .reorder(blocks: b, explanation: e) }
      }
    }
    #expect(validate(blocks([["a;"], ["b;"]])).hasError(containing: "2 blocks"))
    #expect(validate(blocks((0..<9).map { ["x\($0);"] })).hasError(containing: "9 blocks"))
    #expect(validate(blocks([["a;"], ["a;"], ["b;"]])).hasError(containing: "unique text"))
  }

  @Test func recallKeyPointCount() {
    func points(_ n: Int) -> Pack {
      editingExercise("recall-1") { ex in
        if case .recall(let m, _) = ex.body { ex.body = .recall(modelAnswer: m, keyPoints: (0..<n).map { "p\($0)" }) }
      }
    }
    #expect(validate(points(2)).hasError(containing: "2 key points"))
    #expect(validate(points(6)).hasError(containing: "6 key points"))
    #expect(validate(points(4)).errors.isEmpty)
  }

  @Test func compileTemplateNeedsOnePlaceholder() {
    let none = editingExercise("spot-1") { $0.compile = CompileSpec(template: ["class A {}"]) }
    #expect(validate(none).hasError(containing: "exactly once (found 0)"))
    let two = editingExercise("spot-1") { $0.compile = CompileSpec(template: ["{{code}}", "{{code}}"]) }
    #expect(validate(two).hasError(containing: "exactly once (found 2)"))
    let wrongKind = editingExercise("pick-1") { $0.compile = CompileSpec(template: ["{{code}}"]) }
    #expect(validate(wrongKind).hasError(containing: "only supported for identify"))
  }

  @Test func exerciseIdsUniqueKebab() {
    let p = pack.editingItem("alpha") { $0.exercises[1].id = $0.exercises[0].id }
    #expect(validate(p).hasError(containing: "duplicate exercise id"))
    let q = editingExercise("spot-1") { $0.id = "Spot_1" }
    #expect(validate(q).hasError(containing: "not kebab-case"))
  }
}
