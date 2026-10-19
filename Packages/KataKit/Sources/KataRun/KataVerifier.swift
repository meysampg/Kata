#if os(macOS)
  import Foundation
  import KataCore

  /// The outcome of verifying one kata's reference solution and starter.
  public struct KataVerification: Sendable, Codable, Equatable {
    public var itemId: String
    public var ok: Bool
    public var failures: [String]
    public var warnings: [String]
    public var referenceRuns: Int
    public var starterRuns: Int
    /// Median wall time of one reference run (JVM start to exit).
    public var medianMillis: Int?
    public var starterMedianMillis: Int?
  }

  /// Checks that a kata behaves as its kind promises (MAC_PLAN §3.2), using the real runner.
  public struct KataVerifier: Sendable {
    public static let slowMillis = 2000
    public let runner: KataCheckRunner
    public let jdk: JDK

    public init(runner: KataCheckRunner, jdk: JDK) {
      self.runner = runner; self.jdk = jdk
    }

    /// - Parameters:
    ///   - runs: repetitions of reference and starter (default: the kata's `stressRuns`, or 5).
    ///   - concurrency: also run the reference with 1 and 4 processors.
    public func verify(_ kata: Kata, runs: Int? = nil, concurrency: Bool = false) async -> KataVerification {
      let n = max(1, runs ?? kata.effectiveStressRuns)
      var v = KataVerification(
        itemId: kata.itemId, ok: true, failures: [], warnings: [], referenceRuns: 0, starterRuns: 0)
      var referenceTimes: [Int] = []
      var starterTimes: [Int] = []

      let cpuVariants: [[String]] = concurrency
        ? [[], ["-XX:ActiveProcessorCount=1"], ["-XX:ActiveProcessorCount=4"]] : [[]]
      for extra in cpuVariants {
        let label = extra.isEmpty ? "" : " [\(extra[0].split(separator: "=").last ?? "")-cpu]"
        for i in 1...n {
          let tag = "reference run \(i)/\(n)\(label)"
          do {
            let report = try await runner.run(
              KataRunRequest(kata: kata, files: kata.solution, jdk: jdk, extraJVMArguments: extra))
            v.referenceRuns += 1
            if extra.isEmpty { referenceTimes.append(report.wallMillis) }
            v.failures += Self.referenceProblems(report, kata: kata).map { "\(tag): \($0)" }
          } catch {
            v.failures.append("\(tag): \(error)")
          }
        }
      }
      for i in 1...n {
        let tag = "starter run \(i)/\(n)"
        do {
          let report = try await runner.run(KataRunRequest(kata: kata, files: kata.starter, jdk: jdk))
          v.starterRuns += 1
          starterTimes.append(report.wallMillis)
          v.failures += Self.starterProblems(report, kata: kata).map { "\(tag): \($0)" }
        } catch {
          v.failures.append("\(tag): \(error)")
        }
      }
      v.medianMillis = Self.median(referenceTimes)
      v.starterMedianMillis = Self.median(starterTimes)
      if let m = v.medianMillis, m > Self.slowMillis {
        v.warnings.append("median reference run took \(m) ms (target < \(Self.slowMillis) ms)")
      }
      // Identical failures repeat every run; keep the output readable.
      var seen = Set<String>()
      v.failures = v.failures.filter { seen.insert(String($0.drop(while: { $0 != ":" }))).inserted }
      v.ok = v.failures.isEmpty
      return v
    }

    static func median(_ values: [Int]) -> Int? {
      guard !values.isEmpty else { return nil }
      let s = values.sorted()
      return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    // MARK: Rules

    static func commonProblems(_ report: KataReport, kata: Kata) -> [String] {
      var out: [String] = []
      if report.timedOut { out.append("the run hit the wall-clock limit") }
      if report.crashed && !report.timedOut {
        out.append("the harness crashed: \(report.harnessError ?? report.stderrTail)")
      }
      if let e = report.harnessError, !report.crashed { out.append("harness error: \(e)") }
      return out
    }

    static func idProblems(_ report: KataReport, kata: Kata) -> [String] {
      report.checks.map(\.id) == kata.checks.map(\.id)
        ? []
        : [
          "reported checks [\(report.checks.map(\.id).joined(separator: ", "))] differ from kata.json [\(kata.checks.map(\.id).joined(separator: ", "))]"
        ]
    }

    static func compileProblems(_ report: KataReport) -> [String] {
      report.errors.map { "\($0.file ?? "?"):\($0.line): \($0.message)" }
    }

    static func referenceProblems(_ report: KataReport, kata: Kata) -> [String] {
      var out = commonProblems(report, kata: kata)
      guard report.compileOK == true else {
        return out + ["the reference does not compile"] + compileProblems(report)
      }
      out += idProblems(report, kata: kata)
      for c in report.checks where !c.passed {
        out.append("check \(c.id) \(c.status.rawValue): \(c.message)")
      }
      return out
    }

    static func starterProblems(_ report: KataReport, kata: Kata) -> [String] {
      var out = commonProblems(report, kata: kata)
      if report.compileOK != true {
        if kata.starterCompiles {
          out.append("the starter does not compile")
          out += compileProblems(report)
        }
        return out
      }
      out += idProblems(report, kata: kata)
      for c in report.checks where c.status == .timeout {
        out.append("check \(c.id) timed out on the starter: \(c.message)")
      }
      let behaviour = report.checks.filter { $0.kind == .behaviour }
      let design = report.checks.filter { $0.kind == .design }
      switch kata.kind {
      case .refactor:
        for c in behaviour where !c.passed { out.append("behaviour check \(c.id) must stay green on the starter but is \(c.status.rawValue): \(c.message)") }
        if design.allSatisfy(\.passed) { out.append("no design check fails on the starter") }
      case .fix:
        if behaviour.allSatisfy(\.passed) { out.append("no behaviour check fails on the starter") }
      case .implement:
        if report.checks.allSatisfy(\.passed) { out.append("no check fails on the starter") }
      }
      return out
    }
  }
#endif
