import Foundation
import KataSRS

/// Suggests an FSRS rating for a passed kata (MAC_PLAN §5.3). The learner may override it.
public enum KataGrader {
  public static func suggest(
    hints: Int, revealed: Bool, activeMillis: Int, minutes: Int, runs: Int
  ) -> Rating {
    if revealed || hints >= 3 { return .again }
    if hints >= 1 { return .hard }
    let target = Double(minutes) * 60_000
    let active = Double(activeMillis)
    if active <= 0.6 * target && runs <= 3 { return .easy }
    if active <= 1.5 * target { return .good }
    return .hard
  }
}
