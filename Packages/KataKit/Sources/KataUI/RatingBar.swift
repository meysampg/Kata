import KataSRS
import SwiftUI

public extension Rating {
  var title: String {
    switch self {
    case .again: "Again"
    case .hard: "Hard"
    case .good: "Good"
    case .easy: "Easy"
    }
  }

  var tint: Color {
    switch self {
    case .again: .red
    case .hard: .orange
    case .good: .green
    case .easy: .blue
    }
  }
}

/// Again / Hard / Good / Easy with next-interval previews. Floating control: uses glass buttons.
public struct RatingBar: View {
  var previews: [Rating: SchedulingResult]?
  var now: Date
  var suggested: Rating?
  var onRate: (Rating) -> Void

  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var tapCount = 0
  @State private var last: Rating?

  public init(
    previews: [Rating: SchedulingResult]? = nil, now: Date = .now, suggested: Rating? = nil,
    onRate: @escaping (Rating) -> Void
  ) {
    self.previews = previews; self.now = now; self.suggested = suggested; self.onRate = onRate
  }

  public var body: some View {
    VStack(spacing: 8) {
      Text("How well did you remember?")
        .font(.footnote.weight(.medium)).foregroundStyle(.secondary)
      GlassEffectContainer(spacing: 8) {
        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                         count: typeSize.isAccessibilitySize ? 2 : 4),
          spacing: 8
        ) {
          ForEach(Rating.allCases, id: \.self) { rating in
            button(rating)
          }
        }
      }
    }
    .sensoryFeedback(trigger: tapCount) { _, _ in
      switch last {
      case .good, .easy: .success
      case .again: .warning
      case .hard: .impact(weight: .light)
      case nil: nil
      }
    }
  }

  @ViewBuilder
  private func button(_ rating: Rating) -> some View {
    let b = Button {
      last = rating; tapCount += 1
      onRate(rating)
    } label: {
      VStack(spacing: 2) {
        Text(rating.title).font(.callout.weight(.semibold))
        if let r = previews?[rating] {
          Text(IntervalFormatter.short(r, from: now)).font(.caption2)
        }
      }
      .lineLimit(1).minimumScaleFactor(0.7)
      .frame(maxWidth: .infinity, minHeight: 48)
    }
    .tint(rating.tint)
    .accessibilityLabel(label(rating))
    #if os(macOS)
    .keyboardShortcut(KeyEquivalent(Character("\((Rating.allCases.firstIndex(of: rating) ?? 0) + 1)")), modifiers: [])
    #endif
    if rating == suggested { b.buttonStyle(.glassProminent) } else { b.buttonStyle(.glass) }
  }

  private func label(_ rating: Rating) -> String {
    var t = rating.title
    if let r = previews?[rating] { t += ", next review in \(IntervalFormatter.short(r, from: now))" }
    return rating == suggested ? t + ", suggested" : t
  }
}

#Preview("RatingBar") {
  let s = FSRSScheduler()
  RatingBar(previews: s.preview(.new(now: .now), now: .now), suggested: .good) { _ in }
    .padding()
}
