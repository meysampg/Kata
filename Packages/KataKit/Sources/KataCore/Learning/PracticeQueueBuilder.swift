import Foundation

/// Scheduling state of one enrolled exercise card, as the queue builder needs it.
public struct PracticeCardSnapshot: Sendable, Hashable {
  public var key: ExerciseKey
  public var due: Date
  public var lastReview: Date?

  public init(key: ExerciseKey, due: Date, lastReview: Date? = nil) {
    self.key = key; self.due = due; self.lastReview = lastReview
  }
}

/// Builds the daily queue: most-overdue reviews first (capped), plus new exercises (capped),
/// buried so that an item shows at most one review per day, then shuffled with a seed and
/// arranged so that two exercises of one item are never back-to-back when avoidable.
public struct PracticeQueueBuilder: Sendable {
  public var newLimit: Int
  public var reviewLimit: Int
  public var calendar: Calendar

  public init(newLimit: Int = 10, reviewLimit: Int = 100, calendar: Calendar = .current) {
    self.newLimit = newLimit; self.reviewLimit = reviewLimit; self.calendar = calendar
  }

  /// - Parameters:
  ///   - snapshots: every enrolled card (due or not); non-due ones only matter for burying.
  ///   - newCandidates: exercises without a card yet, in preferred order.
  public func build(
    snapshots: [PracticeCardSnapshot], newCandidates: [ExerciseKey], now: Date, seed: UInt64
  ) -> [ExerciseKey] {
    let reviewedToday = snapshots.filter {
      $0.lastReview.map { calendar.isDate($0, inSameDayAs: now) } ?? false
    }
    let due = snapshots.filter { $0.due <= now }
      .sorted { ($0.due, $0.key) < ($1.due, $1.key) }

    var reviews: [ExerciseKey] = []
    var itemsWithReview = Set<ItemKey>()
    for s in due {
      if reviews.count >= max(0, reviewLimit) { break }
      let siblingDoneToday = reviewedToday.contains { $0.key.item == s.key.item && $0.key != s.key }
      if siblingDoneToday || itemsWithReview.contains(s.key.item) { continue }
      itemsWithReview.insert(s.key.item)
      reviews.append(s.key)
    }

    let enrolled = Set(snapshots.map(\.key))
    var seen = Set<ExerciseKey>()
    var fresh: [ExerciseKey] = []
    for k in newCandidates where !enrolled.contains(k) && seen.insert(k).inserted {
      if fresh.count >= max(0, newLimit) { break }
      fresh.append(k)
    }

    var rng = SeededRandom(seed: seed)
    let shuffled = (reviews + fresh).shuffled(using: &rng)
    return Self.separateSiblings(shuffled)
  }

  /// Keeps the given order where possible but never places two exercises of one item next to
  /// each other when that is avoidable: at each step take the first entry whose item differs
  /// from the previous one, preferring the item with the most entries left (so a big group is
  /// not stranded at the tail).
  static func separateSiblings(_ keys: [ExerciseKey]) -> [ExerciseKey] {
    var remaining = keys
    var left: [ItemKey: Int] = [:]
    for k in keys { left[k.item, default: 0] += 1 }
    var out: [ExerciseKey] = []
    out.reserveCapacity(keys.count)
    while !remaining.isEmpty {
      let last = out.last?.item
      var best: Int?
      for (i, k) in remaining.enumerated() where k.item != last {
        if best == nil || left[k.item]! > left[remaining[best!].item]! { best = i }
      }
      let pick = remaining.remove(at: best ?? 0)
      left[pick.item]! -= 1
      out.append(pick)
    }
    return out
  }
}
