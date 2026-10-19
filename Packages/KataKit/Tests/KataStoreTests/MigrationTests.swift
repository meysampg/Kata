import Foundation
import KataCore
import KataSRS
import SwiftData
import Testing

@testable import KataStore

@MainActor
struct MigrationTests {
  func tempStoreURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("kata-migration-\(UUID().uuidString)", isDirectory: true)
      .appendingPathComponent("Kata.store")
  }

  @Test func v1StoreOpensWithV2PlanAndKeepsData() throws {
    let url = tempStoreURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let due = Date(timeIntervalSince1970: 1_800_000_000)

    // Write with a V1-only container, exactly what shipped before V2.
    do {
      let schema = Schema(versionedSchema: KataSchemaV1.self)
      let v1 = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
      let ctx = v1.mainContext
      ctx.insert(ExerciseCard(key: "design-patterns/strategy#spot-1", topicId: "design-patterns",
        itemId: "strategy", stateRaw: 2, stability: 4.5, difficulty: 5.5, due: due,
        lastReview: due.addingTimeInterval(-86400), reps: 3, lapses: 1, createdAt: due))
      ctx.insert(ReviewLogEntry(cardKey: "design-patterns/strategy#spot-1", ratingRaw: 3,
        reviewedAt: due, elapsedDays: 1, scheduledDays: 4, stateBeforeRaw: 2, wasCorrect: true,
        responseMillis: 1200))
      ctx.insert(ItemProgress(key: "design-patterns/strategy", firstOpenedAt: due, lastOpenedAt: due,
        seenRoles: ["definition"], studiedAt: due, isBookmarked: true, bookmarkedAt: due, note: "hi"))
      ctx.insert(DailyActivity(dayKey: "2026-10-18", reviewCount: 4, studiedCount: 1))
      try ctx.save()
    }

    let v2 = try PersistenceFactory.makeContainer(url: url)
    let store = ProgressStore(container: v2)
    let item = ItemKey(topic: "design-patterns", item: "strategy")
    let key = ExerciseKey(item: item, exercise: "spot-1")
    let card = try #require(store.card(key))
    #expect(card.reps == 3 && card.lapses == 1 && card.due == due && card.stability == 4.5)
    #expect(store.logCount() == 1)
    let p = try #require(store.progress(for: item))
    #expect(p.studiedAt == due && p.isBookmarked && p.note == "hi" && p.seenRoles == ["definition"])
    #expect(store.activeDays().count == 1)
    #expect(store.kataCards().isEmpty)
    #expect(store.kataDraft(item) == nil)
  }

  @Test func kataApiRoundTrips() throws {
    let store = ProgressStore(container: try PersistenceFactory.makeContainer(inMemory: true))
    let item = ItemKey(topic: "design-patterns", item: "strategy")
    #expect(store.kataDraft(item) == nil)
    store.saveKataDraft(item, files: ["Checkout.java": "class Checkout {}"])
    #expect(store.kataDraft(item)?["Checkout.java"] == "class Checkout {}")
    let attempt = store.startKataAttempt(item, isReview: false)
    store.updateKataAttempt(attempt, hintsUsed: 1, runCount: 2, activeMillis: 90_000)
    store.recordKataPass(item, files: ["Checkout.java": "done"], attempt: attempt, rating: .good,
      scheduler: FSRSScheduler())
    #expect(store.lastPassedSolution(item) == ["Checkout.java": "done"])
    #expect(store.kataCards().count == 1)
    #expect(store.kataAttempts(for: item).first?.rating == .good)
    #expect(store.logCount() == 1)
    store.resetAllProgress()
    #expect(store.kataCards().isEmpty && store.kataDraft(item) == nil && store.kataAttempts(for: item).isEmpty)
  }
}
