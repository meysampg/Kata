import Foundation

public enum SearchMatchKind: Int, Sendable, Hashable, Comparable {
  case title = 3, alias = 2, body = 1

  public static func < (l: SearchMatchKind, r: SearchMatchKind) -> Bool { l.rawValue < r.rawValue }
}

public struct SearchResult: Sendable, Hashable, Identifiable {
  public var id: ItemKey { key }
  public let key: ItemKey
  public let title: String
  public let category: String
  public let kind: SearchMatchKind
  /// Role of the card containing the match (body matches; nil for title/alias matches).
  public let role: String?
  public let snippet: String?
  public let score: Int
}

/// In-memory full-text index over titles, aliases, intents and card prose.
/// Ranking: title > alias > body. Case- and diacritic-insensitive; all query terms must match.
public struct SearchIndex: Sendable {
  struct Section: Sendable {
    let role: String?
    let text: String
    let folded: String
  }
  struct Entry: Sendable {
    let key: ItemKey
    let title: String
    let foldedTitle: String
    let category: String
    let aliases: [(text: String, folded: String)]
    let sections: [Section]
    let order: Int
  }

  private let entries: [Entry]

  public init(packs: [Pack]) {
    var entries: [Entry] = []
    for pack in packs {
      for meta in pack.topic.items {
        var sections: [Section] = [Section(role: nil, text: meta.intent, folded: Self.fold(meta.intent))]
        if let item = pack.item(meta.id) {
          for card in item.cards {
            let text = card.texts.joined(separator: " ")
            sections.append(Section(role: card.role, text: text, folded: Self.fold(text)))
          }
        }
        entries.append(
          Entry(
            key: pack.key(for: meta.id), title: meta.title, foldedTitle: Self.fold(meta.title),
            category: meta.category, aliases: meta.aliases.map { ($0, Self.fold($0)) },
            sections: sections, order: entries.count))
      }
    }
    self.entries = entries
  }

  public static func fold(_ s: String) -> String {
    s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
  }

  static func terms(_ query: String) -> [String] {
    fold(query).split(whereSeparator: \.isWhitespace).map(String.init)
  }

  public func search(_ query: String, limit: Int = 50) -> [SearchResult] {
    let terms = Self.terms(query)
    guard !terms.isEmpty else { return [] }
    let joined = terms.joined(separator: " ")
    var scored: [(SearchResult, Int)] = []
    for e in entries {
      if terms.allSatisfy({ e.foldedTitle.contains($0) }) {
        var score = 3000
        if e.foldedTitle == joined { score += 1000 }
        else if e.foldedTitle.hasPrefix(joined) { score += 500 }
        else if e.foldedTitle.split(separator: " ").contains(where: { $0.hasPrefix(terms[0]) }) { score += 200 }
        scored.append((result(e, .title, nil, nil, score), e.order))
      } else if let a = e.aliases.first(where: { al in terms.allSatisfy { al.folded.contains($0) } }) {
        var score = 2000
        if a.folded == joined { score += 1000 }
        else if a.folded.hasPrefix(joined) { score += 500 }
        scored.append((result(e, .alias, nil, nil, score), e.order))
      } else if let s = e.sections.first(where: { sec in terms.allSatisfy { sec.folded.contains($0) } }) {
        scored.append((result(e, .body, s.role, snippet(s.text, term: terms[0]), 1000), e.order))
      }
    }
    scored.sort { l, r in
      if l.0.score != r.0.score { return l.0.score > r.0.score }
      if l.0.title != r.0.title { return l.0.title < r.0.title }
      return l.1 < r.1
    }
    return Array(scored.prefix(max(0, limit)).map(\.0))
  }

  private func result(
    _ e: Entry, _ kind: SearchMatchKind, _ role: String?, _ snippet: String?, _ score: Int
  ) -> SearchResult {
    SearchResult(
      key: e.key, title: e.title, category: e.category, kind: kind, role: role,
      snippet: snippet, score: score)
  }

  private func snippet(_ text: String, term: String) -> String {
    guard let r = text.range(
      of: term, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive])
    else { return String(text.prefix(100)) }
    let lo = text.index(r.lowerBound, offsetBy: -40, limitedBy: text.startIndex) ?? text.startIndex
    let hi = text.index(r.upperBound, offsetBy: 60, limitedBy: text.endIndex) ?? text.endIndex
    return (lo > text.startIndex ? "…" : "") + text[lo..<hi] + (hi < text.endIndex ? "…" : "")
  }
}
