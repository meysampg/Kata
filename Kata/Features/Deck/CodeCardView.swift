import KataCore
import KataUI
import SwiftUI

/// Code card: Read / Walkthrough (the mode switch lives in the deck's toolbar). The walkthrough
/// view owns its vertical scroll, so this view must not be wrapped in another ScrollView.
struct CodeCardView: View {
  let card: CodeCard
  @Binding var mode: CodeViewMode
  @Environment(AppSettings.self) private var settings

  var body: some View {
    CodeWalkthroughView(
      card: card, fontSize: settings.codeFontPoints, showLineNumbers: settings.showLineNumbers,
      mode: $mode,
      readFooter: card.expectedOutput.flatMap { $0.isEmpty ? nil : AnyView(outputSection($0)) })
  }

  private func outputSection(_ output: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("Output", systemImage: "terminal")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(output)
        .font(.system(size: settings.codeFontPoints, design: .monospaced))
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background.secondary, in: .rect(cornerRadius: Theme.cardRadius))
    .padding(12)
  }
}
