import Foundation
import KataDiagram

/// Inclusive 1-based line range of a region in a code card's `source`.
public struct LineRange: Sendable, Hashable, Codable {
  public var start: Int
  public var end: Int

  public init(start: Int, end: Int) { self.start = start; self.end = end }

  public var lines: ClosedRange<Int> { start...max(start, end) }

  public init(from decoder: Decoder) throws {
    var c = try decoder.unkeyedContainer()
    start = try c.decode(Int.self)
    end = try c.decode(Int.self)
    guard c.isAtEnd else {
      throw DecodingError.dataCorruptedError(
        in: c, debugDescription: "Line range must have exactly two elements")
    }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.unkeyedContainer()
    try c.encode(start)
    try c.encode(end)
  }
}

public struct WalkthroughStep: Sendable, Hashable, Codable {
  public var region: String
  public var note: String

  public init(region: String, note: String) { self.region = region; self.note = note }

  private enum CodingKeys: String, CodingKey, CaseIterable { case region, note }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    region = try c.decode(String.self, forKey: .region)
    note = try c.decode(String.self, forKey: .note)
  }
}

/// A code card. `file` is the authoring source file; `source` and `regions` are filled in by
/// `PackBuilder` (markers stripped, 1-based inclusive ranges in the stripped source).
public struct CodeCard: Sendable, Hashable {
  public var file: String
  public var language: String?
  public var expectedOutput: String?
  public var walkthrough: [WalkthroughStep]
  public var source: String
  public var regions: [String: LineRange]

  public init(
    file: String, language: String? = nil, expectedOutput: String? = nil,
    walkthrough: [WalkthroughStep], source: String = "", regions: [String: LineRange] = [:]
  ) {
    self.file = file; self.language = language; self.expectedOutput = expectedOutput
    self.walkthrough = walkthrough; self.source = source; self.regions = regions
  }

  /// Source split into lines (no trailing empty line).
  public var lines: [String] {
    source.isEmpty ? [] : source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
  }
}

public struct ListGroup: Sendable, Hashable, Codable {
  public var title: String
  public var tone: Tone
  public var items: [String]

  public init(title: String, tone: Tone, items: [String]) {
    self.title = title; self.tone = tone; self.items = items
  }

  private enum CodingKeys: String, CodingKey, CaseIterable { case title, tone, items }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    title = try c.decode(String.self, forKey: .title)
    tone = try c.decode(Tone.self, forKey: .tone)
    items = try c.decode([String].self, forKey: .items)
  }
}

public enum ComparisonRelation: String, Sendable, Codable, CaseIterable {
  case lookAlike, alternative, combines, oftenConfused, specializes
}

public struct ComparisonRow: Sendable, Hashable, Codable {
  public var ref: ItemID
  public var relation: ComparisonRelation
  public var difference: String

  public init(ref: ItemID, relation: ComparisonRelation, difference: String) {
    self.ref = ref; self.relation = relation; self.difference = difference
  }

  private enum CodingKeys: String, CodingKey, CaseIterable { case ref, relation, difference }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    ref = try c.decode(String.self, forKey: .ref)
    relation = try c.decode(ComparisonRelation.self, forKey: .relation)
    difference = try c.decode(String.self, forKey: .difference)
  }
}

public struct Reference: Sendable, Hashable, Codable {
  /// Free label: "JDK", "Spring", "Kubernetes" (JSON key `where`).
  public var origin: String
  public var name: String
  public var detail: String

  public init(origin: String, name: String, detail: String) {
    self.origin = origin; self.name = name; self.detail = detail
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case origin = "where", name, detail
  }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    origin = try c.decode(String.self, forKey: .origin)
    name = try c.decode(String.self, forKey: .name)
    detail = try c.decode(String.self, forKey: .detail)
  }
}

public enum CardContent: Sendable, Equatable {
  case text(blocks: [Block])
  case code(CodeCard)
  case diagram(diagrams: [Diagram])
  case lists([ListGroup])
  case comparison(rows: [ComparisonRow])
  case references(entries: [Reference])

  public var type: CardType {
    switch self {
    case .text: .text
    case .code: .code
    case .diagram: .diagram
    case .lists: .lists
    case .comparison: .comparison
    case .references: .references
    }
  }
}

/// One card of an item. In the built pack `type` is always present; in authoring files it is
/// inferred from the role (decoding `userInfo[.kataRoleTypes]`).
public struct Card: Sendable, Equatable, Codable {
  public var role: String
  public var content: CardContent

  public init(role: String, content: CardContent) {
    self.role = role; self.content = content
  }

  public var type: CardType { content.type }

  private enum CodingKeys: String, CodingKey {
    case role, type, blocks, file, language, expectedOutput, walkthrough, source, regions
    case diagrams, lists, rows, entries
  }

  private static func allowedKeys(_ type: CardType) -> Set<String> {
    let base: Set<String> = ["role", "type"]
    switch type {
    case .text: return base.union(["blocks"])
    case .code:
      return base.union(["file", "language", "expectedOutput", "walkthrough", "source", "regions"])
    case .diagram: return base.union(["diagrams"])
    case .lists: return base.union(["lists"])
    case .comparison: return base.union(["rows"])
    case .references: return base.union(["entries"])
    }
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    role = try c.decode(String.self, forKey: .role)
    let explicit = try c.decodeIfPresent(CardType.self, forKey: .type)
    let inferred = (decoder.userInfo[.kataRoleTypes] as? [String: CardType])?[role]
    guard let type = explicit ?? inferred else {
      throw DecodingError.dataCorruptedError(
        forKey: .role, in: c,
        debugDescription: "Cannot determine card type: role '\(role)' is not in the topic's roles")
    }
    if let explicit, let inferred, explicit != inferred {
      throw DecodingError.dataCorruptedError(
        forKey: .type, in: c,
        debugDescription: "Card type '\(explicit.rawValue)' does not match role '\(role)' (\(inferred.rawValue))")
    }
    try decoder.rejectUnknownKeys(allowed: Card.allowedKeys(type))
    switch type {
    case .text:
      content = .text(blocks: try c.decode([Block].self, forKey: .blocks))
    case .code:
      content = .code(
        CodeCard(
          file: try c.decode(String.self, forKey: .file),
          language: try c.decodeIfPresent(String.self, forKey: .language),
          expectedOutput: try c.decodeIfPresent(String.self, forKey: .expectedOutput),
          walkthrough: try c.decode([WalkthroughStep].self, forKey: .walkthrough),
          source: try c.decodeIfPresent(String.self, forKey: .source) ?? "",
          regions: try c.decodeIfPresent([String: LineRange].self, forKey: .regions) ?? [:]))
    case .diagram:
      content = .diagram(diagrams: try c.decode([Diagram].self, forKey: .diagrams))
    case .lists:
      content = .lists(try c.decode([ListGroup].self, forKey: .lists))
    case .comparison:
      content = .comparison(rows: try c.decode([ComparisonRow].self, forKey: .rows))
    case .references:
      content = .references(entries: try c.decode([Reference].self, forKey: .entries))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(role, forKey: .role)
    try c.encode(type, forKey: .type)
    switch content {
    case .text(let blocks): try c.encode(blocks, forKey: .blocks)
    case .code(let code):
      try c.encode(code.file, forKey: .file)
      try c.encodeIfPresent(code.language, forKey: .language)
      try c.encodeIfPresent(code.expectedOutput, forKey: .expectedOutput)
      try c.encode(code.walkthrough, forKey: .walkthrough)
      try c.encode(code.source, forKey: .source)
      try c.encode(code.regions, forKey: .regions)
    case .diagram(let d): try c.encode(d, forKey: .diagrams)
    case .lists(let l): try c.encode(l, forKey: .lists)
    case .comparison(let r): try c.encode(r, forKey: .rows)
    case .references(let e): try c.encode(e, forKey: .entries)
    }
  }

  /// All prose in the card (for search and link checks). Code source is excluded.
  public var texts: [String] {
    switch content {
    case .text(let blocks): return blocks.flatMap(\.texts)
    case .code(let code): return code.walkthrough.map(\.note)
    case .diagram(let ds):
      return ds.flatMap { d -> [String] in
        switch d {
        case .classDiagram(let c):
          return [c.title] + c.nodes.flatMap { [$0.name] + ($0.role.map { [$0] } ?? []) }
            + c.notes.map(\.text)
        case .sequence(let s):
          return [s.title] + s.participants.map(\.name) + s.messages.map(\.label)
        }
      }
    case .lists(let ls): return ls.flatMap { [$0.title] + $0.items }
    case .comparison(let rows): return rows.flatMap { [$0.ref, $0.difference] }
    case .references(let es): return es.flatMap { [$0.origin, $0.name, $0.detail] }
    }
  }
}
