import KataCode
import SwiftUI

/// Per-line adornment for `CodeView` (e.g. tap-line exercise selection and feedback).
public struct LineDecoration: Sendable, Equatable {
  public var fill: Color?
  public var outline: Color?
  public var symbolName: String?
  public var symbolColor: Color?

  public init(
    fill: Color? = nil, outline: Color? = nil, symbolName: String? = nil, symbolColor: Color? = nil
  ) {
    self.fill = fill; self.outline = outline; self.symbolName = symbolName; self.symbolColor = symbolColor
  }
}

/// Caches tokenised/split source so scrolling and re-renders never re-lex.
final class TokenLineCache: @unchecked Sendable {
  static let shared = TokenLineCache()
  private let lock = NSLock()
  private var table: [String: [[CodeToken]]] = [:]

  func lines(source: String, language: String) -> [[CodeToken]] {
    let key = language + "\u{0}" + source
    lock.lock()
    if let hit = table[key] { lock.unlock(); return hit }
    lock.unlock()
    let tokens = HighlighterRegistry.shared.highlighter(for: language).tokenize(source)
    let lines = CodeLines.split(tokens)
    lock.lock()
    if table.count > 64 { table.removeAll() }
    table[key] = lines
    lock.unlock()
    return lines
  }
}

/// Syntax-highlighted code. The line-number gutter stays fixed while the code scrolls horizontally.
/// Lines are 1-based everywhere in the API.
public struct CodeView: View {
  let source: String
  let language: String
  let fontSize: CGFloat
  let showLineNumbers: Bool
  let highlightedLines: ClosedRange<Int>?
  let dimOthers: Bool
  let onTapLine: ((Int) -> Void)?
  let lineDecorations: [Int: LineDecoration]
  let scrollsVertically: Bool
  let scrollToLine: Int?
  let footer: AnyView?

  @Environment(\.colorScheme) private var scheme
  @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
  @State private var viewportWidth: CGFloat = 0

  /// - Parameters:
  ///   - scrollsVertically: wrap in a vertical `ScrollView` so `scrollToLine` works.
  ///   - footer: shown after the last line, inside the vertical scroll (needs `scrollsVertically`).
  ///   - scrollToLine: when it changes, scrolls that line to the centre (needs `scrollsVertically`).
  public init(
    source: String, language: String = "java", fontSize: CGFloat = 14,
    showLineNumbers: Bool = true, highlightedLines: ClosedRange<Int>? = nil,
    dimOthers: Bool = false, onTapLine: ((Int) -> Void)? = nil,
    lineDecorations: [Int: LineDecoration] = [:], scrollsVertically: Bool = false,
    scrollToLine: Int? = nil, footer: AnyView? = nil
  ) {
    self.source = source; self.language = language; self.fontSize = fontSize
    self.showLineNumbers = showLineNumbers; self.highlightedLines = highlightedLines
    self.dimOthers = dimOthers; self.onTapLine = onTapLine; self.lineDecorations = lineDecorations
    self.scrollsVertically = scrollsVertically; self.scrollToLine = scrollToLine
    self.footer = footer
  }

  private var scaledSize: CGFloat { fontSize * scale }

  public var body: some View {
    if scrollsVertically {
      ScrollViewReader { proxy in
        ScrollView(.vertical) {
          VStack(spacing: 0) {
            content
            if let footer { footer }
          }
        }
          .onChange(of: scrollToLine) { _, line in
            guard let line else { return }
            withAnimation(.smooth) { proxy.scrollTo(line, anchor: .center) }
          }
          .task {
            if let line = scrollToLine { proxy.scrollTo(line, anchor: .center) }
          }
      }
    } else {
      content
    }
  }

  private var content: some View {
    let lines = TokenLineCache.shared.lines(source: source, language: language)
    let metrics = MonoMetrics.metrics(size: scaledSize)
    let rowHeight = metrics.lineHeight + 2
    let digits = max(2, String(lines.count).count)
    let gutterWidth = showLineNumbers ? CGFloat(digits) * metrics.charWidth + 16 : 0
    let theme = CodeTheme.theme(for: scheme)
    let font = Font.system(size: scaledSize, design: .monospaced)

    return HStack(alignment: .top, spacing: 0) {
      if showLineNumbers || scrollToLine != nil || scrollsVertically {
        VStack(alignment: .trailing, spacing: 0) {
          ForEach(Array(lines.enumerated()), id: \.offset) { i, _ in
            let n = i + 1
            HStack(spacing: 2) {
              if showLineNumbers {
                Text(String(n))
                  .font(Font.system(size: scaledSize * 0.85, design: .monospaced))
                  .foregroundStyle(theme.gutterColor)
              }
              if let sym = lineDecorations[n]?.symbolName {
                Image(systemName: sym).font(.system(size: scaledSize * 0.8))
                  .foregroundStyle(lineDecorations[n]?.symbolColor ?? Color.accentColor)
              }
            }
            .frame(width: showLineNumbers ? gutterWidth : nil, height: rowHeight, alignment: .trailing)
            .padding(.trailing, showLineNumbers ? 0 : 0)
            .opacity(opacity(for: n))
            .contentShape(.rect)
            .onTapGesture { onTapLine?(n) }
            .id(n)
            .accessibilityHidden(true)
          }
        }
        .frame(width: showLineNumbers ? gutterWidth : nil)
        .padding(.trailing, showLineNumbers ? 8 : 0)
      }
      ScrollView(.horizontal) {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(Array(lines.enumerated()), id: \.offset) { i, tokens in
            let n = i + 1
            row(tokens, n: n, font: font, theme: theme, height: rowHeight)
          }
        }
        .frame(minWidth: viewportWidth, alignment: .leading)
      }
      .scrollBounceBehavior(.basedOnSize)
      .scrollIndicators(.hidden)
      .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewportWidth = $0 }
    }
  }

  private func row(_ tokens: [CodeToken], n: Int, font: Font, theme: CodeTheme, height: CGFloat)
    -> some View
  {
    let deco = lineDecorations[n]
    let active = highlightedLines?.contains(n) == true
    return Text(Self.attributed(tokens, theme: theme))
      .font(font)
      .lineLimit(1)
      .fixedSize(horizontal: true, vertical: false)
      .padding(.horizontal, 6)
      .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
      .background {
        if active { Color.accentColor.opacity(0.16) }
        if let f = deco?.fill { f }
      }
      .overlay {
        if let o = deco?.outline {
          RoundedRectangle(cornerRadius: 4).strokeBorder(o, lineWidth: 1.5)
        }
      }
      .opacity(opacity(for: n))
      .contentShape(.rect)
      .onTapGesture { onTapLine?(n) }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Line \(n): \(tokens.map(\.text).joined())")
      .accessibilityAddTraits(onTapLine == nil ? [] : .isButton)
  }

  private func opacity(for n: Int) -> Double {
    guard dimOthers, let r = highlightedLines else { return 1 }
    return r.contains(n) ? 1 : 0.35
  }

  static func attributed(_ tokens: [CodeToken], theme: CodeTheme) -> AttributedString {
    if tokens.isEmpty { return AttributedString(" ") }
    var out = AttributedString()
    for t in tokens {
      var a = AttributedString(t.text)
      a.foregroundColor = theme.color(for: t.kind)
      out += a
    }
    return out
  }
}

#Preview("CodeView") {
  let src = """
    public interface DiscountPolicy {
        Money apply(Money subtotal); // strategy
    }

    /** Percent off. */
    record PercentOff(int percent) implements DiscountPolicy {
        public Money apply(Money subtotal) {
            return subtotal.times(100 - percent).dividedBy(100);
        }
    }
    """
  ScrollView {
    CodeView(source: src, highlightedLines: 6...9, dimOthers: true, onTapLine: { _ in })
      .padding()
  }
}
