import Foundation
import KataCore

/// The harness's NDJSON report, parsed (MAC_PLAN §4.3). Pure: no JDK needed.
public struct KataReport: Sendable, Equatable {
  public enum Severity: String, Sendable, Equatable { case error, warning }

  public struct Diagnostic: Sendable, Equatable {
    public var severity: Severity
    /// File name (no directory), nil for diagnostics without a position.
    public var file: String?
    /// 1-based line and column for display only (javac expands tabs in columns).
    public var line: Int
    public var column: Int
    /// UTF-16 offsets into the file, the same unit as `NSString`; -1 when unknown.
    public var start: Int
    public var end: Int
    public var code: String
    public var message: String

    public init(
      severity: Severity, file: String?, line: Int, column: Int, start: Int, end: Int, code: String,
      message: String
    ) {
      self.severity = severity; self.file = file; self.line = line; self.column = column
      self.start = start; self.end = end; self.code = code; self.message = message
    }

    /// The range to underline in `source`, clamped to its UTF-16 length. A single-point range
    /// is widened by one unit when possible so it stays visible.
    public func range(in source: String) -> NSRange? {
      guard start >= 0 else { return nil }
      let length = (source as NSString).length
      let s = min(start, length)
      var e = min(max(end, s), length)
      if e == s, s < length { e = s + 1 }
      return NSRange(location: s, length: e - s)
    }

    /// Whether the diagnostic comes from the learner's code (not a hidden test).
    public var isPolicyViolation: Bool { code == "kata.policy" }
  }

  public enum Status: String, Sendable, Equatable {
    case pass, fail, error, timeout, blocked, exited
  }

  public struct CheckResult: Sendable, Equatable {
    public var id: String
    public var kind: CheckKind
    public var status: Status
    public var message: String
    public var file: String?
    public var line: Int?
    public var millis: Int
    public var output: String
    /// 1-based repetition that failed, when the check repeats.
    public var run: Int?
    /// An earlier check timed out, so this result may be affected by its leftover thread.
    public var affected: Bool

    public var passed: Bool { status == .pass }
  }

  /// nil when the harness never got as far as reporting the compile result.
  public var compileOK: Bool?
  public var diagnostics: [Diagnostic] = []
  public var checks: [CheckResult] = []
  /// Harness-reported duration; nil without `done`.
  public var doneMillis: Int?
  /// The process ended without a `done` event (killed, crashed, or hung).
  public var crashed: Bool = false
  /// The wall-clock deadline killed the process.
  public var timedOut: Bool = false
  public var stderrTail: String = ""
  /// Harness-level error message, if the harness itself failed.
  public var harnessError: String?
  /// Lines that were not valid events (garbage or a truncated tail).
  public var ignoredLines: Int = 0
  /// Wall time of the whole run as seen by Swift.
  public var wallMillis: Int = 0

  public init() {}

  public var errors: [Diagnostic] { diagnostics.filter { $0.severity == .error } }
  public var passedCount: Int { checks.filter(\.passed).count }
  public func result(for id: String) -> CheckResult? { checks.first { $0.id == id } }

  /// Every expected check passed and nothing went wrong around them.
  public func allPassed(expecting specs: [KataCheckSpec]) -> Bool {
    compileOK == true && !crashed && checks.map(\.id) == specs.map(\.id) && checks.allSatisfy(\.passed)
  }

  // MARK: Parsing

  private struct Event: Decodable {
    var type: String
    var ok: Bool?
    var diagnostics: [Diag]?
    var id: String?
    var kind: String?
    var status: String?
    var message: String?
    var file: String?
    var line: Int?
    var millis: Int?
    var output: String?
    var run: Int?
    var affected: Bool?

    struct Diag: Decodable {
      var severity: String
      var file: String?
      var line: Int?
      var column: Int?
      var start: Int?
      var end: Int?
      var code: String?
      var message: String
    }
  }

  /// Parses an NDJSON report. Garbage and truncated lines are skipped; a missing `done` event
  /// sets `crashed` and attaches the tail of stderr.
  public static func parse(ndjson: String, stderr: String = "") -> KataReport {
    var report = KataReport()
    var sawDone = false
    let decoder = JSONDecoder()
    for raw in ndjson.split(separator: "\n", omittingEmptySubsequences: true) {
      guard let event = try? decoder.decode(Event.self, from: Data(raw.utf8)) else {
        report.ignoredLines += 1
        continue
      }
      switch event.type {
      case "compile":
        report.compileOK = event.ok ?? false
        report.diagnostics = (event.diagnostics ?? []).map {
          Diagnostic(
            severity: $0.severity == "error" ? .error : .warning, file: $0.file, line: $0.line ?? 0,
            column: $0.column ?? 0, start: $0.start ?? -1, end: $0.end ?? -1, code: $0.code ?? "",
            message: $0.message)
        }
      case "check":
        guard let id = event.id else { report.ignoredLines += 1; continue }
        report.checks.append(
          CheckResult(
            id: id, kind: CheckKind(rawValue: event.kind ?? "") ?? .behaviour,
            status: Status(rawValue: event.status ?? "") ?? .error, message: event.message ?? "",
            file: event.file, line: event.line, millis: event.millis ?? 0, output: event.output ?? "",
            run: event.run, affected: event.affected ?? false))
      case "done":
        sawDone = true
        report.doneMillis = event.millis
      case "error":
        report.harnessError = event.message
      default:
        report.ignoredLines += 1
      }
    }
    if !sawDone {
      report.crashed = true
    }
    if report.crashed || report.harnessError != nil {
      report.stderrTail = tail(of: stderr, lines: 20)
    }
    return report
  }

  static func tail(of text: String, lines count: Int) -> String {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    return lines.suffix(count).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
