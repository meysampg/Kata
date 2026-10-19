#if os(macOS)
  import AppKit
  import KataCode
  import KataUI

  /// The kata editor's text view: TextKit 1, monospaced, plain text, with the indentation rules
  /// of `KataCode.Indentation` (MAC_PLAN §5.3).
  @MainActor
  public final class CodeTextView: NSTextView {
    /// Called with +1 / -1 for ⌘+ / ⌘−.
    public var fontStep: ((Int) -> Void)?
    public private(set) var diagnostics: [EditorDiagnostic] = []
    weak var highlighter: EditorHighlighter?

    private static let squiggle = NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDot.rawValue

    /// A text view on an explicit TextKit 1 stack (touching `layoutManager` on a TextKit 2 view
    /// would silently downgrade it).
    public static func make() -> CodeTextView {
      let storage = NSTextStorage()
      let layout = NSLayoutManager()
      let container = NSTextContainer(size: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
      storage.addLayoutManager(layout)
      layout.addTextContainer(container)
      let view = CodeTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300), textContainer: container)
      view.configure()
      return view
    }

    private func configure() {
      isRichText = false
      importsGraphics = false
      allowsUndo = true
      usesFindBar = true
      isIncrementalSearchingEnabled = true
      isAutomaticQuoteSubstitutionEnabled = false
      isAutomaticDashSubstitutionEnabled = false
      isAutomaticTextReplacementEnabled = false
      isAutomaticSpellingCorrectionEnabled = false
      isAutomaticLinkDetectionEnabled = false
      isAutomaticDataDetectionEnabled = false
      isAutomaticTextCompletionEnabled = false
      isContinuousSpellCheckingEnabled = false
      isGrammarCheckingEnabled = false
      smartInsertDeleteEnabled = false
      textContainerInset = NSSize(width: 4, height: 6)
      isVerticallyResizable = true
      isHorizontallyResizable = true
      autoresizingMask = [.width]
      maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
      textContainer?.widthTracksTextView = false
      textContainer?.heightTracksTextView = false
      textContainer?.lineFragmentPadding = 4
      addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self))
    }

    // MARK: Appearance

    public func apply(theme: CodeTheme, fontSize: CGFloat) {
      let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
      let width = ("M" as NSString).size(withAttributes: [.font: font]).width
      let style = NSMutableParagraphStyle()
      style.tabStops = []
      style.defaultTabInterval = width * 4
      let base = EditorHighlighter.baseColor(theme)
      self.font = font
      textColor = base
      insertionPointColor = base
      backgroundColor = .textBackgroundColor
      defaultParagraphStyle = style
      typingAttributes = [.font: font, .foregroundColor: base, .paragraphStyle: style]
      if let storage = textStorage, storage.length > 0 {
        let all = NSRange(location: 0, length: storage.length)
        storage.addAttributes([.font: font, .foregroundColor: base, .paragraphStyle: style], range: all)
      }
      selectedTextAttributes = [.backgroundColor: NSColor.selectedTextBackgroundColor]
    }

    /// Replaces the whole text without leaving an undo step.
    public func setPlainText(_ text: String) {
      let selection = selectedRange()
      string = text
      highlighter?.flush()
      undoManager?.removeAllActions()
      setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
      refreshDiagnostics()
    }

    public override func didChangeText() {
      super.didChangeText()
      highlighter?.flush()
    }

    // MARK: Editing rules

    public func apply(_ edit: Indentation.Edit) {
      guard isEditable, shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return }
      textStorage?.replaceCharacters(in: edit.range, with: edit.replacement)
      didChangeText()
      setSelectedRange(edit.selection)
    }

    public override func insertTab(_ sender: Any?) {
      apply(Indentation.tab(in: string, selection: selectedRange()))
    }

    public override func insertBacktab(_ sender: Any?) {
      apply(Indentation.backtab(in: string, selection: selectedRange()))
    }

    public override func insertNewline(_ sender: Any?) {
      apply(Indentation.newline(in: string, selection: selectedRange()))
    }

    public override func insertText(_ insertString: Any, replacementRange: NSRange) {
      if let s = insertString as? String ?? (insertString as? NSAttributedString)?.string, s == "}",
        replacementRange.location == NSNotFound,
        let edit = Indentation.closeBrace(in: string, selection: selectedRange())
      {
        apply(edit)
        return
      }
      super.insertText(insertString, replacementRange: replacementRange)
    }

    public func toggleComment() {
      apply(Indentation.toggleComment(in: string, selection: selectedRange()))
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
      guard window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
      let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
      let key = event.charactersIgnoringModifiers ?? ""
      if flags == .command {
        switch key {
        case "/" where isEditable:
          toggleComment()
          return true
        case "=", "+":
          fontStep?(1)
          return true
        case "-":
          fontStep?(-1)
          return true
        case "f":
          let item = NSMenuItem()
          item.tag = Int(NSTextFinder.Action.showFindInterface.rawValue)
          performTextFinderAction(item)
          return true
        default: break
        }
      } else if flags == [.command, .shift], key == "=" || key == "+" {
        fontStep?(1)
        return true
      }
      return super.performKeyEquivalent(with: event)
    }

    // MARK: Diagnostics

    public func setDiagnostics(_ new: [EditorDiagnostic]) {
      guard new != diagnostics else { return }
      diagnostics = new
      refreshDiagnostics()
    }

    private func refreshDiagnostics() {
      guard let lm = layoutManager else { return }
      let length = (string as NSString).length
      let all = NSRange(location: 0, length: length)
      lm.removeTemporaryAttribute(.underlineStyle, forCharacterRange: all)
      lm.removeTemporaryAttribute(.underlineColor, forCharacterRange: all)
      for d in diagnostics {
        let start = min(d.range.location, length)
        let r = NSRange(location: start, length: min(d.range.length, length - start))
        guard r.length > 0 else { continue }
        lm.addTemporaryAttributes(
          [
            .underlineStyle: Self.squiggle,
            .underlineColor: d.severity == .error ? NSColor.systemRed : NSColor.systemOrange,
          ], forCharacterRange: r)
      }
    }

    public override func mouseMoved(with event: NSEvent) {
      super.mouseMoved(with: event)
      guard !diagnostics.isEmpty else { toolTip = nil; return }
      let index = characterIndexForInsertion(at: convert(event.locationInWindow, from: nil))
      let hits = diagnostics.filter { NSLocationInRange(index, $0.range) || index == NSMaxRange($0.range) && $0.range.length == 0 }
      toolTip = hits.isEmpty ? nil : hits.map(\.message).joined(separator: "\n")
    }

    // MARK: Navigation

    /// Selects `range`, scrolls it into view and flashes it.
    public func reveal(_ range: NSRange) {
      let length = (string as NSString).length
      let start = min(max(range.location, 0), length)
      let r = NSRange(location: start, length: min(max(range.length, 0), length - start))
      setSelectedRange(r)
      scrollRangeToVisible(r)
      window?.makeFirstResponder(self)
      showFindIndicator(for: r.length > 0 ? r : (string as NSString).lineRange(for: r))
    }
  }
#endif
