import Foundation

/// An item's body: ordered cards and exercises. Its registry entry is an `ItemMeta`.
public struct Item: Sendable, Equatable, Codable, Identifiable {
  public var id: ItemID
  public var cards: [Card]
  public var exercises: [Exercise]

  public init(id: ItemID, cards: [Card], exercises: [Exercise]) {
    self.id = id; self.cards = cards; self.exercises = exercises
  }

  private enum CodingKeys: String, CodingKey, CaseIterable { case id, cards, exercises }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    cards = try c.decode([Card].self, forKey: .cards)
    exercises = try c.decode([Exercise].self, forKey: .exercises)
  }

  public func card(role: String) -> Card? { cards.first { $0.role == role } }
  public func exercise(_ id: ExerciseID) -> Exercise? { exercises.first { $0.id == id } }
}

/// A built content pack: the topic registry plus the bodies of the items that exist.
public struct Pack: Sendable, Equatable, Codable {
  public var topic: Topic
  public var items: [Item]

  public init(topic: Topic, items: [Item]) {
    self.topic = topic; self.items = items
  }

  private enum CodingKeys: String, CodingKey, CaseIterable { case topic, items }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    topic = try c.decode(Topic.self, forKey: .topic)
    items = try c.decode([Item].self, forKey: .items)
  }

  public var id: TopicID { topic.id }

  public func item(_ id: ItemID) -> Item? { items.first { $0.id == id } }

  public func key(for item: ItemID) -> ItemKey { ItemKey(topic: topic.id, item: item) }

  /// Keys of all exercises of the given item.
  public func exerciseKeys(for item: ItemID) -> [ExerciseKey] {
    (self.item(item)?.exercises ?? []).map { ExerciseKey(item: key(for: item), exercise: $0.id) }
  }

  /// Number of exercises in an item (0 if the body is not in the pack).
  public func exerciseCount(for item: ItemID) -> Int { self.item(item)?.exercises.count ?? 0 }
}
