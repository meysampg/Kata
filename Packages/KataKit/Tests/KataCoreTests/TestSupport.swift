import Foundation

@testable import KataCore

enum Fixtures {
  static var root: URL {
    Bundle.module.resourceURL!.appendingPathComponent("Fixtures", isDirectory: true)
  }
  static var miniTopic: URL { root.appendingPathComponent("mini-topic", isDirectory: true) }
  static func broken(_ name: String) -> URL {
    root.appendingPathComponent("broken/\(name)", isDirectory: true)
  }

  static func miniPack() throws -> Pack { try PackBuilder.build(topicDirectory: miniTopic) }

  /// Copies the mini topic into a fresh temp dir named `mini-topic` so tests can edit files.
  static func scratchCopy() throws -> URL {
    let parent = FileManager.default.temporaryDirectory
      .appendingPathComponent("kata-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    let dest = parent.appendingPathComponent("mini-topic", isDirectory: true)
    try FileManager.default.copyItem(at: miniTopic, to: dest)
    return dest
  }

  static func edit(_ url: URL, _ transform: (String) -> String) throws {
    let s = try String(contentsOf: url, encoding: .utf8)
    try transform(s).write(to: url, atomically: true, encoding: .utf8)
  }
}

extension Pack {
  /// Mutates one item (by id) and returns the new pack.
  func editingItem(_ id: ItemID, _ body: (inout Item) -> Void) -> Pack {
    var copy = self
    let i = copy.items.firstIndex { $0.id == id }!
    body(&copy.items[i])
    return copy
  }

  func editingTopic(_ body: (inout Topic) -> Void) -> Pack {
    var copy = self
    body(&copy.topic)
    return copy
  }
}

extension Array where Element == ValidationIssue {
  func hasError(containing text: String) -> Bool {
    contains { $0.severity == .error && $0.message.contains(text) }
  }
  func hasWarning(containing text: String) -> Bool {
    contains { $0.severity == .warning && $0.message.contains(text) }
  }
}
