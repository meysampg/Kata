import KataCore
import KataSRS
import SwiftUI

/// The result shown after an answer: what was chosen and how it graded.
public struct ExerciseFeedback {
  public let response: ExerciseResponse
  public let grade: GradeResult

  public init(response: ExerciseResponse, grade: GradeResult) {
    self.response = response; self.grade = grade
  }
}

/// Everything an exercise view needs from its host: values plus closures, so the same views run in
/// the iOS and Mac apps without knowing about the study model.
public struct ExerciseContext {
  public var key: ExerciseKey
  /// Repetitions of the card (seeds the option shuffle).
  public var reps: Int
  public var previews: [Rating: SchedulingResult]
  public var feedback: ExerciseFeedback?
  public var codeFontSize: CGFloat
  /// Resolves an option's referenced item to its title.
  public var title: (ItemID) -> String
  public var submit: (ExerciseResponse) -> Void
  public var rateRecall: (Rating, Set<Int>) -> Void

  public init(
    key: ExerciseKey, reps: Int, previews: [Rating: SchedulingResult], feedback: ExerciseFeedback?,
    codeFontSize: CGFloat, title: @escaping (ItemID) -> String,
    submit: @escaping (ExerciseResponse) -> Void,
    rateRecall: @escaping (Rating, Set<Int>) -> Void
  ) {
    self.key = key; self.reps = reps; self.previews = previews; self.feedback = feedback
    self.codeFontSize = codeFontSize; self.title = title; self.submit = submit
    self.rateRecall = rateRecall
  }
}

/// Chooses the view for an exercise's kind.
public struct ExerciseView: View {
  let exercise: Exercise
  let context: ExerciseContext

  public init(exercise: Exercise, context: ExerciseContext) {
    self.exercise = exercise; self.context = context
  }

  public var body: some View {
    switch exercise.body {
    case .identify: IdentifyExerciseView(exercise: exercise, context: context)
    case .choose: ChooseExerciseView(exercise: exercise, context: context)
    case .tapLine: TapLineExerciseView(exercise: exercise, context: context)
    case .reorder: ReorderExerciseView(exercise: exercise, context: context)
    case .recall: RecallExerciseView(exercise: exercise, context: context)
    }
  }
}

/// Prompt text above an exercise.
struct ExercisePrompt: View {
  let text: String
  var body: some View {
    Text(InlineMarkdown.attributed(text))
      .font(.title3.weight(.semibold))
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// A code snippet shown in a card (read-only, horizontally scrollable inside).
struct ExerciseCode: View {
  let lines: [String]
  let fontSize: CGFloat

  var body: some View {
    CodeView(
      source: lines.joined(separator: "\n"), fontSize: fontSize,
      showLineNumbers: false)
      .padding(12)
      .background(.background.secondary, in: .rect(cornerRadius: Theme.cardRadius))
  }
}

/// Shuffled option buttons shared by Identify and Choose.
struct OptionListView: View {
  let options: [ExerciseOption]
  let order: [Int]
  let context: ExerciseContext
  let onPick: (Int) -> Void

  private var feedback: ExerciseFeedback? { context.feedback }

  private var chosen: Int? {
    if case .option(let i)? = feedback?.response { return i }
    return nil
  }

  private func text(_ option: ExerciseOption) -> String {
    if let ref = option.ref { return context.title(ref) }
    return option.text ?? ""
  }

  var body: some View {
    VStack(spacing: 10) {
      ForEach(order, id: \.self) { index in
        let option = options[index]
        let isChosen = chosen == index
        let reveal = feedback != nil
        let state: Color = reveal ? (option.correct ? .green : (isChosen ? .red : .clear)) : .clear
        Button { onPick(index) } label: {
          HStack(spacing: 10) {
            Text(InlineMarkdown.attributed(text(option)))
              .font(.body.weight(.medium))
              .multilineTextAlignment(.leading)
              .frame(maxWidth: .infinity, alignment: .leading)
            if reveal && (option.correct || isChosen) {
              Image(systemName: option.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(state)
            }
          }
          .padding(.horizontal, 16).padding(.vertical, 14)
          .frame(maxWidth: .infinity, minHeight: 52)
          .background(.background.secondary, in: .rect(cornerRadius: 16))
          .overlay {
            RoundedRectangle(cornerRadius: 16)
              .strokeBorder(state.opacity(reveal && state != .clear ? 0.9 : 0), lineWidth: 2)
          }
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(reveal)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
      }
    }
  }
}
