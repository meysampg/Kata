import KataCore
import KataSRS
import KataStore
import KataUI
import SwiftUI

/// Free recall: think, reveal, tick the key points you had, then self-rate.
struct RecallExerciseView: View {
  let exercise: Exercise
  let session: PracticeSessionModel
  @State private var revealed = false
  @State private var checked: Set<Int> = []

  var body: some View {
    if case .recall(let model, let points) = exercise.body {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          ExercisePrompt(text: exercise.prompt)
          if !revealed {
            Text("Answer in your head or out loud, then reveal the model answer.")
              .font(.subheadline).foregroundStyle(.secondary)
          } else {
            VStack(alignment: .leading, spacing: 8) {
              SectionCaption("Model answer")
              BlocksView(blocks: model).cardSurface()
            }
            VStack(alignment: .leading, spacing: 8) {
              SectionCaption("Tick what you covered")
              VStack(spacing: 0) {
                ForEach(Array(points.enumerated()), id: \.offset) { i, point in
                  Button {
                    if checked.contains(i) { checked.remove(i) } else { checked.insert(i) }
                  } label: {
                    HStack(alignment: .top, spacing: 12) {
                      Image(systemName: checked.contains(i) ? "checkmark.square.fill" : "square")
                        .foregroundStyle(checked.contains(i) ? Color.accentColor : .secondary)
                      Text(InlineMarkdown.attributed(point))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 10)
                    .contentShape(.rect)
                  }
                  .buttonStyle(.plain)
                  .accessibilityAddTraits(checked.contains(i) ? .isSelected : [])
                  if i < points.count - 1 { Divider() }
                }
              }
              .padding(.horizontal, Theme.cardPadding)
              .background(.background.secondary, in: .rect(cornerRadius: Theme.cardRadius))
            }
          }
        }
        .padding(.horizontal, Theme.pageMargin)
        .padding(.vertical, 12)
      }
      .safeAreaInset(edge: .bottom) {
        Group {
          if !revealed {
            Button {
              withAnimation(.smooth) { revealed = true }
            } label: {
              Text("Reveal answer").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
          } else {
            RatingBar(
              previews: session.previews, now: .now,
              suggested: ExerciseGrader.grade(exercise, response: .recall(checked: checked)).suggestedRating
            ) { rating in
              session.rateRecall(rating, checked: checked)
            }
          }
        }
        .padding(.horizontal, Theme.pageMargin)
        .padding(.bottom, 8)
      }
    }
  }
}
