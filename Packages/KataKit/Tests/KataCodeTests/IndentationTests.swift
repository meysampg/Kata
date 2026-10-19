import Foundation
import Testing

@testable import KataCode

/// `|` marks the caret; `[` and `]` mark a selection. The helpers strip the markers.
private struct Doc {
  var text: String
  var selection: NSRange

  init(_ marked: String) {
    var out = ""
    var start: Int?
    var end: Int?
    for ch in marked {
      switch ch {
      case "|": start = out.utf16.count; end = start
      case "[": start = out.utf16.count
      case "]": end = out.utf16.count
      default: out.append(ch)
      }
    }
    text = out
    selection = NSRange(location: start ?? 0, length: (end ?? start ?? 0) - (start ?? 0))
  }

  /// The document after the edit, with the new selection marked again.
  func marked(_ edit: Indentation.Edit) -> String {
    let new = edit.apply(to: text) as NSString
    let s = edit.selection
    if s.length == 0 {
      return new.replacingCharacters(in: s, with: "|")
    }
    let closed = new.replacingCharacters(in: NSRange(location: s.location + s.length, length: 0), with: "]") as NSString
    return closed.replacingCharacters(in: NSRange(location: s.location, length: 0), with: "[")
  }
}

@Suite struct IndentationTests {
  @Test func tabInsertsFourSpacesAtTheCaret() {
    let d = Doc("int x;|")
    #expect(d.marked(Indentation.tab(in: d.text, selection: d.selection)) == "int x;    |")
  }

  @Test func tabReplacesASingleLineSelection() {
    let d = Doc("a[bc]d")
    #expect(d.marked(Indentation.tab(in: d.text, selection: d.selection)) == "a    |d")
  }

  @Test func tabIndentsEveryTouchedLine() {
    let d = Doc("[one\ntwo\n]three")
    let e = Indentation.tab(in: d.text, selection: d.selection)
    #expect(e.apply(to: d.text) == "    one\n    two\nthree")
    #expect(d.marked(e) == "[    one\n    two\n]three")
  }

  @Test func backtabRemovesUpToFourSpaces() {
    let d = Doc("    a|\n  b")
    #expect(Indentation.backtab(in: d.text, selection: d.selection).apply(to: d.text) == "a\n  b")
    let two = Doc("[    a\n  b]")
    #expect(Indentation.backtab(in: two.text, selection: two.selection).apply(to: two.text) == "a\nb")
  }

  @Test func backtabKeepsTheCaretOnItsCharacter() {
    let d = Doc("    ab|")
    #expect(d.marked(Indentation.backtab(in: d.text, selection: d.selection)) == "ab|")
  }

  @Test func backtabHandlesAHardTabAndNoIndent() {
    let d = Doc("\tx|")
    #expect(Indentation.backtab(in: d.text, selection: d.selection).apply(to: d.text) == "x")
    let n = Doc("x|")
    #expect(Indentation.backtab(in: n.text, selection: n.selection).apply(to: n.text) == "x")
  }

  @Test func newlineCopiesIndentation() {
    let d = Doc("    int x;|")
    #expect(d.marked(Indentation.newline(in: d.text, selection: d.selection)) == "    int x;\n    |")
  }

  @Test func newlineAfterBraceParenAndArrowAddsALevel() {
    for opener in ["class A {", "call(", "x ->", "x ->  "] {
      let d = Doc("  \(opener)|")
      #expect(Indentation.newline(in: d.text, selection: d.selection).replacement == "\n      ")
    }
  }

  @Test func newlineBetweenBracesOpensABlock() {
    let d = Doc("void f() {|}")
    let e = Indentation.newline(in: d.text, selection: d.selection)
    #expect(d.marked(e) == "void f() {\n    |\n}")
  }

  @Test func newlineInsideTheIndentationDoesNotDuplicateIt() {
    let d = Doc("  |  x")
    #expect(Indentation.newline(in: d.text, selection: d.selection).replacement == "\n  ")
  }

  @Test func newlineReplacesTheSelection() {
    let d = Doc("a[bc]d")
    #expect(Indentation.newline(in: d.text, selection: d.selection).apply(to: d.text) == "a\nd")
  }

  @Test func closeBraceOutdentsABlankIndentedLine() {
    let d = Doc("{\n    |")
    let e = try! #require(Indentation.closeBrace(in: d.text, selection: d.selection))
    #expect(d.marked(e) == "{\n}|")
    let deep = Doc("        |")
    let e2 = try! #require(Indentation.closeBrace(in: deep.text, selection: deep.selection))
    #expect(e2.apply(to: deep.text) == "    }")
  }

  @Test func closeBraceDoesNotApplyAfterCodeOrAtColumnZero() {
    let a = Doc("x = |")
    #expect(Indentation.closeBrace(in: a.text, selection: a.selection) == nil)
    let b = Doc("|")
    #expect(Indentation.closeBrace(in: b.text, selection: b.selection) == nil)
    let c = Doc("[   ]")
    #expect(Indentation.closeBrace(in: c.text, selection: c.selection) == nil)
  }

  @Test func toggleCommentAddsAtTheSmallestIndent() {
    let d = Doc("[    a\n      b\n\n    c]")
    let e = Indentation.toggleComment(in: d.text, selection: d.selection)
    #expect(e.apply(to: d.text) == "    // a\n    //   b\n\n    // c")
  }

  @Test func toggleCommentRemovesWhenEveryLineIsCommented() {
    let d = Doc("[    // a\n    //b\n    // c]")
    #expect(Indentation.toggleComment(in: d.text, selection: d.selection).apply(to: d.text) == "    a\n    b\n    c")
  }

  @Test func toggleCommentCommentsWhenOnlySomeAreCommented() {
    let d = Doc("[// a\nb]")
    #expect(Indentation.toggleComment(in: d.text, selection: d.selection).apply(to: d.text) == "// // a\n// b")
  }

  @Test func toggleCommentOnACaretLineKeepsTheCaretOnItsText() {
    let d = Doc("ab|c\nxyz")
    let e = Indentation.toggleComment(in: d.text, selection: d.selection)
    #expect(e.apply(to: d.text) == "// abc\nxyz")
    #expect(d.marked(e) == "// ab|c\nxyz")
    let back = Doc("// ab|c\nxyz")
    #expect(back.marked(Indentation.toggleComment(in: back.text, selection: back.selection)) == "ab|c\nxyz")
  }

  @Test func offsetsAreUTF16() {
    let d = Doc("😀 x|")
    let e = Indentation.newline(in: d.text, selection: d.selection)
    #expect(e.selection.location == d.selection.location + 1)
    let t = Doc("[😀\n😀]")
    #expect(Indentation.tab(in: t.text, selection: t.selection).apply(to: t.text) == "    😀\n    😀")
  }

  @Test func selectionEndingAtALineStartDoesNotTouchThatLine() {
    let d = Doc("[a\n]b")
    #expect(Indentation.toggleComment(in: d.text, selection: d.selection).apply(to: d.text) == "// a\nb")
  }
}
