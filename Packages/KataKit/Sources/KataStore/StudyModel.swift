import Foundation
import KataCore
import KataSRS
import Observation

/// Derived learning state shared by the iOS and Mac apps: mastery, the review queue and due counts,
/// computed from store snapshots and the content library.
@MainActor @Observable
public final class StudyModel {
  public let library: ContentLibrary
  public let store: ProgressStore
  public let settings: AppSettings
  /// Items that have a body in some pack. Registry-only items are "coming soon".
  public let contentKeys: Set<ItemKey>
  /// Items that have a coding kata (Mac only; empty on iOS).
  public let kataKeys: Set<ItemKey>

  public init(
    library: ContentLibrary, store: ProgressStore, settings: AppSettings,
    kataKeys: Set<ItemKey> = []
  ) {
    self.library = library
    self.store = store
    self.settings = settings
    self.contentKeys = Set(library.allItemKeys())
    self.kataKeys = kataKeys
  }

  /// Mastery of every item that has a body, computed from stored cards. Items with a kata count
  /// the kata card and one extra exercise.
  public func masteryMap() -> [ItemKey: ItemMastery] {
    var byItem: [ItemKey: [FSRSCard]] = [:]
    for r in store.allCardRecords() {
      let isKata = r.key.exercise == "kata" && kataKeys.contains(r.key.item)
      if isKata || library.exercise(r.key) != nil {
        byItem[r.key.item, default: []].append(r.card)
      }
    }
    var out: [ItemKey: ItemMastery] = [:]
    for key in contentKeys {
      var total = library.pack(key.topic)?.exerciseCount(for: key.item) ?? 0
      if kataKeys.contains(key) { total += 1 }
      out[key] = MasteryCalculator.compute(cards: byItem[key] ?? [], totalExercises: total)
    }
    return out
  }

  /// Cards whose exercise still exists in the library (kata cards are excluded).
  private func liveSnapshots() -> [PracticeCardSnapshot] {
    store.allCardRecords().filter { library.exercise($0.key) != nil }
      .map { PracticeCardSnapshot(key: $0.key, due: $0.card.due, lastReview: $0.card.lastReview) }
  }

  /// Exercises of studied items that have no card yet (e.g. added by a content update).
  private func newCandidates() -> [ExerciseKey] {
    let enrolled = Set(store.allCardRecords().map(\.key))
    let progress = store.allProgress()
    return contentKeys.sorted().filter { progress[$0]?.studiedAt != nil }.flatMap { key in
      (library.pack(key.topic)?.exerciseKeys(for: key.item) ?? []).filter { !enrolled.contains($0) }
    }
  }

  /// The review queue as of `now`: due cards plus new exercises of studied items.
  public func reviewQueue(now: Date = .now) -> [ExerciseKey] {
    let builder = PracticeQueueBuilder(
      newLimit: settings.newExercisesPerDay, reviewLimit: settings.dailyReviewLimit)
    let day = DayKey(now, calendar: DayKey.gregorian()).string
    return builder.build(
      snapshots: liveSnapshots(), newCandidates: newCandidates(), now: now,
      seed: SeededRandom.hash("review@\(day)"))
  }

  /// Number of reviews that will be due by the end of the given day (for reminders).
  public func dueCount(onDayOf date: Date) -> Int {
    let cal = Calendar.current
    let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: date)) ?? date
    return liveSnapshots().filter { $0.due < end }.count
  }

  public func nextDueDate() -> Date? { liveSnapshots().map(\.due).min() }
}
