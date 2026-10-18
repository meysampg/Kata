import KataCore
import KataSRS
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
      if session == nil { session = PracticeSessionModel(request: request, model: model) }
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
          PracticeSummaryView(summary: session.summary) { close(session) }
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
      let fb = feedbackOrNil(session)
      switch ex.body {
      case .identify: IdentifyExerciseView(exercise: ex, key: key, session: session, feedback: fb)
      case .choose: ChooseExerciseView(exercise: ex, key: key, session: session, feedback: fb)
      case .tapLine: TapLineExerciseView(exercise: ex, session: session, feedback: fb)
      case .reorder: ReorderExerciseView(exercise: ex, key: key, session: session, feedback: fb)
      case .recall: RecallExerciseView(exercise: ex, session: session)
      }
    } else {
      ProgressView()
    }
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
        lines: Self.lines(for: ex, grade: fb.grade, topic: session.currentKey?.item.topic ?? "", session: session),
        suggested: fb.grade.suggestedRating, previews: session.previews, now: .now
      ) { rating in
        withAnimation(.smooth) { session.commit(rating) }
      }
      .transition(.move(edge: .bottom).combined(with: .opacity))
    }
  }

  static func lines(for exercise: Exercise, grade: GradeResult, topic: TopicID, session: PracticeSessionModel) -> [FeedbackLine] {
    let f = grade.feedback
    var out: [FeedbackLine] = []
    switch exercise.body {
    case .identify(_, let options), .choose(_, let options):
      let correctTitle = options.first(where: \.correct).map { o in
        o.ref.map { session.title(of: $0, topic: topic) } ?? o.text ?? ""
      }
      if grade.correct {
        if let why = f.correctWhy { out.append(FeedbackLine(text: why)) }
      } else {
        if let why = f.chosenWhy { out.append(FeedbackLine(label: "Your answer", text: why)) }
        if let why = f.correctWhy {
          out.append(FeedbackLine(label: "Correct answer: \(correctTitle ?? "")", text: why))
        }
      }
    case .tapLine, .reorder:
      if let e = f.explanation { out.append(FeedbackLine(text: e)) }
    case .recall:
      if !f.missedPoints.isEmpty {
        out.append(FeedbackLine(label: "Missed", text: f.missedPoints.joined(separator: "\n")))
      }
    }
    return out
  }
}
