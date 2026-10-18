import Foundation
import KataSRS

/// What the learner answered.
public enum ExerciseResponse: Sendable, Hashable {
  /// Index into the exercise's authored `options`.
  case option(Int)
  /// 1-based line number.
  case line(Int)
  /// The learner's arrangement as indices into the authored (correct-order) `blocks`.
  case order([Int])
  /// Indices of key points the learner ticked after revealing the model answer.
  case recall(checked: Set<Int>)
}

public struct GradeFeedback: Sendable, Hashable {
  /// `why` of the option the learner picked.
  public var chosenWhy: String?
  /// `why` of the correct option.
  public var correctWhy: String?
  /// Explanation for tapLine/reorder.
  public var explanation: String?
  /// Key points not ticked in a recall exercise.
  public var missedPoints: [String]

  public init(
    chosenWhy: String? = nil, correctWhy: String? = nil, explanation: String? = nil,
    missedPoints: [String] = []
  ) {
    self.chosenWhy = chosenWhy
    self.correctWhy = correctWhy
    self.explanation = explanation
    self.missedPoints = missedPoints
  }
}

public struct GradeResult: Sendable, Hashable {
  public var correct: Bool
  public var suggestedRating: Rating
  public var feedback: GradeFeedback

  public init(correct: Bool, suggestedRating: Rating, feedback: GradeFeedback) {
    self.correct = correct; self.suggestedRating = suggestedRating; self.feedback = feedback
  }
}

public enum ExerciseGrader {
  /// Wrong gives `.again`; correct suggests `.good` (the learner may raise or lower it).
  /// Recall: all points -> good, at least half -> hard, fewer -> again.
  /// A response of the wrong shape for the exercise grades as wrong.
  public static func grade(_ exercise: Exercise, response: ExerciseResponse) -> GradeResult {
    switch (exercise.body, response) {
    case (.identify(_, let options), .option(let i)), (.choose(_, let options), .option(let i)):
      return gradeOptions(options, picked: i)
    case (.tapLine(_, let flaw, let explanation), .line(let n)):
      let ok = flaw.contains(n)
      return result(ok, GradeFeedback(explanation: explanation))
    case (.reorder(let blocks, let explanation), .order(let order)):
      let arranged = order.compactMap { blocks.indices.contains($0) ? blocks[$0] : nil }
      let ok = order.count == blocks.count && arranged == blocks
      return result(ok, GradeFeedback(explanation: explanation))
    case (.recall(_, let points), .recall(let checked)):
      let valid = checked.filter { points.indices.contains($0) }
      let missed = points.indices.filter { !valid.contains($0) }.map { points[$0] }
      let rating: Rating
      if points.isEmpty || valid.count == points.count { rating = .good }
      else if valid.count * 2 >= points.count { rating = .hard }
      else { rating = .again }
      return GradeResult(
        correct: rating != .again, suggestedRating: rating,
        feedback: GradeFeedback(missedPoints: missed))
    default:
      return result(false, GradeFeedback())
    }
  }

  private static func gradeOptions(_ options: [ExerciseOption], picked: Int) -> GradeResult {
    let correctWhy = options.first(where: \.correct)?.why
    guard options.indices.contains(picked) else {
      return result(false, GradeFeedback(correctWhy: correctWhy))
    }
    let chosen = options[picked]
    return result(chosen.correct, GradeFeedback(chosenWhy: chosen.why, correctWhy: correctWhy))
  }

  private static func result(_ ok: Bool, _ feedback: GradeFeedback) -> GradeResult {
    GradeResult(correct: ok, suggestedRating: ok ? .good : .again, feedback: feedback)
  }

  /// Stable presentation order for shuffled options/blocks, seeded by `(key, reps)` so answer
  /// positions cannot be memorised.
  public static func presentationOrder(count: Int, key: ExerciseKey, reps: Int) -> [Int] {
    SeededRandom.permutation(count: count, seed: SeededRandom.seed(key: key, reps: reps))
  }
}
