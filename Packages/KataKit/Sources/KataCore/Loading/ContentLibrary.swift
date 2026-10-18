import Foundation

public enum ContentLibraryError: Error, Sendable, CustomStringConvertible {
  case decoding(file: String, message: String)
  case duplicateTopic(TopicID)

  public var description: String {
    switch self {
    case .decoding(let file, let message): "\(file): \(message)"
    case .duplicateTopic(let id): "Duplicate topic '\(id)'"
    }
  }
}

/// A resolved item: registry entry plus body, in the context of its topic.
public struct LibraryItem: Sendable, Equatable {
  public let key: ItemKey
  public let meta: ItemMeta
  public let item: Item
  public let category: Category?
  public let template: TemplateSpec?
}

/// All installed content packs. Immutable after init, so safe to share across actors.
public final class ContentLibrary: Sendable {
  public let packs: [Pack]
  private let packIndex: [TopicID: Int]
  public let searchIndex: SearchIndex

  public init(packs: [Pack]) {
    let sorted = packs.sorted { ($0.topic.sortOrder, $0.topic.id) < ($1.topic.sortOrder, $1.topic.id) }
    self.packs = sorted
    var index: [TopicID: Int] = [:]
    for (i, p) in sorted.enumerated() where index[p.topic.id] == nil { index[p.topic.id] = i }
    self.packIndex = index
    self.searchIndex = SearchIndex(packs: sorted)
  }

  /// Decodes packs from `*.kpack` files.
  public convenience init(urls: [URL]) throws {
    var packs: [Pack] = []
    var seen = Set<TopicID>()
    for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
      let pack = try Self.decodePack(at: url)
      guard seen.insert(pack.topic.id).inserted else {
        throw ContentLibraryError.duplicateTopic(pack.topic.id)
      }
      packs.append(pack)
    }
    self.init(packs: packs)
  }

  /// Loads every `*.kpack` in a directory (non-recursive).
  public convenience init(directory: URL) throws {
    let urls = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "kpack" }
    try self.init(urls: urls)
  }

  /// Loads every `*.kpack` in the bundle (root or `Packs/` subdirectory).
  public static func live(bundle: Bundle = .main) throws -> ContentLibrary {
    var urls = bundle.urls(forResourcesWithExtension: "kpack", subdirectory: nil) ?? []
    urls += bundle.urls(forResourcesWithExtension: "kpack", subdirectory: "Packs") ?? []
    return try ContentLibrary(urls: urls)
  }

  public static func decodePack(at url: URL) throws -> Pack {
    do {
      return try decodePack(data: Data(contentsOf: url))
    } catch let e as DecodingError {
      throw ContentLibraryError.decoding(
        file: url.lastPathComponent, message: DecodingErrorFormatter.describe(e))
    }
  }

  public static func decodePack(data: Data) throws -> Pack {
    try JSONDecoder().decode(Pack.self, from: data)
  }

  // MARK: Queries

  /// Topic registries ordered by `sortOrder`.
  public var topics: [Topic] { packs.map(\.topic) }

  public func pack(_ id: TopicID) -> Pack? { packIndex[id].map { packs[$0] } }

  public func topic(_ id: TopicID) -> Topic? { pack(id)?.topic }

  public func meta(_ key: ItemKey) -> ItemMeta? { pack(key.topic)?.topic.meta(for: key.item) }

  public func item(_ key: ItemKey) -> LibraryItem? {
    guard let pack = pack(key.topic), let meta = pack.topic.meta(for: key.item),
      let item = pack.item(key.item)
    else { return nil }
    return LibraryItem(
      key: key, meta: meta, item: item, category: pack.topic.category(of: meta),
      template: pack.topic.template(for: meta))
  }

  public func exercise(_ key: ExerciseKey) -> Exercise? {
    pack(key.item.topic)?.item(key.item.item)?.exercise(key.exercise)
  }

  /// Items present in packs (registry entries without bodies are skipped).
  public func allItemKeys() -> [ItemKey] {
    packs.flatMap { p in p.topic.items.filter { p.item($0.id) != nil }.map { p.key(for: $0.id) } }
  }

  public func learningPath(_ topic: TopicID) -> LearningPath? {
    pack(topic).map { LearningPath(pack: $0) }
  }

  public func search(_ query: String, limit: Int = 50) -> [SearchResult] {
    searchIndex.search(query, limit: limit)
  }
}
