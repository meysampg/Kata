import Foundation

/// What the learner does in a kata (MAC_PLAN §2.2).
public enum KataKind: String, Sendable, Codable, CaseIterable {
  /// Working code with a smell; the pattern removes it and behaviour checks stay green.
  case refactor
  /// A construction with a crisp contract, built against a compiling skeleton.
  case implement
  /// The pattern's classic failure; the learner finds and fixes the bugs.
  case fix
}

public enum CheckKind: String, Sendable, Codable, CaseIterable {
  case behaviour, design
}

/// A Java source file embedded at build time.
public struct KataFile: Sendable, Hashable, Codable {
  public var name: String
  public var source: String

  public init(name: String, source: String) {
    self.name = name; self.source = source
  }

  private enum CodingKeys: String, CodingKey, CaseIterable { case name, source }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    name = try c.decode(String.self, forKey: .name)
    source = try c.decode(String.self, forKey: .source)
  }
}

/// One entry of `kata.json` `checks`: must equal the `@Check` ids the harness reports, in order.
public struct KataCheckSpec: Sendable, Hashable, Codable {
  public var id: String
  public var kind: CheckKind
  public var title: String

  public init(id: String, kind: CheckKind, title: String) {
    self.id = id; self.kind = kind; self.title = title
  }

  private enum CodingKeys: String, CodingKey, CaseIterable { case id, kind, title }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    kind = try c.decode(CheckKind.self, forKey: .kind)
    title = try c.decode(String.self, forKey: .title)
  }
}

/// A coding kata with every file embedded (the `.kkata` form).
public struct Kata: Sendable, Equatable, Codable {
  public static let defaultTimeoutSeconds = 10
  public static let defaultStressRuns = 5

  public var itemId: ItemID
  public var kind: KataKind
  public var title: String
  /// Target time in minutes; drives the rating suggestion.
  public var minutes: Int
  public var task: [Block]
  public var starter: [KataFile]
  /// Names of starter files the learner may not edit.
  public var readOnly: Set<String>
  public var solution: [KataFile]
  public var tests: [KataFile]
  public var checks: [KataCheckSpec]
  public var hints: [[Block]]
  public var timeoutSeconds: Int
  public var stressRuns: Int?
  /// `false` only for implement katas whose skeleton intentionally does not compile.
  public var starterCompiles: Bool

  public init(
    itemId: ItemID, kind: KataKind, title: String, minutes: Int, task: [Block],
    starter: [KataFile], readOnly: Set<String> = [], solution: [KataFile], tests: [KataFile],
    checks: [KataCheckSpec], hints: [[Block]], timeoutSeconds: Int = Kata.defaultTimeoutSeconds,
    stressRuns: Int? = nil, starterCompiles: Bool = true
  ) {
    self.itemId = itemId; self.kind = kind; self.title = title; self.minutes = minutes
    self.task = task; self.starter = starter; self.readOnly = readOnly; self.solution = solution
    self.tests = tests; self.checks = checks; self.hints = hints
    self.timeoutSeconds = timeoutSeconds; self.stressRuns = stressRuns
    self.starterCompiles = starterCompiles
  }

  /// How many times tooling repeats the reference and starter runs.
  public var effectiveStressRuns: Int { stressRuns ?? Self.defaultStressRuns }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case itemId, kind, title, minutes, task, starter, readOnly, solution, tests, checks, hints
    case timeoutSeconds, stressRuns, starterCompiles
  }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    itemId = try c.decode(String.self, forKey: .itemId)
    kind = try c.decode(KataKind.self, forKey: .kind)
    title = try c.decode(String.self, forKey: .title)
    minutes = try c.decode(Int.self, forKey: .minutes)
    task = try c.decode([Block].self, forKey: .task)
    starter = try c.decode([KataFile].self, forKey: .starter)
    readOnly = Set(try c.decodeIfPresent([String].self, forKey: .readOnly) ?? [])
    solution = try c.decode([KataFile].self, forKey: .solution)
    tests = try c.decode([KataFile].self, forKey: .tests)
    checks = try c.decode([KataCheckSpec].self, forKey: .checks)
    hints = try c.decode([[Block]].self, forKey: .hints)
    timeoutSeconds = try c.decodeIfPresent(Int.self, forKey: .timeoutSeconds) ?? Self.defaultTimeoutSeconds
    stressRuns = try c.decodeIfPresent(Int.self, forKey: .stressRuns)
    starterCompiles = try c.decodeIfPresent(Bool.self, forKey: .starterCompiles) ?? true
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(itemId, forKey: .itemId)
    try c.encode(kind, forKey: .kind)
    try c.encode(title, forKey: .title)
    try c.encode(minutes, forKey: .minutes)
    try c.encode(task, forKey: .task)
    try c.encode(starter, forKey: .starter)
    if !readOnly.isEmpty { try c.encode(readOnly.sorted(), forKey: .readOnly) }
    try c.encode(solution, forKey: .solution)
    try c.encode(tests, forKey: .tests)
    try c.encode(checks, forKey: .checks)
    try c.encode(hints, forKey: .hints)
    try c.encode(timeoutSeconds, forKey: .timeoutSeconds)
    try c.encodeIfPresent(stressRuns, forKey: .stressRuns)
    if !starterCompiles { try c.encode(false, forKey: .starterCompiles) }
  }
}

/// `kata.json` as authored: file names instead of embedded sources.
public struct KataManifest: Sendable, Equatable, Decodable {
  public var kind: KataKind
  public var title: String
  public var minutes: Int
  public var task: [Block]
  public var starter: [String]
  public var readOnly: [String]
  public var solution: [String]
  public var tests: [String]
  public var checks: [KataCheckSpec]
  public var hints: [[Block]]
  public var timeoutSeconds: Int
  public var stressRuns: Int?
  public var starterCompiles: Bool

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case kind, title, minutes, task, starter, readOnly, solution, tests, checks, hints
    case timeoutSeconds, stressRuns, starterCompiles
  }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    kind = try c.decode(KataKind.self, forKey: .kind)
    title = try c.decode(String.self, forKey: .title)
    minutes = try c.decode(Int.self, forKey: .minutes)
    task = try c.decode([Block].self, forKey: .task)
    starter = try c.decode([String].self, forKey: .starter)
    readOnly = try c.decodeIfPresent([String].self, forKey: .readOnly) ?? []
    solution = try c.decode([String].self, forKey: .solution)
    tests = try c.decode([String].self, forKey: .tests)
    checks = try c.decode([KataCheckSpec].self, forKey: .checks)
    hints = try c.decode([[Block]].self, forKey: .hints)
    timeoutSeconds = try c.decodeIfPresent(Int.self, forKey: .timeoutSeconds) ?? Kata.defaultTimeoutSeconds
    stressRuns = try c.decodeIfPresent(Int.self, forKey: .stressRuns)
    starterCompiles = try c.decodeIfPresent(Bool.self, forKey: .starterCompiles) ?? true
  }
}

/// The contents of one `.kkata` file: every kata of one topic.
public struct KataPack: Sendable, Equatable, Codable {
  public var topicId: TopicID
  public var katas: [Kata]

  public init(topicId: TopicID, katas: [Kata]) {
    self.topicId = topicId; self.katas = katas
  }

  private enum CodingKeys: String, CodingKey, CaseIterable { case topicId, katas }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    topicId = try c.decode(String.self, forKey: .topicId)
    katas = try c.decode([Kata].self, forKey: .katas)
  }

  public func kata(for item: ItemID) -> Kata? { katas.first { $0.itemId == item } }
}
