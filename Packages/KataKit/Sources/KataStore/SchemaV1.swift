import Foundation
import SwiftData

/// Version 1 of the on-device progress schema. No relationships: rows are keyed by the stable
/// content keys (`ItemKey.rawValue`, `ExerciseKey.rawValue`), so content can change freely.
public enum KataSchemaV1: VersionedSchema {
  public static let versionIdentifier = Schema.Version(1, 0, 0)
  public static var models: [any PersistentModel.Type] {
    [ExerciseCard.self, ReviewLogEntry.self, ItemProgress.self, DailyActivity.self]
  }
}

extension KataSchemaV1 {
  /// FSRS state of one enrolled exercise. Cards whose exercise has disappeared from the pack are
  /// ignored, never deleted.
  @Model public final class ExerciseCard {
    #Index<ExerciseCard>([\.due], [\.itemId])
    /// `ExerciseKey.rawValue`, e.g. `design-patterns/strategy#spot-1`.
    @Attribute(.unique) public var key: String
    public var topicId: String
    public var itemId: String
    public var stateRaw: Int
    public var stability: Double
    public var difficulty: Double
    public var due: Date
    public var lastReview: Date?
    public var reps: Int
    public var lapses: Int
    public var createdAt: Date

    public init(
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

  @Model public final class ReviewLogEntry {
    public var cardKey: String
    public var ratingRaw: Int
    public var reviewedAt: Date
    public var elapsedDays: Double
    public var scheduledDays: Double
    public var stateBeforeRaw: Int
    public var wasCorrect: Bool?
    public var responseMillis: Int?

    public init(
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
  @Model public final class ItemProgress {
    /// `ItemKey.rawValue`, e.g. `design-patterns/strategy`.
    @Attribute(.unique) public var key: String
    public var firstOpenedAt: Date
    public var lastOpenedAt: Date
    public var seenRoles: [String]
    public var studiedAt: Date?
    public var isBookmarked: Bool
    public var bookmarkedAt: Date?
    /// At most 140 characters.
    public var note: String

    public init(
      key: String, firstOpenedAt: Date = .now, lastOpenedAt: Date = .now, seenRoles: [String] = [],
      studiedAt: Date? = nil, isBookmarked: Bool = false, bookmarkedAt: Date? = nil,
      note: String = ""
    ) {
      self.key = key; self.firstOpenedAt = firstOpenedAt; self.lastOpenedAt = lastOpenedAt
      self.seenRoles = seenRoles; self.studiedAt = studiedAt; self.isBookmarked = isBookmarked
      self.bookmarkedAt = bookmarkedAt; self.note = note
    }
  }

  @Model public final class DailyActivity {
    /// yyyy-MM-dd, gregorian, local time zone.
    @Attribute(.unique) public var dayKey: String
    public var reviewCount: Int
    public var studiedCount: Int

    public init(dayKey: String, reviewCount: Int = 0, studiedCount: Int = 0) {
      self.dayKey = dayKey; self.reviewCount = reviewCount; self.studiedCount = studiedCount
    }
  }
}

public typealias ExerciseCard = KataSchemaV1.ExerciseCard
public typealias ReviewLogEntry = KataSchemaV1.ReviewLogEntry
public typealias ItemProgress = KataSchemaV1.ItemProgress
public typealias DailyActivity = KataSchemaV1.DailyActivity
