import Foundation

/// Lexical category of a token, used by the UI to pick a colour.
public enum TokenKind: String, Sendable, Hashable, CaseIterable, Codable {
  case keyword, type, function, identifier, annotation, string, number
  case comment, docComment, `operator`, punctuation, whitespace
}

/// A contiguous slice of source text with its lexical category.
/// Concatenating the `text` of all tokens reproduces the source exactly.
public struct CodeToken: Sendable, Hashable {
  public var kind: TokenKind
  public var text: String

  public init(kind: TokenKind, text: String) {
    self.kind = kind
    self.text = text
  }
}

/// Turns source text into tokens.
public protocol SyntaxHighlighter: Sendable {
  func tokenize(_ source: String) -> [CodeToken]
}

/// Emits the whole source as a single identifier-less plain token per line break run.
public struct PlainLexer: SyntaxHighlighter {
  public init() {}

  public func tokenize(_ source: String) -> [CodeToken] {
    source.isEmpty ? [] : [CodeToken(kind: .identifier, text: source)]
  }
}

/// Lookup of highlighters by language name.
public final class HighlighterRegistry: @unchecked Sendable {
  public static let shared = HighlighterRegistry()

  private let lock = NSLock()
  private var table: [String: any SyntaxHighlighter]

  public init() {
    table = ["java": JavaLexer()]
  }

  /// Registers (or replaces) a highlighter for a language name (case-insensitive).
  public func register(_ highlighter: any SyntaxHighlighter, for language: String) {
    lock.lock()
    defer { lock.unlock() }
    table[Self.normalize(language)] = highlighter
  }

  /// Returns the highlighter for `language`, or a `PlainLexer` when unknown.
  public func highlighter(for language: String) -> any SyntaxHighlighter {
    lock.lock()
    defer { lock.unlock() }
    return table[Self.normalize(language)] ?? PlainLexer()
  }

  private static func normalize(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
}

public enum CodeLines {
  /// Splits tokens into lines. Tokens spanning line breaks (block comments, text blocks,
  /// whitespace runs) are cut at each `\n`; a trailing `\r` is dropped. The result always
  /// has `(number of "\n") + 1` lines; empty lines are empty arrays.
  public static func split(_ tokens: [CodeToken]) -> [[CodeToken]] {
    var lines: [[CodeToken]] = [[]]
    for token in tokens {
      if !token.text.contains("\n") {
        if !token.text.isEmpty { lines[lines.count - 1].append(token) }
        continue
      }
      let parts = token.text.split(separator: "\n", omittingEmptySubsequences: false)
      for (i, part) in parts.enumerated() {
        if i > 0 { lines.append([]) }
        var p = Substring(part)
        if i < parts.count - 1, p.last == "\r" { p = p.dropLast() }
        if !p.isEmpty { lines[lines.count - 1].append(CodeToken(kind: token.kind, text: String(p))) }
      }
    }
    return lines
  }
}
