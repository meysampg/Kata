import KataCore
import KataSRS
import KataStore
import KataUI
import SwiftUI

/// Full-screen practice session: top bar, one exercise at a time, feedback panel.
struct PracticeSessionView: View {
  let request: PracticeRequest
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
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
    .background(Color(.systemBackground))
    .task {
      if session == nil { session = PracticeSessionModel(
          kind: request.kind, model: model.study, onEnd: { [model] in await model.refreshReminders() }) }
    }
  }

  @ViewBuilder
  private func content(_ session: PracticeSessionModel) -> some View {
    switch session.phase {
    case .finished:
      VStack(spacing: 0) {
        if session.isEmpty {
          emptyState
        } else {
          PracticeSummaryView(summary: summaryValues(session.summary)) { close(session) }
        }
      }
    default:
      VStack(spacing: 0) {
        topBar(session)
        exercise(session)
          .id(session.step)
      }
      .safeAreaInset(edge: .bottom, spacing: 0) { feedbackPanel(session) }
      .sensoryFeedback(trigger: feedbackKind(session)) { _, new in
        switch new {
        case .right: .success
        case .wrong: .warning
        case .none: nil
        }
      }
    }
  }

  private func summaryValues(_ s: PracticeSessionModel.Summary) -> PracticeSummaryValues {
    PracticeSummaryValues(
      total: s.total, correct: s.correct, counts: s.counts, streak: s.streak,
      firstStudy: s.firstStudy, itemTitle: s.itemTitle)
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label("Nothing to practice", systemImage: "checkmark.circle")
    } description: {
      Text("No reviews are due right now.")
    } actions: {
      Button("Done") { dismiss() }.buttonStyle(.glassProminent)
    }
  }

  // MARK: Top bar

  private func topBar(_ session: PracticeSessionModel) -> some View {
    VStack(spacing: 10) {
      HStack {
        Button {
          if session.engine.position == 0 { close(session) } else { confirmClose = true }
        } label: {
          Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 40, height: 40)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
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
        Color.clear.frame(width: 40, height: 40)
      }
      ProgressView(value: session.progressFraction)
        .animation(.smooth, value: session.progressFraction)
    }
    .padding(.horizontal, Theme.pageMargin)
    .padding(.top, 8)
    .padding(.bottom, 4)
  }

  private func close(_ session: PracticeSessionModel) {
    session.leave()
    dismiss()
  }

  // MARK: Exercise

  private var feedbackOrNil: (PracticeSessionModel) -> PracticeSessionModel.Feedback? {
    { s in if case .feedback(let f) = s.phase { f } else { nil } }
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

  private enum FeedbackKind: Equatable { case none, right, wrong }

  private func feedbackKind(_ session: PracticeSessionModel) -> FeedbackKind {
    guard let f = feedbackOrNil(session) else { return .none }
    return f.grade.correct ? .right : .wrong
  }

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
      .transition(.move(edge: .bottom).combined(with: .opacity))
    }
  }
}
