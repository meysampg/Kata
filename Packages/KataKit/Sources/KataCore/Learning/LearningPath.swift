import Foundation

/// The ordered sections of a topic's path.
public struct LearningPath: Sendable, Hashable {
  public struct Section: Sendable, Hashable {
    public let title: String
    public let items: [ItemID]
  }

  public let topic: TopicID
  public let sections: [Section]

  public init(topic: TopicID, sections: [PathSection]) {
    self.topic = topic
    self.sections = sections.map { Section(title: $0.title, items: $0.items) }
  }

  public init(pack: Pack) { self.init(topic: pack.topic.id, sections: pack.topic.path) }

  /// All items in path order.
  public var allItems: [ItemID] { sections.flatMap(\.items) }

  public func section(containing item: ItemID) -> Section? {
    sections.first { $0.items.contains(item) }
  }

  public func index(of item: ItemID) -> Int? { allItems.firstIndex(of: item) }

  /// The next item to study: the first item after `current` (in path order, wrapping around)
  /// whose mastery is not started. With `current == nil` the search starts at the beginning.
  /// Returns nil when every item has been started.
  public func next(after current: ItemID? = nil, progress: [ItemID: Mastery]) -> ItemID? {
    let all = allItems
    guard !all.isEmpty else { return nil }
    let start = current.flatMap { all.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
    for offset in 0..<all.count {
      let id = all[(start + offset) % all.count]
      if (progress[id] ?? .notStarted) == .notStarted { return id }
    }
    return nil
  }

  /// Number of items per section that are started, for headers like "12 / 70 studied".
  public func startedCount(progress: [ItemID: Mastery]) -> (started: Int, total: Int) {
    let all = allItems
    return (all.filter { (progress[$0] ?? .notStarted) != .notStarted }.count, all.count)
  }
}
