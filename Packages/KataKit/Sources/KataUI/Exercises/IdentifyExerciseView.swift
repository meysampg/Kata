import KataCore
import SwiftUI

struct IdentifyExerciseView: View {
  let exercise: Exercise
  let context: ExerciseContext

  var body: some View {
    if case .identify(let lines, let options) = exercise.body {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          ExercisePrompt(text: exercise.prompt)
          ExerciseCode(lines: lines, fontSize: context.codeFontSize)
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
