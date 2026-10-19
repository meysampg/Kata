import Foundation
import Observation

/// Mac-only settings, persisted in UserDefaults (`mac.*` keys). Settings shared with iOS live in
/// `AppSettings` (KataStore).
@MainActor @Observable
final class MacSettings {
  static let katasPerDayRange: ClosedRange<Int> = 1...5

  private let defaults: UserDefaults

  /// How many katas Today offers per day, counting the ones already done.
  var katasPerDay: Int {
    didSet { defaults.set(katasPerDay, forKey: "mac.katasPerDay") }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let stored = defaults.object(forKey: "mac.katasPerDay") as? Int ?? 2
    katasPerDay = min(max(stored, Self.katasPerDayRange.lowerBound), Self.katasPerDayRange.upperBound)
  }
}
