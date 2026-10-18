import Foundation

public enum Tone: String, Sendable, Codable, CaseIterable {
  case positive, negative, warning, info
}

/// Rich-text building block used by text cards and recall model answers.
/// Inline text is a Markdown subset (`**bold**`, `*italic*`, `` `code` ``, `[x](kata:id)`).
public enum Block: Sendable, Hashable, Codable {
  case lead(String)
  case paragraph(String)
  case heading(String)
  case bullets([String])
  case numbered([String])
  case callout(tone: Tone, text: String)
  case code(language: String, lines: [String])

  private enum CodingKeys: String, CodingKey {
    case type, text, items, tone, language, lines
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let type = try c.decode(String.self, forKey: .type)
    func allow(_ keys: Set<String>) throws {
      try decoder.rejectUnknownKeys(allowed: keys.union(["type"]))
    }
    switch type {
    case "lead": try allow(["text"]); self = .lead(try c.decode(String.self, forKey: .text))
    case "p": try allow(["text"]); self = .paragraph(try c.decode(String.self, forKey: .text))
    case "heading": try allow(["text"]); self = .heading(try c.decode(String.self, forKey: .text))
    case "bullets": try allow(["items"]); self = .bullets(try c.decode([String].self, forKey: .items))
    case "numbered": try allow(["items"]); self = .numbered(try c.decode([String].self, forKey: .items))
    case "callout":
      try allow(["tone", "text"])
      self = .callout(
        tone: try c.decode(Tone.self, forKey: .tone), text: try c.decode(String.self, forKey: .text))
    case "code":
      try allow(["language", "lines"])
      self = .code(
        language: try c.decode(String.self, forKey: .language),
        lines: try c.decode([String].self, forKey: .lines))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type, in: c, debugDescription: "Unknown block type '\(type)'")
    }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .lead(let t): try c.encode("lead", forKey: .type); try c.encode(t, forKey: .text)
    case .paragraph(let t): try c.encode("p", forKey: .type); try c.encode(t, forKey: .text)
    case .heading(let t): try c.encode("heading", forKey: .type); try c.encode(t, forKey: .text)
    case .bullets(let i): try c.encode("bullets", forKey: .type); try c.encode(i, forKey: .items)
    case .numbered(let i): try c.encode("numbered", forKey: .type); try c.encode(i, forKey: .items)
    case .callout(let tone, let t):
      try c.encode("callout", forKey: .type)
      try c.encode(tone, forKey: .tone)
      try c.encode(t, forKey: .text)
    case .code(let lang, let lines):
      try c.encode("code", forKey: .type)
      try c.encode(lang, forKey: .language)
      try c.encode(lines, forKey: .lines)
    }
  }

  /// Every prose string in the block (code lines excluded).
  public var texts: [String] {
    switch self {
    case .lead(let t), .paragraph(let t), .heading(let t): [t]
    case .bullets(let i), .numbered(let i): i
    case .callout(_, let t): [t]
    case .code: []
    }
  }
}
