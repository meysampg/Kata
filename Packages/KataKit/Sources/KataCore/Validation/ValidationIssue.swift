import Foundation

public struct ValidationIssue: Sendable, Hashable, CustomStringConvertible {
  public enum Severity: String, Sendable, Hashable, Comparable {
    case warning, error

    public static func < (l: Severity, r: Severity) -> Bool { l == .warning && r == .error }
  }

  public var severity: Severity
  public var path: String
  public var message: String

  public init(_ severity: Severity, _ path: String, _ message: String) {
    self.severity = severity; self.path = path; self.message = message
  }

  public var description: String { "\(severity.rawValue): \(path): \(message)" }
}

extension Sequence where Element == ValidationIssue {
  public var errors: [ValidationIssue] { filter { $0.severity == .error } }
  public var warnings: [ValidationIssue] { filter { $0.severity == .warning } }
}
