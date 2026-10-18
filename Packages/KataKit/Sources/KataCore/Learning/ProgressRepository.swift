import Foundation
import KataSRS

/// One enrolled exercise card.
public struct CardRecord: Sendable, Hashable, Codable {
  public var key: ExerciseKey
  public var card: FSRSCard
  public var createdAt: Date

  public init(key: ExerciseKey, card: FSRSCard, createdAt: Date) {
    self.key = key; self.card = card; self.createdAt = createdAt
  }
}

public struct ReviewLogRecord: Sendable, Hashable, Codable {
  public var cardKey: ExerciseKey
  public var rating: Rating
  public var reviewedAt: Date
  public var elapsedDays: Double
  public var scheduledDays: Double
  public var stateBefore: CardState
  public var wasCorrect: Bool?
  public var responseMillis: Int?

  public init(
    cardKey: ExerciseKey, rating: Rating, reviewedAt: Date, elapsedDays: Double,
    scheduledDays: Double, stateBefore: CardState, wasCorrect: Bool? = nil,
    responseMillis: Int? = nil
  ) {
    self.cardKey = cardKey; self.rating = rating; self.reviewedAt = reviewedAt
    self.elapsedDays = elapsedDays; self.scheduledDays = scheduledDays
    self.stateBefore = stateBefore; self.wasCorrect = wasCorrect
    self.responseMillis = responseMillis
  }
}

public struct ItemProgressRecord: Sendable, Hashable, Codable {
  public static let maxNoteLength = 140

  public var key: ItemKey
  public var firstOpenedAt: Date
  public var lastOpenedAt: Date
  public var seenRoles: [String]
  public var studiedAt: Date?
  public var isBookmarked: Bool
  public var bookmarkedAt: Date?
  public var note: String

  public init(
    key: ItemKey, firstOpenedAt: Date, lastOpenedAt: Date? = nil, seenRoles: [String] = [],
    studiedAt: Date? = nil, isBookmarked: Bool = false, bookmarkedAt: Date? = nil, note: String = ""
  ) {
    self.key = key; self.firstOpenedAt = firstOpenedAt
    self.lastOpenedAt = lastOpenedAt ?? firstOpenedAt; self.seenRoles = seenRoles
    self.studiedAt = studiedAt; self.isBookmarked = isBookmarked
    self.bookmarkedAt = bookmarkedAt; self.note = String(note.prefix(Self.maxNoteLength))
  }
}

public struct DailyActivityRecord: Sendable, Hashable, Codable {
  public var day: DayKey
  public var reviewCount: Int
  public var studiedCount: Int

  public init(day: DayKey, reviewCount: Int = 0, studiedCount: Int = 0) {
    self.day = day; self.reviewCount = reviewCount; self.studiedCount = studiedCount
  }
}

/// Persistence boundary. The app implements it with SwiftData; tests use
/// `InMemoryProgressRepository`. Methods are `async` so main-actor-isolated implementations
/// can conform.
public protocol ProgressRepository: Sendable {
  func card(for key: ExerciseKey) async throws -> CardRecord?
  func cards(forItem item: ItemKey) async throws -> [CardRecord]
  func allCards() async throws -> [CardRecord]
  /// Cards with `due <= date`, most overdue first.
  func dueCards(asOf date: Date, limit: Int?) async throws -> [CardRecord]
  func upsertCard(_ record: CardRecord) async throws

  func appendLog(_ log: ReviewLogRecord) async throws
  func logs(since date: Date?) async throws -> [ReviewLogRecord]

  func itemProgress(for key: ItemKey) async throws -> ItemProgressRecord?
  func allItemProgress() async throws -> [ItemProgressRecord]
  func saveItemProgress(_ record: ItemProgressRecord) async throws

  func activity(for day: DayKey) async throws -> DailyActivityRecord?
  func allActivity() async throws -> [DailyActivityRecord]
  func addActivity(day: DayKey, reviews: Int, studied: Int) async throws

  func resetAll() async throws
}

public actor InMemoryProgressRepository: ProgressRepository {
  private var cardsByKey: [ExerciseKey: CardRecord] = [:]
  private var logList: [ReviewLogRecord] = []
  private var progress: [ItemKey: ItemProgressRecord] = [:]
  private var days: [DayKey: DailyActivityRecord] = [:]

  public init() {}

  public func card(for key: ExerciseKey) -> CardRecord? { cardsByKey[key] }

  public func cards(forItem item: ItemKey) -> [CardRecord] {
    cardsByKey.values.filter { $0.key.item == item }.sorted { $0.key < $1.key }
  }

  public func allCards() -> [CardRecord] { cardsByKey.values.sorted { $0.key < $1.key } }

  public func dueCards(asOf date: Date, limit: Int?) -> [CardRecord] {
    let due = cardsByKey.values.filter { $0.card.due <= date }
      .sorted { ($0.card.due, $0.key) < ($1.card.due, $1.key) }
    return limit.map { Array(due.prefix($0)) } ?? due
  }

  public func upsertCard(_ record: CardRecord) { cardsByKey[record.key] = record }

  public func appendLog(_ log: ReviewLogRecord) { logList.append(log) }

  public func logs(since date: Date?) -> [ReviewLogRecord] {
    guard let date else { return logList }
    return logList.filter { $0.reviewedAt >= date }
  }

  public func itemProgress(for key: ItemKey) -> ItemProgressRecord? { progress[key] }

  public func allItemProgress() -> [ItemProgressRecord] {
    progress.values.sorted { $0.key < $1.key }
  }

  public func saveItemProgress(_ record: ItemProgressRecord) { progress[record.key] = record }

  public func activity(for day: DayKey) -> DailyActivityRecord? { days[day] }

  public func allActivity() -> [DailyActivityRecord] { days.values.sorted { $0.day < $1.day } }

  public func addActivity(day: DayKey, reviews: Int, studied: Int) {
    var r = days[day] ?? DailyActivityRecord(day: day)
    r.reviewCount += reviews
    r.studiedCount += studied
    days[day] = r
  }

  public func resetAll() {
    cardsByKey = [:]; logList = []; progress = [:]; days = [:]
  }
}
