import KataCore
import SwiftUI

public enum CodeViewMode: String, Sendable, CaseIterable, Identifiable {
  case read = "Read"
  case walkthrough = "Walkthrough"
  public var id: String { rawValue }
}

/// Segmented Read / Walkthrough switch, suitable for a toolbar or header.
public struct CodeModePicker: View {
  @Binding var mode: CodeViewMode
  public init(mode: Binding<CodeViewMode>) { _mode = mode }

  public var body: some View {
    Picker("Mode", selection: $mode) {
      ForEach(CodeViewMode.allCases) { Text($0.rawValue).tag($0) }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
  }
}

/// A code card: plain reading, or a guided walkthrough with a note panel pinned to the bottom.
public struct CodeWalkthroughView: View {
  let source: String
  let language: String
  let fontSize: CGFloat
  let showLineNumbers: Bool
  let externalMode: Binding<CodeViewMode>?
  let readFooter: AnyView?

  @State private var localMode: CodeViewMode = .read
  @State private var state: WalkthroughState

  public init(
    source: String, language: String = "java", steps: [WalkthroughState.Step],
    fontSize: CGFloat = 14, showLineNumbers: Bool = true, mode: Binding<CodeViewMode>? = nil,
    readFooter: AnyView? = nil
  ) {
    self.readFooter = readFooter
    self.source = source; self.language = language; self.fontSize = fontSize
    self.showLineNumbers = showLineNumbers; self.externalMode = mode
    _state = State(initialValue: WalkthroughState(steps: steps))
  }

  public init(
    card: CodeCard, fontSize: CGFloat = 14, showLineNumbers: Bool = true,
    mode: Binding<CodeViewMode>? = nil, readFooter: AnyView? = nil
  ) {
    self.init(
      source: card.source, language: card.language ?? "java",
      steps: WalkthroughState(card: card).steps, fontSize: fontSize,
      showLineNumbers: showLineNumbers, mode: mode, readFooter: readFooter)
  }

  private var mode: CodeViewMode { externalMode?.wrappedValue ?? localMode }
  private var walking: Bool { mode == .walkthrough && !state.isEmpty }

  public var body: some View {
    VStack(spacing: 8) {
      if externalMode == nil, !state.isEmpty {
        CodeModePicker(mode: $localMode).padding(.horizontal)
      }
      CodeView(
        source: source, language: language, fontSize: fontSize, showLineNumbers: showLineNumbers,
        highlightedLines: walking ? state.current?.lines : nil, dimOthers: walking,
        scrollsVertically: true, scrollToLine: walking ? state.current?.lines.lowerBound : nil,
        footer: walking ? nil : readFooter
      )
      #if DEBUG
      .onAppear {
        // Screenshot hook: `-KataWalk N` (demo mode) starts at step N.
        let n = UserDefaults.standard.integer(forKey: "KataWalk")
        if UserDefaults.standard.bool(forKey: "KataDemo"), n > 1 { state.go(to: n - 1) }
      }
      #endif
      .animation(.smooth, value: state.index)
      .animation(.smooth, value: walking)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if walking, let step = state.current {
          panel(step).transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
    }
  }

  private func panel(_ step: WalkthroughState.Step) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(InlineMarkdown.attributed(step.note))
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
      HStack {
        Button { state.previous() } label: { Image(systemName: "chevron.left") }
          .disabled(!state.canGoPrevious)
          .accessibilityLabel("Previous step")
          #if os(macOS)
          .keyboardShortcut(.upArrow, modifiers: [])
          #endif
        Spacer()
        Text(state.progressText).font(.footnote).foregroundStyle(.secondary).monospacedDigit()
        Spacer()
        Button { state.next() } label: { Image(systemName: "chevron.right") }
          .disabled(!state.canGoNext)
          .accessibilityLabel("Next step")
          #if os(macOS)
          .keyboardShortcut(.downArrow, modifiers: [])
          #endif
      }
      .buttonStyle(.glass)
    }
    .padding(14)
    .glassEffect(.regular, in: .rect(cornerRadius: 22))
    .padding(.horizontal, 12)
    .padding(.bottom, 8)
  }
}

#Preview("Walkthrough") {
  CodeWalkthroughView(
    source: "interface P {\n  int f(int x);\n}\n\nclass A implements P {\n  public int f(int x) { return x + 1; }\n}",
    steps: [
      .init(lines: 1...3, note: "The **strategy** interface."),
      .init(lines: 5...7, note: "A concrete strategy, `A`."),
    ])
}
