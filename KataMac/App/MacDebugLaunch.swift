#if DEBUG
import AppKit
import KataCore
import KataSRS
import KataStore
import SwiftData
import SwiftUI

/// Debug-only launch routing and demo data, used to capture screenshots.
///
/// `-KataDemo YES` swaps in an in-memory store seeded through the public store APIs and a
/// throwaway settings suite, so the on-disk store and the real settings are never touched.
/// `-KataScreen <name>` (demo mode only) then routes straight to a screen:
/// `today`, `path`, `library`, `category:<id>`, `bookmarks`, `search` (optionally `search:<query>`),
/// `item` (or `item:<role>`, e.g. `item:structure`), `itempractice`, `kata`, `practice` (a review
/// session) and `settings`.
/// With `-KataScreen kata`, `-KataAutoRun YES` runs the checks once when the screen appears and
/// `-KataAutoSolve strategy` runs them, loads the reference solution and runs them again (a
/// no-UI end-to-end smoke; the snapshot waits for it). `-KataAutoRate good` then rates the pass.
/// `-KataSnapshot <file.png>` additionally writes the main window (and the Settings window, as
/// `<file>-settings.png`) to disk after the screen has settled, then quits: a screenshot that needs
/// no screen-recording permission.
@MainActor
enum DebugLaunch {
  static var isDemo: Bool { UserDefaults.standard.bool(forKey: "KataDemo") }

  static var screen: String? {
    isDemo ? UserDefaults.standard.string(forKey: "KataScreen") : nil
  }

  /// Counts debug jobs still running (kata auto-runs); the snapshot waits for zero.
  @MainActor @Observable
  final class Jobs {
    static let shared = Jobs()
    var running = 0
  }

  static var autoRun: Bool { isDemo && UserDefaults.standard.bool(forKey: "KataAutoRun") }
  static var autoSolve: String? { isDemo ? UserDefaults.standard.string(forKey: "KataAutoSolve") : nil }
  static var autoRate: String? { isDemo ? UserDefaults.standard.string(forKey: "KataAutoRate") : nil }

  /// Drives a kata session from launch arguments.
  static func driveKata(_ session: KataSessionModel) async {
    guard autoRun || autoSolve != nil else { return }
    Jobs.shared.running += 1
    defer { Jobs.shared.running -= 1 }
    await session.run()
    if let which = autoSolve, session.key.item == which {
      session.replaceFiles(session.kata.solution)
      await session.run()
      print("KataAutoSolve: passed=\(session.passed) checks=\(session.passedCount)/\(session.kata.checks.count) hints=\(session.hintsShown)")
      if let r = autoRate {
        let rating: Rating = ["again": .again, "hard": .hard, "good": .good, "easy": .easy][r] ?? .good
        if let scheduled = session.rate(rating) { print("KataAutoRate: \(rating) next due \(scheduled.card.due)") }
      }
    }
  }

  static func makeModel() -> MacAppModel {
    let suiteName = "kata.mac.demo"
    UserDefaults.standard.removePersistentDomain(forName: suiteName)
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    return MacAppModel.make(
      container: MacAppModel.inMemoryContainer(), settings: AppSettings(defaults: defaults),
      macSettings: MacSettings(defaults: defaults))
  }

  static func run(_ model: MacAppModel) async {
    guard isDemo else { return }
    seed(model)
    guard let screen else { return }
    let parts = screen.split(separator: ":", maxSplits: 1).map(String.init)
    let arg = parts.count > 1 ? parts[1] : nil
    let strategy = ItemKey(topic: "design-patterns", item: "strategy")
    switch parts[0] {
    case "today": model.show(.today)
    case "path": model.show(.path)
    case "library": model.show(.library)
    case "category": model.show(.category("design-patterns", arg ?? "behavioral"))
    case "bookmarks": model.show(.bookmarks)
    case "item":
      model.show(.library)
      model.open(strategy, role: arg)
    case "itempractice":
      model.show(.library)
      model.open(strategy, tab: .practice)
    case "kata":
      model.show(.library)
      model.open(strategy, tab: .kata)
    case "practice": model.startReview()
    case "search":
      model.searchQuery = arg ?? "state"
      model.show(.search)
    case "settings":
      try? await Task.sleep(for: .milliseconds(400))
      NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    default: break
    }
  }

  /// Writes window snapshots when `-KataSnapshot <path>` was passed, then terminates.
  static func snapshotIfRequested() async {
    guard isDemo, let path = UserDefaults.standard.string(forKey: "KataSnapshot") else { return }
    try? await Task.sleep(for: .seconds(2.5))
    var waited = 0
    while Jobs.shared.running > 0, waited < 600 {
      try? await Task.sleep(for: .milliseconds(100))
      waited += 1
    }
    try? await Task.sleep(for: .seconds(1))
    let base = URL(fileURLWithPath: path)
    for window in NSApp.windows where window.isVisible && window.contentView != nil {
      guard let view = window.contentView?.superview ?? window.contentView else { continue }
      let isSettings = window.title == "General" || window.title.hasSuffix("Settings")
      let url = isSettings
        ? base.deletingPathExtension().appendingPathExtension("settings.png") : base
      // The window server's own capture of just this window renders rulers and AppKit text
      // views faithfully; `cacheDisplay` below is the fallback.
      let capture = Process()
      capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
      capture.arguments = ["-x", "-o", "-l", String(window.windowNumber), url.path]
      try? FileManager.default.removeItem(at: url)
      if (try? capture.run()) != nil {
        capture.waitUntilExit()
        if capture.terminationStatus == 0, FileManager.default.fileExists(atPath: url.path) { continue }
      }
      guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
      view.cacheDisplay(in: view.bounds, to: rep)
      if let data = rep.representation(using: .png, properties: [:]) { try? data.write(to: url) }
    }
    NSApp.terminate(nil)
  }

  private static func seed(_ model: MacAppModel) {
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
