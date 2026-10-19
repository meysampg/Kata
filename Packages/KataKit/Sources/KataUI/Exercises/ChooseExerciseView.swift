import KataCore
import SwiftUI

struct ChooseExerciseView: View {
  let exercise: Exercise
  let context: ExerciseContext

  var body: some View {
    if case .choose(let scenario, let options) = exercise.body {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text(InlineMarkdown.attributed(scenario))
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
            .cardSurface()
          ExercisePrompt(text: exercise.prompt)
          OptionListView(
            options: options,
            order: ExerciseGrader.presentationOrder(count: options.count, key: context.key, reps: context.reps),
            context: context
          ) { context.submit(.option($0)) }
        }
        .padding(.horizontal, Theme.pageMargin)
        .padding(.vertical, 12)
      }
    }
  }
}
