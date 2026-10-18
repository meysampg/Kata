import KataCore
import KataUI
import SwiftUI

struct TapLineExerciseView: View {
  let exercise: Exercise
  let session: PracticeSessionModel
  let feedback: PracticeSessionModel.Feedback?
  @Environment(AppSettings.self) private var settings
  @State private var selected: Int?

  var body: some View {
    if case .tapLine(let lines, let flaw, _) = exercise.body {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          ExercisePrompt(text: exercise.prompt)
          CodeView(
            source: lines.joined(separator: "\n"), fontSize: settings.codeFontPoints,
            showLineNumbers: true,
            onTapLine: { n in if feedback == nil { selected = n } },
            lineDecorations: decorations(flaw: flaw)
          )
          .padding(12)
          .background(.background.secondary, in: .rect(cornerRadius: Theme.cardRadius))
          if feedback == nil {
            Text("Tap the line, then check.").font(.footnote).foregroundStyle(.secondary)
          }
        }
        .padding(.horizontal, Theme.pageMargin)
        .padding(.vertical, 12)
      }
      .safeAreaInset(edge: .bottom) {
        if feedback == nil {
          Button {
            if let selected { session.submit(.line(selected)) }
          } label: {
            Text("Check").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(.glassProminent)
          .disabled(selected == nil)
          .padding(.horizontal, Theme.pageMargin)
          .padding(.bottom, 8)
        }
      }
    }
  }

  private func decorations(flaw: [Int]) -> [Int: LineDecoration] {
    var out: [Int: LineDecoration] = [:]
    if feedback == nil {
      if let s = selected {
        out[s] = LineDecoration(fill: Color.accentColor.opacity(0.14), outline: .accentColor)
      }
      return out
    }
    for n in flaw {
      out[n] = LineDecoration(
        fill: Color.red.opacity(0.16), symbolName: "exclamationmark.triangle.fill", symbolColor: .red)
    }
    if let s = selected {
      if flaw.contains(s) {
        out[s] = LineDecoration(
          fill: Color.green.opacity(0.18), outline: .green, symbolName: "checkmark.circle.fill",
          symbolColor: .green)
      } else {
        out[s] = LineDecoration(outline: .red, symbolName: "xmark.circle.fill", symbolColor: .red)
      }
    }
    return out
  }
}
