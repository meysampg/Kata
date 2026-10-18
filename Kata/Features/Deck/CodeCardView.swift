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
      mode: $mode)
  }
}
