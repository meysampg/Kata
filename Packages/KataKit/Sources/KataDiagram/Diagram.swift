import Foundation

/// Authoring model for diagrams embedded in `diagram` cards (PLAN §2b).
public enum Diagram: Sendable, Equatable, Codable {
  case classDiagram(ClassDiagram)
  case sequence(SequenceDiagram)

  private enum CodingKeys: String, CodingKey { case kind }

  public var title: String {
    switch self {
    case .classDiagram(let d): d.title
    case .sequence(let d): d.title
    }
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try c.decode(String.self, forKey: .kind)
    switch kind {
    case "class": self = .classDiagram(try ClassDiagram(from: decoder))
    case "sequence": self = .sequence(try SequenceDiagram(from: decoder))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .kind, in: c, debugDescription: "Unknown diagram kind '\(kind)'")
    }
  }

  public func encode(to encoder: Encoder) throws {
    switch self {
    case .classDiagram(let d): try d.encode(to: encoder)
    case .sequence(let d): try d.encode(to: encoder)
    }
  }
}

// MARK: - Class diagram

public struct ClassDiagram: Sendable, Equatable, Codable {
  public enum NodeKind: String, Sendable, Equatable, Codable, CaseIterable {
    case `class`, interface, abstract, record, `enum`
  }
  public enum Relation: String, Sendable, Equatable, Codable, CaseIterable {
    case realizes, extends, association, aggregation, composition, dependency
  }

  public struct Node: Sendable, Equatable, Codable {
    public var id: String
    public var name: String
    public var kind: NodeKind
    public var role: String?
    public var col: Double
    public var row: Double
    public var members: [String]

    public init(
      id: String, name: String, kind: NodeKind = .class, role: String? = nil,
      col: Double, row: Double, members: [String] = []
    ) {
      self.id = id; self.name = name; self.kind = kind; self.role = role
      self.col = col; self.row = row; self.members = members
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
      case id, name, kind, role, col, row, members
    }

    public init(from decoder: Decoder) throws {
      try decoder.rejectUnknownKeys(CodingKeys.self)
      let c = try decoder.container(keyedBy: CodingKeys.self)
      id = try c.decode(String.self, forKey: .id)
      name = try c.decode(String.self, forKey: .name)
      kind = try c.decode(NodeKind.self, forKey: .kind)
      role = try c.decodeIfPresent(String.self, forKey: .role)
      col = try c.decode(Double.self, forKey: .col)
      row = try c.decode(Double.self, forKey: .row)
      members = try c.decodeIfPresent([String].self, forKey: .members) ?? []
    }
  }

  public struct Edge: Sendable, Equatable, Codable {
    public var from: String
    public var to: String
    public var rel: Relation
    public var label: String?

    public init(from: String, to: String, rel: Relation, label: String? = nil) {
      self.from = from; self.to = to; self.rel = rel; self.label = label
    }

    private enum CodingKeys: String, CodingKey, CaseIterable { case from, to, rel, label }

    public init(from decoder: Decoder) throws {
      try decoder.rejectUnknownKeys(CodingKeys.self)
      let c = try decoder.container(keyedBy: CodingKeys.self)
      from = try c.decode(String.self, forKey: .from)
      to = try c.decode(String.self, forKey: .to)
      rel = try c.decode(Relation.self, forKey: .rel)
      label = try c.decodeIfPresent(String.self, forKey: .label)
    }
  }

  public struct Note: Sendable, Equatable, Codable {
    public var attachTo: String
    public var text: String

    public init(attachTo: String, text: String) {
      self.attachTo = attachTo; self.text = text
    }

    private enum CodingKeys: String, CodingKey, CaseIterable { case attachTo, text }

    public init(from decoder: Decoder) throws {
      try decoder.rejectUnknownKeys(CodingKeys.self)
      let c = try decoder.container(keyedBy: CodingKeys.self)
      attachTo = try c.decode(String.self, forKey: .attachTo)
      text = try c.decode(String.self, forKey: .text)
    }
  }

  public var title: String
  public var nodes: [Node]
  public var edges: [Edge]
  public var notes: [Note]

  public init(title: String, nodes: [Node], edges: [Edge] = [], notes: [Note] = []) {
    self.title = title; self.nodes = nodes; self.edges = edges; self.notes = notes
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case kind, title, nodes, edges, notes
  }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try c.decode(String.self, forKey: .kind)
    guard kind == "class" else {
      throw DecodingError.dataCorruptedError(
        forKey: .kind, in: c, debugDescription: "Expected kind 'class', got '\(kind)'")
    }
    title = try c.decode(String.self, forKey: .title)
    nodes = try c.decode([Node].self, forKey: .nodes)
    edges = try c.decodeIfPresent([Edge].self, forKey: .edges) ?? []
    notes = try c.decodeIfPresent([Note].self, forKey: .notes) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode("class", forKey: .kind)
    try c.encode(title, forKey: .title)
    try c.encode(nodes, forKey: .nodes)
    try c.encode(edges, forKey: .edges)
    try c.encode(notes, forKey: .notes)
  }
}

// MARK: - Sequence diagram

public struct SequenceDiagram: Sendable, Equatable, Codable {
  public enum MessageStyle: String, Sendable, Equatable, Codable, CaseIterable {
    case call, async, `return`, create
  }
  public enum FragmentKind: String, Sendable, Equatable, Codable, CaseIterable {
    case alt, loop, opt
  }

  public struct Participant: Sendable, Equatable, Codable {
    public var id: String
    public var name: String
    public var role: String?

    public init(id: String, name: String, role: String? = nil) {
      self.id = id; self.name = name; self.role = role
    }

    private enum CodingKeys: String, CodingKey, CaseIterable { case id, name, role }

    public init(from decoder: Decoder) throws {
      try decoder.rejectUnknownKeys(CodingKeys.self)
      let c = try decoder.container(keyedBy: CodingKeys.self)
      id = try c.decode(String.self, forKey: .id)
      name = try c.decode(String.self, forKey: .name)
      role = try c.decodeIfPresent(String.self, forKey: .role)
    }
  }

  public struct Message: Sendable, Equatable, Codable {
    public var from: String
    public var to: String
    public var label: String
    public var style: MessageStyle

    public init(from: String, to: String, label: String, style: MessageStyle = .call) {
      self.from = from; self.to = to; self.label = label; self.style = style
    }

    private enum CodingKeys: String, CodingKey, CaseIterable { case from, to, label, style }

    public init(from decoder: Decoder) throws {
      try decoder.rejectUnknownKeys(CodingKeys.self)
      let c = try decoder.container(keyedBy: CodingKeys.self)
      from = try c.decode(String.self, forKey: .from)
      to = try c.decode(String.self, forKey: .to)
      label = try c.decode(String.self, forKey: .label)
      style = try c.decode(MessageStyle.self, forKey: .style)
    }
  }

  public struct Fragment: Sendable, Equatable, Codable {
    public var kind: FragmentKind
    public var guardText: String
    /// Index of the first message inside the fragment.
    public var from: Int
    /// Index of the last message inside the fragment (inclusive).
    public var to: Int

    public init(kind: FragmentKind, guardText: String, from: Int, to: Int) {
      self.kind = kind; self.guardText = guardText; self.from = from; self.to = to
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
      case kind, guardText = "guard", from, to
    }

    public init(from decoder: Decoder) throws {
      try decoder.rejectUnknownKeys(CodingKeys.self)
      let c = try decoder.container(keyedBy: CodingKeys.self)
      kind = try c.decode(FragmentKind.self, forKey: .kind)
      guardText = try c.decode(String.self, forKey: .guardText)
      from = try c.decode(Int.self, forKey: .from)
      to = try c.decode(Int.self, forKey: .to)
    }
  }

  public var title: String
  public var participants: [Participant]
  public var messages: [Message]
  public var fragments: [Fragment]

  public init(
    title: String, participants: [Participant], messages: [Message],
    fragments: [Fragment] = []
  ) {
    self.title = title; self.participants = participants
    self.messages = messages; self.fragments = fragments
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case kind, title, participants, messages, fragments
  }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try c.decode(String.self, forKey: .kind)
    guard kind == "sequence" else {
      throw DecodingError.dataCorruptedError(
        forKey: .kind, in: c, debugDescription: "Expected kind 'sequence', got '\(kind)'")
    }
    title = try c.decode(String.self, forKey: .title)
    participants = try c.decode([Participant].self, forKey: .participants)
    messages = try c.decode([Message].self, forKey: .messages)
    fragments = try c.decodeIfPresent([Fragment].self, forKey: .fragments) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode("sequence", forKey: .kind)
    try c.encode(title, forKey: .title)
    try c.encode(participants, forKey: .participants)
    try c.encode(messages, forKey: .messages)
    try c.encode(fragments, forKey: .fragments)
  }
}

// MARK: - Strict decoding

struct DynamicKey: CodingKey {
  var stringValue: String
  var intValue: Int? { nil }
  init?(stringValue: String) { self.stringValue = stringValue }
  init?(intValue: Int) { nil }
}

extension Decoder {
  /// Throws if the current keyed container holds keys not declared in `K`.
  func rejectUnknownKeys<K: CodingKey & CaseIterable>(_ type: K.Type) throws {
    let c = try container(keyedBy: DynamicKey.self)
    let allowed = Set(K.allCases.map(\.stringValue))
    let unknown = c.allKeys.map(\.stringValue).filter { !allowed.contains($0) }.sorted()
    if !unknown.isEmpty {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: codingPath,
          debugDescription: "Unknown key(s): \(unknown.joined(separator: ", "))"))
    }
  }
}
