import KataCore
import SwiftUI

struct ReorderExerciseView: View {
  let exercise: Exercise
  let context: ExerciseContext
  /// Indices into the authored (correct-order) blocks, in the learner's current arrangement.
  @State private var order: [Int] = []
  #if os(macOS)
  /// The block that ⌥↑ / ⌥↓ and the row arrows move.
  @State private var selected: Int?
  #endif

  private var feedback: ExerciseFeedback? { context.feedback }

  #if os(macOS)
  private static let dragHint = "Drag the rows, use the arrows, or select a row and press ⌥↑ / ⌥↓."
  #else
  private static let dragHint = "Drag the handles to reorder."
  #endif

  private var isCorrect: Bool { order == Array(order.indices) }

  private var hintText: String {
    guard feedback != nil else { return Self.dragHint }
    return isCorrect ? "Correct order." : "Your order is marked; the correct order follows."
  }

  var body: some View {
    if case .reorder(let blocks, _) = exercise.body {
      VStack(alignment: .leading, spacing: 8) {
        ExercisePrompt(text: exercise.prompt)
          .padding(.horizontal, Theme.pageMargin)
        Text(hintText)
          .font(.footnote).foregroundStyle(.secondary)
          .padding(.horizontal, Theme.pageMargin)
        list(blocks)
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
      #if os(macOS)
      .background { keyboardMoves }
      #endif
      .onAppear {
        guard order.isEmpty else { return }
        var shuffled = ExerciseGrader.presentationOrder(count: blocks.count, key: context.key, reps: context.reps)
        if shuffled == Array(blocks.indices), shuffled.count > 1 { shuffled.append(shuffled.removeFirst()) }
        order = shuffled
        #if DEBUG && os(macOS)
        // Screenshot hooks: `-KataReorder move` swaps the first two rows; `check` also submits.
        if let mode = UserDefaults.standard.string(forKey: "KataReorder") {
          order.swapAt(0, 1); selected = order[0]
          if mode == "check" { Task { @MainActor in context.submit(.order(order)) } }
        }
        #endif
      }
    }
  }

  @ViewBuilder
  private func list(_ blocks: [[String]]) -> some View {
    #if os(macOS)
    List(selection: listSelection) { rows(blocks) }
    #else
    List { rows(blocks) }
    #endif
  }

  @ViewBuilder
  private func rows(_ blocks: [[String]]) -> some View {
          Section {
          ForEach(order, id: \.self) { index in
            let position = order.firstIndex(of: index) ?? 0
            let right = position == index
            HStack(spacing: 10) {
              #if os(macOS)
              if feedback == nil {
                Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                  .accessibilityHidden(true)
              }
              #endif
              HighlightedCodeText(
                source: blocks[index].joined(separator: "\n"), size: context.codeFontSize - 1)
              #if os(macOS)
              if feedback == nil { moveButtons(index) }
              #endif
              if feedback != nil {
                Image(systemName: right ? "checkmark.circle.fill" : "xmark.circle.fill")
                  .foregroundStyle(right ? .green : .red)
              }
            }
            .padding(.vertical, 4)
            #if os(macOS)
            .tag(index)
            #endif
            .listRowBackground(
              (feedback == nil ? Color.clear : (right ? Color.green : Color.red).opacity(0.12))
            )
          }
          .onMove { from, to in order.move(fromOffsets: from, toOffset: to) }
          .moveDisabled(feedback != nil)
          } header: {
            if feedback != nil { Text("Your order") }
          }
          if feedback != nil, !isCorrect {
            Section("Correct order") {
              // Offset ids so these rows never share identity with the learner's rows above.
              ForEach(blocks.indices.map { $0 + 1000 }, id: \.self) { rowID in
                let position = rowID - 1000
                let block = blocks[position]
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                  Text("\(position + 1)")
                    .font(.footnote.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(.green)
                    .frame(width: 18, alignment: .trailing)
                  HighlightedCodeText(
                    source: block.joined(separator: "\n"), size: context.codeFontSize - 1)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.green.opacity(0.12))
              }
            }
          }
        
  }

  #if os(macOS)
  private var listSelection: Binding<Int?> {
    Binding(get: { feedback == nil ? selected : nil }, set: { selected = $0 })
  }

  private func move(_ block: Int, by delta: Int) {
    guard feedback == nil, let from = order.firstIndex(of: block) else { return }
    let to = from + delta
    guard order.indices.contains(to) else { return }
    withAnimation(.smooth(duration: 0.2)) { order.swapAt(from, to) }
    selected = block
  }

  private func moveButtons(_ block: Int) -> some View {
    let position = order.firstIndex(of: block) ?? 0
    return HStack(spacing: 2) {
      Button { move(block, by: -1) } label: { Image(systemName: "chevron.up") }
        .disabled(position == 0)
        .help("Move up")
        .accessibilityLabel("Move up")
      Button { move(block, by: 1) } label: { Image(systemName: "chevron.down") }
        .disabled(position == order.count - 1)
        .help("Move down")
        .accessibilityLabel("Move down")
    }
    .buttonStyle(.borderless)
    .foregroundStyle(.secondary)
  }

  /// ⌥↑ / ⌥↓ move the selected row.
  private var keyboardMoves: some View {
    HStack {
      Button("Move up") { if let selected { move(selected, by: -1) } }
        .keyboardShortcut(.upArrow, modifiers: .option)
      Button("Move down") { if let selected { move(selected, by: 1) } }
        .keyboardShortcut(.downArrow, modifiers: .option)
    }
    .opacity(0).allowsHitTesting(false).accessibilityHidden(true)
  }
  #endif
}
