import CoreGraphics
import Foundation
import Testing

@testable import KataDiagram

enum Fixtures {
  static let classJSON = """
    {"kind": "class", "title": "Class", "nodes": [
      {"id": "checkout", "name": "Checkout", "kind": "class", "role": "Context", "col": 0.5, "row": 0,
       "members": ["- policy: DiscountPolicy", "+ total(prices): BigDecimal"]},
      {"id": "policy", "name": "DiscountPolicy", "kind": "interface", "role": "Strategy", "col": 0.5, "row": 1,
       "members": ["+ apply(subtotal): BigDecimal"]},
      {"id": "pct", "name": "PercentOff", "kind": "record", "role": "ConcreteStrategy", "col": 0, "row": 2,
       "members": ["+ apply(subtotal)"]},
      {"id": "flat", "name": "FlatOff", "kind": "record", "role": "ConcreteStrategy", "col": 1, "row": 2,
       "members": ["+ apply(subtotal)"]}],
     "edges": [
      {"from": "checkout", "to": "policy", "rel": "aggregation", "label": "policy"},
      {"from": "pct", "to": "policy", "rel": "realizes"},
      {"from": "flat", "to": "policy", "rel": "realizes"}],
     "notes": [{"attachTo": "policy", "text": "a lambda also implements it"}]}
    """

  static let sequenceJSON = """
    {"kind": "sequence", "title": "Sequence", "participants": [
      {"id": "client", "name": "Client"}, {"id": "checkout", "name": "Checkout", "role": "Context"},
      {"id": "policy", "name": "PercentOff", "role": "Strategy"}],
     "messages": [
      {"from": "client", "to": "checkout", "label": "new Checkout(policy)", "style": "create"},
      {"from": "client", "to": "checkout", "label": "total(prices)", "style": "call"},
      {"from": "checkout", "to": "policy", "label": "apply(subtotal)", "style": "call"},
      {"from": "policy", "to": "checkout", "label": "discounted", "style": "return"},
      {"from": "checkout", "to": "client", "label": "total", "style": "return"}]}
    """

  static func decode(_ json: String) throws -> Diagram {
    try JSONDecoder().decode(Diagram.self, from: Data(json.utf8))
  }

  static func classDiagram() throws -> ClassDiagram {
    guard case .classDiagram(let d) = try decode(classJSON) else { fatalError() }
    return d
  }

  static func sequence() throws -> SequenceDiagram {
    guard case .sequence(let d) = try decode(sequenceJSON) else { fatalError() }
    return d
  }
}

@Suite struct DiagramDecodingTests {
  @Test func decodesClass() throws {
    let d = try Fixtures.decode(Fixtures.classJSON)
    #expect(d.title == "Class")
    guard case .classDiagram(let c) = d else { Issue.record("not class"); return }
    #expect(c.nodes.count == 4)
    #expect(c.nodes[0].col == 0.5)
    #expect(c.nodes[1].kind == .interface)
    #expect(c.edges[0].rel == .aggregation && c.edges[0].label == "policy")
    #expect(c.notes.first?.attachTo == "policy")
  }

  @Test func decodesSequence() throws {
    let d = try Fixtures.decode(Fixtures.sequenceJSON)
    guard case .sequence(let s) = d else { Issue.record("not sequence"); return }
    #expect(s.participants.count == 3 && s.messages.count == 5 && s.fragments.isEmpty)
    #expect(s.messages[0].style == .create)
  }

  @Test func roundTrips() throws {
    for json in [Fixtures.classJSON, Fixtures.sequenceJSON] {
      let d = try Fixtures.decode(json)
      let again = try JSONDecoder().decode(Diagram.self, from: JSONEncoder().encode(d))
      #expect(d == again)
    }
  }

  @Test func decodesFragments() throws {
    let json = """
      {"kind":"sequence","title":"S","participants":[{"id":"a","name":"A"}],
       "messages":[{"from":"a","to":"a","label":"x","style":"async"}],
       "fragments":[{"kind":"loop","guard":"each item","from":0,"to":0}]}
      """
    guard case .sequence(let s) = try Fixtures.decode(json) else { return }
    #expect(s.fragments == [.init(kind: .loop, guardText: "each item", from: 0, to: 0)])
  }

  @Test func rejectsUnknownKeys() {
    let topLevel = Fixtures.classJSON.replacingOccurrences(of: "\"title\": \"Class\",", with: "\"title\": \"Class\", \"bogus\": 1,")
    #expect(throws: DecodingError.self) { try Fixtures.decode(topLevel) }
    let nested = Fixtures.classJSON.replacingOccurrences(of: "\"label\": \"policy\"", with: "\"label\": \"policy\", \"color\": \"red\"")
    #expect(throws: DecodingError.self) { try Fixtures.decode(nested) }
    let seq = Fixtures.sequenceJSON.replacingOccurrences(of: "\"style\": \"call\"", with: "\"style\": \"call\", \"x\": 1")
    #expect(throws: DecodingError.self) { try Fixtures.decode(seq) }
  }

  @Test func rejectsBadKindAndEnums() {
    #expect(throws: DecodingError.self) { try Fixtures.decode(#"{"kind":"state","title":"x"}"#) }
    let bad = Fixtures.classJSON.replacingOccurrences(of: "\"realizes\"", with: "\"inherits\"")
    #expect(throws: DecodingError.self) { try Fixtures.decode(bad) }
  }
}

@Suite struct ClassLayoutTests {
  @Test func noNodeOverlapAndDeterministic() throws {
    let d = try Fixtures.classDiagram()
    let a = ClassDiagramLayout.layout(d)
    let b = ClassDiagramLayout.layout(d)
    #expect(a == b)
    for i in a.boxes.indices {
      for j in a.boxes.indices where j > i {
        #expect(!a.boxes[i].rect.overlapsInterior(a.boxes[j].rect))
      }
    }
    for box in a.boxes {
      #expect(box.rect.minX >= 0 && box.rect.minY >= 0)
      #expect(box.rect.maxX <= a.size.width && box.rect.maxY <= a.size.height)
    }
  }

  @Test func fractionalColumnIsCentered() throws {
    let s = ClassDiagramLayout.layout(try Fixtures.classDiagram())
    func rect(_ id: String) -> CGRect { s.boxes.first { $0.id == id }!.rect }
    let mid = (rect("pct").midX + rect("flat").midX) / 2
    #expect(abs(rect("checkout").midX - mid) < 0.001)
    #expect(abs(rect("policy").midX - mid) < 0.001)
    #expect(rect("checkout").minY < rect("policy").minY && rect("policy").minY < rect("pct").minY)
  }

  @Test func edgeEndpointsOnBorders() throws {
    let d = try Fixtures.classDiagram()
    let s = ClassDiagramLayout.layout(d)
    func rect(_ id: String) -> CGRect { s.boxes.first { $0.id == id }!.rect }
    func onBorder(_ p: CGPoint, _ r: CGRect) -> Bool {
      let inX = p.x >= r.minX - 0.001 && p.x <= r.maxX + 0.001
      let inY = p.y >= r.minY - 0.001 && p.y <= r.maxY + 0.001
      let edge = abs(p.x - r.minX) < 0.001 || abs(p.x - r.maxX) < 0.001
        || abs(p.y - r.minY) < 0.001 || abs(p.y - r.maxY) < 0.001
      return inX && inY && edge
    }
    // First three lines are the edges, in order.
    for (i, e) in d.edges.enumerated() {
      let pts = s.lines[i].points
      #expect(onBorder(pts.first!, rect(e.from)))
      #expect(onBorder(pts.last!, rect(e.to)))
    }
  }

  @Test func edgeMarkers() throws {
    let s = ClassDiagramLayout.layout(try Fixtures.classDiagram())
    #expect(s.lines[0].startMarker == .hollowDiamond && !s.lines[0].dashed)
    #expect(s.lines[1].endMarker == .hollowTriangle && s.lines[1].dashed)
    let style = ClassDiagramLayout.style(of:)
    #expect(style(.extends) == (false, .none, .hollowTriangle))
    #expect(style(.composition).start == .filledDiamond)
    #expect(style(.dependency) == (true, .none, .openArrow))
    #expect(style(.association).end == .openArrow)
  }

  @Test func nodeSizeAndCompartments() throws {
    let s = ClassDiagramLayout.layout(try Fixtures.classDiagram())
    let policy = s.boxes.first { $0.id == "policy" }!
    #expect(policy.style == .interfaceNode)
    #expect(policy.compartments.count == 2)
    #expect(policy.compartments[0].lines.map(\.text) == ["«interface»", "DiscountPolicy", "(Strategy)"])
    let longest = "+ apply(subtotal): BigDecimal".count
    #expect(policy.rect.width >= CGFloat(longest) * 7.2)
    let wide = ClassDiagramLayout.layout(try Fixtures.classDiagram(), metrics: .init(charWidth: 10, lineHeight: 20))
    #expect(wide.size.width > s.size.width && wide.size.height > s.size.height)
  }

  @Test func noteBesideNode() throws {
    let s = ClassDiagramLayout.layout(try Fixtures.classDiagram())
    let policy = s.boxes.first { $0.id == "policy" }!
    let note = s.boxes.first { $0.style == .note }!
    #expect(note.rect.minX > policy.rect.maxX)
    #expect(note.rect.minY == policy.rect.minY)
    #expect(note.compartments[0].lines.map(\.text).joined(separator: " ") == "a lambda also implements it")
  }
}

@Suite struct SequenceLayoutTests {
  @Test func messageYIncreasesAndReturnsDashed() throws {
    let d = try Fixtures.sequence()
    let s = SequenceDiagramLayout.layout(d)
    let lifelines = s.lines.prefix(3)
    #expect(lifelines.allSatisfy { $0.dashed && $0.points.count == 2 && $0.points[0].x == $0.points[1].x })
    let msgs = Array(s.lines.dropFirst(3))
    #expect(msgs.count == 5)
    let ys = msgs.map { $0.points[0].y }
    #expect(zip(ys, ys.dropFirst()).allSatisfy { $0 < $1 })
    #expect(msgs[0].dashed && msgs[0].endMarker == .openArrow)  // create
    #expect(!msgs[1].dashed && msgs[1].endMarker == .filledArrow)  // call
    #expect(msgs[3].dashed && msgs[4].dashed)  // returns
    #expect(msgs[3].points[0].x > msgs[3].points[1].x)  // right to left
    #expect(s.texts.contains { $0.text == "«create» new Checkout(policy)" })
  }

  @Test func selfMessageIsLoop() {
    let d = SequenceDiagram(
      title: "S", participants: [.init(id: "a", name: "A"), .init(id: "b", name: "B")],
      messages: [
        .init(from: "a", to: "a", label: "retry", style: .call),
        .init(from: "a", to: "b", label: "go", style: .call),
      ])
    let s = SequenceDiagramLayout.layout(d)
    let msgs = Array(s.lines.dropFirst(2))
    #expect(msgs[0].points.count == 4)
    #expect(msgs[0].points[0].x == msgs[0].points[3].x && msgs[0].points[1].x > msgs[0].points[0].x)
    #expect(msgs[1].points[0].y > msgs[0].points[3].y)
  }

  @Test func fragmentSpansMessages() {
    let d = SequenceDiagram(
      title: "S", participants: [.init(id: "a", name: "A"), .init(id: "b", name: "B")],
      messages: [
        .init(from: "a", to: "b", label: "m0", style: .call),
        .init(from: "a", to: "b", label: "m1", style: .call),
        .init(from: "b", to: "a", label: "m2", style: .return),
      ],
      fragments: [.init(kind: .alt, guardText: "ok", from: 1, to: 2)])
    let s = SequenceDiagramLayout.layout(d)
    let frag = s.boxes.first { $0.style == .fragment }!
    let msgs = Array(s.lines.dropFirst(2))
    #expect(frag.rect.minY > msgs[0].points[0].y)
    #expect(frag.rect.minY < msgs[1].points[0].y)
    #expect(frag.rect.maxY > msgs[2].points[0].y)
    #expect(s.texts.contains { $0.text == "alt [ok]" })
    let ys = msgs.map { $0.points[0].y }
    #expect(zip(ys, ys.dropFirst()).allSatisfy { $0 < $1 })
  }

  @Test func participantsLaidOutLeftToRight() throws {
    let s = SequenceDiagramLayout.layout(try Fixtures.sequence())
    let ps = s.boxes.filter { $0.style == .participant }
    #expect(ps.count == 3)
    #expect(zip(ps, ps.dropFirst()).allSatisfy { $0.rect.maxX < $1.rect.minX })
    #expect(SequenceDiagramLayout.layout(try Fixtures.sequence()) == s)
  }
}

@Suite struct DescriberTests {
  @Test func classDescription() throws {
    let text = DiagramDescriber.describe(try Fixtures.decode(Fixtures.classJSON))
    #expect(text.contains("Checkout has a DiscountPolicy"))
    #expect(text.contains("PercentOff implements DiscountPolicy"))
    #expect(text.contains("FlatOff implements DiscountPolicy"))
    #expect(text.contains("a lambda also implements it"))
  }

  @Test func sequenceDescription() throws {
    let text = DiagramDescriber.describe(try Fixtures.decode(Fixtures.sequenceJSON))
    #expect(text.contains("Step 1: Client creates Checkout"))
    #expect(text.contains("Step 3: Checkout calls PercentOff: apply(subtotal)"))
    #expect(text.contains("Step 4: PercentOff returns to Checkout: discounted"))
  }
}

@Suite struct LinterTests {
  @Test func strategyFixturesAreClean() throws {
    #expect(DiagramLinter.issues(try Fixtures.decode(Fixtures.classJSON)) == [])
    #expect(DiagramLinter.issues(try Fixtures.decode(Fixtures.sequenceJSON)) == [])
  }

  @Test func classProblems() throws {
    var d = try Fixtures.classDiagram()
    d.nodes.append(.init(id: "pct", name: "Dup", col: 0, row: 2))
    d.edges.append(.init(from: "ghost", to: "pct", rel: .extends))
    d.notes.append(.init(attachTo: "nope", text: "x"))
    let msgs = DiagramLinter.issues(.classDiagram(d)).map(\.message)
    #expect(msgs.contains { $0.contains("duplicate node id 'pct'") })
    #expect(msgs.contains { $0.contains("unknown node 'ghost'") })
    #expect(msgs.contains { $0.contains("unknown node 'nope'") })
    #expect(msgs.contains { $0.contains("share cell") })
  }

  @Test func limitsAndColumnWarning() {
    let nodes = (0..<9).map { ClassDiagram.Node(id: "n\($0)", name: "N\($0)", col: Double($0 % 3), row: Double($0 / 3)) }
    let edges = (0..<11).map { _ in ClassDiagram.Edge(from: "n0", to: "n1", rel: .association) }
    let issues = DiagramLinter.issues(.classDiagram(.init(title: "t", nodes: nodes, edges: edges)))
    #expect(issues.contains { $0.severity == .error && $0.message.contains("9 nodes") })
    #expect(issues.contains { $0.severity == .error && $0.message.contains("11 edges") })
    #expect(issues.contains { $0.severity == .warning && $0.message.contains("3 columns") })
    let two = DiagramLinter.issues(.classDiagram(.init(title: "t", nodes: Array(nodes.prefix(2)).enumerated().map { var n = $1; n.col = Double($0); n.row = 0; return n })))
    #expect(two.isEmpty)
  }

  @Test func sequenceProblems() {
    let ps = (0..<6).map { SequenceDiagram.Participant(id: "p\($0)", name: "P\($0)") }
    let ms = (0..<11).map { _ in SequenceDiagram.Message(from: "p0", to: "p1", label: "m") }
    var d = SequenceDiagram(title: "t", participants: ps, messages: ms)
    d.messages.append(.init(from: "p0", to: "zzz", label: "bad"))
    d.fragments = [.init(kind: .opt, guardText: "g", from: 3, to: 99)]
    let msgs = DiagramLinter.issues(.sequence(d)).map(\.message)
    #expect(msgs.contains { $0.contains("6 participants") })
    #expect(msgs.contains { $0.contains("12 messages") })
    #expect(msgs.contains { $0.contains("unknown participant 'zzz'") })
    #expect(msgs.contains { $0.contains("invalid message range") })
  }

  @Test func detectsOverlappingNotes() {
    // A wide note attached to the left node collides with its right neighbour in both directions.
    let d = ClassDiagram(
      title: "t",
      nodes: [.init(id: "a", name: "A", col: 0, row: 0), .init(id: "b", name: "B", col: 0.25, row: 0)])
    #expect(DiagramLinter.issues(.classDiagram(d)).contains { $0.message.contains("overlap") })
  }
}
