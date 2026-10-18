import Foundation
import KataSRS
import Testing

@testable import KataCore

enum T {
  static var utc: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
  }
  static let t0 = Date(timeIntervalSince1970: 1_800_000_000)
  static func key(_ item: String, _ ex: String = "e1") -> ExerciseKey {
    ExerciseKey(topic: "t", item: item, exercise: ex)
  }
  static func card(_ s: CardState, stability: Double = 5, due: Date = t0) -> FSRSCard {
    FSRSCard(stability: stability, difficulty: 5, due: due, state: s)
  }
}

@Suite struct MasteryTests {
  @Test func weightsMatchAzBar() {
    let cards = [T.card(.learning, stability: 1), T.card(.relearning, stability: 1),
                 T.card(.review, stability: 5), T.card(.review, stability: 21), T.card(.review, stability: 40)]
    let m = MasteryCalculator.compute(cards: cards, totalExercises: 8)
    #expect(m.total == 8 && m.notStarted == 3 && m.learning == 2 && m.young == 1 && m.mature == 2)
    #expect(abs(m.fraction - (0.5 + 0.6 + 2.0) / 8) < 1e-9)
    #expect(MasteryCalculator.compute(cards: [], totalExercises: 0).fraction == 0)
  }

  @Test func levelBoundaries() {
    func level(_ cards: [FSRSCard], _ total: Int) -> Mastery {
      MasteryCalculator.compute(cards: cards, totalExercises: total).level
    }
    #expect(level([], 5) == .notStarted)
    #expect(level([T.card(.new)], 5) == .notStarted)
    #expect(level([T.card(.learning)], 5) == .learning)
    // all enrolled but one still young/learning
    #expect(level(Array(repeating: T.card(.review, stability: 30), count: 4), 5) == .learning)
    #expect(level(Array(repeating: T.card(.review, stability: 30), count: 4) + [T.card(.learning)], 5) == .learning)
    #expect(level(Array(repeating: T.card(.review, stability: 30), count: 4) + [T.card(.review, stability: 20.9)], 5) == .familiar)
    #expect(level(Array(repeating: T.card(.review, stability: 21), count: 5), 5) == .mastered)
    #expect(level([], 0) == .notStarted)
    #expect(Mastery.mastered > Mastery.familiar && Mastery.familiar > Mastery.learning)
  }
}

@Suite struct LearningPathTests {
  let path = LearningPath(topic: "t", sections: [
    PathSection(title: "A", items: ["a", "b"]), PathSection(title: "B", items: ["c", "d"]),
  ])

  @Test func nextSkipsStartedItems() {
    #expect(path.allItems == ["a", "b", "c", "d"])
    #expect(path.next(progress: [:]) == "a")
    #expect(path.next(progress: ["a": .learning, "b": .mastered]) == "c")
    #expect(path.next(after: "a", progress: ["b": .learning]) == "c")
  }

  @Test func nextWrapsAndEnds() {
    #expect(path.next(after: "d", progress: ["a": .mastered, "b": .learning, "c": .familiar]) == "d")
    #expect(path.next(after: "d", progress: ["b": .learning, "c": .familiar, "d": .learning]) == "a")
    let all: [ItemID: Mastery] = ["a": .learning, "b": .learning, "c": .learning, "d": .learning]
    #expect(path.next(progress: all) == nil)
    #expect(path.startedCount(progress: all) == (4, 4))
    #expect(path.section(containing: "c")?.title == "B")
    #expect(path.index(of: "d") == 3)
  }
}

@Suite struct PracticeQueueTests {
  let now = T.t0
  func builder(new: Int = 10, review: Int = 100) -> PracticeQueueBuilder {
    PracticeQueueBuilder(newLimit: new, reviewLimit: review, calendar: T.utc)
  }
  func snap(_ item: String, _ ex: String, dueOffset: TimeInterval = -3600, reviewedAgo: TimeInterval? = nil) -> PracticeCardSnapshot {
    PracticeCardSnapshot(key: T.key(item, ex), due: now.addingTimeInterval(dueOffset),
                         lastReview: reviewedAgo.map { now.addingTimeInterval(-$0) })
  }

  @Test func onlyDueCardsAreQueued() {
    let q = builder().build(snapshots: [snap("a", "1"), snap("b", "1", dueOffset: 3600)], newCandidates: [], now: now, seed: 1)
    #expect(q == [T.key("a", "1")])
  }

  @Test func reviewLimitKeepsMostOverdue() {
    let s = (0..<5).map { snap("i\($0)", "1", dueOffset: -Double($0 + 1) * 1000) }
    let q = builder(review: 2).build(snapshots: s, newCandidates: [], now: now, seed: 3)
    #expect(Set(q) == [T.key("i4", "1"), T.key("i3", "1")])
  }

  @Test func newLimitAndEnrolledFiltered() {
    let fresh = (0..<6).map { T.key("n\($0)") }
    let q = builder(new: 3).build(snapshots: [], newCandidates: fresh, now: now, seed: 1)
    #expect(q.count == 3)
    #expect(Set(q).isSubset(of: Set(fresh.prefix(3))))
    let enrolled = builder().build(snapshots: [snap("n0", "e1", dueOffset: 3600)], newCandidates: fresh, now: now, seed: 1)
    #expect(!enrolled.contains(T.key("n0")))
    let dup = builder().build(snapshots: [], newCandidates: [fresh[0], fresh[0]], now: now, seed: 1)
    #expect(dup.count == 1)
  }

  @Test func atMostOneReviewPerItem() {
    let s = [snap("a", "1", dueOffset: -300), snap("a", "2", dueOffset: -200), snap("a", "3", dueOffset: -100), snap("b", "1")]
    let q = builder().build(snapshots: s, newCandidates: [], now: now, seed: 9)
    #expect(q.filter { $0.item.item == "a" } == [T.key("a", "1")])
    #expect(q.contains(T.key("b", "1")))
  }

  @Test func siblingReviewedTodayBuriesTheItem() {
    let s = [snap("a", "1", reviewedAgo: 600), snap("a", "2", dueOffset: -100), snap("b", "1")]
    let q = builder().build(snapshots: s, newCandidates: [], now: now, seed: 9)
    // a#1 was reviewed today (and is due again): its sibling a#2 is buried; a#1 itself stays
    #expect(!q.contains(T.key("a", "2")))
    #expect(q.contains(T.key("b", "1")))
  }

  @Test func noAdjacentSiblings() {
    let fresh = (0..<4).flatMap { i in (0..<3).map { T.key("i\(i)", "e\($0)") } }
    for seed in 0..<20 {
      let q = builder(new: 12).build(snapshots: [], newCandidates: fresh, now: now, seed: UInt64(seed))
      #expect(q.count == 12)
      for (a, b) in zip(q, q.dropFirst()) { #expect(a.item != b.item, "seed \(seed): \(q)") }
    }
  }

  @Test func seededDeterminism() {
    let fresh = (0..<8).map { T.key("n\($0)") }
    let s = (0..<6).map { snap("r\($0)", "1", dueOffset: -Double($0 + 1)) }
    let a = builder().build(snapshots: s, newCandidates: fresh, now: now, seed: 42)
    let b = builder().build(snapshots: s, newCandidates: fresh, now: now, seed: 42)
    let c = builder().build(snapshots: s, newCandidates: fresh, now: now, seed: 43)
    #expect(a == b)
    #expect(a != c)
    #expect(Set(a) == Set(c))
  }
}

@Suite struct ReviewSessionEngineTests {
  let scheduler = FSRSScheduler(calendar: T.utc)
  func entry(_ i: Int) -> ReviewEntry {
    let c = FSRSCard(stability: 5, difficulty: 5, due: T.t0, lastReview: T.t0.addingTimeInterval(-86400 * 5), reps: 2, lapses: 0, state: .review)
    return ReviewEntry(key: T.key("i\(i)"), card: c)
  }

  @Test func againRequeuesAtPlusThreeMaxTwice() {
    var e = ReviewSessionEngine(entries: [entry(0), entry(1), entry(2), entry(4)], scheduler: scheduler)
    #expect(e.total == 4 && e.position == 0)
    e.reveal()
    #expect(e.isRevealed)
    e.rate(.again, now: T.t0)  // [a, b, c, d] -> a' after d? position+3 = index 3 -> [a, b, c, a', d]
    #expect(!e.isRevealed)
    #expect(e.current?.key == T.key("i1"))
    e.rate(.good, now: T.t0)
    e.rate(.good, now: T.t0)
    #expect(e.current?.key == T.key("i0"))
    #expect(e.current?.card.state == .relearning)
    e.rate(.again, now: T.t0)  // second requeue
    #expect(e.current?.key == T.key("i4"))
    e.rate(.good, now: T.t0)
    #expect(e.current?.key == T.key("i0"))
    e.rate(.again, now: T.t0)  // third again: not requeued
    #expect(e.isFinished)
    #expect(e.counts[.again] == 3 && e.counts[.good] == 3)
    #expect(e.total == 4)
  }

  @Test func finishAndResult() {
    var e = ReviewSessionEngine(entries: [entry(0)], scheduler: scheduler)
    let r = e.rate(.good, now: T.t0)
    #expect(r.card.state == .review && r.scheduledDays >= 1)
    #expect(e.isFinished && e.current == nil)
    let extra = e.rate(.good, now: T.t0)  // no-op when finished
    #expect(extra.card.state == .new)
  }
}

@Suite struct ProgressRepositoryTests {
  @Test func cardsDueAndLogs() async throws {
    let repo = InMemoryProgressRepository()
    let k1 = T.key("a", "1"), k2 = T.key("a", "2"), k3 = T.key("b", "1")
    try await repo.upsertCard(CardRecord(key: k1, card: T.card(.review, due: T.t0.addingTimeInterval(-100)), createdAt: T.t0))
    try await repo.upsertCard(CardRecord(key: k2, card: T.card(.review, due: T.t0.addingTimeInterval(-200)), createdAt: T.t0))
    try await repo.upsertCard(CardRecord(key: k3, card: T.card(.review, due: T.t0.addingTimeInterval(500)), createdAt: T.t0))
    #expect(try await repo.dueCards(asOf: T.t0, limit: nil).map(\.key) == [k2, k1])
    #expect(try await repo.dueCards(asOf: T.t0, limit: 1).map(\.key) == [k2])
    #expect(try await repo.cards(forItem: k1.item).count == 2)
    #expect(try await repo.card(for: k3)?.key == k3)
    try await repo.appendLog(ReviewLogRecord(cardKey: k1, rating: .good, reviewedAt: T.t0, elapsedDays: 1, scheduledDays: 3, stateBefore: .review))
    #expect(try await repo.logs(since: T.t0.addingTimeInterval(1)).isEmpty)
    #expect(try await repo.logs(since: nil).count == 1)
  }

  @Test func itemProgressActivityAndReset() async throws {
    let repo = InMemoryProgressRepository()
    let key = ItemKey(topic: "t", item: "a")
    var p = ItemProgressRecord(key: key, firstOpenedAt: T.t0, note: String(repeating: "x", count: 200))
    #expect(p.note.count == ItemProgressRecord.maxNoteLength)
    p.isBookmarked = true
    try await repo.saveItemProgress(p)
    #expect(try await repo.itemProgress(for: key)?.isBookmarked == true)
    let day = DayKey(T.t0, calendar: T.utc)
    try await repo.addActivity(day: day, reviews: 3, studied: 1)
    try await repo.addActivity(day: day, reviews: 2, studied: 0)
    #expect(try await repo.activity(for: day) == DailyActivityRecord(day: day, reviewCount: 5, studiedCount: 1))
    try await repo.resetAll()
    #expect(try await repo.allItemProgress().isEmpty)
    #expect(await repo.allActivity().isEmpty)
    #expect(await repo.allCards().isEmpty)
  }
}
