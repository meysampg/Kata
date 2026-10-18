import CoreGraphics
import Foundation

public enum ClassDiagramLayout {
  static let margin: CGFloat = 16
  static let padding: CGFloat = 8
  static let vPadding: CGFloat = 6
  static let hGap: CGFloat = 48
  static let vGap: CGFloat = 56
  static let minNodeWidth: CGFloat = 96
  static let noteGap: CGFloat = 14
  static let noteWrap = 24

  public static func layout(_ d: ClassDiagram, metrics: TextMetrics = .default) -> DiagramScene {
    let lh = metrics.lineHeight
    typealias Scene = DiagramScene

    struct Content {
      var header: [(String, Scene.TextStyle)]
      var members: [String]
      var size: CGSize
    }

    func content(_ n: ClassDiagram.Node) -> Content {
      var header: [(String, Scene.TextStyle)] = []
      switch n.kind {
      case .class: break
      case .interface: header.append(("«interface»", .stereotype))
      case .abstract: header.append(("«abstract»", .stereotype))
      case .record: header.append(("«record»", .stereotype))
      case .enum: header.append(("«enum»", .stereotype))
      }
      header.append((n.name, n.kind == .abstract || n.kind == .interface ? .abstractName : .name))
      if let role = n.role, !role.isEmpty { header.append(("(\(role))", .role)) }
      var widest = header.map { metrics.width(of: $0.0) }.max() ?? 0
      widest = max(widest, n.members.map { metrics.width(of: $0) }.max() ?? 0)
      let w = max(minNodeWidth, widest + 2 * padding)
      var h = CGFloat(header.count) * lh + 2 * vPadding
      if !n.members.isEmpty { h += CGFloat(n.members.count) * lh + 2 * vPadding }
      return Content(header: header, members: n.members, size: CGSize(width: w, height: h))
    }

    let contents = d.nodes.map(content)
    guard !d.nodes.isEmpty else { return Scene(size: CGSize(width: margin * 2, height: margin * 2)) }
    let maxW = contents.map(\.size.width).max() ?? 0
    let maxH = contents.map(\.size.height).max() ?? 0
    let xPitch = maxW + hGap
    let yPitch = maxH + vGap
    let minCol = d.nodes.map(\.col).min() ?? 0
    let minRow = d.nodes.map(\.row).min() ?? 0

    var boxes: [Scene.Box] = []
    var rectByID: [String: CGRect] = [:]

    for (n, c) in zip(d.nodes, contents) {
      let cx = margin + (n.col - minCol) * xPitch + maxW / 2
      let cy = margin + (n.row - minRow) * yPitch + maxH / 2
      let rect = CGRect(
        x: cx - c.size.width / 2, y: cy - c.size.height / 2,
        width: c.size.width, height: c.size.height)
      var compartments: [Scene.Compartment] = []
      let headerH = CGFloat(c.header.count) * lh + 2 * vPadding
      let headerRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: headerH)
      let headerLines = c.header.enumerated().map { i, h in
        Scene.TextLine(
          text: h.0, style: h.1,
          rect: CGRect(
            x: rect.minX + padding, y: rect.minY + vPadding + CGFloat(i) * lh,
            width: rect.width - 2 * padding, height: lh),
          alignment: .center)
      }
      compartments.append(.init(rect: headerRect, lines: headerLines))
      if !c.members.isEmpty {
        let mh = CGFloat(c.members.count) * lh + 2 * vPadding
        let mRect = CGRect(x: rect.minX, y: rect.minY + headerH, width: rect.width, height: mh)
        let lines = c.members.enumerated().map { i, m in
          Scene.TextLine(
            text: m, style: .member,
            rect: CGRect(
              x: rect.minX + padding, y: mRect.minY + vPadding + CGFloat(i) * lh,
              width: rect.width - 2 * padding, height: lh),
            alignment: .leading)
        }
        compartments.append(.init(rect: mRect, lines: lines))
      }
      let style: Scene.BoxStyle =
        switch n.kind {
        case .class: .classNode
        case .interface: .interfaceNode
        case .abstract: .abstractNode
        case .record: .recordNode
        case .enum: .enumNode
        }
      boxes.append(.init(id: n.id, rect: rect, style: style, compartments: compartments))
      if rectByID[n.id] == nil { rectByID[n.id] = rect }
    }

    // Edges
    var lines: [Scene.Line] = []
    var texts: [Scene.Text] = []
    for e in d.edges {
      guard let a = rectByID[e.from], let b = rectByID[e.to] else { continue }
      let pts: [CGPoint]
      if e.from == e.to {
        let r = a
        let y0 = r.minY + r.height * 0.3, y1 = r.minY + r.height * 0.7
        pts = [
          CGPoint(x: r.maxX, y: y0), CGPoint(x: r.maxX + 24, y: y0),
          CGPoint(x: r.maxX + 24, y: y1), CGPoint(x: r.maxX, y: y1),
        ]
      } else {
        pts = [clip(from: a, toward: center(b)), clip(from: b, toward: center(a))]
      }
      let (dashed, start, end) = style(of: e.rel)
      lines.append(.init(points: pts, dashed: dashed, startMarker: start, endMarker: end))
      if let label = e.label, !label.isEmpty {
        let mid = pts.count == 2
          ? CGPoint(x: (pts[0].x + pts[1].x) / 2, y: (pts[0].y + pts[1].y) / 2)
          : CGPoint(x: pts[1].x, y: (pts[1].y + pts[2].y) / 2)
        texts.append(.init(text: label, origin: CGPoint(x: mid.x + 6, y: mid.y), alignment: .leading, style: .label))
      }
    }

    // Notes
    var occupied = boxes.map(\.rect)
    for note in d.notes {
      guard let target = rectByID[note.attachTo] else { continue }
      let wrapped = wrap(note.text, width: noteWrap)
      let textW = (wrapped.map { metrics.width(of: $0) }.max() ?? 0)
      let w = textW + 2 * padding
      let h = CGFloat(wrapped.count) * lh + 2 * vPadding
      let right = CGRect(x: target.maxX + noteGap, y: target.minY, width: w, height: h)
      let left = CGRect(x: target.minX - noteGap - w, y: target.minY, width: w, height: h)
      let rect = occupied.contains { $0.overlapsInterior(right) }
        && !occupied.contains { $0.overlapsInterior(left) } ? left : right
      occupied.append(rect)
      let ls = wrapped.enumerated().map { i, t in
        Scene.TextLine(
          text: t, style: .note,
          rect: CGRect(
            x: rect.minX + padding, y: rect.minY + vPadding + CGFloat(i) * lh,
            width: textW, height: lh),
          alignment: .leading)
      }
      boxes.append(.init(id: nil, rect: rect, style: .note, compartments: [.init(rect: rect, lines: ls)]))
      // Connector from the note to the node.
      let nearX = rect.minX > target.maxX ? rect.minX : rect.maxX
      let farX = rect.minX > target.maxX ? target.maxX : target.minX
      let y = rect.minY + min(h, lh + 2 * vPadding) / 2
      lines.append(.init(
        points: [CGPoint(x: nearX, y: y), CGPoint(x: farX, y: y)], dashed: true,
        startMarker: .none, endMarker: .none))
    }

    return Scene(size: .zero, boxes: boxes, lines: lines, texts: texts)
      .normalized(margin: margin, metrics: metrics)
  }

  static func style(of rel: ClassDiagram.Relation) -> (dashed: Bool, start: DiagramScene.Marker, end: DiagramScene.Marker) {
    switch rel {
    case .realizes: (true, .none, .hollowTriangle)
    case .extends: (false, .none, .hollowTriangle)
    case .association: (false, .none, .openArrow)
    case .aggregation: (false, .hollowDiamond, .none)
    case .composition: (false, .filledDiamond, .none)
    case .dependency: (true, .none, .openArrow)
    }
  }

  static func center(_ r: CGRect) -> CGPoint { CGPoint(x: r.midX, y: r.midY) }

  /// Point where the ray from the rect's centre toward `target` leaves the rect.
  static func clip(from r: CGRect, toward target: CGPoint) -> CGPoint {
    let c = center(r)
    let dx = target.x - c.x, dy = target.y - c.y
    if dx == 0 && dy == 0 { return c }
    let sx = dx == 0 ? CGFloat.infinity : (r.width / 2) / abs(dx)
    let sy = dy == 0 ? CGFloat.infinity : (r.height / 2) / abs(dy)
    let s = min(sx, sy)
    return CGPoint(x: c.x + dx * s, y: c.y + dy * s)
  }

  static func wrap(_ text: String, width: Int) -> [String] {
    var lines: [String] = []
    var current = ""
    for word in text.split(separator: " ") {
      if current.isEmpty { current = String(word) }
      else if current.count + 1 + word.count <= width { current += " " + word }
      else { lines.append(current); current = String(word) }
    }
    if !current.isEmpty { lines.append(current) }
    return lines.isEmpty ? [""] : lines
  }
}
