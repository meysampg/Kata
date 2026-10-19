#if os(macOS)
  import AppKit
  import KataUI
  import SwiftUI

  /// The kata editor as a SwiftUI view: an `NSScrollView` holding a `CodeTextView`, a line-number
  /// ruler, syntax colours and diagnostics.
  public struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool
    var fontSize: CGFloat
    var showsLineNumbers: Bool
    var theme: CodeTheme
    var diagnostics: [EditorDiagnostic]
    var reveal: EditorReveal?
    var autoFocus: Bool
    var onSelectionChange: ((EditorPosition) -> Void)?
    var onFontStep: ((Int) -> Void)?

    public init(
      text: Binding<String>, isEditable: Bool = true, fontSize: CGFloat = 13, showsLineNumbers: Bool = true,
      theme: CodeTheme = .light, diagnostics: [EditorDiagnostic] = [], reveal: EditorReveal? = nil,
      autoFocus: Bool = false, onSelectionChange: ((EditorPosition) -> Void)? = nil,
      onFontStep: ((Int) -> Void)? = nil
    ) {
      _text = text
      self.isEditable = isEditable; self.fontSize = fontSize; self.showsLineNumbers = showsLineNumbers
      self.theme = theme; self.diagnostics = diagnostics; self.reveal = reveal; self.autoFocus = autoFocus
      self.onSelectionChange = onSelectionChange; self.onFontStep = onFontStep
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public func makeNSView(context: Context) -> EditorContainerView {
      let scroll = NSScrollView()
      let textView = CodeTextView.make()
      scroll.documentView = textView
      scroll.hasVerticalScroller = true
      scroll.hasHorizontalScroller = true
      scroll.autohidesScrollers = true
      scroll.borderType = .noBorder
      scroll.drawsBackground = true
      scroll.backgroundColor = .textBackgroundColor
      textView.minSize = NSSize(width: 0, height: scroll.contentSize.height)

      let ruler = LineNumberRuler(scrollView: scroll, textView: textView)
      let container = EditorContainerView(scroll: scroll, ruler: ruler)

      let c = context.coordinator
      c.textView = textView
      c.ruler = ruler
      c.highlighter = EditorHighlighter(theme: theme)
      textView.delegate = c
      textView.apply(theme: theme, fontSize: fontSize)
      textView.string = text
      c.highlighter?.attach(to: textView)
      ruler.theme = theme
      ruler.fontSize = fontSize
      container.showsRuler = showsLineNumbers
      textView.isEditable = isEditable
      textView.isSelectable = true
      textView.fontStep = onFontStep
      textView.setDiagnostics(diagnostics)
      ruler.diagnosticMarkers = diagnostics
      c.appliedTheme = theme
      c.appliedFontSize = fontSize
      if autoFocus {
        DispatchQueue.main.async { [weak textView] in textView?.window?.makeFirstResponder(textView) }
      }
      return container
    }

    public func updateNSView(_ container: EditorContainerView, context: Context) {
      let c = context.coordinator
      c.parent = self
      guard let textView = c.textView, let ruler = c.ruler else { return }
      if c.appliedTheme != theme || c.appliedFontSize != fontSize {
        textView.apply(theme: theme, fontSize: fontSize)
        c.highlighter?.theme = theme
        c.highlighter?.rehighlightAll()
        ruler.theme = theme
        ruler.fontSize = fontSize
        c.appliedTheme = theme
        c.appliedFontSize = fontSize
      }
      textView.isEditable = isEditable
      textView.fontStep = onFontStep
      container.showsRuler = showsLineNumbers
      if textView.string != text {
        c.isApplyingExternalText = true
        textView.setPlainText(text)
        c.isApplyingExternalText = false
        c.reportSelection()
      }
      textView.setDiagnostics(diagnostics)
      ruler.diagnosticMarkers = diagnostics
      if let reveal, reveal.id != c.lastReveal {
        c.lastReveal = reveal.id
        textView.reveal(reveal.range)
      }
    }

    /// Gutter on the left, scroll view on the right.
    @MainActor
    public final class EditorContainerView: NSView {
      let scroll: NSScrollView
      let ruler: LineNumberRuler
      var showsRuler = true { didSet { if oldValue != showsRuler { needsLayout = true } } }

      init(scroll: NSScrollView, ruler: LineNumberRuler) {
        self.scroll = scroll; self.ruler = ruler
        super.init(frame: .zero)
        addSubview(scroll)
        addSubview(ruler)
      }

      @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

      public override func layout() {
        super.layout()
        let width = showsRuler ? ruler.ruleThickness : 0
        ruler.isHidden = !showsRuler
        ruler.frame = NSRect(x: 0, y: 0, width: width, height: bounds.height)
        scroll.frame = NSRect(x: width, y: 0, width: max(0, bounds.width - width), height: bounds.height)
      }
    }

    @MainActor
    public final class Coordinator: NSObject, NSTextViewDelegate {
      var parent: CodeEditorView
      weak var textView: CodeTextView?
      weak var ruler: LineNumberRuler?
      var highlighter: EditorHighlighter?
      var appliedTheme: CodeTheme?
      var appliedFontSize: CGFloat = 0
      var lastReveal: UUID?
      var isApplyingExternalText = false

      init(_ parent: CodeEditorView) { self.parent = parent }

      public func textDidChange(_ notification: Notification) {
        guard !isApplyingExternalText, let textView else { return }
        let new = textView.string
        if parent.text != new { parent.text = new }
        reportSelection()
      }

      public func textViewDidChangeSelection(_ notification: Notification) { reportSelection() }

      func reportSelection() {
        guard let textView else { return }
        let position = EditorPosition.of(offset: textView.selectedRange().location, in: textView.string)
        ruler?.currentLine = position.line
        parent.onSelectionChange?(position)
      }
    }
  }
#endif
