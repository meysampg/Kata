import KataCore
import KataUI
import SwiftUI

struct ChooseExerciseView: View {
  let exercise: Exercise
  let key: ExerciseKey
  let session: PracticeSessionModel
  let feedback: PracticeSessionModel.Feedback?

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
