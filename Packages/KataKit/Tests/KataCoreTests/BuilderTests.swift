import Foundation
import Testing

@testable import KataCore

@Suite struct BuilderTests {
  @Test func stripsMarkersAndComputesRanges() throws {
    let src = """
      import x;

      // [[a
      class A {
          // [[b
          int x;
          // ]]
      }
      // ]]
      class B {}

      """
    let r = try MarkerStripper.strip(src)
    #expect(r.source == "import x;\n\nclass A {\n    int x;\n}\nclass B {}")
    #expect(r.regions["a"] == LineRange(start: 3, end: 5))
    #expect(r.regions["b"] == LineRange(start: 4, end: 4))
    #expect(!r.source.contains("[["))
  }

  @Test func indentedMarkersAndCRLF() throws {
    let r = try MarkerStripper.strip("class A {\r\n    //   [[ inner \r\n    int x;\r\n    // ]]\r\n}\r\n")
    #expect(r.source == "class A {\n    int x;\n}")
    #expect(r.regions["inner"] == LineRange(start: 2, end: 2))
  }

  @Test func markerErrors() {
    #expect(throws: MarkerError.self) { try MarkerStripper.strip("// [[a\nint x;\n") }
    #expect(throws: MarkerError.self) { try MarkerStripper.strip("int x;\n// ]]\n") }
    #expect(throws: MarkerError.self) { try MarkerStripper.strip("// [[a\n// ]]\n") }
    #expect(throws: MarkerError.self) { try MarkerStripper.strip("// [[a\nx;\n// ]]\n// [[a\ny;\n// ]]\n") }
    #expect(throws: MarkerError.self) { try MarkerStripper.strip("// [[bad id\nx;\n// ]]\n") }
  }

  @Test func ordinaryCommentsAreKept() throws {
    let r = try MarkerStripper.strip("// just a comment\nint x; // [[ not a marker line\n")
    #expect(r.source == "// just a comment\nint x; // [[ not a marker line")
    #expect(r.regions.isEmpty)
  }

  @Test func buildsMiniTopic() throws {
    let pack = try Fixtures.miniPack()
    #expect(pack.items.map(\.id) == ["alpha", "beta"])
    guard case .code(let code) = pack.item("alpha")!.cards[1].content else { Issue.record("no code"); return }
    #expect(code.regions["iface"] == LineRange(start: 1, end: 3))
    #expect(code.regions["impl"] == LineRange(start: 5, end: 7))
    #expect(code.regions["use"]?.lines.count == 2)
    #expect(!code.source.contains("[["))
    #expect(!code.source.contains("// ]]"))
    #expect(code.lines[code.regions["use"]!.start - 1].contains("new Polite()"))
  }

  @Test func outputIsDeterministicAndSorted() throws {
    let a = try PackBuilder.encode(Fixtures.miniPack())
    let b = try PackBuilder.encode(Fixtures.miniPack())
    #expect(a == b)
    let text = String(decoding: a, as: UTF8.self)
    #expect(!text.dropLast().contains("\n"))
    #expect(text.hasSuffix("}\n"))
    // sorted keys: "items" precedes "topic"
    #expect(text.range(of: "\"items\"")!.lowerBound < text.range(of: "\"topic\"")!.lowerBound)
  }

  @Test func onlyFilterLimitsItems() {
    let report = PackBuilder.load(topicDirectory: Fixtures.miniTopic, only: ["beta"])
    #expect(report.items.map(\.id) == ["beta"])
    #expect(report.missingItems.isEmpty)
    #expect(!report.hasErrors)
  }

  @Test func reportsMissingAndOrphanDirectories() {
    let report = PackBuilder.load(topicDirectory: Fixtures.broken("orphan-and-missing"))
    #expect(report.missingItems == ["missing"])
    #expect(report.issues.contains { $0.message.contains("not in the topic registry") && $0.path.hasSuffix("stray") })
  }

  @Test func buildFailsOnBadMarkersAndUnknownKeys() {
    #expect(throws: BuildFailure.self) { try PackBuilder.build(topicDirectory: Fixtures.broken("bad-markers")) }
    #expect(throws: BuildFailure.self) { try PackBuilder.build(topicDirectory: Fixtures.broken("unknown-key")) }
  }

  @Test func javaUnitsSubstitutePlaceholder() throws {
    let units = JavaUnits.units(for: try Fixtures.miniPack())
    let names = units.map(\.name)
    #expect(names.contains("alpha--code-Alpha"))
    #expect(names.contains("alpha--spot-1") && names.contains("alpha--flaw-1") && names.contains("alpha--order-1"))
    #expect(!names.contains("alpha--pick-1"))
    let code = units.first { $0.name == "alpha--code-Alpha" }!
    #expect(code.expectedOutput == "Hello, Kata")
    #expect(code.files["Alpha.java"]?.contains("[[") == false)
    let order = units.first { $0.name == "alpha--order-1" }!.files["Unit.java"]!
    #expect(order.contains("Greeter g = new Polite();\nString s = g.greet(\"x\");\nSystem.out.println(s);\n} }"))
    #expect(!order.contains("{{code}}"))
  }

  @Test func compileRenderKeepsIndentation() {
    let spec = CompileSpec(template: ["class A {", "    {{code}}", "}"])
    #expect(spec.render(code: ["a();", "b();"]) == ["class A {", "    a();", "    b();", "}"])
  }
}
