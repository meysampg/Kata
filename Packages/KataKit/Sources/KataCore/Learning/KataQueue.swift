import Foundation

/// A kata's scheduling state, as the queue needs it.
public struct KataCardSnapshot: Sendable, Hashable {
  public var item: ItemKey
  public var due: Date
  public var lastReview: Date?

  public init(item: ItemKey, due: Date, lastReview: Date? = nil) {
    self.item = item; self.due = due; self.lastReview = lastReview
  }
}

/// Picks today's katas: due reviews first (most overdue first), then new katas in the preferred
/// order, capped at `katasPerDay` minus the katas already done today.
public struct KataQueue: Sendable {
  public static let defaultKatasPerDay = 2

  public var katasPerDay: Int
  public var calendar: Calendar

  public init(katasPerDay: Int = KataQueue.defaultKatasPerDay, calendar: Calendar = .current) {
    self.katasPerDay = katasPerDay; self.calendar = calendar
  }

  /// - Parameters:
  ///   - cards: every enrolled kata card (due or not); `lastReview` today counts as done.
  ///   - newCandidates: items with a kata but no card yet, in preferred order.
  public func build(cards: [KataCardSnapshot], newCandidates: [ItemKey], now: Date) -> [ItemKey] {
    let doneToday = cards.filter { $0.lastReview.map { calendar.isDate($0, inSameDayAs: now) } ?? false }
    let room = max(0, katasPerDay) - doneToday.count
    guard room > 0 else { return [] }
    let doneKeys = Set(doneToday.map(\.item))
    let due = cards.filter { $0.due <= now && !doneKeys.contains($0.item) }
      .sorted { ($0.due, $0.item) < ($1.due, $1.item) }
      .map(\.item)
    let enrolled = Set(cards.map(\.item))
    var seen = Set<ItemKey>()
    let fresh = newCandidates.filter { !enrolled.contains($0) && seen.insert($0).inserted }
    return Array((due + fresh).prefix(room))
  }
}
