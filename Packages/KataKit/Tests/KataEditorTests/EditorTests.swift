#if os(macOS)
  import AppKit
  import Testing

  @testable import KataEditor
  import KataUI

  @MainActor
  struct EditorTests {
    static let source = """
      import java.util.List;

      // Pricing
      final class Checkout {
          private final String code = "NONE";
          int total(List<Integer> p) { return p.size() * 42; }
      }
      """

    static func makeView(_ text: String = source) -> (CodeTextView, EditorHighlighter) {
      let view = CodeTextView.make()
      view.apply(theme: .light, fontSize: 13)
      view.string = text
      let h = EditorHighlighter(theme: .light)
      h.attach(to: view)
      return (view, h)
    }

    /// The temporary foreground colour of every character, nil where none is set.
    static func colors(_ view: NSTextView) -> [NSColor?] {
      let lm = view.layoutManager!
      return (0..<(view.string as NSString).length).map {
        lm.temporaryAttribute(.foregroundColor, atCharacterIndex: $0, effectiveRange: nil) as? NSColor
      }
    }

    @Test func fullHighlightMatchesTheLexer() {
      let (view, _) = Self.makeView()
      #expect(Self.colors(view) == EditorHighlighter.expectedColors(text: view.string, theme: .light))
      #expect(Self.colors(view).contains { $0 != nil })
    }

    @Test func incrementalEditsMatchAFreshHighlight() {
      let (view, h) = Self.makeView()
      let edits: [(NSRange, String)] = [
        (NSRange(location: 0, length: 0), "/* c */ "),
        (NSRange(location: 40, length: 3), ""),
        (NSRange(location: 60, length: 0), "\"unterminated"),
        (NSRange(location: 80, length: 5), "static "),
        (NSRange(location: 20, length: 1), "\n"),
      ]
      for (range, text) in edits {
        let r = NSRange(location: min(range.location, view.string.utf16.count), length: 0)
        let safe = NSRange(location: r.location, length: min(range.length, view.string.utf16.count - r.location))
        view.textStorage?.replaceCharacters(in: safe, with: text)
        h.flush()
        #expect(
          Self.colors(view) == EditorHighlighter.expectedColors(text: view.string, theme: .light),
          "after inserting \(text.debugDescription)")
      }
      _ = h
    }

    @Test func aSmallEditRecoloursOnlyASmallSpan() {
      let (view, h) = Self.makeView()
      view.textStorage?.replaceCharacters(in: NSRange(location: view.string.utf16.count - 2, length: 0), with: "// x\n")
      h.flush()
      #expect(h.lastRecoloured.length < 20)
    }

    @Test func themeChangeRecolours() {
      let (view, h) = Self.makeView()
      h.theme = .dark
      #expect(Self.colors(view) == EditorHighlighter.expectedColors(text: view.string, theme: .dark))
    }

    @Test func tabAndNewlineGoThroughTheRules() {
      let (view, _) = Self.makeView("void f() {")
      view.isEditable = true
      view.setSelectedRange(NSRange(location: 10, length: 0))
      view.insertNewline(nil)
      #expect(view.string == "void f() {\n    ")
      view.insertTab(nil)
      #expect(view.string == "void f() {\n        ")
      view.insertText("}", replacementRange: NSRange(location: NSNotFound, length: 0))
      #expect(view.string == "void f() {\n    }")
      view.insertBacktab(nil)
      #expect(view.string == "void f() {\n}")
    }

    @Test func toggleCommentTogglesBack() {
      let (view, _) = Self.makeView("int a;\nint b;")
      view.isEditable = true
      view.allowsUndo = true
      view.setSelectedRange(NSRange(location: 0, length: 13))
      view.toggleComment()
      #expect(view.string == "// int a;\n// int b;")
      view.toggleComment()
      #expect(view.string == "int a;\nint b;")
    }

    @Test func smartSubstitutionsAreOff() {
      let (view, _) = Self.makeView()
      #expect(!view.isAutomaticQuoteSubstitutionEnabled)
      #expect(!view.isAutomaticDashSubstitutionEnabled)
      #expect(!view.isContinuousSpellCheckingEnabled)
      #expect(view.usesFindBar)
    }

    @Test func diagnosticsUnderlineTheirRange() {
      let (view, _) = Self.makeView()
      view.setDiagnostics([EditorDiagnostic(id: 1, range: NSRange(location: 5, length: 4), severity: .error, message: "boom")])
      let lm = view.layoutManager!
      #expect(lm.temporaryAttribute(.underlineStyle, atCharacterIndex: 6, effectiveRange: nil) != nil)
      #expect(lm.temporaryAttribute(.underlineStyle, atCharacterIndex: 12, effectiveRange: nil) == nil)
      view.setDiagnostics([])
      #expect(lm.temporaryAttribute(.underlineStyle, atCharacterIndex: 6, effectiveRange: nil) == nil)
    }

    @Test func positionCountsUTF16Columns() {
      #expect(EditorPosition.of(offset: 0, in: "ab") == EditorPosition(line: 1, column: 1))
      #expect(EditorPosition.of(offset: 4, in: "a\n😀b") == EditorPosition(line: 2, column: 3))
      #expect(EditorPosition.of(offset: 99, in: "a\n") == EditorPosition(line: 2, column: 1))
    }
  }
#endif

#if os(macOS)
  import SwiftUI

  @MainActor
  struct EditorLayoutTests {
    @Test func theTextStartsAtTheLeftEdgeOfTheClipView() {
      let host = NSHostingView(
        rootView: CodeEditorView(text: .constant("import java.util.List;\nclass A {}"), showsLineNumbers: true)
          .frame(width: 500, height: 300))
      host.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
      let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
      window.contentView = host
      host.layoutSubtreeIfNeeded()
      let scroll = findScroll(host)
      let clip = scroll?.contentView
      #expect(clip != nil)
      #expect(clip?.bounds.origin.x == 0)
      #expect((scroll?.frame.minX ?? 0) > 20)  // the gutter sits to the left, not over the text
    }

    func findScroll(_ v: NSView) -> NSScrollView? {
      if let s = v as? NSScrollView { return s }
      for sub in v.subviews { if let s = findScroll(sub) { return s } }
      return nil
    }
  }
#endif
