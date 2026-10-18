import Foundation

/// The six generic card renderers.
public enum CardType: String, Sendable, Codable, CaseIterable {
  case text, code, diagram, lists, comparison, references
}

public enum ExerciseKind: String, Sendable, Codable, CaseIterable {
  case identify, choose, tapLine, reorder, recall
}

public struct RoleSpec: Sendable, Hashable, Codable {
  public var title: String
  public var symbol: String
  public var type: CardType

  public init(title: String, symbol: String, type: CardType) {
    self.title = title; self.symbol = symbol; self.type = type
  }

  private enum CodingKeys: String, CodingKey, CaseIterable { case title, symbol, type }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    title = try c.decode(String.self, forKey: .title)
    symbol = try c.decode(String.self, forKey: .symbol)
    type = try c.decode(CardType.self, forKey: .type)
  }
}

public struct TemplateSpec: Sendable, Hashable, Codable {
  public var roles: [String]
  public var optionalRoles: [String]

  public init(roles: [String], optionalRoles: [String] = []) {
    self.roles = roles; self.optionalRoles = optionalRoles
  }

  private enum CodingKeys: String, CodingKey, CaseIterable { case roles, optionalRoles }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    roles = try c.decode([String].self, forKey: .roles)
    optionalRoles = try c.decodeIfPresent([String].self, forKey: .optionalRoles) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(roles, forKey: .roles)
    if !optionalRoles.isEmpty { try c.encode(optionalRoles, forKey: .optionalRoles) }
  }
}

public struct Category: Sendable, Hashable, Codable, Identifiable {
  public var id: String
  public var title: String
  public var template: String
  public var summary: String?

  public init(id: String, title: String, template: String, summary: String? = nil) {
    self.id = id; self.title = title; self.template = template; self.summary = summary
  }

  private enum CodingKeys: String, CodingKey, CaseIterable { case id, title, template, summary }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    title = try c.decode(String.self, forKey: .title)
    template = try c.decode(String.self, forKey: .template)
    summary = try c.decodeIfPresent(String.self, forKey: .summary)
  }
}

/// Registry entry: everything the app needs to list an item without loading its body.
public struct ItemMeta: Sendable, Hashable, Codable, Identifiable {
  public var id: ItemID
  public var title: String
  public var category: String
  public var difficulty: Int
  public var aliases: [String]
  public var intent: String

  public init(
    id: ItemID, title: String, category: String, difficulty: Int,
    aliases: [String] = [], intent: String
  ) {
    self.id = id; self.title = title; self.category = category
    self.difficulty = difficulty; self.aliases = aliases; self.intent = intent
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case id, title, category, difficulty, aliases, intent
  }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    title = try c.decode(String.self, forKey: .title)
    category = try c.decode(String.self, forKey: .category)
    difficulty = try c.decode(Int.self, forKey: .difficulty)
    aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
    intent = try c.decode(String.self, forKey: .intent)
  }
}

public struct PathSection: Sendable, Hashable, Codable {
  public var title: String
  public var items: [ItemID]

  public init(title: String, items: [ItemID]) {
    self.title = title; self.items = items
  }

  private enum CodingKeys: String, CodingKey, CaseIterable { case title, items }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    title = try c.decode(String.self, forKey: .title)
    items = try c.decode([String].self, forKey: .items)
  }
}

/// The topic registry (`topic.json`): roles, templates, categories, item metas, path.
public struct Topic: Sendable, Hashable, Codable, Identifiable {
  public static let supportedSchemaVersion = 1

  public var schemaVersion: Int
  public var id: TopicID
  public var title: String
  public var subtitle: String?
  public var symbol: String
  public var sortOrder: Int
  public var codeLanguage: String
  public var javaRelease: Int?
  public var roles: [String: RoleSpec]
  public var templates: [String: TemplateSpec]
  public var requiredExercises: [[ExerciseKind]]
  public var categories: [Category]
  public var items: [ItemMeta]
  public var path: [PathSection]

  public init(
    schemaVersion: Int = Topic.supportedSchemaVersion, id: TopicID, title: String,
    subtitle: String? = nil, symbol: String, sortOrder: Int = 0, codeLanguage: String,
    javaRelease: Int? = nil, roles: [String: RoleSpec], templates: [String: TemplateSpec],
    requiredExercises: [[ExerciseKind]], categories: [Category], items: [ItemMeta],
    path: [PathSection]
  ) {
    self.schemaVersion = schemaVersion; self.id = id; self.title = title
    self.subtitle = subtitle; self.symbol = symbol; self.sortOrder = sortOrder
    self.codeLanguage = codeLanguage; self.javaRelease = javaRelease; self.roles = roles
    self.templates = templates; self.requiredExercises = requiredExercises
    self.categories = categories; self.items = items; self.path = path
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case schemaVersion, id, title, subtitle, symbol, sortOrder, codeLanguage, javaRelease
    case roles, templates, requiredExercises, categories, items, path
  }

  public init(from decoder: Decoder) throws {
    try decoder.rejectUnknownKeys(CodingKeys.self)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
    guard schemaVersion == Topic.supportedSchemaVersion else {
      throw DecodingError.dataCorruptedError(
        forKey: .schemaVersion, in: c,
        debugDescription: "Unsupported schemaVersion \(schemaVersion)")
    }
    id = try c.decode(String.self, forKey: .id)
    title = try c.decode(String.self, forKey: .title)
    subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
    symbol = try c.decode(String.self, forKey: .symbol)
    sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    codeLanguage = try c.decode(String.self, forKey: .codeLanguage)
    javaRelease = try c.decodeIfPresent(Int.self, forKey: .javaRelease)
    roles = try c.decode([String: RoleSpec].self, forKey: .roles)
    templates = try c.decode([String: TemplateSpec].self, forKey: .templates)
    requiredExercises = try c.decode([[ExerciseKind]].self, forKey: .requiredExercises)
    categories = try c.decode([Category].self, forKey: .categories)
    items = try c.decode([ItemMeta].self, forKey: .items)
    path = try c.decode([PathSection].self, forKey: .path)
  }

  // MARK: Lookups

  public func meta(for id: ItemID) -> ItemMeta? { items.first { $0.id == id } }
  public func category(for id: String) -> Category? { categories.first { $0.id == id } }
  public func category(of item: ItemMeta) -> Category? { category(for: item.category) }

  /// Template of the item's category.
  public func template(for item: ItemMeta) -> TemplateSpec? {
    category(of: item).flatMap { templates[$0.template] }
  }

  /// Card types for roles, used as decoding context for authoring cards.
  public var roleTypes: [String: CardType] { roles.mapValues(\.type) }

  public func key(for item: ItemID) -> ItemKey { ItemKey(topic: id, item: item) }
}
