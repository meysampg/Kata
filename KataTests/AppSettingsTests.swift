import Foundation
import Testing

@testable import Kata

@MainActor
struct AppSettingsTests {
  func freshDefaults(_ name: String) -> UserDefaults {
    let d = UserDefaults(suiteName: name)!
    d.removePersistentDomain(forName: name)
    return d
  }

  @Test func defaults() {
    let s = AppSettings(defaults: freshDefaults("kata.tests.defaults"))
    #expect(!s.remindersEnabled)
    #expect(s.reminderHour == 20 && s.reminderMinute == 0)
    #expect(s.desiredRetention == 0.9)
    #expect(s.newExercisesPerDay == 10 && s.dailyReviewLimit == 100)
    #expect(s.codeFontSize == 14 && s.showLineNumbers)
    #expect(s.fsrsParameters.desiredRetention == 0.9)
  }

  @Test func persistsAcrossInstances() {
    let name = "kata.tests.persist"
    let s = AppSettings(defaults: freshDefaults(name))
    s.remindersEnabled = true
    s.reminderHour = 7
    s.reminderMinute = 45
    s.desiredRetention = 0.95
    s.newExercisesPerDay = 4
    s.dailyReviewLimit = 50
    s.codeFontSize = 17
    s.showLineNumbers = false

    let t = AppSettings(defaults: UserDefaults(suiteName: name)!)
    #expect(t.remindersEnabled && t.reminderHour == 7 && t.reminderMinute == 45)
    #expect(t.desiredRetention == 0.95 && t.fsrsParameters.desiredRetention == 0.95)
    #expect(t.newExercisesPerDay == 4 && t.dailyReviewLimit == 50)
    #expect(t.codeFontSize == 17 && !t.showLineNumbers)
  }

  @Test func outOfRangeStoredValuesAreClamped() {
    let name = "kata.tests.clamp"
    let d = freshDefaults(name)
    d.set(99.0, forKey: "settings.codeFontSize")
    d.set(0.5, forKey: "settings.desiredRetention")
    d.set(1000, forKey: "settings.dailyReviewLimit")
    d.set(99, forKey: "settings.reminderHour")
    let s = AppSettings(defaults: d)
    #expect(s.codeFontSize == 18)
    #expect(s.desiredRetention == 0.85)
    #expect(s.dailyReviewLimit == 300)
    #expect(s.reminderHour == 23)
  }

  @Test func reminderTimeRoundTrips() {
    let s = AppSettings(defaults: freshDefaults("kata.tests.time"))
    s.reminderTime = Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: .now)!
    #expect(s.reminderHour == 6 && s.reminderMinute == 30)
  }
}
