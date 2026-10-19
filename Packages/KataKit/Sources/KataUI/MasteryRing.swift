import KataCore
import SwiftUI

/// Circular mastery indicator with four visual states.
public struct MasteryRing: View {
  let level: Mastery
  let fraction: Double
  var lineWidth: CGFloat

  public init(level: Mastery, fraction: Double = 0, lineWidth: CGFloat = 4) {
    self.level = level; self.fraction = fraction; self.lineWidth = lineWidth
  }

  private var clamped: Double { min(max(fraction, 0), 1) }

  private var tint: Color {
    switch level {
    case .notStarted: .secondary
    case .learning: .orange
    case .familiar: .teal
    case .mastered: .green
    }
  }

  private var title: String {
    switch level {
    case .notStarted: "Not started"
    case .learning: "Learning"
    case .familiar: "Familiar"
    case .mastered: "Mastered"
    }
  }

  public var body: some View {
    ZStack {
      switch level {
      case .notStarted:
        Circle().strokeBorder(Color.secondary.opacity(0.35),
                              style: StrokeStyle(lineWidth: lineWidth * 0.6, dash: [2, 3]))
      case .learning, .familiar:
        Circle().stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)
        Circle().trim(from: 0, to: max(clamped, 0.04))
          .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
          .rotationEffect(.degrees(-90))
          .animation(.smooth, value: clamped)
        if level == .familiar {
          Circle().fill(tint.opacity(0.15)).padding(lineWidth)
        }
      case .mastered:
        Circle().fill(tint)
        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
          .minimumScaleFactor(0.5)
      }
    }
    .frame(minWidth: 22, minHeight: 22)
    .aspectRatio(1, contentMode: .fit)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityValue(level == .learning || level == .familiar ? "\(Int((clamped * 100).rounded())) percent" : "")
  }
}

#Preview("MasteryRing") {
  HStack(spacing: 20) {
    MasteryRing(level: .notStarted).frame(width: 32)
    MasteryRing(level: .learning, fraction: 0.4).frame(width: 32)
    MasteryRing(level: .familiar, fraction: 0.8).frame(width: 32)
    MasteryRing(level: .mastered, fraction: 1).frame(width: 32)
  }.padding()
}
