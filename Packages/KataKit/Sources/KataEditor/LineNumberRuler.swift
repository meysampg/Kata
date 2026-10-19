#if os(macOS)
  import AppKit
  import KataUI

  /// Line numbers and diagnostic markers beside the text. A plain sibling view rather than an
  /// `NSRulerView`: AppKit lets the text view scroll under a ruler (it hid the first characters
  /// of every line), and the gutter needs nothing the ruler machinery adds.
  @MainActor
  public final class LineNumberRuler: NSView {
    public override var isFlipped: Bool { true }
    public private(set) var ruleThickness: CGFloat = 40 {
      didSet { if oldValue != ruleThickness { superview?.needsLayout = true } }
    }
    private weak var clientView: NSTextView?
    public var theme: CodeTheme = .light { didSet { needsDisplay = true } }
    public var diagnosticMarkers: [EditorDiagnostic] = [] {
      didSet { if diagnosticMarkers != oldValue { needsDisplay = true } }
    }
    public var fontSize: CGFloat = 13 {
      didSet { updateThickness(); needsDisplay = true }
    }
    /// 1-based line to emphasise (the caret's line).
    public var currentLine: Int = 0 {
      didSet { if currentLine != oldValue { needsDisplay = true } }
    }

    private var textView: NSTextView? { clientView }
    private var observers: [any NSObjectProtocol] = []

    public init(scrollView: NSScrollView, textView: NSTextView) {
      super.init(frame: NSRect(x: 0, y: 0, width: 40, height: 100))
      clientView = textView
      scrollView.contentView.postsBoundsChangedNotifications = true
      let center = NotificationCenter.default
      observers.append(
        center.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.contentView, queue: .main) { [weak self] _ in
          MainActor.assumeIsolated { self?.needsDisplay = true }
        })
      observers.append(
        center.addObserver(forName: NSText.didChangeNotification, object: textView, queue: .main) { [weak self] _ in
          MainActor.assumeIsolated { self?.updateThickness(); self?.needsDisplay = true }
        })
      addTrackingArea(
        NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self))
    }

    @available(*, unavailable) required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    isolated deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    private var font: NSFont { .monospacedDigitSystemFont(ofSize: max(9, fontSize - 2), weight: .regular) }

    func updateThickness() {
      let lines = max(1, (textView?.string as NSString?).map { Self.lineStarts($0).count } ?? 1)
      let digits = max(2, String(lines).count)
      let width = ("8" as NSString).size(withAttributes: [.font: font]).width
      let thickness = ceil(CGFloat(digits) * width) + 26
      if abs(thickness - ruleThickness) > 0.5 { ruleThickness = thickness }
    }

    static func lineStarts(_ ns: NSString) -> [Int] {
      var starts = [0]
      var i = 0
      while i < ns.length {
        if ns.character(at: i) == 0x0A { starts.append(i + 1) }
        i += 1
      }
      return starts
    }

    private func lineIndex(of offset: Int, in starts: [Int]) -> Int {
      var lo = 0, hi = starts.count - 1
      while lo < hi {
        let mid = (lo + hi + 1) / 2
        if starts[mid] <= offset { lo = mid } else { hi = mid - 1 }
      }
      return lo
    }

    public override func draw(_ dirtyRect: NSRect) {
      guard let tv = textView, let lm = tv.layoutManager, let tc = tv.textContainer else { return }
      let background = NSColor.textBackgroundColor
      background.setFill()
      bounds.fill()
      NSColor.separatorColor.withAlphaComponent(0.5).setStroke()
      let edge = NSBezierPath()
      edge.move(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.minY))
      edge.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
      edge.lineWidth = 1
      edge.stroke()

      let ns = tv.string as NSString
      let starts = Self.lineStarts(ns)
      let origin = tv.textContainerOrigin
      let visible = tv.visibleRect
      let glyphs = lm.glyphRange(forBoundingRect: visible, in: tc)
      let chars = lm.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
      var line = lineIndex(of: chars.location, in: starts)
      let flagged = Dictionary(grouping: diagnosticMarkers) { lineIndex(of: min($0.range.location, ns.length), in: starts) }

      let numberColor = NSColor(theme.gutterColor)
      let strong = NSColor.secondaryLabelColor
      let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: numberColor]
      let currentAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: strong]

      while line < starts.count, starts[line] <= max(chars.upperBound, chars.location) {
        let offset = starts[line]
        let lineRect: NSRect
        if offset >= ns.length, lm.numberOfGlyphs == 0 || (offset > 0 && ns.character(at: offset - 1) == 0x0A) {
          lineRect = lm.extraLineFragmentRect.isEmpty
            ? NSRect(x: 0, y: 0, width: 0, height: lm.defaultLineHeight(for: tv.font ?? font)) : lm.extraLineFragmentRect
        } else {
          let glyph = lm.glyphIndexForCharacter(at: min(offset, max(0, ns.length - 1)))
          lineRect = lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        }
        let y = convert(NSPoint(x: 0, y: lineRect.minY + origin.y), from: tv).y
        let label = "\(line + 1)" as NSString
        let size = label.size(withAttributes: attrs)
        let ty = y + (lineRect.height - size.height) / 2
        label.draw(
          at: NSPoint(x: bounds.maxX - size.width - 8, y: ty), withAttributes: line + 1 == currentLine ? currentAttrs : attrs)
        if let hits = flagged[line] {
          let isError = hits.contains { $0.severity == .error }
          (isError ? NSColor.systemRed : NSColor.systemOrange).setFill()
          let d: CGFloat = 7
          NSBezierPath(ovalIn: NSRect(x: 6, y: y + (lineRect.height - d) / 2, width: d, height: d)).fill()
        }
        line += 1
      }
    }

    // MARK: Tooltips

    public override func mouseMoved(with event: NSEvent) {
      toolTip = markerMessage(at: convert(event.locationInWindow, from: nil))
    }

    public override func mouseExited(with event: NSEvent) { toolTip = nil }

    func markerMessage(at point: NSPoint) -> String? {
      guard let tv = textView, let lm = tv.layoutManager, let tc = tv.textContainer, !diagnosticMarkers.isEmpty else { return nil }
      let p = tv.convert(point, from: self)
      let local = NSPoint(x: 1, y: p.y - tv.textContainerOrigin.y)
      let glyph = lm.glyphIndex(for: local, in: tc, fractionOfDistanceThroughGlyph: nil)
      let offset = lm.characterIndexForGlyph(at: glyph)
      let ns = tv.string as NSString
      let starts = Self.lineStarts(ns)
      let line = lineIndex(of: offset, in: starts)
      let messages = diagnosticMarkers.filter { lineIndex(of: min($0.range.location, ns.length), in: starts) == line }.map(\.message)
      return messages.isEmpty ? nil : messages.joined(separator: "\n")
    }
  }
#endif
