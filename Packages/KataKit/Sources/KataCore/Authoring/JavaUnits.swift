import Foundation

/// One independently compiled Java unit for `Tools/JavaCheck.java`.
public struct JavaUnit: Sendable, Hashable {
  public var name: String
  public var files: [String: String]
  /// If set, `Main.main` is run and its stdout compared with this text.
  public var expectedOutput: String?
}

public enum JavaUnits {
  /// Code-card files (compiled, and run when `expectedOutput` is set) and every exercise
  /// `compile.template` with its code substituted (`Unit.java`, compile only).
  public static func units(for pack: Pack, only: Set<ItemID>? = nil) -> [JavaUnit] {
    var out: [JavaUnit] = []
    guard pack.topic.codeLanguage == "java" else { return out }
    for item in pack.items where only?.contains(item.id) ?? true {
      for card in item.cards {
        guard case .code(let code) = card.content else { continue }
        let stem = (code.file as NSString).deletingPathExtension
        out.append(
          JavaUnit(
            name: "\(item.id)--code-\(stem)", files: [code.file: code.source + "\n"],
            expectedOutput: code.expectedOutput))
      }
      for ex in item.exercises {
        guard let compile = ex.compile, let code = ex.compilableCode else { continue }
        let text = compile.render(code: code).joined(separator: "\n") + "\n"
        out.append(JavaUnit(name: "\(item.id)--\(ex.id)", files: ["Unit.java": text], expectedOutput: nil))
      }
    }
    return out
  }

  /// Writes `<dir>/<unit>/<file>` and `<dir>/<unit>/expected.txt`.
  public static func write(_ units: [JavaUnit], to dir: URL) throws {
    let fm = FileManager.default
    for u in units {
      let udir = dir.appendingPathComponent(u.name, isDirectory: true)
      try fm.createDirectory(at: udir, withIntermediateDirectories: true)
      for (name, content) in u.files {
        try content.write(to: udir.appendingPathComponent(name), atomically: true, encoding: .utf8)
      }
      if let expected = u.expectedOutput {
        try (expected + "\n").write(
          to: udir.appendingPathComponent("expected.txt"), atomically: true, encoding: .utf8)
      }
    }
  }
}
