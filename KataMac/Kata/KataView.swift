import KataCore
import KataEditor
import KataRun
import KataSRS
import KataStore
import KataUI
import SwiftUI

struct KataSessionKey: FocusedValueKey {
  typealias Value = KataSessionModel
}

extension FocusedValues {
  var kataSession: KataSessionModel? {
    get { self[KataSessionKey.self] }
    set { self[KataSessionKey.self] = newValue }
  }
}

/// The kata screen: task, editor and results side by side (MAC_PLAN §5.3). Below 1200 pt the
/// results move under the editor.
struct KataView: View {
  @Bindable var session: KataSessionModel
  @Environment(MacAppModel.self) private var model

  var body: some View {
    GeometryReader { geometry in
      Group {
        if geometry.size.width >= 1200 {
          HSplitView {
            KataTaskPane(session: session).frame(minWidth: 260, idealWidth: 320, maxWidth: 420)
            KataEditorPane(session: session).frame(minWidth: 380, maxWidth: .infinity)
            KataResultsPane(session: session).frame(minWidth: 300, idealWidth: 360, maxWidth: 440)
          }
        } else {
          HSplitView {
            KataTaskPane(session: session).frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
            VSplitView {
              KataEditorPane(session: session).frame(minHeight: 220, maxHeight: .infinity)
              KataResultsPane(session: session).frame(minHeight: 160, idealHeight: 260, maxHeight: 420)
            }
            .frame(minWidth: 380)
          }
        }
      }
    }
    .focusedSceneValue(\.kataSession, session)
    .confirmationDialog(confirmTitle, isPresented: confirmBinding, titleVisibility: .visible) {
      confirmActions
    } message: {
      Text(confirmMessage)
    }
    .alert(
      "Could not use the IDE", isPresented: Binding(get: { session.ideError != nil }, set: { if !$0 { session.ideError = nil } }),
      actions: { Button("OK", role: .cancel) {} }, message: { Text(session.ideError ?? "") }
    )
    .task { if !model.toolchain.didSearch { await model.toolchain.refresh() } }
    .onDisappear { session.flushDraft() }
    #if DEBUG
    .task { await DebugLaunch.driveKata(session) }
    #endif
  }

  // MARK: Confirmations

  private var confirmBinding: Binding<Bool> {
    Binding(get: { session.confirmation != nil }, set: { if !$0 { session.confirmation = nil } })
  }

  private var confirmTitle: String {
    switch session.confirmation {
    case .hint: "Show hint \(session.hintsShown + 1) of \(session.kata.hints.count)?"
    case .reveal: "Reveal the solution?"
    case .copySolution: "Replace your code with the solution?"
    case .reset: "Reset to the starter?"
    case nil: ""
    }
  }

  private var confirmMessage: String {
    switch session.confirmation {
    case .hint: "Each hint lowers the suggested rating."
    case .reveal: "You will see the reference solution. This counts as giving up: the suggested rating becomes Again."
    case .copySolution: "Your files are overwritten with the reference solution."
    case .reset: "Your code in every file goes back to the starter. Hints already shown stay shown."
    case nil: ""
    }
  }

  @ViewBuilder
  private var confirmActions: some View {
    switch session.confirmation {
    case .hint: Button("Show hint") { session.revealNextHint() }
    case .reveal: Button("Reveal solution", role: .destructive) { session.revealSolution() }
    case .copySolution: Button("Copy into editor", role: .destructive) { session.copySolutionIntoEditor() }
    case .reset: Button("Reset to starter", role: .destructive) { session.resetToStarter() }
    case nil: EmptyView()
    }
    Button("Cancel", role: .cancel) {}
  }
}

// MARK: - Task pane

private struct KataTaskPane: View {
  @Bindable var session: KataSessionModel
  @Environment(AppSettings.self) private var settings

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        header
        BlocksView(blocks: session.kata.task, codeFontSize: max(11, settings.codeFontPoints - 2))
        if session.hintsShown > 0 { hints }
        actions
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
    }
    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text(session.kata.kind.rawValue.capitalized)
          .font(.caption2.weight(.semibold)).foregroundStyle(.tint)
          .padding(.horizontal, 8).padding(.vertical, 3)
          .background(.tint.opacity(0.14), in: .capsule)
        Text("about \(session.kata.minutes) min").font(.caption).foregroundStyle(.secondary)
        if session.isReview {
          Label("Review", systemImage: "arrow.triangle.2.circlepath")
            .font(.caption).foregroundStyle(.orange)
            .help("This kata is due. You start from the starter; your previous solution stays hidden until you pass.")
        }
      }
      Text(session.kata.title).font(.title3.weight(.semibold))
    }
  }

  private var hints: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionCaption("Hints")
      ForEach(0..<session.hintsShown, id: \.self) { i in
        VStack(alignment: .leading, spacing: 6) {
          Text("Hint \(i + 1)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
          BlocksView(blocks: session.kata.hints[i], codeFontSize: 11)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.10), in: .rect(cornerRadius: 10))
      }
    }
  }

  private var actions: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionCaption("Stuck?")
      Button {
        session.requestHint()
      } label: {
        Label(
          session.hintsRemaining == 0 ? "No more hints" : "Show hint (\(session.hintsShown) of \(session.kata.hints.count) shown)",
          systemImage: "lightbulb")
      }
      .disabled(session.hintsRemaining == 0)
      .help("Show next hint (⇧⌘H)")
      Button {
        session.requestReveal()
      } label: {
        Label("Reveal solution", systemImage: "eye")
      }
      .help("Reveal solution (⌥⌘S)")
      Button {
        session.confirmation = .reset
      } label: {
        Label("Reset to starter", systemImage: "arrow.counterclockwise")
      }
      .help("Reset to starter (⇧⌘⌫)")
    }
    .buttonStyle(.bordered)
    .controlSize(.regular)
  }
}
