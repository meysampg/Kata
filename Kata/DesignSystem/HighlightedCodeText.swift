import KataCode
import KataUI
import SwiftUI

/// A short syntax-highlighted snippet as plain `Text` (wraps), for rows where `CodeView`'s
/// horizontal scrolling would fight a list. Uses the same palette as `CodeView`.
struct HighlightedCodeText: View {
  let source: String
  var language = "java"
  var size: CGFloat = 13
  @Environment(\.colorScheme) private var scheme

  var body: some View {
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
