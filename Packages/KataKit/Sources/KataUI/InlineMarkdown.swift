import Foundation
import SwiftUI

public enum InlineMarkdown {
  /// Parses the inline Markdown subset (`**bold**`, `*italic*`, `` `code` ``, `[x](kata:id)`),
  /// preserving whitespace. Falls back to plain text on parse errors.
  public static func attributed(_ text: String) -> AttributedString {
    var out =
      (try? AttributedString(
        markdown: text,
        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
      ?? AttributedString(text)
    for run in out.runs {
      if run.inlinePresentationIntent?.contains(.code) == true {
        out[run.range].font = .system(.body, design: .monospaced)
      }
    }
    return out
  }
}
