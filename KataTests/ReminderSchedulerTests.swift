import Foundation
import Testing

@testable import Kata

struct ReminderSchedulerTests {
  var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
  }

  func date(_ d: Int, _ h: Int, _ m: Int = 0) -> Date {
    cal.date(from: DateComponents(year: 2026, month: 3, day: d, hour: h, minute: m))!
  }

  @Test func planCoversSevenDaysWhenTimeIsAhead() {
    let plan = ReminderScheduler.plan(
      hour: 20, minute: 0, streak: 0, hasActivityToday: false, dueCount: { _ in 0 },
      now: date(10, 9), calendar: cal)
    #expect(plan.count == 7)
    #expect(plan.map(\.identifier) == ReminderScheduler.identifiers)
    #expect(plan[0].fire.day == 10 && plan[0].fire.hour == 20 && plan[0].fire.minute == 0)
    #expect(plan[6].fire.day == 16)
  }

  @Test func todayIsSkippedWhenTimeHasPassed() {
    let plan = ReminderScheduler.plan(
      hour: 8, minute: 0, streak: 0, hasActivityToday: false, dueCount: { _ in 3 },
      now: date(10, 9), calendar: cal)
    #expect(plan.count == 6)
    #expect(plan[0].identifier == "review-reminder-1")
    #expect(plan[0].fire.day == 11)
  }

  @Test func todayIsSkippedWhenAlreadyActiveAndNothingDue() {
    let skipped = ReminderScheduler.plan(
      hour: 20, minute: 0, streak: 2, hasActivityToday: true, dueCount: { _ in 0 },
      now: date(10, 9), calendar: cal)
    #expect(skipped.count == 6)
    let kept = ReminderScheduler.plan(
      hour: 20, minute: 0, streak: 2, hasActivityToday: true,
      dueCount: { d in cal.isDate(d, inSameDayAs: date(10, 9)) ? 2 : 0 },
      now: date(10, 9), calendar: cal)
    #expect(kept.count == 7)
  }

  @Test func messageReflectsDueCountAndStreak() {
    #expect(ReminderScheduler.message(due: 1, streak: 0) == "1 review is due.")
    #expect(ReminderScheduler.message(due: 5, streak: 1) == "5 reviews are due.")
    #expect(ReminderScheduler.message(due: 5, streak: 4) == "5 reviews are due. Keep your 4-day streak going.")
    #expect(ReminderScheduler.message(due: 0, streak: 9).contains("Pick one to study"))
  }
}
