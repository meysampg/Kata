import KataCore
import KataSRS
import OSLog
import SwiftData
import SwiftUI

/// Composition root: content, progress store, settings, navigation state.
@MainActor @Observable
final class AppModel {
  let container: ModelContainer
  let library: ContentLibrary
  /// Set when a pack failed to decode; the app then runs with an empty library.
  let libraryError: String?
  let store: ProgressStore
  let settings: AppSettings
  let reminders: ReminderScheduler
  /// Items that have a body in some pack. Registry-only items are "coming soon".
  let contentKeys: Set<ItemKey>

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
    self.library = library
    self.libraryError = libraryError
    self.settings = settings
    self.store = ProgressStore(container: container)
    self.reminders = ReminderScheduler()
    self.contentKeys = Set(library.allItemKeys())
  }

  // MARK: Factories

  static func live() -> AppModel {
    #if DEBUG
    if DebugLaunch.isDemo { return DebugLaunch.makeModel() }
    #endif
    let container: ModelContainer
    do {
      container = try ModelContainer(
        for: Schema(versionedSchema: KataSchemaV1.self), migrationPlan: KataMigrationPlan.self)
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
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    // An in-memory container for a valid schema cannot realistically fail.
    return try! ModelContainer(
      for: Schema(versionedSchema: KataSchemaV1.self), migrationPlan: KataMigrationPlan.self,
      configurations: config)
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

  // MARK: Derived learning state

  /// Mastery of every item that has a body, computed from stored cards.
  func masteryMap() -> [ItemKey: ItemMastery] {
    var byItem: [ItemKey: [FSRSCard]] = [:]
    for r in store.allCardRecords() where library.exercise(r.key) != nil {
      byItem[r.key.item, default: []].append(r.card)
    }
    var out: [ItemKey: ItemMastery] = [:]
    for key in contentKeys {
      let total = library.pack(key.topic)?.exerciseCount(for: key.item) ?? 0
      out[key] = MasteryCalculator.compute(cards: byItem[key] ?? [], totalExercises: total)
    }
    return out
  }

  /// Cards whose exercise still exists in the library.
  private func liveSnapshots() -> [PracticeCardSnapshot] {
    store.allCardRecords().filter { library.exercise($0.key) != nil }
      .map { PracticeCardSnapshot(key: $0.key, due: $0.card.due, lastReview: $0.card.lastReview) }
  }

  /// Exercises of studied items that have no card yet (e.g. added by a content update).
  private func newCandidates() -> [ExerciseKey] {
    let enrolled = Set(store.allCardRecords().map(\.key))
    let progress = store.allProgress()
    return contentKeys.sorted().filter { progress[$0]?.studiedAt != nil }.flatMap { key in
      (library.pack(key.topic)?.exerciseKeys(for: key.item) ?? []).filter { !enrolled.contains($0) }
    }
  }

  /// The review queue as of `now`: due cards plus new exercises of studied items.
  func reviewQueue(now: Date = .now) -> [ExerciseKey] {
    let builder = PracticeQueueBuilder(
      newLimit: settings.newExercisesPerDay, reviewLimit: settings.dailyReviewLimit)
    let day = DayKey(now, calendar: DayKey.gregorian()).string
    return builder.build(
      snapshots: liveSnapshots(), newCandidates: newCandidates(), now: now,
      seed: SeededRandom.hash("review@\(day)"))
  }

  /// Number of reviews that will be due by the end of the given day (for reminders).
  func dueCount(onDayOf date: Date) -> Int {
    let cal = Calendar.current
    let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: date)) ?? date
    return liveSnapshots().filter { $0.due < end }.count
  }

  func nextDueDate() -> Date? { liveSnapshots().map(\.due).min() }

  // MARK: Reminders

  func refreshReminders() async {
    await reminders.reschedule(
      enabled: settings.remindersEnabled, hour: settings.reminderHour,
      minute: settings.reminderMinute, streak: store.currentStreak(),
      hasActivityToday: store.hasActivity(on: .now), dueCount: { self.dueCount(onDayOf: $0) })
  }
}
