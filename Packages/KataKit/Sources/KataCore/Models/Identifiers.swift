import Foundation

public typealias TopicID = String
public typealias ItemID = String
public typealias ExerciseID = String

/// Stable identifier of an item across topics, e.g. `design-patterns/strategy`.
/// Never rename: progress is keyed by it.
public struct ItemKey: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
  public let topic: TopicID
  public let item: ItemID

  public init(topic: TopicID, item: ItemID) {
    self.topic = topic
    self.item = item
  }

  public init?(rawValue: String) {
    let parts = rawValue.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
    self.init(topic: String(parts[0]), item: String(parts[1]))
  }

  public var rawValue: String { "\(topic)/\(item)" }
  public var description: String { rawValue }

  public init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    guard let key = ItemKey(rawValue: raw) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Invalid item key '\(raw)'"))
    }
    self = key
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    try c.encode(rawValue)
  }

  public static func < (l: ItemKey, r: ItemKey) -> Bool { l.rawValue < r.rawValue }
}

/// Stable identifier of one exercise, e.g. `design-patterns/strategy#spot-1`.
public struct ExerciseKey: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
  public let item: ItemKey
  public let exercise: ExerciseID

  public init(item: ItemKey, exercise: ExerciseID) {
    self.item = item
    self.exercise = exercise
  }

  public init(topic: TopicID, item: ItemID, exercise: ExerciseID) {
    self.init(item: ItemKey(topic: topic, item: item), exercise: exercise)
  }

  public init?(rawValue: String) {
    let parts = rawValue.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[1].isEmpty, let item = ItemKey(rawValue: String(parts[0]))
    else { return nil }
    self.init(item: item, exercise: String(parts[1]))
  }

  public var rawValue: String { "\(item.rawValue)#\(exercise)" }
  public var description: String { rawValue }

  public init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    guard let key = ExerciseKey(rawValue: raw) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Invalid exercise key '\(raw)'"))
    }
    self = key
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    try c.encode(rawValue)
  }

  public static func < (l: ExerciseKey, r: ExerciseKey) -> Bool { l.rawValue < r.rawValue }
}
