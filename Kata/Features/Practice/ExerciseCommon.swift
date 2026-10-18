import KataCore
import KataUI
import SwiftUI

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
  @Environment(AppSettings.self) private var settings

  var body: some View {
    CodeView(
      source: lines.joined(separator: "\n"), fontSize: settings.codeFontPoints,
      showLineNumbers: false)
      .padding(12)
      .background(.background.secondary, in: .rect(cornerRadius: Theme.cardRadius))
  }
}

/// Shuffled option buttons shared by Identify and Choose.
struct OptionListView: View {
  let options: [ExerciseOption]
  let order: [Int]
  let topic: TopicID
  let session: PracticeSessionModel
  let feedback: PracticeSessionModel.Feedback?
  let onPick: (Int) -> Void

  private var chosen: Int? {
    if case .option(let i)? = feedback?.response { return i }
    return nil
  }

  private func text(_ option: ExerciseOption) -> String {
    if let ref = option.ref { return session.title(of: ref, topic: topic) }
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
