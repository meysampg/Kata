import Foundation
import KataCore
import KataRun
import Observation

/// Runs a kata's checks against the learner's files. The real implementation spawns a JDK; tests
/// and previews can substitute their own.
protocol KataChecking: Sendable {
  func run(files: [KataFile], kata: Kata) async throws -> KataReport
}

enum KataCheckError: Error, Equatable {
  case noJDK
}

/// Finds the JDK to use (the Settings choice, else `java_home -v 21+`) and owns the shared runner.
@MainActor @Observable
final class JavaToolchain {
  /// Every installed JDK of version 21 or newer.
  private(set) var installed: [JDK] = []
  /// What `java_home -v 21+` picks.
  private(set) var defaultJDK: JDK?
  /// A search has finished, so `defaultJDK == nil` means "none installed".
  private(set) var didSearch = false
  private(set) var isSearching = false

  let runner: KataCheckRunner
  private let preferredHome: @MainActor () -> String?

  init(runner: KataCheckRunner = KataCheckRunner(), preferredHome: @escaping @MainActor () -> String? = { nil }) {
    self.runner = runner
    self.preferredHome = preferredHome
  }

  private var search: Task<Void, Never>?

  /// Looks for JDKs off the main actor. Callers during a search wait for the same search.
  func refresh() async {
    if let search { await search.value; return }
    isSearching = true
    let task = Task { @MainActor in
      let found = await Task.detached(priority: .userInitiated) {
        (JDKLocator.installed(minimum: 21), JDKLocator.default(minimum: 21))
      }.value
      installed = found.0
      defaultJDK = found.1
      didSearch = true
      isSearching = false
      search = nil
    }
    search = task
    await task.value
  }

  /// The JDK a run should use now: the Settings choice when it still exists, else the default.
  func selectedJDK() async -> JDK? {
    if !didSearch { await refresh() }
    return currentJDK
  }

  /// `selectedJDK()` without searching.
  var currentJDK: JDK? {
    if let home = preferredHome(), let chosen = installed.first(where: { $0.home.path == home }) { return chosen }
    return defaultJDK
  }

  /// True once a search found no usable JDK.
  var isMissing: Bool { didSearch && currentJDK == nil }
}

struct JavaKataChecker: KataChecking {
  let toolchain: JavaToolchain

  func run(files: [KataFile], kata: Kata) async throws -> KataReport {
    guard let jdk = await toolchain.selectedJDK() else { throw KataCheckError.noJDK }
    return try await toolchain.runner.run(KataRunRequest(kata: kata, files: files, jdk: jdk))
  }
}

// MARK: - Settings "Test" button

struct JavaTestResult: Equatable {
  var ok: Bool
  var summary: String
  var detail: String
}

extension JavaToolchain {
  /// `javac -version`, then compile the harness and run a one-check sample kata.
  func test() async -> JavaTestResult {
    guard let jdk = await selectedJDK() else {
      return JavaTestResult(ok: false, summary: "No JDK 21+ found", detail: "Install one, then look again.")
    }
    let temp = FileManager.default.temporaryDirectory
    let version = try? await KataProcess(
      executable: jdk.javac, arguments: ["-version"], currentDirectory: temp,
      environment: HarnessCache.environment(tmp: temp), timeout: .seconds(20)
    ).run()
    let javac = version.map { ($0.stdoutText + $0.stderrText).trimmingCharacters(in: .whitespacesAndNewlines) } ?? "javac did not start"
    let sample = Kata(
      itemId: "sample", kind: .fix, title: "Sample", minutes: 10, task: [],
      starter: [KataFile(name: "Sample.java", source: "final class Sample { static int two() { return 2; } }\n")],
      solution: [],
      tests: [
        KataFile(
          name: "SampleTest.java",
          source: "import kata.*;\nclass SampleTest { @Check(id = \"sample\") void two() { Expect.equal(2, Sample.two(), \"two\"); } }\n")
      ],
      checks: [KataCheckSpec(id: "sample", kind: .behaviour, title: "Sample")], hints: [])
    do {
      let clock = ContinuousClock()
      let began = clock.now
      let report = try await runner.run(KataRunRequest(kata: sample, jdk: jdk))
      let elapsed = clock.now - began
      let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
      if report.compileOK == true, report.allPassed(expecting: sample.checks) {
        return JavaTestResult(ok: true, summary: String(format: "Works. The sample kata ran in %.1f s.", seconds), detail: javac)
      }
      let why = report.errors.first?.message ?? report.checks.first?.message ?? report.stderrTail
      return JavaTestResult(ok: false, summary: "The sample kata did not pass", detail: "\(javac)\n\(why)")
    } catch {
      return JavaTestResult(ok: false, summary: "The harness could not run", detail: "\(javac)\n\(error)")
    }
  }
}
