#if os(iOS)
import KataDiagram
import SwiftUI
import UIKit

typealias DScene = DiagramScene

enum DiagramLayouts {
  @MainActor
  static func scene(for diagram: Diagram, fontSize: CGFloat = 12) -> DiagramScene {
    let m = MonoMetrics.metrics(size: fontSize)
    switch diagram {
    case .classDiagram(let d): return ClassDiagramLayout.layout(d, metrics: m)
    case .sequence(let d): return SequenceDiagramLayout.layout(d, metrics: m)
    }
  }
}

/// Draws a `DiagramScene` with `Canvas`, scaled to the width it is given.
struct DiagramCanvas: View {
  let scene: DiagramScene
  var fontSize: CGFloat = 12
  var selectedID: String?
  var onTapBox: ((String?) -> Void)?

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Canvas { ctx, size in
      let s = scene.size.width > 0 ? size.width / scene.size.width : 1
      ctx.scaleBy(x: s, y: s)
      draw(&ctx)
    }
    .aspectRatio(max(scene.size.width, 1) / max(scene.size.height, 1), contentMode: .fit)
    .contentShape(.rect)
    .gesture(
      SpatialTapGesture().onEnded { value in
        guard let onTapBox else { return }
        onTapBox(hit(value.location))
      }
    )
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewWidth = $0 }
  }

  @State private var viewWidth: CGFloat = 1

  private func hit(_ p: CGPoint) -> String? {
    let s = scene.size.width > 0 ? viewWidth / scene.size.width : 1
    let q = CGPoint(x: p.x / s, y: p.y / s)
    return scene.boxes.last { $0.id != nil && $0.rect.insetBy(dx: -4, dy: -4).contains(q) }?.id
  }

  // MARK: Drawing

  private var ink: Color { .primary }
  private var bg: Color { Color(uiColor: .systemBackground) }
  private var boxFill: Color { Color(uiColor: .secondarySystemBackground) }

  private func connected(_ line: DScene.Line, to rect: CGRect) -> Bool {
    let r = rect.insetBy(dx: -2, dy: -2)
    return [line.points.first, line.points.last].contains { $0.map(r.contains) ?? false }
  }

  private func font(_ style: DScene.TextStyle) -> Font {
    let base = Font.system(size: fontSize, design: .monospaced)
    switch style {
    case .name, .title, .fragmentHeader: return base.weight(.semibold)
    case .abstractName: return base.weight(.semibold).italic()
    case .stereotype, .role, .note, .label: return Font.system(size: fontSize * 0.9, design: .monospaced)
    case .member: return base
    }
  }

  private func textColor(_ style: DScene.TextStyle) -> Color {
    switch style {
    case .stereotype, .role, .label, .note, .fragmentHeader: .secondary
    default: .primary
    }
  }

  private func drawText(_ ctx: inout GraphicsContext, _ text: String, style: DScene.TextStyle,
                        at p: CGPoint, alignment: DScene.Alignment, opacity: Double = 1) {
    var t = Text(text).font(font(style)).foregroundColor(textColor(style))
    if style == .role { t = t.italic() }
    var c = ctx
    c.opacity = opacity
    let anchor: UnitPoint =
      switch alignment {
      case .leading: .leading
      case .center: .center
      case .trailing: .trailing
      }
    c.draw(c.resolve(t), at: p, anchor: anchor)
  }

  private func draw(_ ctx: inout GraphicsContext) {
    let selectedRect = scene.boxes.first { $0.id != nil && $0.id == selectedID }?.rect
    let dim = selectedRect != nil

    // Lines first (under boxes).
    for line in scene.lines {
      let on = selectedRect.map { connected(line, to: $0) } ?? true
      drawLine(&ctx, line, color: on && dim ? .accentColor : ink, width: on && dim ? 2 : 1.2,
               opacity: on ? 1 : 0.3)
    }

    for box in scene.boxes {
      let selected = box.id != nil && box.id == selectedID
      let faded = dim && !selected
      var c = ctx
      c.opacity = faded ? 0.5 : 1
      drawBox(&c, box, selected: selected)
    }

    for t in scene.texts {
      drawText(&ctx, t.text, style: t.style, at: t.origin, alignment: t.alignment, opacity: dim ? 0.6 : 1)
    }
  }

  private func drawBox(_ ctx: inout GraphicsContext, _ box: DScene.Box, selected: Bool) {
    let stroke: Color = selected ? .accentColor : ink.opacity(0.75)
    let lw: CGFloat = selected ? 2.2 : 1.2
    switch box.style {
    case .note:
      var p = Path()
      let r = box.rect, f: CGFloat = 8
      p.move(to: CGPoint(x: r.minX, y: r.minY))
      p.addLine(to: CGPoint(x: r.maxX - f, y: r.minY))
      p.addLine(to: CGPoint(x: r.maxX, y: r.minY + f))
      p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
      p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
      p.closeSubpath()
      ctx.fill(p, with: .color(.yellow.opacity(0.18)))
      ctx.stroke(p, with: .color(ink.opacity(0.5)), lineWidth: 1)
    case .fragment:
      let p = Path(roundedRect: box.rect, cornerRadius: 3)
      ctx.stroke(p, with: .color(ink.opacity(0.4)),
                 style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
    case .participant:
      let p = Path(roundedRect: box.rect, cornerRadius: 6)
      ctx.fill(p, with: .color(boxFill))
      ctx.stroke(p, with: .color(stroke), lineWidth: lw)
    default:
      let p = Path(roundedRect: box.rect, cornerRadius: 6)
      ctx.fill(p, with: .color(boxFill))
      let dash: [CGFloat] = box.style == .interfaceNode ? [5, 3] : []
      ctx.stroke(p, with: .color(stroke), style: StrokeStyle(lineWidth: lw, dash: dash))
    }
    for (i, comp) in box.compartments.enumerated() {
      if i > 0, box.style != .note {
        var sep = Path()
        sep.move(to: CGPoint(x: comp.rect.minX, y: comp.rect.minY))
        sep.addLine(to: CGPoint(x: comp.rect.maxX, y: comp.rect.minY))
        ctx.stroke(sep, with: .color(stroke.opacity(0.6)), lineWidth: 1)
      }
      for l in comp.lines {
        let x: CGFloat =
          switch l.alignment {
          case .leading: l.rect.minX
          case .center: l.rect.midX
          case .trailing: l.rect.maxX
          }
        drawText(&ctx, l.text, style: l.style, at: CGPoint(x: x, y: l.rect.midY), alignment: l.alignment)
      }
    }
  }

  private func drawLine(_ ctx: inout GraphicsContext, _ line: DScene.Line, color: Color,
                        width: CGFloat, opacity: Double) {
    guard line.points.count >= 2 else { return }
    var c = ctx
    c.opacity = opacity
    var pts = line.points
    // Trim the stroke where hollow/filled shapes are drawn so the line doesn't poke through.
    let startTrim = Self.trim(for: line.startMarker), endTrim = Self.trim(for: line.endMarker)
    pts[0] = Self.move(pts[0], toward: pts[1], by: startTrim)
    pts[pts.count - 1] = Self.move(pts[pts.count - 1], toward: pts[pts.count - 2], by: endTrim)
    var path = Path()
    path.addLines(pts)
    c.stroke(path, with: .color(color),
             style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round,
                                dash: line.dashed ? [5, 4] : []))
    drawMarker(&c, line.startMarker, tip: line.points[0], from: line.points[1], color: color, width: width)
    drawMarker(&c, line.endMarker, tip: line.points[line.points.count - 1],
               from: line.points[line.points.count - 2], color: color, width: width)
  }

  private static func trim(for m: DScene.Marker) -> CGFloat {
    switch m {
    case .none, .openArrow: 0
    case .filledArrow: 9
    case .hollowTriangle: 11
    case .hollowDiamond, .filledDiamond: 16
    }
  }

  private static func move(_ p: CGPoint, toward q: CGPoint, by d: CGFloat) -> CGPoint {
    let dx = q.x - p.x, dy = q.y - p.y
    let len = max((dx * dx + dy * dy).squareRoot(), 0.001)
    return CGPoint(x: p.x + dx / len * d, y: p.y + dy / len * d)
  }

  private func drawMarker(_ ctx: inout GraphicsContext, _ m: DScene.Marker, tip: CGPoint,
                          from other: CGPoint, color: Color, width: CGFloat) {
    guard m != .none else { return }
    let dx = other.x - tip.x, dy = other.y - tip.y
    let len = max((dx * dx + dy * dy).squareRoot(), 0.001)
    let u = CGPoint(x: dx / len, y: dy / len)          // from tip back along the line
    let n = CGPoint(x: -u.y, y: u.x)                   // normal
    func pt(_ back: CGFloat, _ side: CGFloat) -> CGPoint {
      CGPoint(x: tip.x + u.x * back + n.x * side, y: tip.y + u.y * back + n.y * side)
    }
    switch m {
    case .none: break
    case .openArrow:
      var p = Path()
      p.move(to: pt(9, 5)); p.addLine(to: tip); p.addLine(to: pt(9, -5))
      ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    case .filledArrow:
      var p = Path()
      p.move(to: tip); p.addLine(to: pt(9, 4.5)); p.addLine(to: pt(9, -4.5)); p.closeSubpath()
      ctx.fill(p, with: .color(color))
    case .hollowTriangle:
      var p = Path()
      p.move(to: tip); p.addLine(to: pt(11, 6)); p.addLine(to: pt(11, -6)); p.closeSubpath()
      ctx.fill(p, with: .color(bg))
      ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineJoin: .round))
    case .hollowDiamond, .filledDiamond:
      var p = Path()
      p.move(to: tip); p.addLine(to: pt(8, 5)); p.addLine(to: pt(16, 0)); p.addLine(to: pt(8, -5))
      p.closeSubpath()
      ctx.fill(p, with: .color(m == .filledDiamond ? color : bg))
      ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineJoin: .round))
    }
  }
}

/// Fit-to-width diagram. Tap a type to highlight the relationships touching it.
public struct DiagramView: View {
  let diagram: Diagram
  let scene: DiagramScene
  let onSelect: ((String?) -> Void)?
  @State private var selected: String?

  /// - Parameter onSelect: called with the tapped node id (nil when deselected).
  @MainActor
  public init(diagram: Diagram, onSelect: ((String?) -> Void)? = nil) {
    self.diagram = diagram
    self.scene = DiagramLayouts.scene(for: diagram)
    self.onSelect = onSelect
  }

  public var body: some View {
    DiagramCanvas(scene: scene, selectedID: selected) { id in
      let next = (id == selected) ? nil : id
      withAnimation(.smooth(duration: 0.2)) { selected = next }
      onSelect?(next)
    }
    .frame(maxWidth: scene.size.width * 1.5)
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(DiagramDescriber.describe(diagram))
    .accessibilityAddTraits(.isImage)
  }
}

/// Pinch-to-zoom diagram in a two-axis scroll view, for an "Expand" sheet.
public struct ZoomableDiagramView: View {
  let diagram: Diagram
  let scene: DiagramScene
  @State private var zoom: CGFloat = 1
  @State private var baseZoom: CGFloat = 1
  @State private var selected: String?

  @MainActor
  public init(diagram: Diagram) {
    self.diagram = diagram
    self.scene = DiagramLayouts.scene(for: diagram)
  }

  public var body: some View {
    ScrollView([.horizontal, .vertical]) {
      DiagramCanvas(scene: scene, selectedID: selected) { id in
        selected = (id == selected) ? nil : id
      }
      .frame(width: scene.size.width * zoom, height: scene.size.height * zoom)
      .padding(12)
    }
    .gesture(
      MagnifyGesture()
        .onChanged { zoom = min(max(baseZoom * $0.magnification, 0.5), 4) }
        .onEnded { _ in baseZoom = zoom }
    )
    .onTapGesture(count: 2) { withAnimation(.smooth) { zoom = 1; baseZoom = 1 } }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(DiagramDescriber.describe(diagram))
    .accessibilityAddTraits(.isImage)
  }
}

#Preview("Class diagram") {
  let d = ClassDiagram(
    title: "Strategy",
    nodes: [
      .init(id: "ctx", name: "Checkout", kind: .class, role: "Context", col: 0, row: 0, members: ["- policy: DiscountPolicy", "+ total(): Money"]),
      .init(id: "p", name: "DiscountPolicy", kind: .interface, role: "Strategy", col: 1, row: 0, members: ["+ apply(Money): Money"]),
      .init(id: "a", name: "PercentOff", kind: .record, role: "Concrete", col: 1, row: 1, members: []),
    ],
    edges: [
      .init(from: "ctx", to: "p", rel: .aggregation),
      .init(from: "a", to: "p", rel: .realizes),
    ],
    notes: [.init(attachTo: "p", text: "Swap at runtime")])
  ScrollView { DiagramView(diagram: .classDiagram(d)).padding() }
}

#Preview("Sequence diagram") {
  let d = SequenceDiagram(
    title: "Checkout",
    participants: [.init(id: "c", name: "Client"), .init(id: "k", name: "Checkout", role: "Context"), .init(id: "p", name: "Policy", role: "Strategy")],
    messages: [
      .init(from: "c", to: "k", label: "total()"),
      .init(from: "k", to: "p", label: "apply(m)"),
      .init(from: "p", to: "k", label: "Money", style: .return),
    ],
    fragments: [.init(kind: .opt, guardText: "has policy", from: 1, to: 2)])
  ScrollView { DiagramView(diagram: .sequence(d)).padding() }
}
#endif
