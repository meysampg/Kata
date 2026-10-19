#if DEBUG
import KataCore
import KataSRS
import KataStore
import SwiftData
import SwiftUI

/// Debug-only launch routing and demo data, used to capture screenshots from a device.
///
/// `-KataDemo YES` swaps in an in-memory store seeded through the public store APIs and a
/// throwaway settings suite, so the on-disk store and the real settings are never touched.
/// `-KataScreen <name>` (demo mode only) then routes straight to a screen:
/// `today`, `path`, `library`, `deck` (or `deck:<role>`, e.g. `deck:structure`), `practice`,
/// `search` (optionally `search:<query>`), `settings`.
@MainActor
enum DebugLaunch {
  static var isDemo: Bool { UserDefaults.standard.bool(forKey: "KataDemo") }

  static var screen: String? {
    isDemo ? UserDefaults.standard.string(forKey: "KataScreen") : nil
  }

  static func makeModel() -> AppModel {
    let suiteName = "kata.demo"
    UserDefaults.standard.removePersistentDomain(forName: suiteName)
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    return AppModel.make(container: AppModel.inMemoryContainer(), settings: AppSettings(defaults: defaults))
  }

  static func run(_ model: AppModel) async {
    guard isDemo else { return }
    seed(model)
    guard let screen else { return }
    let parts = screen.split(separator: ":", maxSplits: 1).map(String.init)
    let arg = parts.count > 1 ? parts[1] : nil
    let strategy = ItemKey(topic: "design-patterns", item: "strategy")
    switch parts[0] {
    case "today": model.selectedTab = .today
    case "path": model.selectedTab = .path
    case "library": model.selectedTab = .library
    case "deck":
      model.selectedTab = .library
      model.libraryPath.append(DeckRoute(key: strategy, role: arg))
    case "practice": model.startReview()
    case "search":
      model.selectedTab = .search
      model.searchQuery = arg ?? "state"
    case "settings": model.isSettingsPresented = true
    default: break
    }
  }

  private static func seed(_ model: AppModel) {
    let store = model.store
    let strategy = ItemKey(topic: "design-patterns", item: "strategy")
    guard let pack = model.library.pack(strategy.topic), pack.item(strategy.item) != nil else { return }
    let scheduler = model.settings.scheduler
    let cal = Calendar.current
    func day(_ ago: Int, hour: Int = 20) -> Date {
      let start = cal.startOfDay(for: .now)
      let date = cal.date(byAdding: .day, value: -ago, to: start) ?? start
      return min(cal.date(bySettingHour: hour, minute: 15, second: 0, of: date) ?? date, .now)
    }
    let keys = pack.exerciseKeys(for: strategy.item)
    func key(_ i: Int) -> ExerciseKey? { keys.indices.contains(i) ? keys[i] : nil }

    for role in pack.item(strategy.item)?.cards.map(\.role) ?? [] {
      store.markOpened(strategy, role: role, now: day(6))
    }
    store.markStudied(strategy, now: day(6))
    store.setBookmarked(strategy, true, now: day(5))
    store.setNote(strategy, "Compare with State: who picks the behavior?", now: day(5))

    // Learned over the past week; the older cards are due again today.
    let plan: [(index: Int, ago: Int)] = [(0, 6), (1, 6), (2, 5), (3, 4), (4, 3), (0, 2), (3, 1)]
    for step in plan {
      if let k = key(step.index) {
        store.record(.good, key: k, scheduler: scheduler, correct: true, now: day(step.ago))
      }
    }
  }
}
#endif
