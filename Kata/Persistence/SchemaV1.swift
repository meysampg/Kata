import Foundation
import SwiftData

/// Version 1 of the on-device progress schema. No relationships: rows are keyed by the stable
/// content keys (`ItemKey.rawValue`, `ExerciseKey.rawValue`), so content can change freely.
enum KataSchemaV1: VersionedSchema {
  static let versionIdentifier = Schema.Version(1, 0, 0)
  static var models: [any PersistentModel.Type] {
    [ExerciseCard.self, ReviewLogEntry.self, ItemProgress.self, DailyActivity.self]
  }
}

extension KataSchemaV1 {
  /// FSRS state of one enrolled exercise. Cards whose exercise has disappeared from the pack are
  /// ignored, never deleted.
  @Model final class ExerciseCard {
    #Index<ExerciseCard>([\.due], [\.itemId])
    /// `ExerciseKey.rawValue`, e.g. `design-patterns/strategy#spot-1`.
    @Attribute(.unique) var key: String
    var topicId: String
    var itemId: String
    var stateRaw: Int
    var stability: Double
    var difficulty: Double
    var due: Date
    var lastReview: Date?
    var reps: Int
    var lapses: Int
    var createdAt: Date

    init(
      key: String, topicId: String, itemId: String, stateRaw: Int = 0, stability: Double = 0,
      difficulty: Double = 0, due: Date = .now, lastReview: Date? = nil, reps: Int = 0,
      lapses: Int = 0, createdAt: Date = .now
    ) {
      self.key = key; self.topicId = topicId; self.itemId = itemId; self.stateRaw = stateRaw
      self.stability = stability; self.difficulty = difficulty; self.due = due
      self.lastReview = lastReview; self.reps = reps; self.lapses = lapses
      self.createdAt = createdAt
    }
  }

  @Model final class ReviewLogEntry {
    var cardKey: String
    var ratingRaw: Int
    var reviewedAt: Date
    var elapsedDays: Double
    var scheduledDays: Double
    var stateBeforeRaw: Int
    var wasCorrect: Bool?
    var responseMillis: Int?

    init(
      cardKey: String, ratingRaw: Int, reviewedAt: Date, elapsedDays: Double,
      scheduledDays: Double, stateBeforeRaw: Int, wasCorrect: Bool? = nil,
      responseMillis: Int? = nil
    ) {
      self.cardKey = cardKey; self.ratingRaw = ratingRaw; self.reviewedAt = reviewedAt
      self.elapsedDays = elapsedDays; self.scheduledDays = scheduledDays
      self.stateBeforeRaw = stateBeforeRaw; self.wasCorrect = wasCorrect
      self.responseMillis = responseMillis
    }
  }

  /// Created the first time an item's deck is opened.
  @Model final class ItemProgress {
    /// `ItemKey.rawValue`, e.g. `design-patterns/strategy`.
    @Attribute(.unique) var key: String
    var firstOpenedAt: Date
    var lastOpenedAt: Date
    var seenRoles: [String]
    var studiedAt: Date?
    var isBookmarked: Bool
    var bookmarkedAt: Date?
    /// At most 140 characters.
    var note: String

    init(
      key: String, firstOpenedAt: Date = .now, lastOpenedAt: Date = .now, seenRoles: [String] = [],
      studiedAt: Date? = nil, isBookmarked: Bool = false, bookmarkedAt: Date? = nil,
      note: String = ""
    ) {
      self.key = key; self.firstOpenedAt = firstOpenedAt; self.lastOpenedAt = lastOpenedAt
      self.seenRoles = seenRoles; self.studiedAt = studiedAt; self.isBookmarked = isBookmarked
      self.bookmarkedAt = bookmarkedAt; self.note = note
    }
  }

  @Model final class DailyActivity {
    /// yyyy-MM-dd, gregorian, local time zone.
    @Attribute(.unique) var dayKey: String
    var reviewCount: Int
    var studiedCount: Int

    init(dayKey: String, reviewCount: Int = 0, studiedCount: Int = 0) {
      self.dayKey = dayKey; self.reviewCount = reviewCount; self.studiedCount = studiedCount
    }
  }
}

typealias ExerciseCard = KataSchemaV1.ExerciseCard
typealias ReviewLogEntry = KataSchemaV1.ReviewLogEntry
typealias ItemProgress = KataSchemaV1.ItemProgress
typealias DailyActivity = KataSchemaV1.DailyActivity
