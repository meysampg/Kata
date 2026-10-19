import Foundation
import KataCore
import KataSRS
import SwiftData

/// All reads and writes of learning progress. Main-actor only; engines receive plain value
/// snapshots (`FSRSCard`, `CardRecord`), never SwiftData models.
///
/// Conforms to KataCore's `ProgressRepository` (Repository pattern): the async protocol methods
/// forward to the synchronous API that the UI uses.
@MainActor @Observable
public final class ProgressStore {
  private let container: ModelContainer
  private let calendar: Calendar
  /// Bumped after every write and read in every query, so views observing the store refresh.
  public private(set) var revision = 0

  private var context: ModelContext { container.mainContext }

  public init(container: ModelContainer, calendar: Calendar = DayKey.gregorian()) {
    self.container = container
    self.calendar = calendar
  }

  // MARK: Helpers

  private func dayKey(_ date: Date) -> DayKey { DayKey(date, calendar: calendar) }

  private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
    (try? context.fetch(descriptor)) ?? []
  }

  private func save() {
    try? context.save()
    revision += 1
  }

  private func cardModel(_ key: ExerciseKey) -> ExerciseCard? {
    let raw = key.rawValue
    var d = FetchDescriptor<ExerciseCard>(predicate: #Predicate { $0.key == raw })
    d.fetchLimit = 1
    return fetch(d).first
  }

  private func progressModel(_ key: ItemKey) -> ItemProgress? {
    let raw = key.rawValue
    var d = FetchDescriptor<ItemProgress>(predicate: #Predicate { $0.key == raw })
    d.fetchLimit = 1
    return fetch(d).first
  }

  private static func snapshot(_ m: ExerciseCard) -> FSRSCard {
    FSRSCard(
      stability: m.stability, difficulty: m.difficulty, due: m.due, lastReview: m.lastReview,
      reps: m.reps, lapses: m.lapses, state: CardState(rawValue: m.stateRaw) ?? .new)
  }

  private static func record(_ m: ExerciseCard) -> CardRecord? {
    ExerciseKey(rawValue: m.key).map {
      CardRecord(key: $0, card: snapshot(m), createdAt: m.createdAt)
    }
  }

  private static func record(_ m: ItemProgress) -> ItemProgressRecord? {
    ItemKey(rawValue: m.key).map {
      ItemProgressRecord(
        key: $0, firstOpenedAt: m.firstOpenedAt, lastOpenedAt: m.lastOpenedAt,
        seenRoles: m.seenRoles, studiedAt: m.studiedAt, isBookmarked: m.isBookmarked,
        bookmarkedAt: m.bookmarkedAt, note: m.note)
    }
  }

  private func activityModel(_ day: DayKey) -> DailyActivity? {
    let s = day.string
    var d = FetchDescriptor<DailyActivity>(predicate: #Predicate { $0.dayKey == s })
    d.fetchLimit = 1
    return fetch(d).first
  }

  private func activityOrNew(_ day: DayKey) -> DailyActivity {
    if let a = activityModel(day) { return a }
    let a = DailyActivity(dayKey: day.string)
    context.insert(a)
    return a
  }

  // MARK: Cards

  public func card(_ key: ExerciseKey) -> FSRSCard? {
    _ = revision
    return cardModel(key).map(Self.snapshot)
  }

  public func cardRecords(forItem item: ItemKey) -> [CardRecord] {
    _ = revision
    let topic = item.topic, id = item.item
    let d = FetchDescriptor<ExerciseCard>(
      predicate: #Predicate { $0.topicId == topic && $0.itemId == id },
      sortBy: [SortDescriptor(\.key)])
    return fetch(d).compactMap(Self.record)
  }

  public func allCardRecords() -> [CardRecord] {
    _ = revision
    return fetch(FetchDescriptor<ExerciseCard>(sortBy: [SortDescriptor(\.key)]))
      .compactMap(Self.record)
  }

  /// Cards with `due <= date`, most overdue first.
  public func dueRecords(asOf date: Date, limit: Int? = nil) -> [CardRecord] {
    _ = revision
    var d = FetchDescriptor<ExerciseCard>(
      predicate: #Predicate { $0.due <= date },
      sortBy: [SortDescriptor(\.due), SortDescriptor(\.key)])
    if let limit { d.fetchLimit = max(0, limit) }
    return fetch(d).compactMap(Self.record)
  }

  public func dueCount(asOf date: Date) -> Int {
    _ = revision
    return (try? context.fetchCount(
      FetchDescriptor<ExerciseCard>(predicate: #Predicate { $0.due <= date }))) ?? 0
  }

  public func nextDueDate() -> Date? {
    _ = revision
    var d = FetchDescriptor<ExerciseCard>(sortBy: [SortDescriptor(\.due)])
    d.fetchLimit = 1
    return fetch(d).first?.due
  }

  /// Rates an exercise: creates the card on first rating, schedules it with FSRS, appends a log
  /// entry and counts the day's activity.
  @discardableResult
  public func record(
    _ rating: Rating, key: ExerciseKey, scheduler: FSRSScheduler, correct: Bool? = nil,
    responseMillis: Int? = nil, now: Date = .now
  ) -> SchedulingResult {
    let model: ExerciseCard
    if let existing = cardModel(key) {
      model = existing
    } else {
      model = ExerciseCard(
        key: key.rawValue, topicId: key.item.topic, itemId: key.item.item, due: now,
        createdAt: now)
      context.insert(model)
    }
    let before = Self.snapshot(model)
    let result = scheduler.next(before, rating: rating, now: now)
    let c = result.card
    model.stateRaw = c.state.rawValue
    model.stability = c.stability
    model.difficulty = c.difficulty
    model.due = c.due
    model.lastReview = c.lastReview
    model.reps = c.reps
    model.lapses = c.lapses

    context.insert(
      ReviewLogEntry(
        cardKey: key.rawValue, ratingRaw: rating.rawValue, reviewedAt: now,
        elapsedDays: result.elapsedDays, scheduledDays: result.scheduledDays,
        stateBeforeRaw: before.state.rawValue, wasCorrect: correct,
        responseMillis: responseMillis))
    activityOrNew(dayKey(now)).reviewCount += 1
    save()
    return result
  }

  public func logCount() -> Int {
    _ = revision
    return (try? context.fetchCount(FetchDescriptor<ReviewLogEntry>())) ?? 0
  }

  // MARK: Item progress

  public func progress(for key: ItemKey) -> ItemProgressRecord? {
    _ = revision
    return progressModel(key).flatMap(Self.record)
  }

  public func allProgress() -> [ItemKey: ItemProgressRecord] {
    _ = revision
    var out: [ItemKey: ItemProgressRecord] = [:]
    for m in fetch(FetchDescriptor<ItemProgress>()) {
      if let r = Self.record(m) { out[r.key] = r }
    }
    return out
  }

  private func progressOrNew(_ key: ItemKey, now: Date) -> ItemProgress {
    if let m = progressModel(key) { return m }
    let m = ItemProgress(key: key.rawValue, firstOpenedAt: now, lastOpenedAt: now)
    context.insert(m)
    return m
  }

  /// Marks a deck as opened (creating its progress row) and the given role as seen.
  public func markOpened(_ key: ItemKey, role: String? = nil, now: Date = .now) {
    let m = progressOrNew(key, now: now)
    m.lastOpenedAt = now
    if let role, !m.seenRoles.contains(role) { m.seenRoles.append(role) }
    save()
  }

  /// Sets `studiedAt` the first time and counts the day's activity. Returns true on first study.
  @discardableResult
  public func markStudied(_ key: ItemKey, now: Date = .now) -> Bool {
    let m = progressOrNew(key, now: now)
    m.lastOpenedAt = now
    guard m.studiedAt == nil else { save(); return false }
    m.studiedAt = now
    activityOrNew(dayKey(now)).studiedCount += 1
    save()
    return true
  }

  public func isBookmarked(_ key: ItemKey) -> Bool { progress(for: key)?.isBookmarked ?? false }

  public func setBookmarked(_ key: ItemKey, _ value: Bool, now: Date = .now) {
    let m = progressOrNew(key, now: now)
    m.isBookmarked = value
    m.bookmarkedAt = value ? now : nil
    save()
  }

  public func setNote(_ key: ItemKey, _ text: String, now: Date = .now) {
    let m = progressOrNew(key, now: now)
    m.note = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(ItemProgressRecord.maxNoteLength))
    save()
  }

  /// Bookmarked items, most recently bookmarked first.
  public func bookmarks() -> [ItemProgressRecord] {
    _ = revision
    return fetch(FetchDescriptor<ItemProgress>(predicate: #Predicate { $0.isBookmarked }))
      .compactMap(Self.record)
      .sorted { ($0.bookmarkedAt ?? .distantPast) > ($1.bookmarkedAt ?? .distantPast) }
  }

  /// Studied items, most recently opened first.
  public func recentlyStudied(limit: Int) -> [ItemProgressRecord] {
    _ = revision
    return fetch(FetchDescriptor<ItemProgress>(predicate: #Predicate { $0.studiedAt != nil }))
      .compactMap(Self.record)
      .sorted { $0.lastOpenedAt > $1.lastOpenedAt }
      .prefix(max(0, limit)).map { $0 }
  }

  // MARK: Activity and streak

  public func todayActivity(now: Date = .now) -> (reviews: Int, studied: Int) {
    _ = revision
    guard let a = activityModel(dayKey(now)) else { return (0, 0) }
    return (a.reviewCount, a.studiedCount)
  }

  public func hasActivity(on date: Date) -> Bool {
    _ = revision
    guard let a = activityModel(dayKey(date)) else { return false }
    return a.reviewCount + a.studiedCount > 0
  }

  /// Days with any recorded activity.
  public func activeDays() -> Set<DayKey> {
    _ = revision
    var out = Set<DayKey>()
    for a in fetch(FetchDescriptor<DailyActivity>()) where a.reviewCount + a.studiedCount > 0 {
      if let k = DayKey(string: a.dayKey) { out.insert(k) }
    }
    return out
  }

  /// Consecutive active days, counting back from today if active, else from yesterday.
  public func currentStreak(now: Date = .now) -> Int {
    StreakCalculator.current(
      active: activeDays(), frozen: [], today: dayKey(now), calendar: calendar)
  }

  // MARK: Reset

  /// Deletes all progress: cards, logs, item progress (bookmarks and notes included), activity.
  public func resetAllProgress() {
    try? context.delete(model: ExerciseCard.self)
    try? context.delete(model: ReviewLogEntry.self)
    try? context.delete(model: ItemProgress.self)
    try? context.delete(model: DailyActivity.self)
    try? context.delete(model: KataAttempt.self)
    try? context.delete(model: KataSolution.self)
    save()
  }

  // MARK: Katas (Mac)

  /// The FSRS card of an item's kata shares `ExerciseCard` with the exercise id `kata`.
  public static func kataCardKey(_ item: ItemKey) -> ExerciseKey {
    ExerciseKey(item: item, exercise: "kata")
  }

  private func solutionModel(_ item: ItemKey) -> KataSolution? {
    let raw = item.rawValue
    var d = FetchDescriptor<KataSolution>(predicate: #Predicate { $0.itemKey == raw })
    d.fetchLimit = 1
    return fetch(d).first
  }

  private func solutionOrNew(_ item: ItemKey, now: Date) -> KataSolution {
    if let m = solutionModel(item) { return m }
    let m = KataSolution(itemKey: item.rawValue, updatedAt: now)
    context.insert(m)
    return m
  }

  private static func decodeFiles(_ data: Data?) -> [String: String]? {
    guard let data, !data.isEmpty else { return nil }
    return try? JSONDecoder().decode([String: String].self, from: data)
  }

  private static func encodeFiles(_ files: [String: String]) -> Data {
    let e = JSONEncoder()
    e.outputFormatting = [.sortedKeys]
    return (try? e.encode(files)) ?? Data()
  }

  /// The saved draft (`[file name: source]`), if any.
  public func kataDraft(_ item: ItemKey) -> [String: String]? {
    _ = revision
    return Self.decodeFiles(solutionModel(item)?.draftJSON)
  }

  /// Callers debounce (about one second).
  public func saveKataDraft(_ item: ItemKey, files: [String: String], now: Date = .now) {
    let m = solutionOrNew(item, now: now)
    m.draftJSON = Self.encodeFiles(files)
    m.updatedAt = now
    save()
  }

  public func clearKataDraft(_ item: ItemKey, now: Date = .now) {
    guard let m = solutionModel(item) else { return }
    m.draftJSON = Data()
    m.updatedAt = now
    save()
  }

  /// The last passing solution, if any.
  public func lastPassedSolution(_ item: ItemKey) -> [String: String]? {
    _ = revision
    return Self.decodeFiles(solutionModel(item)?.passedJSON)
  }

  public func startKataAttempt(
    _ item: ItemKey, isReview: Bool, mode: String = "editor", now: Date = .now
  ) -> PersistentIdentifier {
    let a = KataAttempt(itemKey: item.rawValue, startedAt: now, isReview: isReview, modeRaw: mode)
    context.insert(a)
    save()
    return a.persistentModelID
  }

  public func updateKataAttempt(
    _ id: PersistentIdentifier, hintsUsed: Int? = nil, revealedSolution: Bool? = nil,
    runCount: Int? = nil, activeMillis: Int? = nil, mode: String? = nil
  ) {
    guard let a = context.model(for: id) as? KataAttempt else { return }
    if let hintsUsed { a.hintsUsed = hintsUsed }
    if let revealedSolution { a.revealedSolution = revealedSolution }
    if let runCount { a.runCount = runCount }
    if let activeMillis { a.activeMillis = activeMillis }
    if let mode { a.modeRaw = mode }
    save()
  }

  public func kataAttempts(for item: ItemKey) -> [KataAttemptRecord] {
    _ = revision
    let raw = item.rawValue
    let d = FetchDescriptor<KataAttempt>(
      predicate: #Predicate { $0.itemKey == raw }, sortBy: [SortDescriptor(\.startedAt)])
    return fetch(d).map {
      KataAttemptRecord(
        itemKey: $0.itemKey, startedAt: $0.startedAt, passedAt: $0.passedAt, isReview: $0.isReview,
        hintsUsed: $0.hintsUsed, revealedSolution: $0.revealedSolution, runCount: $0.runCount,
        activeMillis: $0.activeMillis, rating: $0.ratingRaw.flatMap(Rating.init(rawValue:)),
        modeRaw: $0.modeRaw)
    }
  }

  /// Rates a passed kata: schedules (or creates) the `#kata` FSRS card through the same path as
  /// `record(...)`, logs `responseMillis = activeMillis`, bumps the day's activity and keeps the
  /// passing files.
  @discardableResult
  public func recordKataPass(
    _ item: ItemKey, files: [String: String], attempt: PersistentIdentifier, rating: Rating,
    scheduler: FSRSScheduler, now: Date = .now
  ) -> SchedulingResult {
    let a = context.model(for: attempt) as? KataAttempt
    let millis = a?.activeMillis
    a?.passedAt = now
    a?.ratingRaw = rating.rawValue
    let result = record(
      rating, key: Self.kataCardKey(item), scheduler: scheduler, correct: true,
      responseMillis: millis, now: now)
    let m = solutionOrNew(item, now: now)
    m.passedJSON = Self.encodeFiles(files)
    m.passedAt = now
    m.updatedAt = now
    save()
    return result
  }

  /// Moves a kata card's due date (the Debug "Make due now" command and tests). Returns false
  /// when the item has no kata card yet.
  @discardableResult
  public func setKataDue(_ item: ItemKey, to date: Date) -> Bool {
    guard let m = cardModel(Self.kataCardKey(item)) else { return false }
    m.due = date
    save()
    return true
  }

  /// Cards of katas (exercise id `kata`).
  public func kataCards() -> [CardRecord] {
    allCardRecords().filter { $0.key.exercise == "kata" }
  }
}

/// Value snapshot of a `KataAttempt`.
public struct KataAttemptRecord: Sendable, Equatable {
  public let itemKey: String
  public let startedAt: Date
  public let passedAt: Date?
  public let isReview: Bool
  public let hintsUsed: Int
  public let revealedSolution: Bool
  public let runCount: Int
  public let activeMillis: Int
  public let rating: Rating?
  public let modeRaw: String
}

// MARK: - ProgressRepository

extension ProgressStore: ProgressRepository {
  public func card(for key: ExerciseKey) async throws -> CardRecord? {
    cardModel(key).flatMap(Self.record)
  }

  public func cards(forItem item: ItemKey) async throws -> [CardRecord] { cardRecords(forItem: item) }

  public func allCards() async throws -> [CardRecord] { allCardRecords() }

  public func dueCards(asOf date: Date, limit: Int?) async throws -> [CardRecord] {
    dueRecords(asOf: date, limit: limit)
  }

  public func upsertCard(_ record: CardRecord) async throws {
    let m: ExerciseCard
    if let existing = cardModel(record.key) {
      m = existing
    } else {
      m = ExerciseCard(
        key: record.key.rawValue, topicId: record.key.item.topic, itemId: record.key.item.item,
        createdAt: record.createdAt)
      context.insert(m)
    }
    let c = record.card
    m.stateRaw = c.state.rawValue; m.stability = c.stability; m.difficulty = c.difficulty
    m.due = c.due; m.lastReview = c.lastReview; m.reps = c.reps; m.lapses = c.lapses
    save()
  }

  public func appendLog(_ log: ReviewLogRecord) async throws {
    context.insert(
      ReviewLogEntry(
        cardKey: log.cardKey.rawValue, ratingRaw: log.rating.rawValue, reviewedAt: log.reviewedAt,
        elapsedDays: log.elapsedDays, scheduledDays: log.scheduledDays,
        stateBeforeRaw: log.stateBefore.rawValue, wasCorrect: log.wasCorrect,
        responseMillis: log.responseMillis))
    save()
  }

  public func logs(since date: Date?) async throws -> [ReviewLogRecord] {
    var d = FetchDescriptor<ReviewLogEntry>(sortBy: [SortDescriptor(\.reviewedAt)])
    if let date { d.predicate = #Predicate { $0.reviewedAt >= date } }
    return fetch(d).compactMap { m in
      guard let key = ExerciseKey(rawValue: m.cardKey), let rating = Rating(rawValue: m.ratingRaw)
      else { return nil }
      return ReviewLogRecord(
        cardKey: key, rating: rating, reviewedAt: m.reviewedAt, elapsedDays: m.elapsedDays,
        scheduledDays: m.scheduledDays, stateBefore: CardState(rawValue: m.stateBeforeRaw) ?? .new,
        wasCorrect: m.wasCorrect, responseMillis: m.responseMillis)
    }
  }

  public func itemProgress(for key: ItemKey) async throws -> ItemProgressRecord? {
    progressModel(key).flatMap(Self.record)
  }

  public func allItemProgress() async throws -> [ItemProgressRecord] {
    allProgress().values.sorted { $0.key < $1.key }
  }

  public func saveItemProgress(_ record: ItemProgressRecord) async throws {
    let m = progressOrNew(record.key, now: record.firstOpenedAt)
    m.firstOpenedAt = record.firstOpenedAt; m.lastOpenedAt = record.lastOpenedAt
    m.seenRoles = record.seenRoles; m.studiedAt = record.studiedAt
    m.isBookmarked = record.isBookmarked; m.bookmarkedAt = record.bookmarkedAt
    m.note = record.note
    save()
  }

  public func activity(for day: DayKey) async throws -> DailyActivityRecord? {
    activityModel(day).map {
      DailyActivityRecord(day: day, reviewCount: $0.reviewCount, studiedCount: $0.studiedCount)
    }
  }

  public func allActivity() async throws -> [DailyActivityRecord] {
    fetch(FetchDescriptor<DailyActivity>()).compactMap { m in
      DayKey(string: m.dayKey).map {
        DailyActivityRecord(day: $0, reviewCount: m.reviewCount, studiedCount: m.studiedCount)
      }
    }.sorted { $0.day < $1.day }
  }

  public func addActivity(day: DayKey, reviews: Int, studied: Int) async throws {
    let a = activityOrNew(day)
    a.reviewCount += reviews
    a.studiedCount += studied
    save()
  }

  public func resetAll() async throws { resetAllProgress() }
}
