import Foundation
import KataCore
import KataSRS
import Observation

/// State machine of one practice session. Wraps KataCore's `ReviewSessionEngine`; every rating is
/// persisted immediately through the `ProgressStore`, so closing early loses nothing.
@MainActor @Observable
public final class PracticeSessionModel {
  /// What a session is made of.
  public enum Kind: Sendable {
    /// Due reviews (plus new exercises of studied items), built by `PracticeQueueBuilder`.
    case review
    /// First-exposure / extra practice: every exercise of one item.
    case item(ItemKey)
  }

  public struct Feedback {
    public let response: ExerciseResponse
    public let grade: GradeResult
  }

  public enum Phase {
    case answering
    case feedback(Feedback)
    case finished
  }

  public struct Summary {
    public var total = 0
    public var correct = 0
    public var counts: [Rating: Int] = [:]
    public var streak = 0
    public var firstStudy = false
    public var itemTitle: String?
  }

  private let model: StudyModel
  public let kind: Kind
  /// Called after the session finishes or the learner leaves (the iOS app reschedules reminders).
  private let onEnd: @MainActor () async -> Void
  public private(set) var engine: ReviewSessionEngine
  public private(set) var phase: Phase = .answering
  public private(set) var summary = Summary()
  /// Bumped for every new step so exercise views reset their local state.
  public private(set) var step = 0
  private var shownAt = Date()
  private let scheduler: FSRSScheduler

  public init(
    kind: Kind, model: StudyModel, onEnd: @escaping @MainActor () async -> Void = {}
  ) {
    self.kind = kind
    self.model = model
    self.onEnd = onEnd
    self.scheduler = model.settings.scheduler
    let now = Date()
    let keys: [ExerciseKey]
    switch kind {
    case .review:
      keys = model.reviewQueue(now: now)
    case .item(let item):
      keys = model.library.pack(item.topic)?.exerciseKeys(for: item.item) ?? []
    }
    let entries = keys.map { key in
      ReviewEntry(key: key, card: model.store.card(key) ?? .new(now: now))
    }
    engine = ReviewSessionEngine(entries: entries, scheduler: scheduler)
    if engine.isFinished { phase = .finished }
  }

  // MARK: Current exercise

  public var isEmpty: Bool { engine.total == 0 }

  public var currentKey: ExerciseKey? { engine.current?.key }

  public var currentExercise: Exercise? { currentKey.flatMap { model.library.exercise($0) } }

  /// 1-based position for "3 of 12", clamped because requeued exercises extend the run.
  public var displayPosition: Int { min(engine.position + 1, max(engine.total, 1)) }

  public var progressFraction: Double {
    engine.total == 0 ? 1 : min(1, Double(engine.position) / Double(engine.total))
  }

  public var reps: Int { engine.current?.card.reps ?? 0 }

  public var previews: [Rating: SchedulingResult] {
    guard let card = engine.current?.card else { return [:] }
    return scheduler.preview(card, now: .now)
  }

  public func title(of ref: ItemID, topic: TopicID) -> String {
    model.library.meta(ItemKey(topic: topic, item: ref))?.title ?? ref
  }

  // MARK: Answering

  /// Grades a response; the view then shows the feedback panel.
  public func submit(_ response: ExerciseResponse) {
    guard case .answering = phase, let exercise = currentExercise else { return }
    phase = .feedback(Feedback(response: response, grade: ExerciseGrader.grade(exercise, response: response)))
  }

  /// Rates after feedback (Continue / Hard / Easy).
  public func commit(_ rating: Rating) {
    guard case .feedback(let fb) = phase else { return }
    persist(rating, grade: fb.grade)
  }

  /// Recall is self-rated: the learner ticks key points and picks any of the four ratings.
  public func rateRecall(_ rating: Rating, checked: Set<Int>) {
    guard case .answering = phase, let exercise = currentExercise else { return }
    persist(rating, grade: ExerciseGrader.grade(exercise, response: .recall(checked: checked)))
  }

  private func persist(_ rating: Rating, grade: GradeResult) {
    guard let key = currentKey else { return }
    let now = Date()
    let millis = Int(now.timeIntervalSince(shownAt) * 1000)
    model.store.record(
      rating, key: key, scheduler: scheduler, correct: grade.correct, responseMillis: millis, now: now)
    engine.rate(rating, now: now)
    summary.total += 1
    if grade.correct { summary.correct += 1 }
    summary.counts[rating, default: 0] += 1
    if engine.isFinished {
      finish(now: now)
    } else {
      phase = .answering
      step += 1
      shownAt = Date()
    }
  }

  private func finish(now: Date) {
    if case .item(let item) = kind {
      summary.firstStudy = model.store.markStudied(item, now: now)
      summary.itemTitle = model.library.meta(item)?.title
    }
    summary.streak = model.store.currentStreak(now: now)
    phase = .finished
    Task { [onEnd] in await onEnd() }
  }

  /// Called when the learner leaves early; nothing to undo since ratings are already saved.
  public func leave() {
    Task { [onEnd] in await onEnd() }
  }
}
