import KataSRS
import SwiftUI

/// The numbers shown at the end of a session.
public struct PracticeSummaryValues {
  public var total: Int
  public var correct: Int
  public var counts: [Rating: Int]
  public var streak: Int
  public var firstStudy: Bool
  public var itemTitle: String?

  public init(
    total: Int, correct: Int, counts: [Rating: Int], streak: Int, firstStudy: Bool,
    itemTitle: String?
  ) {
    self.total = total; self.correct = correct; self.counts = counts; self.streak = streak
    self.firstStudy = firstStudy; self.itemTitle = itemTitle
  }
}

public struct PracticeSummaryView: View {
  let summary: PracticeSummaryValues
  let onDone: () -> Void

  public init(summary: PracticeSummaryValues, onDone: @escaping () -> Void) {
    self.summary = summary; self.onDone = onDone
  }

  public var body: some View {
    VStack(spacing: 24) {
      Spacer()
      Image(systemName: "checkmark.circle")
        .font(.system(size: 56, weight: .light))
        .foregroundStyle(.green)
        .accessibilityHidden(true)
      VStack(spacing: 6) {
        Text(summary.firstStudy ? "Studied" : "Session complete").font(.title.weight(.semibold))
        if let title = summary.itemTitle {
          Text(title).font(.title3).foregroundStyle(.secondary)
        }
      }
      VStack(spacing: 10) {
        stat("Exercises", "\(summary.total)")
        if summary.total > 0 {
          stat("Answered right", "\(summary.correct) of \(summary.total)")
        }
        ForEach(Rating.allCases, id: \.self) { rating in
          if let n = summary.counts[rating], n > 0 {
            HStack {
              Circle().fill(rating.tint).frame(width: 8, height: 8)
              Text(rating.title)
              Spacer()
              Text("\(n)").monospacedDigit().foregroundStyle(.secondary)
            }
            .font(.subheadline)
          }
        }
        stat("Streak", summary.streak > 0 ? "\(summary.streak)-day" : "None yet")
      }
      .cardSurface()
      .frame(maxWidth: 420)
      Spacer()
      Button(action: onDone) {
        Text("Done").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
      }
      .buttonStyle(.glassProminent)
      .keyboardShortcut(.defaultAction)
      .frame(maxWidth: 420)
    }
    .padding(.horizontal, Theme.pageMargin)
    .padding(.bottom, 12)
  }

  private func stat(_ label: String, _ value: String) -> some View {
    HStack {
      Text(label).foregroundStyle(.secondary)
      Spacer()
      Text(value).font(.body.weight(.semibold)).monospacedDigit()
    }
    .font(.subheadline)
  }
}
