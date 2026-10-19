import KataCore
import SwiftUI

struct ReorderExerciseView: View {
  let exercise: Exercise
  let context: ExerciseContext
  /// Indices into the authored (correct-order) blocks, in the learner's current arrangement.
  @State private var order: [Int] = []

  private var feedback: ExerciseFeedback? { context.feedback }

  #if os(macOS)
  private static let dragHint = "Drag the rows to reorder."
  #else
  private static let dragHint = "Drag the handles to reorder."
  #endif

  var body: some View {
    if case .reorder(let blocks, _) = exercise.body {
      VStack(alignment: .leading, spacing: 8) {
        ExercisePrompt(text: exercise.prompt)
          .padding(.horizontal, Theme.pageMargin)
        Text(feedback == nil ? Self.dragHint : "Correct order is shown in green.")
          .font(.footnote).foregroundStyle(.secondary)
          .padding(.horizontal, Theme.pageMargin)
        List {
          ForEach(order, id: \.self) { index in
            let position = order.firstIndex(of: index) ?? 0
            let right = position == index
            HStack(spacing: 10) {
              HighlightedCodeText(
                source: blocks[index].joined(separator: "\n"), size: context.codeFontSize - 1)
              if feedback != nil {
                Image(systemName: right ? "checkmark.circle.fill" : "xmark.circle.fill")
                  .foregroundStyle(right ? .green : .red)
              }
            }
            .padding(.vertical, 4)
            .listRowBackground(
              (feedback == nil ? Color.clear : (right ? Color.green : Color.red).opacity(0.12))
            )
          }
          .onMove { from, to in order.move(fromOffsets: from, toOffset: to) }
          .moveDisabled(feedback != nil)
        }
        #if os(iOS)
        .environment(\.editMode, .constant(feedback == nil ? .active : .inactive))
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .scrollBounceBehavior(.basedOnSize)
      }
      .padding(.top, 12)
      .safeAreaInset(edge: .bottom) {
        if feedback == nil {
          Button {
            context.submit(.order(order))
          } label: {
            Text("Check").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(.glassProminent)
          .keyboardShortcut(.defaultAction)
          .padding(.horizontal, Theme.pageMargin)
          .padding(.bottom, 8)
        }
      }
      .onAppear {
        guard order.isEmpty else { return }
        var shuffled = ExerciseGrader.presentationOrder(count: blocks.count, key: context.key, reps: context.reps)
        if shuffled == Array(blocks.indices), shuffled.count > 1 { shuffled.append(shuffled.removeFirst()) }
        order = shuffled
      }
    }
  }
}
