import Foundation
import KataSRS
import Observation

/// User settings, persisted in UserDefaults (`settings.*` keys) through `didSet`.
@MainActor @Observable
public final class AppSettings {
  public static let retentionOptions: [Double] = [0.85, 0.90, 0.95]
  public static let codeFontRange: ClosedRange<Double> = 12...18
  public static let newPerDayRange: ClosedRange<Int> = 1...30
  public static let reviewLimitRange: ClosedRange<Int> = 10...300

  private let defaults: UserDefaults

  public var remindersEnabled: Bool { didSet { defaults.set(remindersEnabled, forKey: "settings.remindersEnabled") } }
  public var reminderHour: Int { didSet { defaults.set(reminderHour, forKey: "settings.reminderHour") } }
  public var reminderMinute: Int { didSet { defaults.set(reminderMinute, forKey: "settings.reminderMinute") } }
  public var desiredRetention: Double { didSet { defaults.set(desiredRetention, forKey: "settings.desiredRetention") } }
  public var newExercisesPerDay: Int { didSet { defaults.set(newExercisesPerDay, forKey: "settings.newExercisesPerDay") } }
  public var dailyReviewLimit: Int { didSet { defaults.set(dailyReviewLimit, forKey: "settings.dailyReviewLimit") } }
  public var codeFontSize: Double { didSet { defaults.set(codeFontSize, forKey: "settings.codeFontSize") } }
  public var showLineNumbers: Bool { didSet { defaults.set(showLineNumbers, forKey: "settings.showLineNumbers") } }

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    remindersEnabled = defaults.object(forKey: "settings.remindersEnabled") as? Bool ?? false
    reminderHour = min(max(defaults.object(forKey: "settings.reminderHour") as? Int ?? 20, 0), 23)
    reminderMinute = min(max(defaults.object(forKey: "settings.reminderMinute") as? Int ?? 0, 0), 59)
    let retention = defaults.object(forKey: "settings.desiredRetention") as? Double ?? 0.9
    desiredRetention = Self.retentionOptions.min { abs($0 - retention) < abs($1 - retention) } ?? 0.9
    newExercisesPerDay = Self.clamp(
      defaults.object(forKey: "settings.newExercisesPerDay") as? Int ?? 10, Self.newPerDayRange)
    dailyReviewLimit = Self.clamp(
      defaults.object(forKey: "settings.dailyReviewLimit") as? Int ?? 100, Self.reviewLimitRange)
    codeFontSize = min(
      max(defaults.object(forKey: "settings.codeFontSize") as? Double ?? 14, Self.codeFontRange.lowerBound),
      Self.codeFontRange.upperBound)
    showLineNumbers = defaults.object(forKey: "settings.showLineNumbers") as? Bool ?? true
  }

  private static func clamp(_ v: Int, _ r: ClosedRange<Int>) -> Int { min(max(v, r.lowerBound), r.upperBound) }

  public var fsrsParameters: FSRSParameters { FSRSParameters(desiredRetention: desiredRetention) }

  public var scheduler: FSRSScheduler { FSRSScheduler(parameters: fsrsParameters) }

  public var codeFontPoints: CGFloat { CGFloat(codeFontSize) }

  /// Reminder time as a `Date` today, for a `DatePicker`.
  public var reminderTime: Date {
    get {
      Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: .now) ?? .now
    }
    set {
      let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
      reminderHour = c.hour ?? 20
      reminderMinute = c.minute ?? 0
    }
  }
}
