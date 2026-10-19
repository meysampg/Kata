import Foundation

/// Reads `items/<id>/kata/` (MAC_PLAN §2.1) into a `Kata`, embedding every file.
public enum KataLoader {
  public static let directoryName = "kata"
  static let subdirectories = ["starter", "solution", "tests"]

  /// Whether the item has a `kata/` directory.
  public static func hasKata(itemDir: URL) -> Bool {
    var isDir: ObjCBool = false
    return FileManager.default.fileExists(
      atPath: itemDir.appendingPathComponent(directoryName).path, isDirectory: &isDir) && isDir.boolValue
  }

  /// Loads the kata of an item. Problems are returned as issues; the kata is `nil` when any
  /// of them is an error.
  public static func load(itemDir: URL, itemId: ItemID, path: String) -> (Kata?, [ValidationIssue]) {
    guard hasKata(itemDir: itemDir) else { return (nil, []) }
    let dir = itemDir.appendingPathComponent(directoryName, isDirectory: true)
    let base = "\(path)/kata"
    var issues: [ValidationIssue] = []
    func err(_ file: String, _ message: String) { issues.append(.init(.error, "\(base)/\(file)", message)) }

    let manifest: KataManifest
    do {
      manifest = try JSONDecoder().decode(
        KataManifest.self, from: Data(contentsOf: dir.appendingPathComponent("kata.json")))
    } catch {
      err("kata.json", PackBuilder.describe(error))
      return (nil, issues)
    }

    // Nothing but kata.json and the three file directories.
    let fm = FileManager.default
    for name in ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).sorted()
    where name != "kata.json" && !subdirectories.contains(name) && !name.hasPrefix(".") {
      err(name, "unexpected entry in kata/ (only kata.json, starter/, solution/, tests/ are allowed)")
    }

    func read(_ names: [String], in sub: String) -> [KataFile] {
      var files: [KataFile] = []
      var seen = Set<String>()
      for name in names {
        if !seen.insert(name).inserted { err("kata.json", "\(sub) lists '\(name)' twice"); continue }
        guard !name.contains("/"), name.hasSuffix(".java"), !name.hasPrefix(".") else {
          err("kata.json", "\(sub) file '\(name)' must be a plain name ending in .java")
          continue
        }
        let url = dir.appendingPathComponent(sub).appendingPathComponent(name)
        do {
          files.append(KataFile(name: name, source: try String(contentsOf: url, encoding: .utf8)))
        } catch {
          err("\(sub)/\(name)", "listed in kata.json but cannot be read")
        }
      }
      // Stray files on disk.
      let onDisk = (try? fm.contentsOfDirectory(atPath: dir.appendingPathComponent(sub).path)) ?? []
      for name in onDisk.sorted() where !names.contains(name) && !name.hasPrefix(".") {
        err("\(sub)/\(name)", "file is not listed in kata.json \(sub)")
      }
      return files
    }

    let starter = read(manifest.starter, in: "starter")
    let solution = read(manifest.solution, in: "solution")
    let tests = read(manifest.tests, in: "tests")
    guard !issues.contains(where: { $0.severity == .error }) else { return (nil, issues) }

    let kata = Kata(
      itemId: itemId, kind: manifest.kind, title: manifest.title, minutes: manifest.minutes,
      task: manifest.task, starter: starter, readOnly: Set(manifest.readOnly), solution: solution,
      tests: tests, checks: manifest.checks, hints: manifest.hints,
      timeoutSeconds: manifest.timeoutSeconds, stressRuns: manifest.stressRuns,
      starterCompiles: manifest.starterCompiles)
    return (kata, issues)
  }
}
