import Foundation

public struct ExerciseOption: Sendable, Hashable, Codable {
  /// Either a reference to another item (`ref`) or free `text`.
  public var ref: ItemID?
  public var text: String?
  public var correct: Bool
  public var why: String

  public init(ref: ItemID? = nil, text: String? = nil, correct: Bool = false, why: String) {
    self.ref = ref; self.text = text; self.correct = correct; self.why = why
  }

  private enum CodingKeys: String, CodingKey, CaseIterable { case ref, text, correct, why }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    ref = try c.decodeIfPresent(String.self, forKey: .ref)
    text = try c.decodeIfPresent(String.self, forKey: .text)
    correct = try c.decodeIfPresent(Bool.self, forKey: .correct) ?? false
    why = try c.decode(String.self, forKey: .why)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(ref, forKey: .ref)
    try c.encodeIfPresent(text, forKey: .text)
    if correct { try c.encode(true, forKey: .correct) }
    try c.encode(why, forKey: .why)
  }
}

public enum ExerciseBody: Sendable, Hashable {
  case identify(lines: [String], options: [ExerciseOption])
  case choose(scenario: String, options: [ExerciseOption])
  /// `flawLines` are 1-based.
  case tapLine(lines: [String], flawLines: [Int], explanation: String)
  /// `blocks` are in the correct order; the app shuffles them.
  case reorder(blocks: [[String]], explanation: String)
  case recall(modelAnswer: [Block], keyPoints: [String])

  public var kind: ExerciseKind {
    switch self {
    case .identify: .identify
    case .choose: .choose
    case .tapLine: .tapLine
    case .reorder: .reorder
    case .recall: .recall
    }
  }
}

/// Optional compile check: `template` lines contain exactly one `{{code}}` placeholder.
public struct CompileSpec: Sendable, Hashable, Codable {
  public static let placeholder = "{{code}}"
  public var template: [String]

  public init(template: [String]) { self.template = template }

  private enum CodingKeys: String, CodingKey, CaseIterable { case template }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    template = try c.decode([String].self, forKey: .template)
  }

  /// Substitutes `code` lines for the placeholder line, keeping the placeholder's indentation.
  public func render(code: [String]) -> [String] {
    var out: [String] = []
    for line in template {
      if let r = line.range(of: Self.placeholder) {
        let prefix = String(line[..<r.lowerBound])
        let suffix = String(line[r.upperBound...])
        for (i, c) in code.enumerated() {
          out.append((i == 0 ? prefix : String(repeating: " ", count: prefix.count)) + c
            + (i == code.count - 1 ? suffix : ""))
        }
        if code.isEmpty { out.append(prefix + suffix) }
      } else {
        out.append(line)
      }
    }
    return out
  }
}

public struct Exercise: Sendable, Hashable, Codable, Identifiable {
  public var id: ExerciseID
  public var prompt: String
  public var body: ExerciseBody
  public var compile: CompileSpec?

  public init(id: ExerciseID, prompt: String, body: ExerciseBody, compile: CompileSpec? = nil) {
    self.id = id; self.prompt = prompt; self.body = body; self.compile = compile
  }

  public var kind: ExerciseKind { body.kind }

  /// The code the compile template wraps: identify/tapLine `lines`, reorder blocks in order.
  public var compilableCode: [String]? {
    switch body {
    case .identify(let lines, _), .tapLine(let lines, _, _): lines
    case .reorder(let blocks, _): blocks.flatMap { $0 }
    case .choose, .recall: nil
    }
  }

  private enum CodingKeys: String, CodingKey {
    case id, kind, prompt, lines, options, scenario, flawLines, explanation, blocks
    case modelAnswer, keyPoints, compile
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    let kind = try c.decode(ExerciseKind.self, forKey: .kind)
    prompt = try c.decode(String.self, forKey: .prompt)
    compile = try c.decodeIfPresent(CompileSpec.self, forKey: .compile)
    let common: Set<String> = ["id", "kind", "prompt", "compile"]
    switch kind {
    case .identify:
      try decoder.rejectUnknownKeys(allowed: common.union(["lines", "options"]))
      body = .identify(
        lines: try c.decode([String].self, forKey: .lines),
        options: try c.decode([ExerciseOption].self, forKey: .options))
    case .choose:
      try decoder.rejectUnknownKeys(allowed: common.union(["scenario", "options"]))
      body = .choose(
        scenario: try c.decode(String.self, forKey: .scenario),
        options: try c.decode([ExerciseOption].self, forKey: .options))
    case .tapLine:
      try decoder.rejectUnknownKeys(allowed: common.union(["lines", "flawLines", "explanation"]))
      body = .tapLine(
        lines: try c.decode([String].self, forKey: .lines),
        flawLines: try c.decode([Int].self, forKey: .flawLines),
        explanation: try c.decode(String.self, forKey: .explanation))
    case .reorder:
      try decoder.rejectUnknownKeys(allowed: common.union(["blocks", "explanation"]))
      body = .reorder(
        blocks: try c.decode([[String]].self, forKey: .blocks),
        explanation: try c.decode(String.self, forKey: .explanation))
    case .recall:
      try decoder.rejectUnknownKeys(allowed: common.union(["modelAnswer", "keyPoints"]))
      body = .recall(
        modelAnswer: try c.decode([Block].self, forKey: .modelAnswer),
        keyPoints: try c.decode([String].self, forKey: .keyPoints))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(kind, forKey: .kind)
    try c.encode(prompt, forKey: .prompt)
    switch body {
    case .identify(let lines, let options):
      try c.encode(lines, forKey: .lines); try c.encode(options, forKey: .options)
    case .choose(let scenario, let options):
      try c.encode(scenario, forKey: .scenario); try c.encode(options, forKey: .options)
    case .tapLine(let lines, let flaw, let explanation):
      try c.encode(lines, forKey: .lines); try c.encode(flaw, forKey: .flawLines)
      try c.encode(explanation, forKey: .explanation)
    case .reorder(let blocks, let explanation):
      try c.encode(blocks, forKey: .blocks); try c.encode(explanation, forKey: .explanation)
    case .recall(let model, let points):
      try c.encode(model, forKey: .modelAnswer); try c.encode(points, forKey: .keyPoints)
    }
    try c.encodeIfPresent(compile, forKey: .compile)
  }

  /// Prose in the exercise (for link checks).
  public var texts: [String] {
    switch body {
    case .identify(_, let options): return [prompt] + options.map(\.why)
    case .choose(let scenario, let options): return [prompt, scenario] + options.map(\.why)
    case .tapLine(_, _, let e): return [prompt, e]
    case .reorder(_, let e): return [prompt, e]
    case .recall(let model, let points): return [prompt] + model.flatMap(\.texts) + points
    }
  }
}
