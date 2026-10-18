import CoreGraphics
import Foundation

public enum SequenceDiagramLayout {
  static let margin: CGFloat = 16
  static let padding: CGFloat = 8
  static let hGap: CGFloat = 40
  static let minWidth: CGFloat = 90
  static let step: CGFloat = 38
  static let selfStep: CGFloat = 50
  static let selfWidth: CGFloat = 32
  static let selfHeight: CGFloat = 18
  static let fragmentTop: CGFloat = 24
  static let fragmentBottom: CGFloat = 16

  public static func layout(_ d: SequenceDiagram, metrics: TextMetrics = .default) -> DiagramScene {
    typealias Scene = DiagramScene
    let lh = metrics.lineHeight
    guard !d.participants.isEmpty else {
      return Scene(size: CGSize(width: margin * 2, height: margin * 2))
    }

    let hasRole = d.participants.contains { ($0.role ?? "").isEmpty == false }
    let headerH = CGFloat(hasRole ? 2 : 1) * lh + 12
    let widths = d.participants.map { p -> CGFloat in
      let r = (p.role ?? "").isEmpty ? 0 : metrics.width(of: "(\(p.role!))")
      return max(minWidth, max(metrics.width(of: p.name), r) + 2 * padding)
    }
    let maxW = widths.max() ?? minWidth
    let pitch = maxW + hGap

    var centerX: [String: CGFloat] = [:]
    var indexByID: [String: Int] = [:]
    var boxes: [Scene.Box] = []
    for (i, p) in d.participants.enumerated() {
      let cx = margin + maxW / 2 + CGFloat(i) * pitch
      if centerX[p.id] == nil { centerX[p.id] = cx; indexByID[p.id] = i }
      let w = widths[i]
      let rect = CGRect(x: cx - w / 2, y: margin, width: w, height: headerH)
      var ls = [Scene.TextLine(
        text: p.name, style: .name,
        rect: CGRect(x: rect.minX + padding, y: rect.minY + 6, width: w - 2 * padding, height: lh),
        alignment: .center)]
      if let role = p.role, !role.isEmpty {
        ls.append(.init(
          text: "(\(role))", style: .role,
          rect: CGRect(x: rect.minX + padding, y: rect.minY + 6 + lh, width: w - 2 * padding, height: lh),
          alignment: .center))
      }
      boxes.append(.init(id: p.id, rect: rect, style: .participant, compartments: [.init(rect: rect, lines: ls)]))
    }

    // Message y positions: strictly increasing.
    var y = margin + headerH + 34
    var ys: [CGFloat] = []
    var fragmentTopY: [Int: CGFloat] = [:]   // by fragment index
    var fragmentBottomY: [Int: CGFloat] = [:]
    for (i, m) in d.messages.enumerated() {
      let starting = d.fragments.indices.filter { d.fragments[$0].from == i }
      y += CGFloat(starting.count) * fragmentTop
      for f in starting { fragmentTopY[f] = y - fragmentTop + 4 }
      ys.append(y)
      let isSelf = m.from == m.to
      let ending = d.fragments.indices.filter { d.fragments[$0].to == i }
      let bottomOfMessage = y + (isSelf ? selfHeight : 0)
      for f in ending { fragmentBottomY[f] = bottomOfMessage + fragmentBottom - 4 }
      y += (isSelf ? selfStep : step) + CGFloat(ending.count) * fragmentBottom
    }
    let lifelineEnd = (ys.last ?? (margin + headerH)) + 40
      + CGFloat(d.fragments.count) * 0

    var lines: [Scene.Line] = []
    var texts: [Scene.Text] = []
    // Lifelines
    for p in d.participants {
      guard let cx = centerX[p.id], indexByID[p.id] != nil else { continue }
      lines.append(.init(
        points: [CGPoint(x: cx, y: margin + headerH), CGPoint(x: cx, y: lifelineEnd)],
        dashed: true, startMarker: .none, endMarker: .none))
    }

    // Fragments (drawn before messages so they sit behind)
    for (fi, f) in d.fragments.enumerated() {
      guard let top = fragmentTopY[fi], let bottom = fragmentBottomY[fi], f.from <= f.to,
        f.from >= 0, f.to < d.messages.count
      else { continue }
      var minX = CGFloat.infinity, maxX = -CGFloat.infinity
      for m in d.messages[f.from...f.to] {
        for id in [m.from, m.to] {
          if let cx = centerX[id] { minX = min(minX, cx); maxX = max(maxX, cx) }
        }
        if m.from == m.to, let cx = centerX[m.from] { maxX = max(maxX, cx + selfWidth) }
      }
      guard minX.isFinite else { continue }
      let rect = CGRect(x: minX - 28, y: top, width: maxX - minX + 56, height: bottom - top)
      boxes.append(.init(id: nil, rect: rect, style: .fragment, compartments: []))
      let header = f.guardText.isEmpty ? f.kind.rawValue : "\(f.kind.rawValue) [\(f.guardText)]"
      texts.append(.init(
        text: header, origin: CGPoint(x: rect.minX + 6, y: rect.minY + 10),
        alignment: .leading, style: .fragmentHeader))
    }

    // Messages
    for (i, m) in d.messages.enumerated() {
      guard let x0 = centerX[m.from], let x1 = centerX[m.to] else { continue }
      let yy = ys[i]
      let dashed = m.style == .return || m.style == .create
      let end: Scene.Marker = m.style == .call ? .filledArrow : .openArrow
      let label = m.style == .create ? "«create» \(m.label)" : m.label
      if m.from == m.to {
        lines.append(.init(
          points: [
            CGPoint(x: x0, y: yy), CGPoint(x: x0 + selfWidth, y: yy),
            CGPoint(x: x0 + selfWidth, y: yy + selfHeight), CGPoint(x: x0, y: yy + selfHeight),
          ], dashed: dashed, startMarker: .none, endMarker: end))
        texts.append(.init(
          text: label, origin: CGPoint(x: x0 + selfWidth + 6, y: yy + selfHeight / 2),
          alignment: .leading, style: .label))
      } else {
        lines.append(.init(
          points: [CGPoint(x: x0, y: yy), CGPoint(x: x1, y: yy)],
          dashed: dashed, startMarker: .none, endMarker: end))
        texts.append(.init(
          text: label, origin: CGPoint(x: (x0 + x1) / 2, y: yy - lh / 2 - 2),
          alignment: .center, style: .label))
      }
    }

    return Scene(size: .zero, boxes: boxes, lines: lines, texts: texts)
      .normalized(margin: margin, metrics: metrics)
  }
}
