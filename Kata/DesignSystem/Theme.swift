import SwiftUI

/// Layout constants and small shared modifiers. Content surfaces are plain
/// `.background.secondary` cards: glass is reserved for the floating control layer.
enum Theme {
  static let pageMargin: CGFloat = 20
  static let cardRadius: CGFloat = 20
  static let cardPadding: CGFloat = 16
  static let rowSpacing: CGFloat = 12
}

extension View {
  /// A calm content card: secondary background, rounded, no glass.
  func cardSurface(padding: CGFloat = Theme.cardPadding) -> some View {
    self
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.background.secondary, in: .rect(cornerRadius: Theme.cardRadius))
  }
}

/// Small uppercase-free section caption used above cards.
struct SectionCaption: View {
  let text: String
  init(_ text: String) { self.text = text }

  var body: some View {
    Text(text)
      .font(.footnote.weight(.semibold))
      .foregroundStyle(.secondary)
      .textCase(nil)
      .accessibilityAddTraits(.isHeader)
  }
}

/// Shown for registry items that have no body yet.
struct ComingSoonBadge: View {
  var body: some View {
    Text("Coming soon")
      .font(.caption2.weight(.medium))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(.quaternary, in: .capsule)
  }
}

/// Difficulty as 1-3 filled dots.
struct DifficultyDots: View {
  let level: Int

  var body: some View {
    HStack(spacing: 3) {
      ForEach(1...3, id: \.self) { i in
        Circle()
          .fill(i <= level ? Color.secondary : Color.secondary.opacity(0.25))
          .frame(width: 5, height: 5)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Difficulty \(level) of 3")
  }
}
