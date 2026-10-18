import Foundation
import KataSRS

public struct ReviewEntry: Sendable, Hashable {
  public var key: ExerciseKey
  public var card: FSRSCard

  public init(key: ExerciseKey, card: FSRSCard) {
    self.key = key
    self.card = card
  }
}

/// Drives one review/practice session. Adapted from AzBar: keyed by `ExerciseKey`;
/// an `again` rating requeues the exercise 3 positions later, at most twice.
public struct ReviewSessionEngine: Sendable {
  private var entries: [ReviewEntry]
  private var requeues: [ExerciseKey: Int] = [:]
  private let scheduler: FSRSScheduler
  public private(set) var position: Int = 0
  public private(set) var isRevealed: Bool = false
  public private(set) var counts: [Rating: Int] = [:]
  public let total: Int

  public init(entries: [ReviewEntry], scheduler: FSRSScheduler) {
    self.entries = entries
    self.scheduler = scheduler
    self.total = entries.count
  }

  public var current: ReviewEntry? { entries.indices.contains(position) ? entries[position] : nil }
  public var isFinished: Bool { current == nil }

  public mutating func reveal() { isRevealed = true }

  @discardableResult
  public mutating func rate(_ r: Rating, now: Date) -> SchedulingResult {
    guard let entry = current else {
      return SchedulingResult(card: FSRSCard.new(now: now), elapsedDays: 0, scheduledDays: 0)
    }
    let result = scheduler.next(entry.card, rating: r, now: now)
    counts[r, default: 0] += 1
    if r == .again, requeues[entry.key, default: 0] < 2 {
      requeues[entry.key, default: 0] += 1
      let at = min(position + 3, entries.count)
      entries.insert(ReviewEntry(key: entry.key, card: result.card), at: at)
    }
    position += 1
    isRevealed = false
    return result
  }
}
