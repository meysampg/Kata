import Foundation

/// Authoring rules for katas (MAC_PLAN §3.1). Errors fail validation; warnings are advisory.
public enum KataValidator {
  /// The exercise id the kata's FSRS card uses; no exercise may take it.
  public static let reservedExerciseId = "kata"

  public static let titleMaxLength = 60
  public static let taskMaxWords = 180
  public static let minutesRange = 10...40
  public static let hintCount = 3
  public static let hintMaxWords = 50
  public static let hintCodeMaxLines = 10
  public static let starterMaxLines = 120
  public static let solutionMaxLines = 150
  public static let columnWarn = 80, columnError = 100
  public static let maxTimeoutSeconds = 30
  public static let stressRunsRange = 1...200

  private static let checkAnnotation = try! NSRegularExpression(
    pattern: #"@Check\s*\(([^)]*)\)"#)
  private static let idArgument = try! NSRegularExpression(pattern: #"\bid\s*=\s*"([^"]*)""#)
  private static let topLevelType = try! NSRegularExpression(
    pattern: #"^((?:public|final|abstract|sealed|non-sealed|static|strictfp)\s+)*(class|interface|enum|record|@interface)\s+([A-Za-z_][A-Za-z0-9_]*)"#,
    options: [.anchorsMatchLines])
  private static let exitCall = try! NSRegularExpression(
    pattern: #"\bSystem\s*\.\s*exit\s*\(|\bRuntime\b[^;]*\.\s*(exit|halt)\s*\("#)

  public static func validate(katas: [Kata], topic: Topic, options: ValidationOptions = .init())
    -> [ValidationIssue]
  {
    var issues: [ValidationIssue] = []
    let registry = Set(topic.items.map(\.id))
    var seen = Set<ItemID>()
    for kata in katas where options.items?.contains(kata.itemId) ?? true {
      if !registry.contains(kata.itemId) {
        issues.append(.init(.error, "\(topic.id)/\(kata.itemId)/kata", "kata belongs to an item that is not in the registry"))
      }
      if !seen.insert(kata.itemId).inserted {
        issues.append(.init(.error, "\(topic.id)/\(kata.itemId)/kata", "duplicate kata"))
      }
      issues += validate(kata, topicId: topic.id, registry: registry)
    }
    if options.requireAllKatas && options.items == nil {
      let have = Set(katas.map(\.itemId))
      for meta in topic.items where !have.contains(meta.id) {
        issues.append(.init(.error, "\(topic.id)/\(meta.id)", "registry item has no kata/"))
      }
    }
    return issues
  }

  public static func validate(_ kata: Kata, topicId: TopicID, registry: Set<ItemID>) -> [ValidationIssue] {
    var issues: [ValidationIssue] = []
    let base = "\(topicId)/\(kata.itemId)/kata"
    func err(_ m: String, _ file: String? = nil) {
      issues.append(.init(.error, file.map { "\(base)/\($0)" } ?? base, m))
    }
    func warn(_ m: String, _ file: String? = nil) {
      issues.append(.init(.warning, file.map { "\(base)/\($0)" } ?? base, m))
    }

    // Header.
    let title = kata.title.trimmingCharacters(in: .whitespaces)
    if title.isEmpty { err("empty title") }
    if kata.title.count > titleMaxLength {
      err("title has \(kata.title.count) characters (max \(titleMaxLength))")
    }
    if !minutesRange.contains(kata.minutes) {
      err("minutes \(kata.minutes) is outside \(minutesRange.lowerBound)...\(minutesRange.upperBound)")
    }
    if kata.timeoutSeconds < 1 || kata.timeoutSeconds > maxTimeoutSeconds {
      err("timeoutSeconds \(kata.timeoutSeconds) is outside 1...\(maxTimeoutSeconds)")
    }
    if let runs = kata.stressRuns, !stressRunsRange.contains(runs) {
      err("stressRuns \(runs) is outside \(stressRunsRange.lowerBound)...\(stressRunsRange.upperBound)")
    }
    if !kata.starterCompiles && kata.kind != .implement {
      err("starterCompiles: false is only allowed for implement katas")
    }

    // Task and hints.
    if kata.task.isEmpty { err("empty task") }
    let taskWords = kata.task.flatMap(\.texts).reduce(0) { $0 + PackValidator.words($1) }
    if taskWords > taskMaxWords { err("task has \(taskWords) words (max \(taskMaxWords))") }

    if kata.hints.count != hintCount {
      err("expected exactly \(hintCount) hints, found \(kata.hints.count)")
    }
    for (i, hint) in kata.hints.enumerated() {
      let n = i + 1
      if hint.isEmpty { err("hint \(n) is empty") }
      let words = hint.flatMap(\.texts).reduce(0) { $0 + PackValidator.words($1) }
      if words > hintMaxWords { err("hint \(n) has \(words) words (max \(hintMaxWords))") }
      for block in hint {
        if case .code(_, let lines) = block {
          if n != hintCount { err("hint \(n) has a code block (only hint \(hintCount) may)") }
          if lines.count > hintCodeMaxLines {
            err("hint \(n) code has \(lines.count) lines (max \(hintCodeMaxLines))")
          }
        }
      }
    }
    let proseBlocks = kata.task + kata.hints.flatMap { $0 }
    for text in proseBlocks.flatMap(\.texts) {
      for m in PackValidator.kataLink.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
        guard let r = Range(m.range(at: 1), in: text) else { continue }
        if !registry.contains(String(text[r])) {
          err("link 'kata:\(text[r])' does not resolve to a registry item")
        }
      }
    }

    // Files.
    fileChecks(kata, err: err, warn: warn)

    // Checks.
    var ids = Set<String>()
    for c in kata.checks {
      if !PackValidator.isKebab(c.id) { err("check id '\(c.id)' is not kebab-case") }
      if !ids.insert(c.id).inserted { err("duplicate check id '\(c.id)'") }
      if c.title.trimmingCharacters(in: .whitespaces).isEmpty { err("check '\(c.id)' has an empty title") }
    }
    let behaviour = kata.checks.filter { $0.kind == .behaviour }.count
    let design = kata.checks.filter { $0.kind == .design }.count
    switch kata.kind {
    case .refactor:
      if behaviour < 2 { err("refactor katas need at least 2 behaviour checks (found \(behaviour))") }
      if design < 2 { err("refactor katas need at least 2 design checks (found \(design))") }
    case .implement:
      if kata.checks.count < 4 { err("implement katas need at least 4 checks (found \(kata.checks.count))") }
    case .fix:
      if behaviour < 1 { err("fix katas need at least 1 behaviour check") }
    }

    // The declared checks must be the @Check ids in the tests, in source order.
    let declared = kata.tests.flatMap { checkIds(in: $0.source) }
    if declared.map(\.id) != kata.checks.map(\.id) {
      err(
        "checks [\(kata.checks.map(\.id).joined(separator: ", "))] do not match the @Check ids in the tests [\(declared.map(\.id).joined(separator: ", "))]"
      )
    } else {
      for (spec, found) in zip(kata.checks, declared) where spec.kind != found.kind {
        err("check '\(spec.id)' is \(spec.kind.rawValue) in kata.json but \(found.kind.rawValue) in the test")
      }
    }
    return issues
  }

  // MARK: Files

  private static func fileChecks(
    _ kata: Kata, err: (String, String?) -> Void, warn: (String, String?) -> Void
  ) {
    func lines(_ s: String) -> [Substring] {
      var l = s.split(separator: "\n", omittingEmptySubsequences: false)
      if l.last?.isEmpty == true { l.removeLast() }
      return l
    }
    func javaFileChecks(_ f: KataFile, dir: String, maxLines: Int) {
      let path = "\(dir)/\(f.name)"
      let ls = lines(f.source)
      if ls.count > maxLines { err("\(ls.count) lines (max \(maxLines))", path) }
      var wide: [Int] = [], tooWide: [Int] = []
      for (i, l) in ls.enumerated() {
        if l.count > columnError { tooWide.append(i + 1) } else if l.count > columnWarn { wide.append(i + 1) }
      }
      if !tooWide.isEmpty { err("line(s) \(list(tooWide)) exceed \(columnError) columns", path) }
      if !wide.isEmpty { warn("line(s) \(list(wide)) exceed \(columnWarn) columns", path) }
      if f.source.range(of: "\t") != nil { warn("contains tab characters", path) }
      if exitCall.firstMatch(in: f.source, range: NSRange(f.source.startIndex..., in: f.source)) != nil {
        err("calls System.exit or Runtime.exit/halt", path)
      }
      for (_, kind, name) in topLevelTypes(in: f.source) where kind.hasPrefix("public") {
        err("top-level type \(name) must not be public (files may be renamed)", path)
      }
    }

    for f in kata.starter { javaFileChecks(f, dir: "starter", maxLines: starterMaxLines) }
    for f in kata.solution { javaFileChecks(f, dir: "solution", maxLines: solutionMaxLines) }
    for f in kata.tests where f.source.range(of: #"System\s*\.\s*exit"#, options: .regularExpression) != nil {
      err("calls System.exit", "tests/\(f.name)")
    }

    if kata.starter.isEmpty { err("no starter files", nil) }
    if kata.solution.isEmpty { err("no solution files", nil) }
    if kata.tests.isEmpty { err("no test files", nil) }

    let starterNames = Set(kata.starter.map(\.name))
    for name in kata.readOnly.sorted() {
      guard starterNames.contains(name) else {
        err("readOnly file '\(name)' is not a starter file", nil)
        continue
      }
      let a = kata.starter.first { $0.name == name }?.source
      let b = kata.solution.first { $0.name == name }?.source
      if a != b { err("read-only file '\(name)' must be identical in starter and solution", nil) }
    }

    // Test files must not redeclare solution types.
    let solutionTypes = Set(kata.solution.flatMap { topLevelTypes(in: $0.source).map(\.name) })
    for t in kata.tests {
      for (_, _, name) in topLevelTypes(in: t.source) where solutionTypes.contains(name) {
        err("declares type \(name), which the solution also declares", "tests/\(t.name)")
      }
    }
  }

  private static func list(_ lines: [Int]) -> String {
    let shown = lines.prefix(5).map(String.init).joined(separator: ", ")
    return lines.count > 5 ? shown + ", ..." : shown
  }

  /// Top-level declarations (column 0) of a Java source: (modifiers+keyword, keyword, name).
  static func topLevelTypes(in source: String) -> [(prefix: String, kind: String, name: String)] {
    let range = NSRange(source.startIndex..., in: source)
    return topLevelType.matches(in: source, range: range).compactMap { m in
      guard let all = Range(m.range, in: source), let name = Range(m.range(at: 3), in: source) else {
        return nil
      }
      return (String(source[all]), String(source[all]), String(source[name]))
    }
  }

  /// `@Check(id = "...", kind = Kind.DESIGN)` annotations in source order.
  static func checkIds(in source: String) -> [(id: String, kind: CheckKind)] {
    let range = NSRange(source.startIndex..., in: source)
    return checkAnnotation.matches(in: source, range: range).compactMap { m in
      guard let args = Range(m.range(at: 1), in: source) else { return nil }
      let text = String(source[args])
      let textRange = NSRange(text.startIndex..., in: text)
      guard let idMatch = idArgument.firstMatch(in: text, range: textRange),
        let idRange = Range(idMatch.range(at: 1), in: text)
      else { return nil }
      let kind: CheckKind = text.range(of: #"kind\s*=\s*(?:Kind\s*\.\s*)?DESIGN"#, options: .regularExpression) != nil
        ? .design : .behaviour
      return (String(text[idRange]), kind)
    }
  }
}
