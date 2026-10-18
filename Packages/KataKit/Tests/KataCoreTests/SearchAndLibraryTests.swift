import Foundation
import Testing

@testable import KataCore

@Suite struct SearchTests {
  func index(_ titles: [(String, [String], String)]) -> SearchIndex {
    let metas = titles.enumerated().map { i, t in
      ItemMeta(id: "i\(i)", title: t.0, category: "c", difficulty: 1, aliases: t.1, intent: t.2)
    }
    let topic = Topic(
      id: "t", title: "T", symbol: "x", codeLanguage: "java", roles: [:], templates: [:],
      requiredExercises: [], categories: [], items: metas, path: [])
    return SearchIndex(packs: [Pack(topic: topic, items: [])])
  }

  @Test func titleBeatsAliasBeatsBody() {
    let idx = index([
      ("Something Else", [], "Mentions strategy in passing."),
      ("Policy Holder", ["Strategy-ish"], "Another."),
      ("Strategy", [], "Swap algorithms."),
    ])
    let r = idx.search("strategy")
    #expect(r.map(\.title) == ["Strategy", "Policy Holder", "Something Else"])
    #expect(r.map(\.kind) == [.title, .alias, .body])
  }

  @Test func caseAndDiacriticFolding() {
    let idx = index([("Café Pattern", ["Crème"], "x"), ("Plain", [], "naïve approach")])
    #expect(idx.search("CAFE").first?.title == "Café Pattern")
    #expect(idx.search("creme").first?.kind == .alias)
    #expect(idx.search("NAIVE").first?.title == "Plain")
    #expect(idx.search("café").first?.title == "Café Pattern")
  }

  @Test func exactTitleOutranksPrefixOutranksContains() {
    let idx = index([("Abstract Factory", [], ""), ("Factory", [], ""), ("Factory Method", [], "")])
    #expect(idx.search("factory").map(\.title) == ["Factory", "Factory Method", "Abstract Factory"])
  }

  @Test func allTermsMustMatchAndEmptyQuery() {
    let idx = index([("Circuit Breaker", [], ""), ("Circuit Board", [], "")])
    #expect(idx.search("circuit breaker").map(\.title) == ["Circuit Breaker"])
    #expect(idx.search("   ").isEmpty)
    #expect(idx.search("zzz").isEmpty)
    #expect(idx.search("circuit", limit: 1).count == 1)
  }

  @Test func bodyMatchReportsRoleAndSnippet() throws {
    let lib = ContentLibrary(packs: [try Fixtures.miniPack()])
    let r = lib.search("hashing")
    #expect(r.count == 1)
    #expect(r[0].key == ItemKey(topic: "mini-topic", item: "alpha"))
    #expect(r[0].kind == .body && r[0].role == "sightings")
    #expect(r[0].snippet?.localizedCaseInsensitiveContains("hashing") == true)
    #expect(lib.search("hello pattern").first?.kind == .alias)
    #expect(lib.search("beta").first?.kind == .title)
  }
}

@Suite struct ContentLibraryTests {
  @Test func loadsKpackFilesFromDirectory() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("kata-lib-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let pack = try Fixtures.miniPack()
    try PackBuilder.encode(pack).write(to: dir.appendingPathComponent("mini-topic.kpack"))
    try Data("ignored".utf8).write(to: dir.appendingPathComponent("notes.txt"))

    let lib = try ContentLibrary(directory: dir)
    #expect(lib.topics.map(\.id) == ["mini-topic"])
    #expect(lib.pack("mini-topic") == pack)
    #expect(lib.pack("nope") == nil)
    let key = ItemKey(topic: "mini-topic", item: "alpha")
    let li = lib.item(key)
    #expect(li?.meta.title == "Alpha Greeter" && li?.category?.id == "patterns" && li?.template?.roles.count == 6)
    #expect(lib.item(ItemKey(topic: "mini-topic", item: "ghost")) == nil)
    #expect(lib.exercise(ExerciseKey(item: key, exercise: "flaw-1"))?.kind == .tapLine)
    #expect(lib.allItemKeys().count == 2)
    #expect(lib.learningPath("mini-topic")?.allItems == ["alpha", "beta"])
    #expect(pack.exerciseKeys(for: "beta").count == 4)
  }

  @Test func duplicateTopicsAndBadFilesFail() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("kata-lib-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let data = try PackBuilder.encode(Fixtures.miniPack())
    try data.write(to: dir.appendingPathComponent("a.kpack"))
    try data.write(to: dir.appendingPathComponent("b.kpack"))
    #expect(throws: ContentLibraryError.self) { try ContentLibrary(directory: dir) }
    try Data("{\"topic\":1}".utf8).write(to: dir.appendingPathComponent("b.kpack"))
    #expect(throws: ContentLibraryError.self) { try ContentLibrary(directory: dir) }
  }

  @Test func topicsAreOrderedBySortOrder() throws {
    var other = try Fixtures.miniPack()
    other.topic.id = "aaa"
    other.topic.sortOrder = 9
    let mini = try Fixtures.miniPack()
    #expect(ContentLibrary(packs: [other, mini]).topics.map(\.id) == ["mini-topic", "aaa"])
  }
}
