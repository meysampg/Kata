import Foundation

public struct StrippedSource: Sendable, Equatable {
  /// Source without marker lines, no trailing newline.
  public var source: String
  /// Region id -> inclusive 1-based line range in `source`.
  public var regions: [String: LineRange]
}

public struct MarkerError: Error, Sendable, Equatable, CustomStringConvertible {
  public var line: Int
  public var message: String
  public var description: String { "line \(line): \(message)" }
}

public enum MarkerStripper {
  /// Removes `// [[id` / `// ]]` marker lines and computes region line ranges in the stripped
  /// source. Regions may be indented; nesting is parsed (the validator rejects overlaps).
  public static func strip(_ raw: String) throws -> StrippedSource {
    let text = raw.replacingOccurrences(of: "\r\n", with: "\n")
    var out: [String] = []
    var regions: [String: LineRange] = [:]
    var open: [(id: String, start: Int, line: Int)] = []

    for (i, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
      let n = i + 1
      let t = line.trimmingCharacters(in: .whitespaces)
      if t.hasPrefix("//"), let id = startID(t) {
        guard !id.isEmpty, id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        else { throw MarkerError(line: n, message: "invalid region id '\(id)'") }
        guard regions[id] == nil, !open.contains(where: { $0.id == id }) else {
          throw MarkerError(line: n, message: "duplicate region '\(id)'")
        }
        open.append((id, out.count + 1, n))
      } else if isEnd(t) {
        guard let r = open.popLast() else {
          throw MarkerError(line: n, message: "region end marker without a start")
        }
        guard out.count >= r.start else {
          throw MarkerError(line: r.line, message: "region '\(r.id)' is empty")
        }
        regions[r.id] = LineRange(start: r.start, end: out.count)
      } else {
        out.append(String(line))
      }
    }
    if let r = open.last {
      throw MarkerError(line: r.line, message: "region '\(r.id)' is never closed")
    }
    while let last = out.last, last.trimmingCharacters(in: .whitespaces).isEmpty { out.removeLast() }
    for (id, r) in regions where r.end > out.count {
      regions[id] = LineRange(start: r.start, end: out.count)
    }
    return StrippedSource(source: out.joined(separator: "\n"), regions: regions)
  }

  private static func startID(_ t: String) -> String? {
    var rest = t.dropFirst(2).drop(while: { $0 == " " || $0 == "\t" })
    guard rest.hasPrefix("[[") else { return nil }
    rest = rest.dropFirst(2)
    return rest.trimmingCharacters(in: .whitespaces)
  }

  private static func isEnd(_ t: String) -> Bool {
    guard t.hasPrefix("//") else { return false }
    let rest = t.dropFirst(2).trimmingCharacters(in: .whitespaces)
    return rest == "]]"
  }
}
