#if os(macOS)
  import AppKit
  import KataCode
  import KataUI

  /// Syntax colours as layout-manager temporary attributes (MAC_PLAN §5.3). They never touch the
  /// text storage, so undo, the find bar and copy are unaffected.
  ///
  /// The whole text is re-lexed on every edit (kata files are short), but only the span between
  /// the unchanged token prefix and suffix is cleared and recoloured.
  @MainActor
  public final class EditorHighlighter: NSObject, NSTextStorageDelegate {
    struct Run: Equatable {
      var kind: TokenKind
      var text: String
      var length: Int { text.utf16.count }
    }

    public var theme: CodeTheme {
      didSet { if theme != oldValue { rehighlightAll() } }
    }
    private let lexer: any SyntaxHighlighter
    private weak var layoutManager: NSLayoutManager?
    private weak var storage: NSTextStorage?
    private var runs: [Run] = []
    /// Ranges recoloured by the last pass, for tests.
    private(set) var lastRecoloured: NSRange = NSRange(location: 0, length: 0)
    /// The storage changed since the last pass. Temporary attributes cannot be touched while the
    /// storage is still processing the edit (the layout manager is out of sync and throws), so
    /// the delegate only marks the change; `CodeTextView.didChangeText` flushes it synchronously
    /// and a main-queue hop catches edits that bypass the text view.
    private var dirty = false

    public init(theme: CodeTheme, language: String = "java") {
      self.theme = theme
      self.lexer = HighlighterRegistry.shared.highlighter(for: language)
    }

    /// Starts colouring `textView`'s storage.
    public func attach(to textView: NSTextView) {
      layoutManager = textView.layoutManager
      storage = textView.textStorage
      storage?.delegate = self
      (textView as? CodeTextView)?.highlighter = self
      rehighlightAll()
    }

    public func rehighlightAll() {
      guard let layoutManager, let storage else { return }
      let full = NSRange(location: 0, length: storage.length)
      dirty = false
      layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
      runs = lexer.tokenize(storage.string).map { Run(kind: $0.kind, text: $0.text) }
      apply(runs[...], from: 0)
      lastRecoloured = full
    }

    public nonisolated func textStorage(
      _ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
      range editedRange: NSRange, changeInLength delta: Int
    ) {
      guard editedMask.contains(.editedCharacters) else { return }
      MainActor.assumeIsolated {
        dirty = true
        DispatchQueue.main.async { MainActor.assumeIsolated { self.flush() } }
      }
    }

    /// Recolours if the text changed since the last pass.
    public func flush() {
      guard dirty else { return }
      update()
    }

    func update() {
      dirty = false
      guard let layoutManager, let storage else { return }
      let new = lexer.tokenize(storage.string).map { Run(kind: $0.kind, text: $0.text) }
      let old = runs
      runs = new
      var prefix = 0
      while prefix < old.count, prefix < new.count, old[prefix] == new[prefix] { prefix += 1 }
      var suffix = 0
      while suffix < old.count - prefix, suffix < new.count - prefix,
        old[old.count - 1 - suffix] == new[new.count - 1 - suffix]
      { suffix += 1 }
      let from = new[..<prefix].reduce(0) { $0 + $1.length }
      let middle = new[prefix..<(new.count - suffix)]
      let length = middle.reduce(0) { $0 + $1.length }
      let range = NSRange(location: from, length: length)
      lastRecoloured = range
      guard length > 0 else { return }
      layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: range)
      apply(middle, from: from)
    }

    private func apply(_ runs: ArraySlice<Run>, from start: Int) {
      guard let layoutManager else { return }
      var location = start
      for run in runs {
        let length = run.length
        if run.kind != .whitespace, run.kind != .identifier {
          layoutManager.addTemporaryAttribute(
            .foregroundColor, value: Self.color(theme, run.kind),
            forCharacterRange: NSRange(location: location, length: length))
        }
        location += length
      }
    }

    static func color(_ theme: CodeTheme, _ kind: TokenKind) -> NSColor {
      let v = theme.rgb(for: kind)
      return NSColor(
        srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
        blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    /// The colour the plain text and caret use.
    public static func baseColor(_ theme: CodeTheme) -> NSColor { color(theme, .identifier) }

    /// What colour each character should have right now, from a fresh lex; for tests.
    static func expectedColors(text: String, theme: CodeTheme) -> [NSColor?] {
      var out: [NSColor?] = []
      for token in JavaLexer().tokenize(text) {
        let c: NSColor? = (token.kind == .whitespace || token.kind == .identifier) ? nil : color(theme, token.kind)
        out += Array(repeating: c, count: token.text.utf16.count)
      }
      return out
    }
  }
#endif
