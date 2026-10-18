import Foundation
import KataSRS

public enum Mastery: Int, Sendable, Hashable, Comparable, Codable, CaseIterable {
  case notStarted, learning, familiar, mastered

  public static func < (l: Mastery, r: Mastery) -> Bool { l.rawValue < r.rawValue }
}

/// Per-item mastery from its exercise cards. Adapted from AzBar's `PoemProgress`.
public struct ItemMastery: Sendable, Hashable {
  public var total: Int
  public var notStarted: Int
  public var learning: Int
  /// Review state with stability below 21 days.
  public var young: Int
  /// Review state with stability of 21 days or more.
  public var mature: Int

  public init(total: Int, notStarted: Int, learning: Int, young: Int, mature: Int) {
    self.total = total; self.notStarted = notStarted; self.learning = learning
    self.young = young; self.mature = mature
  }

  public static let empty = ItemMastery(total: 0, notStarted: 0, learning: 0, young: 0, mature: 0)

  /// Weighted completion in 0...1 (same weights as AzBar: 0.25 / 0.6 / 1.0).
  public var fraction: Double {
    guard total > 0 else { return 0 }
    return (0.25 * Double(learning) + 0.6 * Double(young) + 1.0 * Double(mature)) / Double(total)
  }

  /// notStarted: no card started. mastered: every exercise is mature. familiar: every exercise
  /// has left the learning steps (young or mature). Otherwise learning.
  public var level: Mastery {
    if total == 0 || learning + young + mature == 0 { return .notStarted }
    if mature == total { return .mastered }
    if learning == 0 && notStarted == 0 { return .familiar }
    return .learning
  }
}

public enum MasteryCalculator {
  public static let matureStability = 21.0

  public static func compute(cards: [FSRSCard], totalExercises: Int) -> ItemMastery {
    var learning = 0, young = 0, mature = 0
    for c in cards {
      switch c.state {
      case .new: break
      case .learning, .relearning: learning += 1
      case .review: if c.stability >= matureStability { mature += 1 } else { young += 1 }
      }
    }
    let started = learning + young + mature
    return ItemMastery(
      total: totalExercises, notStarted: max(0, totalExercises - started),
      learning: learning, young: young, mature: mature)
  }
}
