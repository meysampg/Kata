import CoreGraphics
import Foundation

/// Renderer-agnostic drawing primitives produced by the layouts.
public struct DiagramScene: Sendable, Equatable {
  public enum BoxStyle: String, Sendable, Equatable {
    case classNode, interfaceNode, abstractNode, recordNode, enumNode
    case note, participant, fragment
  }

  public enum TextStyle: String, Sendable, Equatable {
    case stereotype, name, abstractName, role, member, note, label, fragmentHeader, title
  }

  public enum Alignment: String, Sendable, Equatable { case leading, center, trailing }

  public enum Marker: String, Sendable, Equatable {
    case none, openArrow, filledArrow, hollowTriangle, hollowDiamond, filledDiamond
  }

  public struct TextLine: Sendable, Equatable {
    public var text: String
    public var style: TextStyle
    /// Frame of the line; text is vertically centred in it.
    public var rect: CGRect
    public var alignment: Alignment
  }

  public struct Compartment: Sendable, Equatable {
    public var rect: CGRect
    public var lines: [TextLine]
  }

  public struct Box: Sendable, Equatable {
    public var id: String?
    public var rect: CGRect
    public var style: BoxStyle
    public var compartments: [Compartment]
  }

  public struct Line: Sendable, Equatable {
    public var points: [CGPoint]
    public var dashed: Bool
    public var startMarker: Marker
    public var endMarker: Marker
  }

  public struct Text: Sendable, Equatable {
    public var text: String
    /// Anchor point; `y` is the vertical centre of the text.
    public var origin: CGPoint
    public var alignment: Alignment
    public var style: TextStyle
  }

  public var size: CGSize
  public var boxes: [Box]
  public var lines: [Line]
  public var texts: [Text]

  public init(size: CGSize = .zero, boxes: [Box] = [], lines: [Line] = [], texts: [Text] = []) {
    self.size = size; self.boxes = boxes; self.lines = lines; self.texts = texts
  }
}

extension DiagramScene {
  func translated(dx: CGFloat, dy: CGFloat) -> DiagramScene {
    func p(_ q: CGPoint) -> CGPoint { CGPoint(x: q.x + dx, y: q.y + dy) }
    func r(_ q: CGRect) -> CGRect { q.offsetBy(dx: dx, dy: dy) }
    var s = self
    s.boxes = boxes.map { b in
      var b = b
      b.rect = r(b.rect)
      b.compartments = b.compartments.map { c in
        var c = c
        c.rect = r(c.rect)
        c.lines = c.lines.map { l in var l = l; l.rect = r(l.rect); return l }
        return c
      }
      return b
    }
    s.lines = lines.map { l in var l = l; l.points = l.points.map(p); return l }
    s.texts = texts.map { t in var t = t; t.origin = p(t.origin); return t }
    return s
  }

  /// Shifts content so its bounds start at `margin` and sizes the scene to fit.
  func normalized(margin: CGFloat, metrics: TextMetrics) -> DiagramScene {
    var minX = CGFloat.infinity, minY = CGFloat.infinity
    var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
    func add(_ x: CGFloat, _ y: CGFloat) {
      minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    }
    for b in boxes { add(b.rect.minX, b.rect.minY); add(b.rect.maxX, b.rect.maxY) }
    for l in lines { for q in l.points { add(q.x, q.y) } }
    for t in texts {
      let w = metrics.width(of: t.text)
      let x0: CGFloat =
        switch t.alignment {
        case .leading: t.origin.x
        case .center: t.origin.x - w / 2
        case .trailing: t.origin.x - w
        }
      add(x0, t.origin.y - metrics.lineHeight / 2)
      add(x0 + w, t.origin.y + metrics.lineHeight / 2)
    }
    guard minX.isFinite else { return DiagramScene(size: CGSize(width: margin * 2, height: margin * 2)) }
    var s = translated(dx: margin - minX, dy: margin - minY)
    s.size = CGSize(width: maxX - minX + margin * 2, height: maxY - minY + margin * 2)
    return s
  }
}

extension CGRect {
  /// True only when the rectangles share positive area (touching edges do not count).
  func overlapsInterior(_ other: CGRect) -> Bool {
    let i = intersection(other)
    return !i.isNull && i.width > 0.5 && i.height > 0.5
  }
}
