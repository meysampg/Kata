import Foundation
import KataSRS
import Testing

@testable import KataCore

@Suite struct GraderTests {
  let pack: Pack
  init() throws { pack = try Fixtures.miniPack() }
  func ex(_ id: String, _ item: String = "alpha") -> Exercise { pack.item(item)!.exercise(id)! }

  @Test func identifyAndChoose() {
    for id in ["spot-1", "pick-1"] {
      let e = ex(id)
      guard case .identify(_, let o) = e.body else {
        guard case .choose(_, let o) = e.body else { Issue.record("kind"); return }
        check(e, o); continue
      }
      check(e, o)
    }
  }

  func check(_ e: Exercise, _ options: [ExerciseOption]) {
    let right = options.firstIndex(where: \.correct)!
    let wrong = options.firstIndex(where: { !$0.correct })!
    let good = ExerciseGrader.grade(e, response: .option(right))
    #expect(good.correct && good.suggestedRating == .good)
    #expect(good.feedback.chosenWhy == options[right].why)
    let bad = ExerciseGrader.grade(e, response: .option(wrong))
    #expect(!bad.correct && bad.suggestedRating == .again)
    #expect(bad.feedback.chosenWhy == options[wrong].why)
    #expect(bad.feedback.correctWhy == options[right].why)
    #expect(!ExerciseGrader.grade(e, response: .option(99)).correct)
  }

  @Test func tapLine() {
    let e = ex("flaw-1")
    #expect(ExerciseGrader.grade(e, response: .line(2)).correct)
    let miss = ExerciseGrader.grade(e, response: .line(1))
    #expect(!miss.correct && miss.suggestedRating == .again)
    #expect(miss.feedback.explanation?.contains("concrete class") == true)
  }

  @Test func reorder() {
    let e = ex("order-1")
    #expect(ExerciseGrader.grade(e, response: .order([0, 1, 2])).correct)
    #expect(!ExerciseGrader.grade(e, response: .order([1, 0, 2])).correct)
    #expect(!ExerciseGrader.grade(e, response: .order([0, 1])).correct)
    #expect(!ExerciseGrader.grade(e, response: .order([0, 1, 7])).correct)
    #expect(!ExerciseGrader.grade(e, response: .order([0, 0, 0])).correct)
  }

  @Test func recallRatings() {
    let e = ex("recall-1")  // 3 key points
    let all = ExerciseGrader.grade(e, response: .recall(checked: [0, 1, 2]))
    #expect(all.suggestedRating == .good && all.correct && all.feedback.missedPoints.isEmpty)
    let two = ExerciseGrader.grade(e, response: .recall(checked: [0, 2]))
    #expect(two.suggestedRating == .hard && two.correct && two.feedback.missedPoints == ["Many implementations"])
    let one = ExerciseGrader.grade(e, response: .recall(checked: [1]))
    #expect(one.suggestedRating == .again && !one.correct)
    let none = ExerciseGrader.grade(e, response: .recall(checked: []))
    #expect(none.suggestedRating == .again && none.feedback.missedPoints.count == 3)
    #expect(ExerciseGrader.grade(e, response: .recall(checked: [9])).suggestedRating == .again)
  }

  @Test func recallHalfBoundary() {
    let e = Exercise(id: "r", prompt: "p", body: .recall(modelAnswer: [], keyPoints: ["a", "b", "c", "d"]))
    #expect(ExerciseGrader.grade(e, response: .recall(checked: [0, 1])).suggestedRating == .hard)
    #expect(ExerciseGrader.grade(e, response: .recall(checked: [0])).suggestedRating == .again)
  }

  @Test func wrongResponseShapeIsWrong() {
    #expect(!ExerciseGrader.grade(ex("flaw-1"), response: .option(0)).correct)
  }

  @Test func presentationOrderIsSeededByKeyAndReps() {
    let k = T.key("a")
    let a = ExerciseGrader.presentationOrder(count: 6, key: k, reps: 0)
    #expect(a == ExerciseGrader.presentationOrder(count: 6, key: k, reps: 0))
    #expect(Set(a) == Set(0..<6))
    let others = (1..<10).map { ExerciseGrader.presentationOrder(count: 6, key: k, reps: $0) }
    #expect(others.contains { $0 != a })
  }
}
