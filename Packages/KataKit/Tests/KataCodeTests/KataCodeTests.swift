import Foundation
import Testing
@testable import KataCode

private func lex(_ s: String) -> [CodeToken] { JavaLexer().tokenize(s) }
private func joined(_ t: [CodeToken]) -> String { t.map(\.text).joined() }
private func sig(_ s: String) -> [CodeToken] { lex(s).filter { $0.kind != .whitespace } }

@Suite struct KataCodeTests {
  @Test func keywordsVsIdentifiers() {
    let t = sig("public class Foo { int x; void run() {} }")
    #expect(t.first { $0.text == "public" }?.kind == .keyword)
    #expect(t.first { $0.text == "Foo" }?.kind == .type)
    #expect(t.first { $0.text == "x" }?.kind == .identifier)
    #expect(t.first { $0.text == "run" }?.kind == .function)
    #expect(sig("record var yield").allSatisfy { $0.kind == .keyword })
    #expect(sig("classy")[0].kind == .identifier)
  }

  @Test func nonSealed() {
    let t = sig("non-sealed class A")
    #expect(t[0] == CodeToken(kind: .keyword, text: "non-sealed"))
    #expect(sig("non - sealed").count == 3)
  }

  @Test func commentsAndDocComments() {
    #expect(sig("// hi\nx")[0] == CodeToken(kind: .comment, text: "// hi"))
    #expect(sig("/* a */")[0].kind == .comment)
    #expect(sig("/** d */")[0].kind == .docComment)
    #expect(sig("/**/")[0].kind == .comment)
    #expect(sig("/* open")[0].text == "/* open")
  }

  @Test func commentMarkersInsideStrings() {
    let t = sig(#"String s = "// not /* a comment */";"#)
    #expect(t.contains { $0.kind == .string && $0.text == #""// not /* a comment */""# })
    #expect(!t.contains { $0.kind == .comment })
  }

  @Test func textBlock() {
    let src = "String s = \"\"\"\n  hi \"quoted\"\n  \"\"\";\nint y;"
    let t = lex(src)
    let tb = t.first { $0.kind == .string }
    #expect(tb?.text == "\"\"\"\n  hi \"quoted\"\n  \"\"\"")
    #expect(joined(t) == src)
  }

  @Test func escapesInStringsAndChars() {
    #expect(sig(#""a\"b""#) == [CodeToken(kind: .string, text: #""a\"b""#)])
    #expect(sig(#"'\''"#)[0].kind == .string)
  }

  @Test func genericsEmitSingleAngles() {
    let t = sig("List<Map<String,Integer>> m")
    #expect(t.map(\.text) == ["List", "<", "Map", "<", "String", ",", "Integer", ">", ">", "m"])
  }

  @Test func numbers() {
    for n in ["0x1F_FFL", "0b1010", "1_000", "3.14f", "1e-9", "2.5E+3d", "100L", ".5", "017"] {
      let t = sig(n)
      #expect(t.count == 1 && t[0].kind == .number, "\(n)")
    }
  }

  @Test func annotations() {
    #expect(sig("@Override")[0] == CodeToken(kind: .annotation, text: "@Override"))
    let t = sig("@interface Foo")
    #expect(t[0].kind != .annotation)
    #expect(t[1] == CodeToken(kind: .keyword, text: "interface"))
  }

  @Test func unterminatedStringStopsAtLineEnd() {
    let t = lex("String s = \"oops\nint x;")
    #expect(t.first { $0.kind == .string }?.text == "\"oops")
    #expect(t.contains { $0.text == "int" && $0.kind == .keyword })
    #expect(joined(t) == "String s = \"oops\nint x;")
  }

  @Test func plainAndRegistry() {
    let p = HighlighterRegistry.shared.highlighter(for: "unknown-lang")
    #expect(p is PlainLexer)
    #expect(HighlighterRegistry.shared.highlighter(for: "Java") is JavaLexer)
    #expect(PlainLexer().tokenize("a b\nc").map(\.text).joined() == "a b\nc")
    #expect(PlainLexer().tokenize("").isEmpty)
  }

  @Test func multilineSplit() {
    let src = "a /* x\n y */ b\n\nc"
    let lines = CodeLines.split(lex(src))
    #expect(lines.count == 4)
    #expect(lines[0].last == CodeToken(kind: .comment, text: "/* x"))
    #expect(lines[1].first(where: { $0.kind == .comment })?.text == " y */")
    #expect(lines[2].isEmpty)
    #expect(lines[3].map(\.text) == ["c"])
    #expect(CodeLines.split([]).count == 1)
    let rejoined = lines.map { $0.map(\.text).joined() }.joined(separator: "\n")
    #expect(rejoined == src)
  }

  @Test func roundTripFuzz() {
    var rng = SeededRNG(seed: 42)
    let alphabet = Array("abcXYZ_$ \t\n\r0123456789.+-*/\\\"'@(){}[]<>;,=!&|éπ#`x") + ["\"\"\"", "/*", "*/", "//", "0x", "non-sealed", "@interface"].flatMap { Array($0) }
    let pieces = ["\"\"\"", "/*", "*/", "//", "0x1F", "non-sealed", "@interface", "class ", "1e+", "\u{1F600}", "e\u{301}"]
    for _ in 0..<500 {
      var s = ""
      for _ in 0..<Int.random(in: 0..<80, using: &rng) {
        if Int.random(in: 0..<6, using: &rng) == 0 { s += pieces.randomElement(using: &rng)! }
        else { s.append(alphabet.randomElement(using: &rng)!) }
      }
      let t = lex(s)
      #expect(joined(t) == s.unicodeScalars.reduce(into: "") { $0.unicodeScalars.append($1) })
      #expect(t.allSatisfy { !$0.text.isEmpty })
    }
  }

  @Test func performance2000Lines() {
    let line = "    public static <T extends Comparable<T>> List<T> sort(List<T> xs) { return xs; } // done \"s\" 0x1F\n"
    let src = String(repeating: line, count: 2000)
    let start = ContinuousClock.now
    let t = lex(src)
    let elapsed = ContinuousClock.now - start
    #expect(joined(t) == src)
    #expect(elapsed < .milliseconds(500), "took \(elapsed)")
  }
}

private struct SeededRNG: RandomNumberGenerator {
  var state: UInt64
  init(seed: UInt64) { state = seed }
  mutating func next() -> UInt64 {
    state &+= 0x9E3779B97F4A7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
    return z ^ (z >> 31)
  }
}
