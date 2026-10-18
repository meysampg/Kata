import Foundation

struct AnyKey: CodingKey {
  var stringValue: String
  var intValue: Int? { nil }
  init?(stringValue: String) { self.stringValue = stringValue }
  init?(intValue: Int) { nil }
}

extension Decoder {
  /// Throws when the current keyed container holds keys outside `allowed`.
  func rejectUnknownKeys(allowed: Set<String>) throws {
    let c = try container(keyedBy: AnyKey.self)
    let unknown = c.allKeys.map(\.stringValue).filter { !allowed.contains($0) }.sorted()
    if !unknown.isEmpty {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: codingPath,
          debugDescription: "Unknown key(s): \(unknown.joined(separator: ", "))"))
    }
  }

  func rejectUnknownKeys<K: CodingKey & CaseIterable>(_ type: K.Type) throws {
    try rejectUnknownKeys(allowed: Set(K.allCases.map(\.stringValue)))
  }
}

extension CodingUserInfoKey {
  /// `[String: CardType]` mapping role id to its card type, used to infer `type`
  /// when decoding authoring cards that omit it.
  public static let kataRoleTypes = CodingUserInfoKey(rawValue: "kata.roleTypes")!
}

public enum DecodingErrorFormatter {
  public static func describe(_ error: Error) -> String {
    func path(_ ctx: DecodingError.Context) -> String {
      let p = ctx.codingPath.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }
        .joined()
      return p.hasPrefix(".") ? String(p.dropFirst()) : p
    }
    guard let e = error as? DecodingError else { return "\(error)" }
    switch e {
    case .dataCorrupted(let c):
      let p = path(c)
      return p.isEmpty ? c.debugDescription : "\(p): \(c.debugDescription)"
    case .keyNotFound(let key, let c):
      let p = path(c)
      return "\(p.isEmpty ? "" : p + ": ")missing key '\(key.stringValue)'"
    case .typeMismatch(_, let c), .valueNotFound(_, let c):
      let p = path(c)
      return "\(p.isEmpty ? "" : p + ": ")\(c.debugDescription)"
    @unknown default:
      return "\(error)"
    }
  }
}
