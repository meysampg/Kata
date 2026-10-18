import Foundation
import KataDiagram

public struct ValidationOptions: Sendable {
  /// Registry items without content are not errors (content in progress).
  public var allowMissing: Bool
  /// Restrict item-level checks to these ids. Topic-level checks always run.
  public var items: Set<ItemID>?

  public init(allowMissing: Bool = false, items: Set<ItemID>? = nil) {
    self.allowMissing = allowMissing
    self.items = items
  }
}

/// Every authoring rule from PLAN §2d. Errors fail validation; warnings are advisory.
public enum PackValidator {
  // Limits (PLAN §2d, §5 content guide).
  public static let codeWarnLines = 70, codeErrorLines = 90
  public static let codeWarnColumns = 80, codeErrorColumns = 100
  public static let walkthroughSteps = 3...7
  public static let walkthroughNoteWords = 35

  /// Validates an authoring directory (loads it first, so decode/marker problems are reported).
  public static func validate(topicDirectory: URL, options: ValidationOptions = .init())
    -> [ValidationIssue]
  {
    let report = PackBuilder.load(topicDirectory: topicDirectory, only: options.items)
    var issues = report.issues
    guard let pack = report.pack else { return issues }
    if pack.topic.id != topicDirectory.lastPathComponent {
      issues.append(
        .init(
          .error, "\(topicDirectory.lastPathComponent)/topic.json",
          "topic id '\(pack.topic.id)' does not match directory name"))
    }
    issues += run(pack: pack, options: options, skipMissing: Set(report.failedItems))
    return issues
  }

  /// Validates an in-memory pack (items absent from `pack.items` count as missing).
  public static func validate(pack: Pack, options: ValidationOptions = .init()) -> [ValidationIssue] {
    run(pack: pack, options: options, skipMissing: [])
  }

  // MARK: - Implementation

  private static let kebab = try! NSRegularExpression(pattern: "^[a-z0-9]+(-[a-z0-9]+)*$")
  private static let kataLink = try! NSRegularExpression(pattern: "\\]\\(kata:([^)\\s]*)\\)")

  private static func isKebab(_ s: String) -> Bool {
    kebab.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
  }

  static func words(_ s: String) -> Int {
    s.split(whereSeparator: \.isWhitespace).filter { $0.contains { $0.isLetter || $0.isNumber } }.count
  }

  private static func run(pack: Pack, options: ValidationOptions, skipMissing: Set<ItemID>)
    -> [ValidationIssue]
  {
    var issues: [ValidationIssue] = []
    let topic = pack.topic
    let registry = Set(topic.items.map(\.id))

    topicChecks(topic, registry: registry, into: &issues)

    // Presence of items.
    let present = Set(pack.items.map(\.id))
    for id in options.items?.subtracting(registry).sorted() ?? [] {
      issues.append(.init(.error, "\(topic.id)/\(id)", "item is not in the topic registry"))
    }
    if !options.allowMissing && options.items == nil {
      for meta in topic.items where !present.contains(meta.id) && !skipMissing.contains(meta.id) {
        issues.append(
          .init(.error, "\(topic.id)/\(meta.id)", "registry item has no items/\(meta.id)/ content"))
      }
    }
    var seenBodies = Set<ItemID>()
    for item in pack.items {
      if !seenBodies.insert(item.id).inserted {
        issues.append(.init(.error, "\(topic.id)/\(item.id)", "duplicate item body"))
      }
      if !registry.contains(item.id) {
        issues.append(.init(.error, "\(topic.id)/\(item.id)", "item body is not in the topic registry"))
      }
    }

    for item in pack.items where options.items?.contains(item.id) ?? true {
      guard let meta = topic.meta(for: item.id) else { continue }
      itemChecks(item, meta: meta, topic: topic, registry: registry, into: &issues)
    }
    return issues
  }

  // MARK: Topic

  private static func topicChecks(_ topic: Topic, registry: Set<ItemID>, into issues: inout [ValidationIssue]) {
    let tp = "\(topic.id)/topic.json"
    func err(_ m: String) { issues.append(.init(.error, tp, m)) }

    if !isKebab(topic.id) { err("topic id '\(topic.id)' is not kebab-case") }
    if topic.roles.isEmpty { err("no roles defined") }
    for (name, t) in topic.templates.sorted(by: { $0.key < $1.key }) {
      if t.roles.isEmpty { err("template '\(name)' has no roles") }
      for r in t.roles + t.optionalRoles where topic.roles[r] == nil {
        err("template '\(name)' references unknown role '\(r)'")
      }
      let all = t.roles + t.optionalRoles
      if Set(all).count != all.count { err("template '\(name)' lists a role twice") }
    }
    var cats = Set<String>()
    for c in topic.categories {
      if !isKebab(c.id) { err("category id '\(c.id)' is not kebab-case") }
      if !cats.insert(c.id).inserted { err("duplicate category id '\(c.id)'") }
      if topic.templates[c.template] == nil {
        err("category '\(c.id)' uses unknown template '\(c.template)'")
      }
    }

    var ids = Set<String>()
    for m in topic.items {
      let p = "\(topic.id)/\(m.id)"
      if !isKebab(m.id) { issues.append(.init(.error, p, "item id '\(m.id)' is not kebab-case")) }
      if !ids.insert(m.id).inserted { issues.append(.init(.error, p, "duplicate item id")) }
      if !cats.contains(m.category) {
        issues.append(.init(.error, p, "unknown category '\(m.category)'"))
      }
      if !(1...3).contains(m.difficulty) {
        issues.append(.init(.error, p, "difficulty \(m.difficulty) is outside 1...3"))
      }
      if m.title.trimmingCharacters(in: .whitespaces).isEmpty {
        issues.append(.init(.error, p, "empty title"))
      }
      if m.intent.trimmingCharacters(in: .whitespaces).isEmpty {
        issues.append(.init(.error, p, "empty intent"))
      }
      if m.aliases.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
        issues.append(.init(.error, p, "empty alias"))
      }
    }

    // Path: every registry item exactly once.
    var counts: [String: Int] = [:]
    for (i, s) in topic.path.enumerated() {
      if s.title.trimmingCharacters(in: .whitespaces).isEmpty { err("path section \(i + 1) has no title") }
      if s.items.isEmpty { err("path section '\(s.title)' is empty") }
      for id in s.items {
        counts[id, default: 0] += 1
        if !registry.contains(id) { err("path section '\(s.title)' lists unknown item '\(id)'") }
      }
    }
    for id in topic.items.map(\.id) where counts[id] == nil {
      err("item '\(id)' is missing from the path")
    }
    for (id, n) in counts.sorted(by: { $0.key < $1.key }) where n > 1 {
      err("item '\(id)' appears \(n) times in the path")
    }
  }

  // MARK: Item

  private static func itemChecks(
    _ item: Item, meta: ItemMeta, topic: Topic, registry: Set<ItemID>,
    into issues: inout [ValidationIssue]
  ) {
    let base = "\(topic.id)/\(item.id)"

    // Cards: exactly the template roles, in template order.
    if let template = topic.template(for: meta) {
      let present = item.cards.map(\.role)
      let allowed = Set(template.roles + template.optionalRoles)
      var seen = Set<String>()
      for r in present {
        if !allowed.contains(r) {
          issues.append(.init(.error, base, "card role '\(r)' is not part of the item's template"))
        }
        if !seen.insert(r).inserted { issues.append(.init(.error, base, "duplicate card role '\(r)'")) }
      }
      for r in template.roles where !present.contains(r) {
        issues.append(.init(.error, base, "missing card for required role '\(r)'"))
      }
      let requiredPresent = present.filter { template.roles.contains($0) }
      let requiredExpected = template.roles.filter { present.contains($0) }
      if requiredPresent != requiredExpected {
        issues.append(
          .init(
            .error, base,
            "cards are out of order: expected \(requiredExpected.joined(separator: ", ")), got \(requiredPresent.joined(separator: ", "))"
          ))
      }
    }

    for card in item.cards {
      let p = "\(base)#card:\(card.role)"
      if let spec = topic.roles[card.role] {
        if spec.type != card.type {
          issues.append(
            .init(.error, p, "card type '\(card.type.rawValue)' does not match role type '\(spec.type.rawValue)'"))
        }
      } else {
        issues.append(.init(.error, p, "role '\(card.role)' is not defined by the topic"))
      }
      cardChecks(card, path: p, topic: topic, registry: registry, itemID: item.id, into: &issues)
    }

    exerciseChecks(item, meta: meta, topic: topic, registry: registry, into: &issues)

    // kata: links in all prose.
    var texts = item.cards.flatMap { c -> [String] in
      if case .comparison = c.content { return [] }
      return c.texts
    }
    texts += item.exercises.flatMap(\.texts)
    for t in texts {
      for m in kataLink.matches(in: t, range: NSRange(t.startIndex..., in: t)) {
        guard let r = Range(m.range(at: 1), in: t) else { continue }
        let id = String(t[r])
        if !registry.contains(id) {
          issues.append(.init(.error, base, "link 'kata:\(id)' does not resolve to a registry item"))
        }
      }
    }
  }

  private static func cardChecks(
    _ card: Card, path p: String, topic: Topic, registry: Set<ItemID>, itemID: ItemID,
    into issues: inout [ValidationIssue]
  ) {
    func err(_ m: String) { issues.append(.init(.error, p, m)) }
    func warn(_ m: String) { issues.append(.init(.warning, p, m)) }

    switch card.content {
    case .text(let blocks):
      if blocks.isEmpty { err("text card has no blocks") }
      var body = 0, codeLines = 0
      for b in blocks {
        switch b {
        case .lead(let t):
          let w = words(t)
          if w > 25 { warn("lead is \(w) words (limit 25)") }
        case .paragraph(let t): body += words(t)
        case .bullets(let i), .numbered(let i):
          body += i.reduce(0) { $0 + words($1) }
          if i.count > 4 { warn("list has \(i.count) items (limit 4)") }
        case .callout(_, let t):
          let w = words(t)
          if w > 40 { warn("callout is \(w) words (limit 40)") }
        case .heading: break
        case .code(_, let lines): codeLines += lines.count
        }
      }
      let limit = card.role == "definition" ? 90 : 120
      if body > limit { warn("body is \(body) words (limit \(limit))") }
      if codeLines > 8 { warn("display code is \(codeLines) lines (limit 8)") }

    case .code(let code):
      codeCardChecks(code, path: p, into: &issues)

    case .diagram(let diagrams):
      if diagrams.isEmpty { err("diagram card has no diagrams") }
      for (i, d) in diagrams.enumerated() {
        for di in DiagramLinter.issues(d) {
          issues.append(
            .init(di.severity == .error ? .error : .warning, "\(p)/diagram[\(i)] \(d.title)", di.message))
        }
      }

    case .lists(let groups):
      if groups.isEmpty { err("lists card has no lists") }
      for g in groups {
        if !(2...4).contains(g.items.count) {
          warn("list '\(g.title)' has \(g.items.count) items (expected 2-4)")
        }
        for it in g.items where words(it) > 18 {
          warn("list '\(g.title)' item is \(words(it)) words (limit 18): \(it.prefix(40))...")
        }
      }

    case .comparison(let rows):
      if !(3...5).contains(rows.count) { warn("comparison has \(rows.count) rows (expected 3-5)") }
      var refs = Set<String>()
      for r in rows {
        if !registry.contains(r.ref) { err("comparison ref '\(r.ref)' is not in the registry") }
        if r.ref == itemID { err("comparison refers to the item itself") }
        if !refs.insert(r.ref).inserted { warn("comparison lists '\(r.ref)' twice") }
        for m in kataLink.matches(in: r.difference, range: NSRange(r.difference.startIndex..., in: r.difference)) {
          if let rg = Range(m.range(at: 1), in: r.difference), !registry.contains(String(r.difference[rg])) {
            err("link 'kata:\(r.difference[rg])' does not resolve to a registry item")
          }
        }
      }

    case .references(let entries):
      if !(3...6).contains(entries.count) { warn("references has \(entries.count) entries (expected 3-6)") }
      for e in entries where e.name.isEmpty || e.detail.isEmpty || e.origin.isEmpty {
        err("reference entry has an empty field")
      }
    }
  }

  private static func codeCardChecks(_ code: CodeCard, path p: String, into issues: inout [ValidationIssue]) {
    func err(_ m: String) { issues.append(.init(.error, p, m)) }
    func warn(_ m: String) { issues.append(.init(.warning, p, m)) }

    let lines = code.lines
    if lines.isEmpty { err("code source is empty") }
    if lines.count > codeErrorLines {
      err("\(lines.count) lines exceeds the limit of \(codeErrorLines)")
    } else if lines.count > codeWarnLines {
      warn("\(lines.count) lines exceeds the recommended \(codeWarnLines)")
    }
    let wide = lines.enumerated().filter { $0.element.count > codeWarnColumns }
    if let widest = wide.max(by: { $0.element.count < $1.element.count }) {
      let msg = "line \(widest.offset + 1) is \(widest.element.count) columns (\(wide.count) line(s) over \(codeWarnColumns))"
      if widest.element.count > codeErrorColumns { err(msg) } else { warn(msg) }
    }

    if !walkthroughSteps.contains(code.walkthrough.count) {
      err("walkthrough has \(code.walkthrough.count) steps (expected 3-7)")
    }
    for s in code.walkthrough {
      if code.regions[s.region] == nil { err("walkthrough region '\(s.region)' does not exist in \(code.file)") }
      let w = words(s.note)
      if w > walkthroughNoteWords { warn("walkthrough note for '\(s.region)' is \(w) words (limit \(walkthroughNoteWords))") }
    }
    let sorted = code.regions.sorted { ($0.value.start, $0.key) < ($1.value.start, $1.key) }
    for (id, r) in sorted where r.start < 1 || r.end > lines.count || r.start > r.end {
      err("region '\(id)' range \(r.start)-\(r.end) is outside the source (\(lines.count) lines)")
    }
    for i in sorted.indices.dropFirst() where sorted[i].value.start <= sorted[i - 1].value.end {
      err("regions '\(sorted[i - 1].key)' and '\(sorted[i].key)' overlap")
    }
  }

  // MARK: Exercises

  private static func exerciseChecks(
    _ item: Item, meta: ItemMeta, topic: Topic, registry: Set<ItemID>,
    into issues: inout [ValidationIssue]
  ) {
    let base = "\(topic.id)/\(item.id)"

    var ids = Set<String>()
    for ex in item.exercises {
      let p = "\(base)#\(ex.id)"
      func err(_ m: String) { issues.append(.init(.error, p, m)) }

      if !isKebab(ex.id) { err("exercise id '\(ex.id)' is not kebab-case") }
      if !ids.insert(ex.id).inserted { err("duplicate exercise id") }
      if ex.prompt.trimmingCharacters(in: .whitespaces).isEmpty { err("empty prompt") }

      switch ex.body {
      case .identify(let lines, let options):
        if lines.isEmpty { err("identify exercise has no code lines") }
        optionChecks(options, itemID: item.id, registry: registry, path: p, into: &issues)
      case .choose(let scenario, let options):
        if scenario.trimmingCharacters(in: .whitespaces).isEmpty { err("empty scenario") }
        optionChecks(options, itemID: item.id, registry: registry, path: p, into: &issues)
      case .tapLine(let lines, let flaw, let explanation):
        if lines.isEmpty { err("tapLine exercise has no lines") }
        if flaw.isEmpty { err("tapLine exercise has no flawLines") }
        for n in flaw where n < 1 || n > lines.count {
          err("flawLine \(n) is out of range (1...\(lines.count))")
        }
        if Set(flaw).count != flaw.count { err("duplicate flawLines") }
        if explanation.trimmingCharacters(in: .whitespaces).isEmpty { err("empty explanation") }
      case .reorder(let blocks, let explanation):
        if !(3...8).contains(blocks.count) { err("reorder has \(blocks.count) blocks (expected 3-8)") }
        if blocks.contains(where: \.isEmpty) { err("reorder has an empty block") }
        let texts = blocks.map { $0.joined(separator: "\n") }
        if Set(texts).count != texts.count { err("reorder blocks must have unique text") }
        if explanation.trimmingCharacters(in: .whitespaces).isEmpty { err("empty explanation") }
      case .recall(let model, let points):
        if model.isEmpty { err("recall has no modelAnswer") }
        if !(3...5).contains(points.count) { err("recall has \(points.count) key points (expected 3-5)") }
        if points.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
          err("recall has an empty key point")
        }
      }

      if let compile = ex.compile {
        if ex.compilableCode == nil {
          err("compile is only supported for identify, tapLine and reorder exercises")
        }
        let n = compile.template.reduce(0) {
          $0 + ($1.components(separatedBy: CompileSpec.placeholder).count - 1)
        }
        if n != 1 { err("compile template must contain \(CompileSpec.placeholder) exactly once (found \(n))") }
      }
    }

    for group in topic.requiredExercises {
      let kinds = Set(item.exercises.map(\.kind))
      if !group.contains(where: kinds.contains) {
        issues.append(
          .init(
            .error, base,
            "missing required exercise: one of \(group.map(\.rawValue).joined(separator: " | "))"))
      }
    }
  }

  private static func optionChecks(
    _ options: [ExerciseOption], itemID: ItemID, registry: Set<ItemID>, path p: String,
    into issues: inout [ValidationIssue]
  ) {
    func err(_ m: String) { issues.append(.init(.error, p, m)) }
    if !(3...4).contains(options.count) { err("\(options.count) options (expected 3-4)") }
    let correct = options.filter(\.correct)
    if correct.count != 1 { err("\(correct.count) correct options (expected exactly 1)") }
    var labels = Set<String>()
    for (i, o) in options.enumerated() {
      if (o.ref == nil) == (o.text == nil) { err("option \(i + 1) must have exactly one of ref or text") }
      if let r = o.ref, !registry.contains(r) { err("option ref '\(r)' is not in the registry") }
      if o.why.trimmingCharacters(in: .whitespaces).isEmpty { err("option \(i + 1) has no why") }
      let label = o.ref ?? o.text ?? ""
      if !labels.insert(label).inserted { err("duplicate option '\(label)'") }
    }
    if let c = correct.first, let r = c.ref, r != itemID {
      issues.append(.init(.warning, p, "correct option references '\(r)', not this item"))
    }
  }
}
