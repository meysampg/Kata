#if os(macOS)
  import Foundation
  import KataCore

  /// Everything one check run needs.
  public struct KataRunRequest: Sendable {
    /// The learner's files.
    public var files: [KataFile]
    /// The hidden tests.
    public var tests: [KataFile]
    public var jdk: JDK
    /// Minimum repetitions of every check (a check's own `repeat` can raise it).
    public var repeatCount: Int
    /// Wall-clock budget for the checks; the JVM is killed after this plus `compileAllowanceSeconds`.
    public var timeoutSeconds: Int
    public var compileAllowanceSeconds: Int
    /// Extra JVM options, e.g. `-XX:ActiveProcessorCount=1`.
    public var extraJVMArguments: [String]
    public var release: Int

    public init(
      files: [KataFile], tests: [KataFile], jdk: JDK, repeatCount: Int = 1, timeoutSeconds: Int = Kata.defaultTimeoutSeconds,
      compileAllowanceSeconds: Int = 3, extraJVMArguments: [String] = [], release: Int = 21
    ) {
      self.files = files; self.tests = tests; self.jdk = jdk; self.repeatCount = repeatCount
      self.timeoutSeconds = timeoutSeconds; self.compileAllowanceSeconds = compileAllowanceSeconds
      self.extraJVMArguments = extraJVMArguments; self.release = release
    }

    public init(kata: Kata, files: [KataFile]? = nil, jdk: JDK, repeatCount: Int = 1, extraJVMArguments: [String] = []) {
      self.init(
        files: files ?? kata.starter, tests: kata.tests, jdk: jdk, repeatCount: repeatCount,
        timeoutSeconds: kata.timeoutSeconds, extraJVMArguments: extraJVMArguments)
    }
  }

  /// Runs checks in a separate JVM, the same way for the app and for `kata-pack`.
  /// One run at a time: a new `run` cancels the one in flight.
  public actor KataCheckRunner {
    public let cache: HarnessCache
    private var current: Task<KataReport, Error>?

    public init(cache: HarnessCache = HarnessCache()) { self.cache = cache }

    /// Standard JVM options for the harness; `extra` goes first so callers can override.
    static func jvmArguments(jar: URL, archive: URL?, extra: [String]) -> [String] {
      var args = [
        "-XX:+UseSerialGC", "-Xmx256m", "-Xss1m", "-XX:TieredStopAtLevel=1", "-XX:-UsePerfData",
        "-Xshare:auto", "-Djava.awt.headless=true", "-Dfile.encoding=UTF-8",
      ]
      if let archive { args.append("-XX:SharedArchiveFile=\(archive.path)") }
      args += extra
      args += ["-cp", jar.path]
      return args
    }

    public func run(_ request: KataRunRequest) async throws -> KataReport {
      current?.cancel()
      let previous = current
      let task = Task { [cache] () async throws -> KataReport in
        _ = try? await previous?.value  // let the cancelled run clean up first
        return try await Self.execute(request, cache: cache)
      }
      current = task
      return try await withTaskCancellationHandler {
        try await task.value
      } onCancel: {
        task.cancel()
      }
    }

    private static func execute(_ request: KataRunRequest, cache: HarnessCache) async throws -> KataReport {
      let harness = try await cache.ensure(jdk: request.jdk)
      let fm = FileManager.default
      let runDir = cache.runsDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
      let src = runDir.appendingPathComponent("src", isDirectory: true)
      let tests = runDir.appendingPathComponent("tests", isDirectory: true)
      let classes = runDir.appendingPathComponent("classes", isDirectory: true)
      let reportFile = runDir.appendingPathComponent("report.ndjson")
      for dir in [src, tests, classes] { try fm.createDirectory(at: dir, withIntermediateDirectories: true) }
      defer { try? fm.removeItem(at: runDir) }
      for f in request.files { try f.source.write(to: src.appendingPathComponent(f.name), atomically: true, encoding: .utf8) }
      for f in request.tests { try f.source.write(to: tests.appendingPathComponent(f.name), atomically: true, encoding: .utf8) }

      let args =
        jvmArguments(jar: harness.jar, archive: harness.archive, extra: request.extraJVMArguments)
        + [
          "KataHarness", "--src", src.path, "--tests", tests.path, "--classes", classes.path,
          "--report", reportFile.path, "--release", String(request.release),
          "--repeat", String(max(1, request.repeatCount)),
        ]
      let outcome = try await KataProcess(
        executable: request.jdk.java, arguments: args, currentDirectory: runDir,
        environment: HarnessCache.environment(tmp: runDir),
        timeout: .seconds(request.timeoutSeconds + request.compileAllowanceSeconds)
      ).run()

      let text = (try? String(contentsOf: reportFile, encoding: .utf8)) ?? ""
      var report = KataReport.parse(ndjson: text, stderr: outcome.stderrText + outcome.stdoutText)
      report.wallMillis = outcome.wallMillis
      report.timedOut = outcome.timedOut
      if outcome.timedOut {
        report.crashed = true
        if report.stderrTail.isEmpty { report.stderrTail = "The run was stopped after the time limit." }
      } else if outcome.outputCapExceeded {
        report.crashed = true
      }
      return report
    }
  }
#endif
