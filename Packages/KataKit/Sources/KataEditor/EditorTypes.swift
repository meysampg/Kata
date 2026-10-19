#if os(macOS)
  import Foundation

  /// A compiler or policy message to show in the editor: an underline, a gutter marker and a tooltip.
  public struct EditorDiagnostic: Sendable, Equatable, Identifiable {
    public enum Severity: Sendable, Equatable { case error, warning }

    public var id: Int
    /// UTF-16 range in the editor's text (the unit javac reports).
    public var range: NSRange
    public var severity: Severity
    public var message: String

    public init(id: Int, range: NSRange, severity: Severity, message: String) {
      self.id = id; self.range = range; self.severity = severity; self.message = message
    }
  }

  /// Asks the editor to select a range, scroll it into view and flash it. A new `id` is a new request.
  public struct EditorReveal: Sendable, Equatable {
    public var id: UUID
    public var range: NSRange

    public init(range: NSRange, id: UUID = UUID()) {
      self.range = range; self.id = id
    }
  }

  /// A 1-based caret position for the status line.
  public struct EditorPosition: Sendable, Equatable {
    public var line: Int
    public var column: Int

    public init(line: Int, column: Int) {
      self.line = line; self.column = column
    }

    /// Position of UTF-16 offset `offset` in `text`.
    public static func of(offset: Int, in text: String) -> EditorPosition {
      let ns = text as NSString
      let at = min(max(offset, 0), ns.length)
      var line = 1
      var lineStart = 0
      var i = 0
      while i < at {
        if ns.character(at: i) == 0x0A { line += 1; lineStart = i + 1 }
        i += 1
      }
      return EditorPosition(line: line, column: at - lineStart + 1)
    }
  }
#endif
