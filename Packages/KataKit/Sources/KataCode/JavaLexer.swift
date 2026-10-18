import Foundation

/// Single-pass Java lexer. Total: never crashes, and token texts concatenate to the source.
public struct JavaLexer: SyntaxHighlighter {
  public init() {}

  static let keywords: Set<String> = [
    "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class", "const",
    "continue", "default", "do", "double", "else", "enum", "extends", "final", "finally", "float",
    "for", "goto", "if", "implements", "import", "instanceof", "int", "interface", "long", "native",
    "new", "package", "private", "protected", "public", "return", "short", "static", "strictfp",
    "super", "switch", "synchronized", "this", "throw", "throws", "transient", "try", "void",
    "volatile", "while", "true", "false", "null", "_",
    // contextual
    "record", "sealed", "permits", "var", "yield", "when", "module", "non-sealed"
  ]

  public func tokenize(_ source: String) -> [CodeToken] {
    var l = Lexer(Array(source.unicodeScalars))
    return l.run()
  }

  private struct Lexer {
    let s: [Unicode.Scalar]
    var i = 0
    var out: [CodeToken] = []

    init(_ s: [Unicode.Scalar]) { self.s = s }

    func at(_ k: Int) -> Unicode.Scalar? { k < s.count ? s[k] : nil }

    mutating func emit(_ kind: TokenKind, _ from: Int, _ to: Int) {
      guard to > from else { return }
      var v = String.UnicodeScalarView()
      v.append(contentsOf: s[from..<to])
      out.append(CodeToken(kind: kind, text: String(v)))
    }

    static func isDigit(_ c: Unicode.Scalar) -> Bool { c.value >= 48 && c.value <= 57 }
    static func isHex(_ c: Unicode.Scalar) -> Bool {
      isDigit(c) || (c.value >= 65 && c.value <= 70) || (c.value >= 97 && c.value <= 102)
    }
    static func isIdentStart(_ c: Unicode.Scalar) -> Bool {
      if c.value < 128 {
        return (c.value >= 65 && c.value <= 90) || (c.value >= 97 && c.value <= 122) || c == "_" || c == "$"
      }
      return Character(c).isLetter
    }
    static func isIdentPart(_ c: Unicode.Scalar) -> Bool {
      isIdentStart(c) || isDigit(c) || (c.value >= 128 && Character(c).isNumber)
    }
    static func isSpace(_ c: Unicode.Scalar) -> Bool {
      c == " " || c == "\t" || c == "\n" || c == "\r" || c == "\u{0C}"
    }

    mutating func run() -> [CodeToken] {
      while i < s.count {
        let c = s[i]
        if Self.isSpace(c) {
          let st = i
          while i < s.count, Self.isSpace(s[i]) { i += 1 }
          emit(.whitespace, st, i)
        } else if c == "/", at(i + 1) == "/" {
          let st = i
          while i < s.count, s[i] != "\n" { i += 1 }
          emit(.comment, st, i)
        } else if c == "/", at(i + 1) == "*" {
          let st = i
          let isDoc = at(i + 2) == "*" && at(i + 3) != "/"
          i += 2
          while i < s.count, !(s[i] == "*" && at(i + 1) == "/") { i += 1 }
          i = min(i + 2, s.count)
          emit(isDoc ? .docComment : .comment, st, i)
        } else if c == "\"", at(i + 1) == "\"", at(i + 2) == "\"" {
          textBlock()
        } else if c == "\"" || c == "'" {
          quoted(c)
        } else if Self.isDigit(c) || (c == "." && at(i + 1).map(Self.isDigit) == true) {
          number()
        } else if c == "@", let n = at(i + 1), Self.isIdentStart(n), !matches("interface", at: i + 1) {
          let st = i
          i += 1
          while i < s.count, Self.isIdentPart(s[i]) || (s[i] == "." && at(i + 1).map(Self.isIdentStart) == true) { i += 1 }
          emit(.annotation, st, i)
        } else if Self.isIdentStart(c) {
          identifier()
        } else if "(){}[];,.".unicodeScalars.contains(c) {
          emit(.punctuation, i, i + 1)
          i += 1
        } else {
          emit(.operator, i, i + 1)
          i += 1
        }
      }
      return out
    }

    func matches(_ word: String, at k: Int) -> Bool {
      var j = k
      for u in word.unicodeScalars {
        guard at(j) == u else { return false }
        j += 1
      }
      return !(at(j).map(Self.isIdentPart) ?? false)
    }

    mutating func textBlock() {
      let st = i
      i += 3
      while i < s.count {
        if s[i] == "\\" { i = min(i + 2, s.count); continue }
        if s[i] == "\"", at(i + 1) == "\"", at(i + 2) == "\"" { i += 3; break }
        i += 1
      }
      emit(.string, st, i)
    }

    mutating func quoted(_ q: Unicode.Scalar) {
      let st = i
      i += 1
      while i < s.count, s[i] != "\n" {
        if s[i] == "\\" {
          i += 1
          if i < s.count, s[i] != "\n" { i += 1 }
          continue
        }
        if s[i] == q { i += 1; break }
        i += 1
      }
      emit(.string, st, i)
    }

    mutating func digits(_ pred: (Unicode.Scalar) -> Bool) {
      while i < s.count, pred(s[i]) || s[i] == "_" { i += 1 }
    }

    mutating func number() {
      let st = i
      if s[i] == "0", let x = at(i + 1), x == "x" || x == "X" {
        i += 2
        digits(Self.isHex)
      } else if s[i] == "0", let x = at(i + 1), x == "b" || x == "B" {
        i += 2
        digits(Self.isDigit)
      } else {
        digits(Self.isDigit)
        if at(i) == ".", at(i + 1).map(Self.isDigit) == true || at(i + 1).map(Self.isIdentStart) != true {
          i += 1
          digits(Self.isDigit)
        }
        if let e = at(i), e == "e" || e == "E" {
          var j = i + 1
          if let sg = at(j), sg == "+" || sg == "-" { j += 1 }
          if at(j).map(Self.isDigit) == true {
            i = j
            digits(Self.isDigit)
          }
        }
      }
      if let f = at(i), "lLfFdD".unicodeScalars.contains(f) { i += 1 }
      emit(.number, st, i)
    }

    mutating func identifier() {
      let st = i
      while i < s.count, Self.isIdentPart(s[i]) { i += 1 }
      var word = String(String.UnicodeScalarView(s[st..<i]))
      if word == "non", at(i) == "-", matches("sealed", at: i + 1) {
        i += 7
        word = "non-sealed"
      }
      let kind: TokenKind
      if Self.isKeyword(word) {
        kind = .keyword
      } else if let f = word.unicodeScalars.first, f.properties.isUppercase {
        kind = .type
      } else {
        var j = i
        while let c = at(j), c == " " || c == "\t" { j += 1 }
        kind = at(j) == "(" ? .function : .identifier
      }
      emit(kind, st, i)
    }

    static func isKeyword(_ w: String) -> Bool { JavaLexer.keywords.contains(w) }
  }
}
