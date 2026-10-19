#if os(macOS)
  import CryptoKit
  import Foundation

  /// A compiled harness, ready to put on a JVM classpath.
  public struct HarnessBuild: Sendable, Equatable {
    public var key: String
    /// `harness.jar` (class data sharing needs a jar, not a directory).
    public var jar: URL
    /// The AppCDS archive, when the warm-up produced one.
    public var archive: URL?
  }

  public struct HarnessError: Error, CustomStringConvertible, Sendable {
    public var description: String
  }

  /// Compiles the bundled harness once per JDK build and keeps it under
  /// `~/Library/Caches/com.github.meysampg.kata.mac/harness/<key>/` (MAC_PLAN §4.2).
  public actor HarnessCache {
    public static let bundleIdentifier = "com.github.meysampg.kata.mac"

    public static var defaultRoot: URL {
      FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(bundleIdentifier, isDirectory: true)
    }

    /// The harness sources shipped as package resources.
    public static var bundledSources: URL {
      Bundle.module.url(forResource: "Harness", withExtension: nil)!
    }

    public let root: URL
    private let sources: URL
    private var memo: [String: HarnessBuild] = [:]

    public init(root: URL = HarnessCache.defaultRoot, sources: URL = HarnessCache.bundledSources) {
      self.root = root; self.sources = sources
    }

    /// Where per-run scratch directories live.
    public nonisolated var runsDirectory: URL { root.appendingPathComponent("runs", isDirectory: true) }

    /// Builds the harness for `jdk` unless a valid build exists.
    public func ensure(jdk: JDK) async throws -> HarnessBuild {
      let key = try Self.key(sources: sources, jdk: jdk)
      if let hit = memo[key] { return hit }
      let dir = root.appendingPathComponent("harness/\(key)", isDirectory: true)
      let fm = FileManager.default
      try fm.createDirectory(at: dir.deletingLastPathComponent(), withIntermediateDirectories: true)
      let ready = dir.appendingPathComponent("ready")

      var attempts = 0
      while true {
        attempts += 1
        if fm.fileExists(atPath: ready.path) { break }
        do {
          try fm.createDirectory(at: dir, withIntermediateDirectories: false)  // we own the build
          do {
            try await build(into: dir, jdk: jdk)
            try Data().write(to: ready)
          } catch {
            try? fm.removeItem(at: dir)
            throw error
          }
          break
        } catch let e as CocoaError where e.code == .fileWriteFileExists {
          // Another process is building: wait for it.
          var waited = 0
          while !fm.fileExists(atPath: ready.path), waited < 600 {
            try await Task.sleep(for: .milliseconds(100))
            waited += 1
          }
          if fm.fileExists(atPath: ready.path) { break }
          if attempts >= 2 { throw HarnessError(description: "timed out waiting for the harness build") }
          try? fm.removeItem(at: dir)  // a builder died; start over
        }
      }
      let archive = dir.appendingPathComponent("harness.jsa")
      let build = HarnessBuild(
        key: key, jar: dir.appendingPathComponent("harness.jar"),
        archive: fm.fileExists(atPath: archive.path) ? archive : nil)
      memo[key] = build
      return build
    }

    /// `sha256(harness sources) + JDK build`, shortened.
    static func key(sources: URL, jdk: JDK) throws -> String {
      var hasher = SHA256()
      for url in try javaFiles(in: sources) {
        hasher.update(data: Data(url.path.replacingOccurrences(of: sources.path, with: "").utf8))
        hasher.update(data: try Data(contentsOf: url))
      }
      let release = (try? Data(contentsOf: jdk.home.appendingPathComponent("release"))) ?? Data(jdk.version.utf8)
      hasher.update(data: release)
      return hasher.finalize().map { String(format: "%02x", $0) }.joined().prefix(16).description
    }

    static func javaFiles(in dir: URL) throws -> [URL] {
      guard
        let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)
      else { throw HarnessError(description: "harness sources not found at \(dir.path)") }
      return (e.allObjects as? [URL] ?? []).filter { $0.pathExtension == "java" }
        .sorted { $0.path < $1.path }
    }

    private func build(into dir: URL, jdk: JDK) async throws {
      let classes = dir.appendingPathComponent("classes", isDirectory: true)
      try FileManager.default.createDirectory(at: classes, withIntermediateDirectories: true)
      let files = try Self.javaFiles(in: sources).map(\.path)
      let env = Self.environment(tmp: dir)
      let compile = try await KataProcess(
        executable: jdk.javac,
        arguments: ["--release", "21", "-Xlint:all", "-encoding", "UTF-8", "-d", classes.path] + files,
        currentDirectory: dir, environment: env, timeout: .seconds(120)
      ).run()
      guard compile.exitStatus == 0 else {
        throw HarnessError(description: "harness compile failed: \(compile.stderrText + compile.stdoutText)")
      }
      let jar = dir.appendingPathComponent("harness.jar")
      let pack = try await KataProcess(
        executable: jdk.jar, arguments: ["--create", "--file", jar.path, "-C", classes.path, "."],
        currentDirectory: dir, environment: env, timeout: .seconds(60)
      ).run()
      guard pack.exitStatus == 0 else {
        throw HarnessError(description: "jar failed: \(pack.stderrText)")
      }
      try? FileManager.default.removeItem(at: classes)
      await warmUp(dir: dir, jdk: jdk, jar: jar, env: env)
    }

    /// Runs a tiny kata once with `-XX:ArchiveClassesAtExit` so later runs start from a CDS archive.
    /// Failure only costs start-up time, so it is ignored.
    private func warmUp(dir: URL, jdk: JDK, jar: URL, env: [String: String]) async {
      let warm = dir.appendingPathComponent("warm", isDirectory: true)
      defer { try? FileManager.default.removeItem(at: warm) }
      do {
        let fm = FileManager.default
        for sub in ["src", "tests", "classes"] {
          try fm.createDirectory(at: warm.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
        try "final class Warm { int one() { return 1; } }\n".write(
          to: warm.appendingPathComponent("src/Warm.java"), atomically: true, encoding: .utf8)
        try """
          import kata.*;
          class WarmTest {
              @Check(id = "one") void one() { Expect.equal(1, new Warm().one(), "one"); }
              @Check(id = "design", kind = Kind.DESIGN) void design() {
                  Expect.isTrue(Types.named("Warm") != null, "Warm");
                  Expect.none(Source.type("Warm").switches(), "switch");
              }
          }
          """.write(to: warm.appendingPathComponent("tests/WarmTest.java"), atomically: true, encoding: .utf8)
        let archive = dir.appendingPathComponent("harness.jsa")
        let args =
          KataCheckRunner.jvmArguments(jar: jar, archive: nil, extra: ["-XX:ArchiveClassesAtExit=\(archive.path)"])
          + [
            "KataHarness", "--src", warm.appendingPathComponent("src").path, "--tests",
            warm.appendingPathComponent("tests").path, "--classes", warm.appendingPathComponent("classes").path,
            "--report", warm.appendingPathComponent("report.ndjson").path, "--release", "21",
          ]
        _ = try await KataProcess(
          executable: jdk.java, arguments: args, currentDirectory: warm, environment: env, timeout: .seconds(60)
        ).run()
      } catch {
        // no archive; runs still work, just start a little slower
      }
    }

    static func environment(tmp: URL) -> [String: String] {
      [
        "PATH": "/usr/bin:/bin", "HOME": NSHomeDirectory(), "LANG": "en_US.UTF-8", "TMPDIR": tmp.path + "/",
      ]
    }
  }
#endif
