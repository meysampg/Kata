import KataCore
import SwiftUI

/// Renders a card's rich-text blocks. `kata:` links go to the environment's `openURL`.
public struct BlocksView: View {
  let blocks: [Block]
  let codeFontSize: CGFloat

  public init(blocks: [Block], codeFontSize: CGFloat = 13) {
    self.blocks = blocks
    self.codeFontSize = codeFontSize
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
        view(for: block)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private func view(for block: Block) -> some View {
    switch block {
    case .lead(let t):
      Text(InlineMarkdown.attributed(t)).font(.title3).fixedSize(horizontal: false, vertical: true)
    case .paragraph(let t):
      Text(InlineMarkdown.attributed(t)).font(.body).fixedSize(horizontal: false, vertical: true)
    case .heading(let t):
      Text(InlineMarkdown.attributed(t)).font(.headline).padding(.top, 6)
        .accessibilityAddTraits(.isHeader)
    case .bullets(let items):
      VStack(alignment: .leading, spacing: 6) {
        ForEach(Array(items.enumerated()), id: \.offset) { _, t in
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").foregroundStyle(.secondary).accessibilityHidden(true)
            Text(InlineMarkdown.attributed(t)).fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    case .numbered(let items):
      VStack(alignment: .leading, spacing: 6) {
        ForEach(Array(items.enumerated()), id: \.offset) { i, t in
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(i + 1).").monospacedDigit().foregroundStyle(.secondary)
            Text(InlineMarkdown.attributed(t)).fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    case .callout(let tone, let text):
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: tone.symbolName).foregroundStyle(tone.color).accessibilityHidden(true)
        Text(InlineMarkdown.attributed(text)).fixedSize(horizontal: false, vertical: true)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(tone.color.opacity(0.12), in: .rect(cornerRadius: 12))
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(tone.label): \(String(InlineMarkdown.attributed(text).characters))")
    case .code(let language, let lines):
      CodeView(
        source: lines.joined(separator: "\n"), language: language, fontSize: codeFontSize,
        showLineNumbers: false
      )
      .padding(10)
      .background(.background.secondary, in: .rect(cornerRadius: 12))
    }
  }
}

#Preview("Blocks") {
  ScrollView {
    BlocksView(blocks: [
      .lead("Swap an **algorithm** at runtime."),
      .heading("When to use"),
      .bullets(["Many `if/else` branches", "Policies that vary"]),
      .numbered(["Define the interface", "Inject it"]),
      .callout(tone: .warning, text: "Don't over-apply. See [Template Method](kata:template-method)."),
      .callout(tone: .positive, text: "Easy to test."),
      .code(language: "java", lines: ["var p = new PercentOff(10);", "p.apply(m);"]),
    ])
    .padding()
  }
}
