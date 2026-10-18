import CoreGraphics
import Foundation

public struct DiagramIssue: Sendable, Equatable, CustomStringConvertible {
  public enum Severity: String, Sendable, Equatable { case error, warning }
  public var severity: Severity
  public var message: String

  public init(_ severity: Severity, _ message: String) {
    self.severity = severity; self.message = message
  }

  public var description: String { "\(severity.rawValue): \(message)" }
}

/// Authoring checks used by the pack validator.
public enum DiagramLinter {
  public static let maxNodes = 8
  public static let maxEdges = 10
  public static let warnColumns = 3
  public static let maxParticipants = 5
  public static let maxMessages = 10

  public static func issues(_ diagram: Diagram, metrics: TextMetrics = .default) -> [DiagramIssue] {
    switch diagram {
    case .classDiagram(let d): issues(d, metrics: metrics)
    case .sequence(let d): issues(d, metrics: metrics)
    }
  }

  static func issues(_ d: ClassDiagram, metrics: TextMetrics) -> [DiagramIssue] {
    var out: [DiagramIssue] = []
    var seen = Set<String>()
    for n in d.nodes where !seen.insert(n.id).inserted {
      out.append(.init(.error, "duplicate node id '\(n.id)'"))
    }
    for e in d.edges {
      if !seen.contains(e.from) { out.append(.init(.error, "edge from unknown node '\(e.from)'")) }
      if !seen.contains(e.to) { out.append(.init(.error, "edge to unknown node '\(e.to)'")) }
    }
    for n in d.notes where !seen.contains(n.attachTo) {
      out.append(.init(.error, "note attached to unknown node '\(n.attachTo)'"))
    }
    var cells: [String: String] = [:]
    for n in d.nodes {
      let key = "\(n.col),\(n.row)"
      if let other = cells[key] {
        out.append(.init(.error, "nodes '\(other)' and '\(n.id)' share cell (col \(n.col), row \(n.row))"))
      } else { cells[key] = n.id }
    }
    if d.nodes.count > maxNodes {
      out.append(.init(.error, "\(d.nodes.count) nodes exceeds the limit of \(maxNodes)"))
    }
    if d.edges.count > maxEdges {
      out.append(.init(.error, "\(d.edges.count) edges exceeds the limit of \(maxEdges)"))
    }
    if let lo = d.nodes.map(\.col).min(), let hi = d.nodes.map(\.col).max() {
      let columns = Int((hi - lo).rounded(.up)) + 1
      if columns >= warnColumns {
        out.append(.init(.warning, "\(columns) columns is hard to read on a phone; prefer 2 or fewer"))
      }
    }
    let scene = ClassDiagramLayout.layout(d, metrics: metrics)
    out += overlaps(scene.boxes.filter { $0.style != .fragment })
    return out
  }

  static func issues(_ d: SequenceDiagram, metrics: TextMetrics) -> [DiagramIssue] {
    var out: [DiagramIssue] = []
    var seen = Set<String>()
    for p in d.participants where !seen.insert(p.id).inserted {
      out.append(.init(.error, "duplicate participant id '\(p.id)'"))
    }
    for (i, m) in d.messages.enumerated() {
      if !seen.contains(m.from) { out.append(.init(.error, "message \(i + 1) from unknown participant '\(m.from)'")) }
      if !seen.contains(m.to) { out.append(.init(.error, "message \(i + 1) to unknown participant '\(m.to)'")) }
    }
    for f in d.fragments where f.from < 0 || f.to >= d.messages.count || f.from > f.to {
      out.append(.init(.error, "fragment '\(f.kind.rawValue)' has invalid message range \(f.from)...\(f.to)"))
    }
    if d.participants.count > maxParticipants {
      out.append(.init(.error, "\(d.participants.count) participants exceeds the limit of \(maxParticipants)"))
    }
    if d.messages.count > maxMessages {
      out.append(.init(.error, "\(d.messages.count) messages exceeds the limit of \(maxMessages)"))
    }
    let scene = SequenceDiagramLayout.layout(d, metrics: metrics)
    out += overlaps(scene.boxes.filter { $0.style == .participant })
    return out
  }

  private static func overlaps(_ boxes: [DiagramScene.Box]) -> [DiagramIssue] {
    var out: [DiagramIssue] = []
    for i in boxes.indices {
      for j in boxes.indices where j > i && boxes[i].rect.overlapsInterior(boxes[j].rect) {
        let a = boxes[i].id ?? "note", b = boxes[j].id ?? "note"
        out.append(.init(.error, "laid-out boxes '\(a)' and '\(b)' overlap"))
      }
    }
    return out
  }
}
