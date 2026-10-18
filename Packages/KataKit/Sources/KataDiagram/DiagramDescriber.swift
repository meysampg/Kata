import Foundation

/// Plain-text descriptions of diagrams for VoiceOver.
public enum DiagramDescriber {
  public static func describe(_ diagram: Diagram) -> String {
    switch diagram {
    case .classDiagram(let d): describe(d)
    case .sequence(let d): describe(d)
    }
  }

  static func describe(_ d: ClassDiagram) -> String {
    let names = Dictionary(d.nodes.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
    var parts: [String] = []
    let list = d.nodes.map { n in
      n.role.map { "\(n.name) (\($0))" } ?? n.name
    }
    var intro = "Class diagram \(d.title), \(d.nodes.count) \(d.nodes.count == 1 ? "type" : "types")"
    if !list.isEmpty { intro += ": " + list.joined(separator: ", ") }
    parts.append(intro + ".")

    let sentences = d.edges.map { e -> String in
      let a = names[e.from] ?? e.from, b = names[e.to] ?? e.to
      let base: String =
        switch e.rel {
        case .realizes: "\(a) implements \(b)"
        case .extends: "\(a) extends \(b)"
        case .association: "\(a) is associated with \(b)"
        case .aggregation: "\(a) has a \(b)"
        case .composition: "\(a) is composed of a \(b)"
        case .dependency: "\(a) depends on \(b)"
        }
      if let l = e.label, !l.isEmpty { return "\(base) (\(l))" }
      return base
    }
    if !sentences.isEmpty { parts.append(sentences.joined(separator: "; ") + ".") }
    for n in d.notes {
      parts.append("Note on \(names[n.attachTo] ?? n.attachTo): \(n.text).")
    }
    return parts.joined(separator: " ")
  }

  static func describe(_ d: SequenceDiagram) -> String {
    let names = Dictionary(d.participants.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
    let list = d.participants.map { p in p.role.map { "\(p.name) (\($0))" } ?? p.name }
    var parts = ["Sequence diagram \(d.title) with participants " + list.joined(separator: ", ") + "."]
    for (i, m) in d.messages.enumerated() {
      let a = names[m.from] ?? m.from, b = names[m.to] ?? m.to
      let s: String =
        switch m.style {
        case .call: m.from == m.to ? "\(a) calls itself: \(m.label)" : "\(a) calls \(b): \(m.label)"
        case .async: "\(a) sends \(b) an asynchronous message: \(m.label)"
        case .return: "\(a) returns to \(b): \(m.label)"
        case .create: "\(a) creates \(b): \(m.label)"
        }
      parts.append("Step \(i + 1): \(s).")
    }
    for f in d.fragments {
      let range = f.from == f.to ? "step \(f.from + 1)" : "steps \(f.from + 1) to \(f.to + 1)"
      let kind: String =
        switch f.kind {
        case .alt: "Alternative"
        case .loop: "Loop"
        case .opt: "Optional"
        }
      parts.append("\(kind) [\(f.guardText)] covers \(range).")
    }
    return parts.joined(separator: " ")
  }
}
