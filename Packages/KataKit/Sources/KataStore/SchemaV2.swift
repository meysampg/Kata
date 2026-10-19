import Foundation
import SwiftData

/// Version 2 of the progress schema: the four V1 models unchanged, plus coding-kata storage.
/// Both tables stay empty on iOS, which never runs katas.
public enum KataSchemaV2: VersionedSchema {
  public static let versionIdentifier = Schema.Version(2, 0, 0)
  public static var models: [any PersistentModel.Type] {
    [
      KataSchemaV1.ExerciseCard.self, KataSchemaV1.ReviewLogEntry.self,
      KataSchemaV1.ItemProgress.self, KataSchemaV1.DailyActivity.self,
      KataAttempt.self, KataSolution.self,
    ]
  }

  /// One run-to-completion (or abandoned) attempt of an item's kata.
  @Model public final class KataAttempt {
    #Index<KataAttempt>([\.itemKey], [\.startedAt])
    /// `ItemKey.rawValue`.
    public var itemKey: String
    public var startedAt: Date
    public var passedAt: Date?
    public var isReview: Bool
    /// 0...3
    public var hintsUsed: Int
    public var revealedSolution: Bool
    public var runCount: Int
    /// Editing time in milliseconds, idle periods over two minutes excluded.
    public var activeMillis: Int
    /// Set when rated.
    public var ratingRaw: Int?
    /// "editor" or "ide".
    public var modeRaw: String

    public init(
      itemKey: String, startedAt: Date = .now, passedAt: Date? = nil, isReview: Bool = false,
      hintsUsed: Int = 0, revealedSolution: Bool = false, runCount: Int = 0, activeMillis: Int = 0,
      ratingRaw: Int? = nil, modeRaw: String = "editor"
    ) {
      self.itemKey = itemKey; self.startedAt = startedAt; self.passedAt = passedAt
      self.isReview = isReview; self.hintsUsed = hintsUsed
      self.revealedSolution = revealedSolution; self.runCount = runCount
      self.activeMillis = activeMillis; self.ratingRaw = ratingRaw; self.modeRaw = modeRaw
    }
  }

  /// Draft and last passing solution per item (files as JSON `[name: source]`).
  @Model public final class KataSolution {
    @Attribute(.unique) public var itemKey: String
    @Attribute(.externalStorage) public var draftJSON: Data
    @Attribute(.externalStorage) public var passedJSON: Data?
    public var passedAt: Date?
    public var updatedAt: Date

    public init(
      itemKey: String, draftJSON: Data = Data(), passedJSON: Data? = nil, passedAt: Date? = nil,
      updatedAt: Date = .now
    ) {
      self.itemKey = itemKey; self.draftJSON = draftJSON; self.passedJSON = passedJSON
      self.passedAt = passedAt; self.updatedAt = updatedAt
    }
  }
}

public typealias KataAttempt = KataSchemaV2.KataAttempt
public typealias KataSolution = KataSchemaV2.KataSolution
