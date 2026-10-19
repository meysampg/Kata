import KataCore
import KataStore
import SwiftUI

struct IdentifyExerciseView: View {
  let exercise: Exercise
  let key: ExerciseKey
  let session: PracticeSessionModel
  let feedback: PracticeSessionModel.Feedback?

  var body: some View {
    if case .identify(let lines, let options) = exercise.body {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          ExercisePrompt(text: exercise.prompt)
          ExerciseCode(lines: lines)
          OptionListView(
            options: options,
            order: ExerciseGrader.presentationOrder(count: options.count, key: key, reps: session.reps),
            topic: key.item.topic, session: session, feedback: feedback
          ) { session.submit(.option($0)) }
        }
        .padding(.horizontal, Theme.pageMargin)
        .padding(.vertical, 12)
      }
    }
  }
}
