import Foundation
import KataCore
import KataSRS
import SwiftData
import Testing

@testable import KataStore

@MainActor
struct ProgressStoreTests {
  let scheduler = FSRSScheduler()
  let strategy = ItemKey(topic: "design-patterns", item: "strategy")

  func makeStore() -> ProgressStore { ProgressStore(container: try! PersistenceFactory.makeContainer(inMemory: true)) }

  func key(_ id: String) -> ExerciseKey { ExerciseKey(item: strategy, exercise: id) }

  func daysAgo(_ n: Int, hour: Int = 12) -> Date {
    let cal = Calendar.current
    let d = cal.date(byAdding: .day, value: -n, to: cal.startOfDay(for: .now))!
    return cal.date(bySettingHour: hour, minute: 0, second: 0, of: d)!
  }

  @Test func recordCreatesAndUpdatesCard() throws {
    let store = makeStore()
    let k = key("spot-1")
    #expect(store.card(k) == nil)
    let now = Date.now
    let r1 = store.record(.good, key: k, scheduler: scheduler, correct: true, now: now)
    let saved = try #require(store.card(k))
    #expect(saved == r1.card)
    #expect(saved.reps == 1)
    let r2 = store.record(.again, key: k, scheduler: scheduler, correct: false, now: now.addingTimeInterval(60))
    #expect(store.card(k) == r2.card)
    #expect(store.card(k)?.reps == 2)
    #expect(store.allCardRecords().count == 1)
    #expect(store.logCount() == 2)
    #expect(store.todayActivity(now: now).reviews == 2)
  }

  @Test func dueQueries() {
    let store = makeStore()
    let now = Date.now
    store.record(.again, key: key("a"), scheduler: scheduler, now: now)  // due in 10 minutes
    store.record(.good, key: key("b"), scheduler: scheduler, now: now)  // due in days
    #expect(store.dueCount(asOf: now) == 0)
    #expect(store.dueCount(asOf: now.addingTimeInterval(3600)) == 1)
    #expect(store.dueRecords(asOf: now.addingTimeInterval(86_400 * 30)).count == 2)
    #expect(store.dueRecords(asOf: now.addingTimeInterval(86_400 * 30), limit: 1).count == 1)
    #expect(store.dueRecords(asOf: now.addingTimeInterval(86_400 * 30)).first?.key == key("a"))
    let next = store.nextDueDate()
    #expect(next != nil && next! > now)
    #expect(store.cardRecords(forItem: strategy).count == 2)
    #expect(store.cardRecords(forItem: ItemKey(topic: "design-patterns", item: "state")).isEmpty)
  }

  @Test func studiedBookmarkAndNote() {
    let store = makeStore()
    #expect(store.progress(for: strategy) == nil)
    store.markOpened(strategy, role: "definition")
    store.markOpened(strategy, role: "definition")
    store.markOpened(strategy, role: "structure")
    let p = store.progress(for: strategy)
    #expect(p?.seenRoles == ["definition", "structure"])
    #expect(p?.studiedAt == nil)

    #expect(store.markStudied(strategy) == true)
    #expect(store.markStudied(strategy) == false)
    #expect(store.progress(for: strategy)?.studiedAt != nil)
    #expect(store.todayActivity().studied == 1)
    #expect(store.recentlyStudied(limit: 5).map(\.key) == [strategy])

    store.setBookmarked(strategy, true)
    #expect(store.isBookmarked(strategy))
    #expect(store.bookmarks().map(\.key) == [strategy])
    store.setBookmarked(strategy, false)
    #expect(store.bookmarks().isEmpty)

    store.setNote(strategy, String(repeating: "x", count: 300))
    #expect(store.progress(for: strategy)?.note.count == ItemProgressRecord.maxNoteLength)
    store.setNote(strategy, "  short  ")
    #expect(store.progress(for: strategy)?.note == "short")
  }

  @Test func streakCountsConsecutiveDays() {
    let store = makeStore()
    for ago in [3, 2, 1] {
      store.record(.good, key: key("s\(ago)"), scheduler: scheduler, now: daysAgo(ago))
    }
    // Today has no activity yet: the streak counts back from yesterday.
    #expect(store.currentStreak() == 3)
    store.record(.good, key: key("today"), scheduler: scheduler, now: .now)
    #expect(store.currentStreak() == 4)
    #expect(store.hasActivity(on: .now))
    #expect(store.activeDays().count == 4)
  }

  @Test func streakBreaksOnGap() {
    let store = makeStore()
    store.record(.good, key: key("a"), scheduler: scheduler, now: daysAgo(5))
    store.record(.good, key: key("b"), scheduler: scheduler, now: daysAgo(1))
    #expect(store.currentStreak() == 1)
  }

  @Test func resetAllClearsEverything() {
    let store = makeStore()
    store.record(.good, key: key("a"), scheduler: scheduler)
    store.markStudied(strategy)
    store.setBookmarked(strategy, true)
    store.resetAllProgress()
    #expect(store.allCardRecords().isEmpty)
    #expect(store.allProgress().isEmpty)
    #expect(store.activeDays().isEmpty)
    #expect(store.logCount() == 0)
    #expect(store.currentStreak() == 0)
  }

  @Test func repositoryConformanceRoundTrips() async throws {
    let store = makeStore()
    let repo: any ProgressRepository = store
    let k = key("order-1")
    let card = FSRSCard(stability: 3, difficulty: 5, due: .now, lastReview: .now, reps: 2, lapses: 1, state: .review)
    try await repo.upsertCard(CardRecord(key: k, card: card, createdAt: .now))
    let loaded = try #require(try await repo.card(for: k))
    #expect(loaded.card.stability == 3 && loaded.card.reps == 2 && loaded.card.state == .review)
    #expect(try await repo.allCards().count == 1)
    try await repo.addActivity(day: DayKey(.now, calendar: DayKey.gregorian()), reviews: 2, studied: 1)
    #expect(try await repo.allActivity().first?.reviewCount == 2)
    try await repo.resetAll()
    #expect(try await repo.allCards().isEmpty)
  }
}
