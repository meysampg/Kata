import KataCore
import KataSRS
import KataStore
import OSLog
import SwiftData
import SwiftUI

/// Composition root: content, progress store, settings, navigation state.
@MainActor @Observable
final class AppModel {
  let container: ModelContainer
  /// Derived learning state (shared with the Mac app through KataStore).
  let study: StudyModel
  /// Set when a pack failed to decode; the app then runs with an empty library.
  let libraryError: String?
  let reminders: ReminderScheduler

  var library: ContentLibrary { study.library }
  var store: ProgressStore { study.store }
  var settings: AppSettings { study.settings }
  /// Items that have a body in some pack. Registry-only items are "coming soon".
  var contentKeys: Set<ItemKey> { study.contentKeys }

  var selectedTab: AppTab = .today
  var todayPath = NavigationPath()
  var pathPath = NavigationPath()
  var libraryPath = NavigationPath()
  var searchPath = NavigationPath()
  var practice: PracticeRequest?
  var isSettingsPresented = false
  var libraryBookmarksOnly = false
  var searchQuery = ""
  /// Topic shown on the Path tab when several packs are installed.
  var pathTopicID: TopicID?

  init(
    container: ModelContainer, library: ContentLibrary, libraryError: String? = nil,
    settings: AppSettings
  ) {
    self.container = container
    self.libraryError = libraryError
    self.study = StudyModel(
      library: library, store: ProgressStore(container: container), settings: settings)
    self.reminders = ReminderScheduler()
  }

  // MARK: Factories

  static func live() -> AppModel {
    #if DEBUG
    if DebugLaunch.isDemo { return DebugLaunch.makeModel() }
    #endif
    let container: ModelContainer
    do {
      container = try PersistenceFactory.makeContainer()
    } catch {
      Logger(subsystem: "com.github.meysampg.kata", category: "persistence")
        .error("On-disk ModelContainer failed: \(String(describing: error))")
      #if DEBUG
      assertionFailure("On-disk ModelContainer failed: \(error)")
      #endif
      container = inMemoryContainer()
    }
    return make(container: container, settings: AppSettings())
  }

  static func make(container: ModelContainer, settings: AppSettings, bundle: Bundle = .main) -> AppModel {
    do {
      return AppModel(container: container, library: try .live(bundle: bundle), settings: settings)
    } catch {
      Logger(subsystem: "com.github.meysampg.kata", category: "content")
        .error("Content failed to load: \(String(describing: error))")
      return AppModel(
        container: container, library: ContentLibrary(packs: []),
        libraryError: String(describing: error), settings: settings)
    }
  }

  static func inMemoryContainer() -> ModelContainer {
    // An in-memory container for a valid schema cannot realistically fail.
    try! PersistenceFactory.makeContainer(inMemory: true)
  }

  static func preview() -> AppModel {
    let suite = UserDefaults(suiteName: "kata.preview") ?? .standard
    return make(container: inMemoryContainer(), settings: AppSettings(defaults: suite))
  }

  // MARK: Navigation

  func hasContent(_ key: ItemKey) -> Bool { contentKeys.contains(key) }

  /// Pushes a deck onto the selected tab's stack.
  func push(_ route: DeckRoute) {
    switch selectedTab {
    case .today: todayPath.append(route)
    case .path: pathPath.append(route)
    case .library: libraryPath.append(route)
    case .search: searchPath.append(route)
    }
  }

  func startReview() { practice = PracticeRequest(kind: .review) }
  func startPractice(item: ItemKey) { practice = PracticeRequest(kind: .item(item)) }

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

  // MARK: Derived learning state (forwarded to StudyModel)

  func masteryMap() -> [ItemKey: ItemMastery] { study.masteryMap() }
  func reviewQueue(now: Date = .now) -> [ExerciseKey] { study.reviewQueue(now: now) }
  func dueCount(onDayOf date: Date) -> Int { study.dueCount(onDayOf: date) }
  func nextDueDate() -> Date? { study.nextDueDate() }

  // MARK: Reminders

  func refreshReminders() async {
    await reminders.reschedule(
      enabled: settings.remindersEnabled, hour: settings.reminderHour,
      minute: settings.reminderMinute, streak: store.currentStreak(),
      hasActivityToday: store.hasActivity(on: .now), dueCount: { self.dueCount(onDayOf: $0) })
  }
}
