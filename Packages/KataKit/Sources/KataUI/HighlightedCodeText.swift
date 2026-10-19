import KataCode
import SwiftUI

/// A short syntax-highlighted snippet as plain `Text` (wraps), for rows where `CodeView`'s
/// horizontal scrolling would fight a list. Uses the same palette as `CodeView`.
public struct HighlightedCodeText: View {
  let source: String
  var language = "java"
  var size: CGFloat = 13
  @Environment(\.colorScheme) private var scheme

  public init(source: String, language: String = "java", size: CGFloat = 13) {
    self.source = source; self.language = language; self.size = size
  }

  public var body: some View {
    let theme = CodeTheme.theme(for: scheme)
    var out = AttributedString()
    for token in HighlighterRegistry.shared.highlighter(for: language).tokenize(source) {
      var a = AttributedString(token.text)
      a.foregroundColor = theme.color(for: token.kind)
      out += a
    }
    return Text(out)
      .font(.system(size: size, design: .monospaced))
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
