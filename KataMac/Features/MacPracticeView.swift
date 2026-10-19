import KataCore
import KataSRS
import KataStore
import KataUI
import SwiftUI

/// A practice session in the detail pane: top bar, one exercise at a time, feedback panel.
///
/// Keys: Return checks an answer or continues, 1-4 rate (Again, Hard, Good, Easy) or pick the nth
/// option, Space reveals the recall answer, Esc leaves.
struct MacPracticeView: View {
  let request: PracticeRequest
  /// Inside an item's Practice tab (no overlay); the close action then returns to the cards.
  var embedded = false
  let onClose: () -> Void

  @Environment(MacAppModel.self) private var model
  @State private var session: PracticeSessionModel?
  @State private var confirmClose = false

  var body: some View {
    Group {
      if let session {
        content(session)
      } else {
        ProgressView()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.background)
    .task {
      if session == nil {
        session = PracticeSessionModel(kind: request.kind, model: model.study)
      }
    }
  }

  @ViewBuilder
  private func content(_ session: PracticeSessionModel) -> some View {
    switch session.phase {
    case .finished:
      if session.isEmpty {
        ContentUnavailableView {
          Label("Nothing to practice", systemImage: "checkmark.circle")
        } description: {
          Text("No reviews are due right now.")
        } actions: {
          Button("Done", action: onClose).buttonStyle(.glassProminent).keyboardShortcut(.defaultAction)
        }
      } else {
        PracticeSummaryView(summary: summaryValues(session.summary), onDone: onClose)
          .frame(maxWidth: MacLayout.readableWidth)
      }
    default:
      VStack(spacing: 0) {
        topBar(session)
        exercise(session)
          .id(session.step)
          .frame(maxWidth: MacLayout.readableWidth + 2 * MacLayout.pageMargin)
          .frame(maxWidth: .infinity)
      }
      .safeAreaInset(edge: .bottom, spacing: 0) { feedbackPanel(session) }
      .background { shortcuts(session) }
    }
  }

  private func summaryValues(_ s: PracticeSessionModel.Summary) -> PracticeSummaryValues {
    PracticeSummaryValues(
      total: s.total, correct: s.correct, counts: s.counts, streak: s.streak,
      firstStudy: s.firstStudy, itemTitle: s.itemTitle)
  }

  // MARK: Top bar

  private func topBar(_ session: PracticeSessionModel) -> some View {
    VStack(spacing: 10) {
      HStack {
        Button {
          if session.engine.position == 0 { close(session) } else { confirmClose = true }
        } label: {
          Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 32, height: 32)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .keyboardShortcut(.cancelAction)
        .help("End session (Esc)")
        .accessibilityLabel("Close")
        .confirmationDialog("End this session?", isPresented: $confirmClose, titleVisibility: .visible) {
          Button("End session", role: .destructive) { close(session) }
          Button("Keep going", role: .cancel) {}
        } message: {
          Text("Your answers so far are saved.")
        }
        Spacer()
        Text("\(session.displayPosition) of \(session.engine.total)")
          .font(.subheadline.weight(.medium)).monospacedDigit().foregroundStyle(.secondary)
        Spacer()
        Color.clear.frame(width: 32, height: 32)
      }
      ProgressView(value: session.progressFraction)
        .animation(.smooth, value: session.progressFraction)
    }
    .frame(maxWidth: MacLayout.readableWidth)
    .padding(.horizontal, MacLayout.pageMargin)
    .padding(.top, 12)
    .padding(.bottom, 4)
  }

  private func close(_ session: PracticeSessionModel) {
    session.leave()
    onClose()
  }

  // MARK: Exercise

  private func feedbackOrNil(_ s: PracticeSessionModel) -> PracticeSessionModel.Feedback? {
    if case .feedback(let f) = s.phase { f } else { nil }
  }

  @ViewBuilder
  private func exercise(_ session: PracticeSessionModel) -> some View {
    if let ex = session.currentExercise, let key = session.currentKey {
      ExerciseView(exercise: ex, context: context(session, key: key))
    } else {
      ProgressView()
    }
  }

  private func context(_ session: PracticeSessionModel, key: ExerciseKey) -> ExerciseContext {
    ExerciseContext(
      key: key, reps: session.reps, previews: session.previews,
      feedback: feedbackOrNil(session).map { ExerciseFeedback(response: $0.response, grade: $0.grade) },
      codeFontSize: model.settings.codeFontPoints,
      title: { session.title(of: $0, topic: key.item.topic) },
      submit: { session.submit($0) },
      rateRecall: { session.rateRecall($0, checked: $1) })
  }

  // MARK: Feedback

  @ViewBuilder
  private func feedbackPanel(_ session: PracticeSessionModel) -> some View {
    if let fb = feedbackOrNil(session), let ex = session.currentExercise {
      FeedbackPanel(
        isCorrect: fb.grade.correct, headline: fb.grade.correct ? "Correct" : "Not quite",
        lines: FeedbackLines.make(
          for: ex, grade: fb.grade,
          title: { session.title(of: $0, topic: session.currentKey?.item.topic ?? "") }),
        suggested: fb.grade.suggestedRating, previews: session.previews, now: .now
      ) { rating in
        withAnimation(.smooth) { session.commit(rating) }
      }
      .frame(maxWidth: MacLayout.readableWidth + 24)
      .frame(maxWidth: .infinity)
      .transition(.move(edge: .bottom).combined(with: .opacity))
    }
  }

  // MARK: Keyboard

  /// Invisible buttons that carry the digit shortcuts: 1-4 rate in the feedback phase, and pick
  /// the nth option while answering a multiple-choice exercise.
  @ViewBuilder
  private func shortcuts(_ session: PracticeSessionModel) -> some View {
    HStack {
      if let fb = feedbackOrNil(session) {
        ForEach(Array(Rating.allCases.enumerated()), id: \.offset) { i, rating in
          Button(rating.title) {
            // A wrong answer always continues as Again, like the Continue button.
            guard fb.grade.correct || rating == .again else { return }
            withAnimation(.smooth) { session.commit(rating) }
          }
          .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [])
        }
      } else if let ex = session.currentExercise, let key = session.currentKey,
        let options = Self.options(of: ex)
      {
        let order = ExerciseGrader.presentationOrder(count: options.count, key: key, reps: session.reps)
        ForEach(Array(order.prefix(9).enumerated()), id: \.offset) { i, optionIndex in
          Button("Option \(i + 1)") { session.submit(.option(optionIndex)) }
            .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [])
        }
      }
    }
    .opacity(0)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private static func options(of exercise: Exercise) -> [ExerciseOption]? {
    switch exercise.body {
    case .identify(_, let options), .choose(_, let options): options
    default: nil
    }
  }
}
