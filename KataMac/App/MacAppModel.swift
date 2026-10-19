import Foundation
import KataCore
import KataSRS
import KataStore
import OSLog
import SwiftData
import SwiftUI

/// Sidebar destinations.
enum MacSection: Hashable {
  case today, path, library
  case category(TopicID, String)
  case search, bookmarks
}

/// The three parts of an item screen.
enum ItemTab: String, CaseIterable, Identifiable {
  case cards = "Cards"
  case practice = "Practice"
  case kata = "Kata"
  var id: String { rawValue }
}

/// Pushes an item onto the detail stack, optionally at a card role or a tab.
struct MacRoute: Hashable {
  let key: ItemKey
  var role: String?
  var tab: ItemTab?
}

/// What a practice session is made of.
struct PracticeRequest: Identifiable {
  let id = UUID()
  let kind: PracticeSessionModel.Kind
}

/// Composition root of the Mac app: content, progress store, settings and navigation.
@MainActor @Observable
final class MacAppModel {
  let container: ModelContainer
  /// Derived learning state (shared with the iOS app through KataStore).
  let study: StudyModel
  let macSettings: MacSettings
  /// Set when a pack failed to decode; the app then runs with an empty library.
  let libraryError: String?

  var library: ContentLibrary { study.library }
  var store: ProgressStore { study.store }
  var settings: AppSettings { study.settings }
  /// Items that have a body in some pack. Registry-only items are "coming soon".
  var contentKeys: Set<ItemKey> { study.contentKeys }

  /// Sidebar selection. Changing it clears the detail stack.
  var selection: MacSection? = .today {
    didSet { if oldValue != selection { path = NavigationPath() } }
  }
  var path = NavigationPath()
  /// A review session shown over the detail pane.
  var practice: PracticeRequest?
  var searchQuery = ""
  /// Bumped to move keyboard focus to the toolbar search field.
  private(set) var searchFocusTick = 0

  init(
    container: ModelContainer, library: ContentLibrary, libraryError: String? = nil,
    settings: AppSettings, macSettings: MacSettings
  ) {
    self.container = container
    self.libraryError = libraryError
    self.macSettings = macSettings
    self.study = StudyModel(
      library: library, store: ProgressStore(container: container), settings: settings,
      kataKeys: Set(library.katas.keys))
  }

  // MARK: Factories

  /// `~/Library/Application Support/com.github.meysampg.kata.mac/Kata.store`. A non-sandboxed app
  /// must not use SwiftData's shared `default.store`.
  static func storeURL(fileManager: FileManager = .default) -> URL {
    let base = (try? fileManager.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
      ?? fileManager.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
    return base.appending(path: "com.github.meysampg.kata.mac").appending(path: "Kata.store")
  }

  static func live() -> MacAppModel {
    #if DEBUG
    if DebugLaunch.isDemo { return DebugLaunch.makeModel() }
    #endif
    let container: ModelContainer
    do {
      container = try PersistenceFactory.makeContainer(url: storeURL())
    } catch {
      Logger(subsystem: "com.github.meysampg.kata.mac", category: "persistence")
        .error("On-disk ModelContainer failed: \(String(describing: error))")
      #if DEBUG
      assertionFailure("On-disk ModelContainer failed: \(error)")
      #endif
      container = inMemoryContainer()
    }
    return make(container: container, settings: AppSettings(), macSettings: MacSettings())
  }

  static func make(
    container: ModelContainer, settings: AppSettings, macSettings: MacSettings,
    bundle: Bundle = .main
  ) -> MacAppModel {
    do {
      return MacAppModel(
        container: container, library: try .live(bundle: bundle, includeKatas: true),
        settings: settings, macSettings: macSettings)
    } catch {
      Logger(subsystem: "com.github.meysampg.kata.mac", category: "content")
        .error("Content failed to load: \(String(describing: error))")
      return MacAppModel(
        container: container, library: ContentLibrary(packs: []),
        libraryError: String(describing: error), settings: settings, macSettings: macSettings)
    }
  }

  static func inMemoryContainer() -> ModelContainer {
    // An in-memory container for a valid schema cannot realistically fail.
    try! PersistenceFactory.makeContainer(inMemory: true)
  }

  // MARK: Navigation

  func hasContent(_ key: ItemKey) -> Bool { contentKeys.contains(key) }

  func show(_ section: MacSection) { selection = section }

  func focusSearch() {
    selection = .search
    searchFocusTick += 1
  }

  /// Pushes an item onto the detail stack.
  func open(_ key: ItemKey, role: String? = nil, tab: ItemTab? = nil) {
    guard hasContent(key) else { return }
    path.append(MacRoute(key: key, role: role, tab: tab))
  }

  func startReview() { practice = PracticeRequest(kind: .review) }

  /// Resolves a `kata:<item-id>` link (optionally `kata:<topic>/<item-id>`) relative to a topic.
  func resolve(link url: URL, in topic: TopicID) -> ItemKey? {
    guard url.scheme == "kata" else { return nil }
    var raw = url.absoluteString.dropFirst("kata:".count)
    while raw.hasPrefix("/") { raw = raw.dropFirst() }
    let text = String(raw)
    if let key = ItemKey(rawValue: text) { return key }
    return ItemKey(topic: topic, item: text)
  }

  func title(of key: ItemKey) -> String { library.meta(key)?.title ?? key.item }

  // MARK: Derived learning state

  func masteryMap() -> [ItemKey: ItemMastery] { study.masteryMap() }
  func reviewQueue(now: Date = .now) -> [ExerciseKey] { study.reviewQueue(now: now) }
  func nextDueDate() -> Date? { study.nextDueDate() }

  /// The katas Today offers: due kata reviews first, then new ones for studied items, capped at
  /// `katasPerDay` minus the ones already done today.
  func dueKatas(now: Date = .now) -> [ItemKey] {
    guard !library.katas.isEmpty else { return [] }
    let cards = store.kataCards().map {
      KataCardSnapshot(item: $0.key.item, due: $0.card.due, lastReview: $0.card.lastReview)
    }
    let progress = store.allProgress()
    var fresh: [ItemKey] = []
    for topic in library.topics {
      guard let path = library.learningPath(topic.id) else { continue }
      for id in path.allItems {
        let key = topic.key(for: id)
        if library.katas[key] != nil, progress[key]?.studiedAt != nil { fresh.append(key) }
      }
    }
    return KataQueue(katasPerDay: macSettings.katasPerDay)
      .build(cards: cards, newCandidates: fresh, now: now)
  }

  /// The next item to study in path order. Items without a body count as done so they are skipped.
  func nextItem(mastery: [ItemKey: ItemMastery]) -> ItemKey? {
    for topic in library.topics {
      guard let path = library.learningPath(topic.id) else { continue }
      if let next = nextItem(topic: topic, path: path, mastery: mastery) { return topic.key(for: next) }
    }
    return nil
  }

  func nextItem(topic: Topic, path: LearningPath, mastery: [ItemKey: ItemMastery]) -> ItemID? {
    var levels: [ItemID: Mastery] = [:]
    for id in path.allItems {
      let key = topic.key(for: id)
      levels[id] = hasContent(key) ? (mastery[key]?.level ?? .notStarted) : .mastered
    }
    return path.next(progress: levels)
  }
}
