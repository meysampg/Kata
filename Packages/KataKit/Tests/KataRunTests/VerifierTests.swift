#if os(macOS)
  import Foundation
  import Testing

  @testable import KataCore
  @testable import KataRun

  /// The pass/fail rules per kata kind, on synthetic reports (no JDK needed).
  @Suite struct KataVerifierRuleTests {
    func kata(_ kind: KataKind, starterCompiles: Bool = true) -> Kata {
      Kata(
        itemId: "demo", kind: kind, title: "Demo", minutes: 10, task: [.lead("x")],
        starter: [KataFile(name: "A.java", source: "")], solution: [KataFile(name: "A.java", source: "")],
        tests: [KataFile(name: "T.java", source: "")],
        checks: [
          KataCheckSpec(id: "b1", kind: .behaviour, title: "b1"),
          KataCheckSpec(id: "d1", kind: .design, title: "d1"),
        ], hints: [], starterCompiles: starterCompiles)
    }

    func report(_ statuses: [(String, String, String)], compile: Bool = true) -> KataReport {
      var lines = [#"{"type":"compile","ok":\#(compile),"diagnostics":[]}"#]
      for (id, kind, status) in statuses {
        lines.append(#"{"type":"check","id":"\#(id)","kind":"\#(kind)","status":"\#(status)","message":"m"}"#)
      }
      lines.append(#"{"type":"done","millis":1}"#)
      return KataReport.parse(ndjson: lines.joined(separator: "\n"))
    }

    let allPass = [("b1", "behaviour", "pass"), ("d1", "design", "pass")]
    let designFails = [("b1", "behaviour", "pass"), ("d1", "design", "fail")]
    let behaviourFails = [("b1", "behaviour", "fail"), ("d1", "design", "pass")]

    @Test func referenceMustPassEverythingInOrder() {
      let k = kata(.refactor)
      #expect(KataVerifier.referenceProblems(report(allPass), kata: k).isEmpty)
      #expect(!KataVerifier.referenceProblems(report(designFails), kata: k).isEmpty)
      #expect(!KataVerifier.referenceProblems(report(allPass.reversed()), kata: k).isEmpty)
      #expect(!KataVerifier.referenceProblems(report(allPass, compile: false), kata: k).isEmpty)
      #expect(!KataVerifier.referenceProblems(report([("b1", "behaviour", "timeout"), ("d1", "design", "pass")]), kata: k).isEmpty)
    }

    @Test func refactorStarterKeepsBehaviourGreenAndFailsDesign() {
      let k = kata(.refactor)
      #expect(KataVerifier.starterProblems(report(designFails), kata: k).isEmpty)
      #expect(!KataVerifier.starterProblems(report(allPass), kata: k).isEmpty)
      #expect(!KataVerifier.starterProblems(report(behaviourFails), kata: k).isEmpty)
      #expect(!KataVerifier.starterProblems(report(designFails, compile: false), kata: k).isEmpty)
    }

    @Test func fixStarterMustFailABehaviourCheck() {
      let k = kata(.fix)
      #expect(KataVerifier.starterProblems(report(behaviourFails), kata: k).isEmpty)
      #expect(!KataVerifier.starterProblems(report(designFails), kata: k).isEmpty)
    }

    @Test func implementStarterMustFailSomethingButMayNotCompileWhenAllowed() {
      #expect(KataVerifier.starterProblems(report(designFails), kata: kata(.implement)).isEmpty)
      #expect(!KataVerifier.starterProblems(report(allPass), kata: kata(.implement)).isEmpty)
      #expect(!KataVerifier.starterProblems(report([], compile: false), kata: kata(.implement)).isEmpty)
      #expect(KataVerifier.starterProblems(report([], compile: false), kata: kata(.implement, starterCompiles: false)).isEmpty)
    }

    @Test func crashesAndTimeoutsAreProblems() {
      var r = report(allPass)
      r.timedOut = true
      #expect(!KataVerifier.referenceProblems(r, kata: kata(.refactor)).isEmpty)
      #expect(!KataVerifier.starterProblems(KataReport.parse(ndjson: ""), kata: kata(.refactor)).isEmpty)
    }

    @Test func medianOfRunTimes() {
      #expect(KataVerifier.median([]) == nil)
      #expect(KataVerifier.median([5, 1, 3]) == 3)
      #expect(KataVerifier.median([4, 1, 3, 2]) == 2)
    }
  }
#endif
