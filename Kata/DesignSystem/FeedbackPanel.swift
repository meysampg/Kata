import KataSRS
import KataUI
import SwiftUI

/// One labelled paragraph of feedback ("You chose", "Why", ...).
struct FeedbackLine: Identifiable {
  let id = UUID()
  var label: String?
  var text: String
}

/// Floating panel under an exercise after it was answered. Wrong answers continue as Again;
/// right answers continue as the suggested rating, with optional Hard / Easy adjustments.
struct FeedbackPanel: View {
  let isCorrect: Bool
  let headline: String
  let lines: [FeedbackLine]
  let suggested: Rating
  let previews: [Rating: SchedulingResult]
  let now: Date
  let onRate: (Rating) -> Void

  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
          .foregroundStyle(isCorrect ? .green : .red)
          .accessibilityHidden(true)
        Text(headline).font(.headline)
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(lines) { line in
            VStack(alignment: .leading, spacing: 2) {
              if let label = line.label {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
              }
              Text(InlineMarkdown.attributed(line.text)).font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: typeSize.isAccessibilitySize ? 220 : 170)
      .scrollBounceBehavior(.basedOnSize)

      GlassEffectContainer(spacing: 8) {
        HStack(spacing: 8) {
          if isCorrect {
            adjust(.hard)
          }
          Button { onRate(suggested) } label: {
            VStack(spacing: 1) {
              Text("Continue").font(.body.weight(.semibold))
              if let p = previews[suggested] {
                Text(IntervalFormatter.short(p, from: now)).font(.caption2)
              }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(.glassProminent)
          .tint(isCorrect ? .green : .red)
          if isCorrect {
            adjust(.easy)
          }
        }
      }
    }
    .padding(16)
    .glassEffect(.regular, in: .rect(cornerRadius: 26))
    .padding(.horizontal, 12)
    .padding(.bottom, 8)
  }

  private func adjust(_ rating: Rating) -> some View {
    Button { onRate(rating) } label: {
      VStack(spacing: 1) {
        Text(rating.title).font(.callout)
        if let p = previews[rating] { Text(IntervalFormatter.short(p, from: now)).font(.caption2) }
      }
      .frame(minWidth: 64, minHeight: 44)
    }
    .buttonStyle(.glass)
    .tint(rating.tint)
  }
}
