import Foundation
import UserNotifications

/// One planned local notification.
struct PlannedReminder: Equatable, Sendable {
  let identifier: String
  let fire: DateComponents
  let title: String
  let body: String
}

/// Schedules one-shot reminders for the next 7 days, each with that day's due count.
@MainActor
final class ReminderScheduler {
  nonisolated static let identifiers = (0..<7).map { "review-reminder-\($0)" }

  init() {}

  func requestAuthorization() async -> Bool {
    (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
  }

  func authorizationStatus() async -> UNAuthorizationStatus {
    await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
  }

  /// Replaces the pending reminders (ids `review-reminder-0...6`).
  func reschedule(
    enabled: Bool, hour: Int, minute: Int, streak: Int, hasActivityToday: Bool,
    dueCount: (Date) -> Int, now: Date = .now, calendar: Calendar = .current
  ) async {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: Self.identifiers)
    guard enabled else { return }
    let plan = Self.plan(
      hour: hour, minute: minute, streak: streak, hasActivityToday: hasActivityToday,
      dueCount: dueCount, now: now, calendar: calendar)
    for r in plan {
      let content = UNMutableNotificationContent()
      content.title = r.title
      content.body = r.body
      content.sound = .default
      let trigger = UNCalendarNotificationTrigger(dateMatching: r.fire, repeats: false)
      try? await center.add(UNNotificationRequest(identifier: r.identifier, content: content, trigger: trigger))
    }
  }

  // MARK: Pure planning (unit tested)

  /// Pure: decides which of the next 7 days get a reminder and what it says.
  /// Today is skipped when the time has passed, or when today already has activity and nothing is due.
  nonisolated static func plan(
    hour: Int, minute: Int, streak: Int, hasActivityToday: Bool, dueCount: (Date) -> Int,
    now: Date, calendar: Calendar
  ) -> [PlannedReminder] {
    let today = calendar.startOfDay(for: now)
    var out: [PlannedReminder] = []
    for offset in 0..<7 {
      guard let day = calendar.date(byAdding: .day, value: offset, to: today),
        let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
      else { continue }
      let due = dueCount(day)
      if offset == 0 {
        if fire <= now { continue }
        if hasActivityToday && due == 0 { continue }
      }
      out.append(
        PlannedReminder(
          identifier: identifiers[offset],
          fire: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire),
          title: "Time for a Kata",
          body: message(due: due, streak: streak)))
    }
    return out
  }

  nonisolated static func message(due: Int, streak: Int) -> String {
    if due > 0 {
      let reviews = due == 1 ? "1 review is due" : "\(due) reviews are due"
      return streak > 1 ? "\(reviews). Keep your \(streak)-day streak going." : "\(reviews)."
    }
    return "A few quiet minutes with a pattern. Pick one to study."
  }
}
