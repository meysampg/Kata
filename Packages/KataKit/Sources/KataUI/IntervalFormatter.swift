import Foundation
import KataSRS

/// Short English interval labels for rating previews ("10 min", "3 h", "5 d", "2 mo", "1.2 y").
public enum IntervalFormatter {
  public static func short(_ r: SchedulingResult, from now: Date) -> String {
    short(seconds: r.card.due.timeIntervalSince(now), scheduledDays: r.scheduledDays)
  }

  public static func short(seconds: TimeInterval, scheduledDays: Double) -> String {
    if scheduledDays <= 0 {
      let minutes = max(1, Int((max(0, seconds) / 60).rounded()))
      if minutes < 60 { return "\(minutes) min" }
      let hours = max(1, Int((Double(minutes) / 60).rounded()))
      if hours < 24 { return "\(hours) h" }
      return "\(max(1, Int((Double(hours) / 24).rounded()))) d"
    }
    let days = max(1, Int(scheduledDays.rounded()))
    if days < 30 { return "\(days) d" }
    if days < 365 { return "\(max(1, Int((Double(days) / 30).rounded()))) mo" }
    let years = (Double(days) / 365 * 10).rounded() / 10
    let text = years == years.rounded() ? String(Int(years)) : String(format: "%.1f", years)
    return "\(text) y"
  }
}
