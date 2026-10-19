import Foundation
import KataCore
#if os(macOS)
  import KataRun
#endif

// kata-pack build | validate | check-java   (see PLAN §2d)

struct Options {
  var command = ""
  var topic: String?
  var items: Set<String>?
  var allowMissing = false
  var content: String?
  var out: String?
  var katasOut: String?
  var noKatas = false
  var kataRuns: Int?
  var jdk: String?
  var timing = false
  var solution = false
  var requireAllKatas = false

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
      case "--katas-out": katasOut = try value(&it, a)
      case "--no-katas": noKatas = true
      case "--kata-runs":
        guard let n = Int(try value(&it, a)), n > 0 else { throw CLIError("--kata-runs needs a positive number") }
        kataRuns = n
      case "--jdk": jdk = try value(&it, a)
      case "--timing": timing = true
      case "--solution": solution = true
      case "--require-all-katas": requireAllKatas = true
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
                                                              and KataMac/Resources/Katas/<topic>.kkata
    validate    [--topic id] [--items a,b] [--allow-missing] [--require-all-katas]
                                                              check authoring rules
    check-java  [--topic id] [--items a,b] [--no-katas] [--kata-runs N] [--jdk <home>] [--timing]
                                                              compile and run Java snippets and katas
    kata-workspace --items a [--solution] --out <dir>         write a kata as an IDE project
  options: --content <dir with topics/>   --out <pack output dir>   --katas-out <kkata output dir>
  """

func run() async throws -> Int32 {
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
    let kataDir = o.katasOut.map { URL(fileURLWithPath: $0) }
      ?? root.appendingPathComponent("KataMac/Resources/Katas", isDirectory: true)
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    var failed = false
    for dir in dirs {
      let report = PackBuilder.load(topicDirectory: dir, only: o.items)
      for i in report.issues { print(i) }
      guard !report.hasErrors, let pack = report.pack else { failed = true; continue }
      let url = outDir.appendingPathComponent("\(pack.topic.id).kpack")
      try PackBuilder.encode(pack).write(to: url, options: .atomic)
      print("built \(url.path): \(pack.items.count)/\(pack.topic.items.count) items")
      if let katas = report.kataPack, !katas.katas.isEmpty {
        let kataURL = kataDir.appendingPathComponent("\(pack.topic.id).kkata")
        try FileManager.default.createDirectory(at: kataDir, withIntermediateDirectories: true)
        try PackBuilder.encodeKatas(katas).write(to: kataURL, options: .atomic)
        print("built \(kataURL.path): \(katas.katas.count) kata(s)")
      }
    }
    return failed ? 1 : 0

  case "validate":
    var errors = 0, warnings = 0
    for dir in dirs {
      let issues = PackValidator.validate(
        topicDirectory: dir,
        options: .init(allowMissing: o.allowMissing, items: o.items, requireAllKatas: o.requireAllKatas))
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
      var katas: [(kata: Kata, concurrency: Bool)] = []
      for dir in dirs {
        let pack = try PackBuilder.build(topicDirectory: dir, only: o.items)
        units += JavaUnits.units(for: pack, only: o.items)
        if !o.noKatas {
          let kataPack = try PackBuilder.buildKatas(topicDirectory: dir, only: o.items)
          for k in kataPack.katas where o.items?.contains(k.itemId) ?? true {
            katas.append((k, pack.topic.meta(for: k.itemId)?.category == "concurrency"))
          }
        }
      }
      let report = try JavaCheckRunner.check(units: units, script: script)
      var verifications: [KataVerification] = []
      if !katas.isEmpty {
        let jdk: JDK
        if let home = o.jdk {
          guard let found = JDKLocator.jdk(at: URL(fileURLWithPath: home)) else {
            throw CLIError("\(home) is not a JDK 21 or newer")
          }
          jdk = found
        } else {
          guard let found = JDKLocator.default(minimum: 21) else {
            throw CLIError("no JDK 21 or newer found (java_home -v 21+)")
          }
          jdk = found
        }
        stderr("kata checks use \(jdk.displayName) at \(jdk.home.path)")
        let verifier = KataVerifier(runner: KataCheckRunner(), jdk: jdk)
        for (kata, concurrency) in katas {
          let v = await verifier.verify(kata, runs: o.kataRuns, concurrency: concurrency)
          verifications.append(v)
          if o.timing {
            stderr(
              "\(kata.itemId): reference median \(v.medianMillis.map(String.init) ?? "?") ms over \(v.referenceRuns) run(s), starter median \(v.starterMedianMillis.map(String.init) ?? "?") ms over \(v.starterRuns) run(s)"
            )
          }
        }
      }
      struct Output: Encodable {
        var ok: Bool
        var units: [JavaCheckReport.UnitReport]
        var katas: [KataVerification]
      }
      let ok = report.ok && verifications.allSatisfy(\.ok)
      let enc = JSONEncoder()
      enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      print(String(decoding: try enc.encode(Output(ok: ok, units: report.units, katas: verifications)), as: UTF8.self))
      return ok ? 0 : 1
    #else
      throw CLIError("check-java is only available on macOS")
    #endif

  case "kata-workspace":
    #if os(macOS)
      guard let outPath = o.out else { throw CLIError("kata-workspace needs --out <dir>") }
      guard let ids = o.items, ids.count == 1, let id = ids.first else {
        throw CLIError("kata-workspace needs exactly one item: --items <id>")
      }
      for dir in dirs {
        let pack = try PackBuilder.buildKatas(topicDirectory: dir, only: [id])
        guard let kata = pack.kata(for: id) else { continue }
        let src = try WorkspaceWriter.write(
          kata: kata, files: o.solution ? kata.solution : kata.starter, to: URL(fileURLWithPath: outPath),
          options: .init(includeTests: true))
        print("wrote \(o.solution ? "solution" : "starter") of \(id) to \(src.deletingLastPathComponent().path)")
        return 0
      }
      throw CLIError("no kata for item '\(id)'")
    #else
      throw CLIError("kata-workspace is only available on macOS")
    #endif

  default:
    throw CLIError("unknown command '\(o.command)'")
  }
}

do {
  exit(try await run())
} catch let e as BuildFailure {
  stderr(e.description)
  exit(1)
} catch {
  stderr("kata-pack: \(error)")
  stderr(usage)
  exit(2)
}
