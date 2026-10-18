import Foundation
import KataCore

// kata-pack build | validate | check-java   (see PLAN §2d)

struct Options {
  var command = ""
  var topic: String?
  var items: Set<String>?
  var allowMissing = false
  var content: String?
  var out: String?

  init(_ args: [String]) throws {
    var it = args.dropFirst().makeIterator()
    guard let cmd = it.next() else { throw CLIError("missing command") }
    command = cmd
    while let a = it.next() {
      switch a {
      case "--topic": topic = try value(&it, a)
      case "--items": items = Set(try value(&it, a).split(separator: ",").map(String.init))
      case "--allow-missing": allowMissing = true
      case "--content": content = try value(&it, a)
      case "--out": out = try value(&it, a)
      default: throw CLIError("unknown option '\(a)'")
      }
    }
  }

  private func value(_ it: inout IndexingIterator<ArraySlice<String>>, _ flag: String) throws -> String {
    guard let v = it.next() else { throw CLIError("\(flag) needs a value") }
    return v
  }
}

struct CLIError: Error, CustomStringConvertible {
  var description: String
  init(_ d: String) { description = d }
}

func stderr(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }

func findRepoRoot() throws -> URL {
  var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).standardizedFileURL
  while true {
    if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Content").path) { return dir }
    let parent = dir.deletingLastPathComponent()
    if parent == dir { throw CLIError("cannot find a directory containing Content/ above the current directory") }
    dir = parent
  }
}

let usage = """
  usage: kata-pack <command> [options]
    build       [--topic id]                                  write Kata/Resources/Packs/<topic>.kpack
    validate    [--topic id] [--items a,b] [--allow-missing]  check authoring rules
    check-java  [--topic id] [--items a,b]                    compile and run Java snippets
  options: --content <dir with topics/>   --out <pack output dir>
  """

func run() throws -> Int32 {
  let o = try Options(CommandLine.arguments)
  let root = try findRepoRoot()
  let contentRoot = o.content.map { URL(fileURLWithPath: $0) } ?? root.appendingPathComponent("Content")
  var dirs = PackBuilder.topicDirectories(contentRoot: contentRoot)
  if let t = o.topic { dirs = dirs.filter { $0.lastPathComponent == t } }
  guard !dirs.isEmpty else { throw CLIError("no topics found\(o.topic.map { " matching '\($0)'" } ?? "")") }

  switch o.command {
  case "build":
    let outDir = o.out.map { URL(fileURLWithPath: $0) }
      ?? root.appendingPathComponent("Kata/Resources/Packs", isDirectory: true)
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    var failed = false
    for dir in dirs {
      let report = PackBuilder.load(topicDirectory: dir, only: o.items)
      for i in report.issues { print(i) }
      guard !report.hasErrors, let pack = report.pack else { failed = true; continue }
      let url = outDir.appendingPathComponent("\(pack.topic.id).kpack")
      try PackBuilder.encode(pack).write(to: url, options: .atomic)
      print("built \(url.path): \(pack.items.count)/\(pack.topic.items.count) items")
    }
    return failed ? 1 : 0

  case "validate":
    var errors = 0, warnings = 0
    for dir in dirs {
      let issues = PackValidator.validate(
        topicDirectory: dir, options: .init(allowMissing: o.allowMissing, items: o.items))
      for i in issues { print(i) }
      errors += issues.errors.count
      warnings += issues.warnings.count
    }
    print("\(errors) error(s), \(warnings) warning(s)")
    return errors > 0 ? 1 : 0

  case "check-java":
    #if os(macOS)
      guard JavaCheckRunner.isJavaAvailable else { throw CLIError("java/javac not found on PATH") }
      let script = root.appendingPathComponent("Tools/JavaCheck.java")
      var units: [JavaUnit] = []
      for dir in dirs {
        let pack = try PackBuilder.build(topicDirectory: dir, only: o.items)
        units += JavaUnits.units(for: pack, only: o.items)
      }
      let report = try JavaCheckRunner.check(units: units, script: script)
      let enc = JSONEncoder()
      enc.outputFormatting = [.prettyPrinted, .sortedKeys]
      print(String(decoding: try enc.encode(report), as: UTF8.self))
      return report.ok ? 0 : 1
    #else
      throw CLIError("check-java is only available on macOS")
    #endif

  default:
    throw CLIError("unknown command '\(o.command)'")
  }
}

do {
  exit(try run())
} catch let e as BuildFailure {
  stderr(e.description)
  exit(1)
} catch {
  stderr("kata-pack: \(error)")
  stderr(usage)
  exit(2)
}
