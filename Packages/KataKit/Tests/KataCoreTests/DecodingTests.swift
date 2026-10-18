import Foundation
import KataDiagram
import Testing

@testable import KataCore

@Suite struct DecodingTests {
  let pack: Pack

  init() throws { pack = try Fixtures.miniPack() }

  @Test func miniPackHasEveryCardTypeAndExerciseKind() throws {
    let types = Set(pack.items.flatMap { $0.cards.map(\.type) })
    #expect(types == Set(CardType.allCases))
    let kinds = Set(pack.items.flatMap { $0.exercises.map(\.kind) })
    #expect(kinds == Set(ExerciseKind.allCases))
    let blockCount = pack.item("alpha")!.cards[0]
    if case .text(let blocks) = blockCount.content { #expect(blocks.count == 7) } else { Issue.record("not text") }
  }

  @Test func roundTripThroughBuiltFormat() throws {
    let data = try PackBuilder.encode(pack)
    let decoded = try ContentLibrary.decodePack(data: data)
    #expect(decoded == pack)
  }

  @Test func builtCardsCarryTypeDiscriminator() throws {
    let json = try JSONSerialization.jsonObject(with: PackBuilder.encode(pack)) as! [String: Any]
    let items = json["items"] as! [[String: Any]]
    let cards = items[0]["cards"] as! [[String: Any]]
    #expect(cards.map { $0["type"] as? String } == ["text", "code", "diagram", "lists", "comparison", "references"])
    #expect(cards[1]["source"] is String)
    let regions = cards[1]["regions"] as! [String: [Int]]
    #expect(regions["iface"]?.count == 2)
  }

  @Test func authoringCardInfersTypeFromRole() throws {
    let json = #"{"role":"definition","blocks":[{"type":"lead","text":"x"}]}"#.data(using: .utf8)!
    let d = JSONDecoder()
    d.userInfo[.kataRoleTypes] = ["definition": CardType.text]
    let card = try d.decode(Card.self, from: json)
    #expect(card.type == .text)
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(Card.self, from: json) }
  }

  @Test func explicitTypeMustMatchRole() {
    let json = #"{"role":"definition","type":"lists","lists":[]}"#.data(using: .utf8)!
    let d = JSONDecoder()
    d.userInfo[.kataRoleTypes] = ["definition": CardType.text]
    #expect(throws: DecodingError.self) { try d.decode(Card.self, from: json) }
  }

  @Test(arguments: [
    #"{"role":"definition","type":"text","blocks":[],"extra":1}"#,
    #"{"role":"definition","type":"text","blocks":[{"type":"lead","text":"x","oops":true}]}"#,
    #"{"role":"definition","type":"text","blocks":[{"type":"mystery","text":"x"}]}"#,
    #"{"role":"definition","type":"text","file":"A.java"}"#,
    #"{"role":"x","type":"lists","lists":[{"title":"t","tone":"info","items":[],"z":1}]}"#,
    #"{"role":"x","type":"comparison","rows":[{"ref":"a","relation":"lookAlike","difference":"d","z":1}]}"#,
    #"{"role":"x","type":"references","entries":[{"where":"w","name":"n","detail":"d","z":1}]}"#,
    #"{"role":"x","type":"code","file":"A.java","walkthrough":[{"region":"r","note":"n","z":1}]}"#,
    #"{"role":"x","type":"diagram","diagrams":[{"kind":"class","title":"t","nodes":[],"zzz":1}]}"#,
  ])
  func unknownKeysAndTypesAreRejected(json: String) {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(Card.self, from: json.data(using: .utf8)!)
    }
  }

  @Test(arguments: [
    #"{"id":"e","kind":"recall","prompt":"p","modelAnswer":[],"keyPoints":[],"extra":1}"#,
    #"{"id":"e","kind":"recall","prompt":"p","modelAnswer":[],"keyPoints":[],"lines":[]}"#,
    #"{"id":"e","kind":"unknown","prompt":"p"}"#,
    #"{"id":"e","kind":"identify","prompt":"p","lines":[],"options":[{"ref":"a","why":"w","bogus":1}]}"#,
    #"{"id":"e","kind":"reorder","prompt":"p","blocks":[],"explanation":"e","compile":{"template":[],"x":1}}"#,
  ])
  func exerciseUnknownKeysAreRejected(json: String) {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(Exercise.self, from: json.data(using: .utf8)!)
    }
  }

  @Test func topicAndItemRejectUnknownKeys() throws {
    var topic = try String(contentsOf: Fixtures.miniTopic.appendingPathComponent("topic.json"), encoding: .utf8)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(Topic.self, from: topic.replacingOccurrences(of: "\"sortOrder\"", with: "\"sortOrdr\"").data(using: .utf8)!)
    }
    topic = topic.replacingOccurrences(of: "\"schemaVersion\": 1", with: "\"schemaVersion\": 2")
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(Topic.self, from: topic.data(using: .utf8)!) }
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(Item.self, from: #"{"id":"a","cards":[],"exercises":[],"x":1}"#.data(using: .utf8)!)
    }
  }

  @Test func lineRangeNeedsTwoElements() {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(LineRange.self, from: "[1,2,3]".data(using: .utf8)!)
    }
    #expect((try? JSONDecoder().decode(LineRange.self, from: "[2,5]".data(using: .utf8)!)) == LineRange(start: 2, end: 5))
  }

  @Test func keysRoundTrip() throws {
    let k = ExerciseKey(topic: "design-patterns", item: "strategy", exercise: "spot-1")
    #expect(k.rawValue == "design-patterns/strategy#spot-1")
    #expect(ExerciseKey(rawValue: k.rawValue) == k)
    #expect(ExerciseKey(rawValue: "nope") == nil)
    #expect(ItemKey(rawValue: "a/b")?.item == "b")
    #expect(ItemKey(rawValue: "a") == nil)
    let data = try JSONEncoder().encode([k])
    #expect(String(decoding: data, as: UTF8.self) == "[\"design-patterns\\/strategy#spot-1\"]")
    #expect(try JSONDecoder().decode([ExerciseKey].self, from: data) == [k])
  }
}
