import Foundation

/// Pure editing rules for a code editor (MAC_PLAN §5.3): Tab, ⇧Tab, Return, `}` and ⌘/.
/// All offsets are UTF-16 code units, the unit of `NSString` and `NSTextView`.
public enum Indentation {
  /// One indentation level.
  public static let unit = "    "

  /// Replace `range` of the old text with `replacement`, then select `selection` of the new text.
  public struct Edit: Sendable, Equatable {
    public var range: NSRange
    public var replacement: String
    public var selection: NSRange

    public init(range: NSRange, replacement: String, selection: NSRange) {
      self.range = range; self.replacement = replacement; self.selection = selection
    }

    /// The text after applying the edit.
    public func apply(to text: String) -> String {
      (text as NSString).replacingCharacters(in: range, with: replacement)
    }
  }

  // MARK: Tab and ⇧Tab

  /// Tab: four spaces at the caret. A selection that spans lines indents every line it touches.
  public static func tab(in text: String, selection: NSRange) -> Edit {
    let ns = text as NSString
    let sel = clamp(selection, ns.length)
    guard ns.substring(with: sel).contains("\n") else {
      return Edit(
        range: sel, replacement: unit, selection: NSRange(location: sel.location + unit.utf16.count, length: 0))
    }
    let lines = touchedLines(ns, sel)
    var edits: [LineEdit] = []
    for line in lines.starts { edits.append(LineEdit(location: line, removed: 0, inserted: unit)) }
    return rewrite(ns, block: lines.block, edits: edits, selection: sel)
  }

  /// ⇧Tab: removes up to four leading spaces (or one tab) from every line the selection touches.
  public static func backtab(in text: String, selection: NSRange) -> Edit {
    let ns = text as NSString
    let sel = clamp(selection, ns.length)
    let lines = touchedLines(ns, sel)
    var edits: [LineEdit] = []
    for start in lines.starts {
      var n = 0
      while n < unit.utf16.count, start + n < ns.length, ns.character(at: start + n) == 0x20 { n += 1 }
      if n == 0, start < ns.length, ns.character(at: start) == 0x09 { n = 1 }
      if n > 0 { edits.append(LineEdit(location: start, removed: n, inserted: "")) }
    }
    return rewrite(ns, block: lines.block, edits: edits, selection: sel)
  }

  // MARK: Return

  /// Return: copies the line's indentation, adds a level after `{`, `(` or `->`, and opens a
  /// blank, indented line between a `{` and the `}` that follows it.
  public static func newline(in text: String, selection: NSRange) -> Edit {
    let ns = text as NSString
    let sel = clamp(selection, ns.length)
    let lineStart = ns.lineRange(for: NSRange(location: sel.location, length: 0)).location
    let before = ns.substring(with: NSRange(location: lineStart, length: sel.location - lineStart))
    var indent = String(before.prefix { $0 == " " || $0 == "\t" })
    let trimmed = before.trimmingCharacters(in: .whitespaces)
    let opens = trimmed.hasSuffix("{") || trimmed.hasSuffix("(") || trimmed.hasSuffix("->")
    let afterLoc = sel.location + sel.length
    let nextChar: unichar? = afterLoc < ns.length ? ns.character(at: afterLoc) : nil
    let closes = nextChar == 0x7D || nextChar == 0x29  // } or )
    if opens && closes && (trimmed.hasSuffix("{") || trimmed.hasSuffix("(")) {
      let inner = indent + unit
      let text = "\n" + inner + "\n" + indent
      return Edit(
        range: sel, replacement: text, selection: NSRange(location: sel.location + 1 + inner.utf16.count, length: 0))
    }
    if opens { indent += unit }
    let text = "\n" + indent
    return Edit(range: sel, replacement: text, selection: NSRange(location: sel.location + text.utf16.count, length: 0))
  }

  // MARK: Closing brace

  /// Typing `}` on a line that holds only whitespace outdents one level. Nil when the rule does
  /// not apply (insert the character normally).
  public static func closeBrace(in text: String, selection: NSRange) -> Edit? {
    let ns = text as NSString
    let sel = clamp(selection, ns.length)
    guard sel.length == 0 else { return nil }
    let lineStart = ns.lineRange(for: NSRange(location: sel.location, length: 0)).location
    let before = ns.substring(with: NSRange(location: lineStart, length: sel.location - lineStart))
    guard !before.isEmpty, before.allSatisfy({ $0 == " " }) else { return nil }
    let drop = min(unit.utf16.count, before.utf16.count)
    return Edit(
      range: NSRange(location: sel.location - drop, length: drop), replacement: "}",
      selection: NSRange(location: sel.location - drop + 1, length: 0))
  }

  // MARK: Comments

  /// ⌘/: comments every non-blank line the selection touches with `// `, or removes the
  /// comments when they are all commented already.
  public static func toggleComment(in text: String, selection: NSRange) -> Edit {
    let ns = text as NSString
    let sel = clamp(selection, ns.length)
    let lines = touchedLines(ns, sel)
    struct Info { var start: Int; var indent: Int; var blank: Bool; var commented: Bool }
    let infos: [Info] = lines.starts.map { start in
      let range = ns.lineRange(for: NSRange(location: start, length: 0))
      var i = start
      let end = range.location + range.length
      while i < end, ns.character(at: i) == 0x20 || ns.character(at: i) == 0x09 { i += 1 }
      let blank = i >= end || ns.character(at: i) == 0x0A || ns.character(at: i) == 0x0D
      let commented = !blank && i + 1 < end && ns.character(at: i) == 0x2F && ns.character(at: i + 1) == 0x2F
      return Info(start: start, indent: i - start, blank: blank, commented: commented)
    }
    let content = infos.filter { !$0.blank }
    guard !content.isEmpty else {
      return Edit(range: sel, replacement: ns.substring(with: sel), selection: sel)
    }
    var edits: [LineEdit] = []
    if content.allSatisfy(\.commented) {
      for info in content {
        let at = info.start + info.indent
        var n = 2
        if at + 2 < ns.length, ns.character(at: at + 2) == 0x20 { n = 3 }
        edits.append(LineEdit(location: at, removed: n, inserted: ""))
      }
    } else {
      let column = content.map(\.indent).min() ?? 0
      for info in content { edits.append(LineEdit(location: info.start + column, removed: 0, inserted: "// ")) }
    }
    return rewrite(ns, block: lines.block, edits: edits, selection: sel)
  }

  // MARK: Helpers

  private struct LineEdit {
    var location: Int
    var removed: Int
    var inserted: String
  }

  private static func clamp(_ r: NSRange, _ length: Int) -> NSRange {
    let loc = min(max(r.location, 0), length)
    return NSRange(location: loc, length: min(max(r.length, 0), length - loc))
  }

  /// Starting offsets of the lines touched by `sel` and the range of those whole lines. A
  /// selection that ends exactly at the start of a line does not touch that line.
  private static func touchedLines(_ ns: NSString, _ sel: NSRange) -> (starts: [Int], block: NSRange) {
    var last = sel
    if sel.length > 0 { last = NSRange(location: sel.location + sel.length - 1, length: 0) }
    let first = ns.lineRange(for: NSRange(location: sel.location, length: 0))
    let tail = ns.lineRange(for: NSRange(location: last.location, length: 0))
    let block = NSRange(location: first.location, length: tail.location + tail.length - first.location)
    var starts: [Int] = []
    var i = first.location
    while i < block.location + block.length {
      starts.append(i)
      i = ns.lineRange(for: NSRange(location: i, length: 0)).upperBound
    }
    if starts.isEmpty { starts = [first.location] }
    return (starts, block)
  }

  /// Applies per-line edits to `block` and maps the selection through them.
  private static func rewrite(_ ns: NSString, block: NSRange, edits: [LineEdit], selection: NSRange) -> Edit {
    let sorted = edits.sorted { $0.location < $1.location }
    var out = ""
    var cursor = block.location
    for e in sorted {
      out += ns.substring(with: NSRange(location: cursor, length: e.location - cursor))
      out += e.inserted
      cursor = e.location + e.removed
    }
    out += ns.substring(with: NSRange(location: cursor, length: block.location + block.length - cursor))

    func map(_ p: Int) -> Int {
      var delta = 0
      for e in sorted {
        if p > e.location {
          if p < e.location + e.removed { delta += e.location - p } else { delta += e.inserted.utf16.count - e.removed }
        }
      }
      return p + delta
    }
    let start = map(selection.location)
    let end = map(selection.location + selection.length)
    return Edit(range: block, replacement: out, selection: NSRange(location: start, length: max(0, end - start)))
  }
}
