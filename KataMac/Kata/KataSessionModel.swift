import Foundation
import KataCore
import KataEditor
import KataRun
import KataSRS
import KataStore
import Observation
import SwiftData

/// One sitting with a kata: the learner's files, the check results, the hint ladder, the rating
/// and (optionally) an IDE workspace being watched. MAC_PLAN §5.3 and §5.4.
@MainActor @Observable
final class KataSessionModel {
  enum EditMode: String, Sendable { case builtIn = "editor", ide }

  /// What sits beside the editor.
  enum Aside: Equatable { case none, reference, previous, revealed }

  enum Phase: Equatable {
    case idle, running
    /// No JDK 21+ is installed.
    case noJDK
    /// The runner failed before a report existed.
    case failed(String)
  }

  /// A question the view asks before something with a cost happens.
  enum Confirmation: Equatable { case hint, reveal, copySolution, reset }

  /// Idle gaps longer than this do not count as working time.
  static let idleLimitMillis = 120_000

  let key: ItemKey
  let kata: Kata
  /// A due card: the session starts from the starter and hides the previous solution.
  let isReview: Bool

  private let store: ProgressStore
  private let settings: AppSettings
  private let checker: any KataChecking
  private let workspaceRoot: @MainActor () -> URL
  private let recheckOnSave: @MainActor () -> Bool
  private let clock: @MainActor () -> Date

  // MARK: Files

  private(set) var fileNames: [String]
  private(set) var files: [String: String]
  var selectedFile: String
  /// Files edited since the last report: their diagnostics no longer match the text.
  private var staleFiles: Set<String> = []
  /// Set to scroll the editor and flash a range.
  var reveal: EditorReveal?

  // MARK: Results

  private(set) var report: KataReport?
  private(set) var phase: Phase = .idle
  private(set) var runCount = 0
  private(set) var lastRunMillis: Int?
  private var runGeneration = 0

  // MARK: Flow

  private(set) var hintsShown = 0
  private(set) var solutionRevealed = false
  var aside: Aside = .none
  var confirmation: Confirmation?
  private(set) var passed = false
  private(set) var suggestedRating: Rating?
  private(set) var rating: Rating?
  /// The learner chose not to reschedule after a practice pass.
  private(set) var ratingSkipped = false
  private(set) var activeMillis = 0
  private(set) var scheduled: SchedulingResult?
  private var passedFiles: [String: String] = [:]
  private var previousSolution: [String: String]?

  // MARK: IDE mode

  private(set) var mode: EditMode = .builtIn
  private(set) var ide: IDE?
  var ideError: String?
  private var watcher: FolderWatcher?

  // MARK: Persistence helpers

  private var attemptID: PersistentIdentifier?
  private var lastActivity: Date?
  private var draftTask: Task<Void, Never>?
  private var runTask: Task<Void, Never>?

  init(
    key: ItemKey, kata: Kata, store: ProgressStore, settings: AppSettings, checker: any KataChecking,
    workspaceRoot: @escaping @MainActor () -> URL, recheckOnSave: @escaping @MainActor () -> Bool = { true },
    clock: @escaping @MainActor () -> Date = { .now }
  ) {
    self.key = key; self.kata = kata; self.store = store; self.settings = settings
    self.checker = checker; self.workspaceRoot = workspaceRoot; self.recheckOnSave = recheckOnSave
    self.clock = clock

    let now = clock()
    let card = store.card(ProgressStore.kataCardKey(key))
    isReview = card.map { $0.due <= now } ?? false
    previousSolution = store.lastPassedSolution(key)

    var names = kata.starter.map(\.name)
    var contents = Dictionary(uniqueKeysWithValues: kata.starter.map { ($0.name, $0.source) })
    if isReview {
      // Redo from blank: the starter comes back and the draft is overwritten.
      store.saveKataDraft(key, files: contents, now: now)
    } else if let draft = store.kataDraft(key), !draft.isEmpty {
      for name in draft.keys.sorted() where !names.contains(name) { names.append(name) }
      for (name, source) in draft { contents[name] = source }
      // Read-only files always come from the kata, never from an old draft.
      for f in kata.starter where kata.readOnly.contains(f.name) { contents[f.name] = f.source }
    }
    fileNames = names
    files = contents
    selectedFile = names.first ?? ""
    lastActivity = now
  }

  // MARK: Derived

  var starterFiles: [KataFile] { kata.starter }

  func orderedFiles() -> [KataFile] {
    fileNames.compactMap { name in files[name].map { KataFile(name: name, source: $0) } }
  }

  func isReadOnly(_ file: String) -> Bool { kata.readOnly.contains(file) }

  /// The built-in editor accepts typing in this file.
  func isEditable(_ file: String) -> Bool { mode == .builtIn && !isReadOnly(file) }

  var canAddFiles: Bool { kata.kind != .fix }

  var isRunning: Bool { phase == .running }

  var hintsRemaining: Int { max(0, kata.hints.count - hintsShown) }

  var canCompare: Bool { passed }

  /// The previous solution is available, but hidden during a review until the learner passes.
  var canShowPrevious: Bool { previousSolution != nil && (!isReview || passed) }

  var previousFiles: [KataFile] {
    (previousSolution ?? [:]).keys.sorted().map { KataFile(name: $0, source: previousSolution?[$0] ?? "") }
  }

  /// The files to show beside the editor for the current `aside`.
  var asideFiles: [KataFile] {
    switch aside {
    case .none: return []
    case .reference, .revealed: return kata.solution
    case .previous: return previousFiles
    }
  }

  /// Total checks that passed in the last report.
  var passedCount: Int { report?.passedCount ?? 0 }

  /// Whether the card exists and is not due yet (a practice pass then leaves FSRS alone unless rated).
  var cardIsNotDue: Bool {
    guard let card = store.card(ProgressStore.kataCardKey(key)) else { return false }
    return card.due > clock()
  }

  /// FSRS previews for the rating buttons.
  func ratingPreviews() -> [Rating: SchedulingResult] {
    let now = clock()
    let card = store.card(ProgressStore.kataCardKey(key)) ?? .new(now: now)
    return settings.scheduler.preview(card, now: now)
  }

  // MARK: Editing

  func setSource(_ text: String, for file: String) {
    guard files[file] != text else { return }
    files[file] = text
    staleFiles.insert(file)
    noteActivity()
    scheduleDraftSave()
  }

  /// Adds an empty `.java` file. Returns an error message when the name is not acceptable.
  @discardableResult
  func addFile(named raw: String) -> String? {
    var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if !name.hasSuffix(".java") { name += ".java" }
    let stem = String(name.dropLast(5))
    guard !stem.isEmpty, stem.first.map({ $0.isLetter || $0 == "_" }) == true,
      stem.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" })
    else { return "Use a Java identifier, for example Discounts.java." }
    guard files[name] == nil else { return "\(name) already exists." }
    guard canAddFiles else { return "This kind of kata keeps its files fixed." }
    fileNames.append(name)
    files[name] = ""
    selectedFile = name
    noteActivity()
    scheduleDraftSave()
    return nil
  }

  /// Removes a file the learner added (starter files stay).
  func removeFile(_ name: String) {
    guard !kata.starter.contains(where: { $0.name == name }), let i = fileNames.firstIndex(of: name) else { return }
    fileNames.remove(at: i)
    files[name] = nil
    staleFiles.remove(name)
    if selectedFile == name { selectedFile = fileNames.first ?? "" }
    scheduleDraftSave()
  }

  /// Replaces every file at once (reset, copy the solution, the debug solver).
  func replaceFiles(_ new: [KataFile]) {
    fileNames = new.map(\.name)
    files = Dictionary(uniqueKeysWithValues: new.map { ($0.name, $0.source) })
    if !fileNames.contains(selectedFile) { selectedFile = fileNames.first ?? "" }
    staleFiles = Set(fileNames)
    report = nil
    noteActivity()
    scheduleDraftSave()
    if mode == .ide { rewriteWorkspace() }
  }

  func resetToStarter() {
    replaceFiles(kata.starter)
    if rating != nil || passed { startNewAttempt() }
    aside = .none
  }

  /// Starts over after a pass: same kata, fresh attempt. FSRS changes only if the learner rates.
  func practiceAgain() {
    replaceFiles(kata.starter)
    startNewAttempt()
    aside = .none
  }

  private func startNewAttempt() {
    attemptID = nil
    hintsShown = 0
    solutionRevealed = false
    runCount = 0
    activeMillis = 0
    lastActivity = nil
    passed = false
    suggestedRating = nil
    rating = nil
    ratingSkipped = false
    scheduled = nil
    passedFiles = [:]
    report = nil
    lastRunMillis = nil
    phase = .idle
  }

  // MARK: Diagnostics for the editor

  func diagnostics(for file: String) -> [EditorDiagnostic] {
    guard let report, !staleFiles.contains(file), let source = files[file] else { return [] }
    var out: [EditorDiagnostic] = []
    for (i, d) in report.diagnostics.enumerated() where d.file == file {
      guard let range = d.range(in: source) else { continue }
      out.append(
        EditorDiagnostic(id: i, range: range, severity: d.severity == .error ? .error : .warning, message: d.message))
    }
    // A failed check points at its line.
    for (i, c) in report.checks.enumerated() where !c.passed && c.file == file {
      guard let line = c.line, let range = Self.range(ofLine: line, in: source) else { continue }
      out.append(EditorDiagnostic(id: 10_000 + i, range: range, severity: .error, message: c.message))
    }
    return out
  }

  /// Whether `file` is one of the learner's (not a hidden test).
  func isUserFile(_ file: String?) -> Bool {
    guard let file else { return false }
    return files[file] != nil
  }

  static func range(ofLine line: Int, in source: String) -> NSRange? {
    let ns = source as NSString
    guard line >= 1 else { return nil }
    var current = 1
    var start = 0
    while current < line {
      let r = ns.range(of: "\n", range: NSRange(location: start, length: ns.length - start))
      if r.location == NSNotFound { return nil }
      start = r.location + 1
      current += 1
    }
    let lr = ns.lineRange(for: NSRange(location: start, length: 0))
    var length = lr.length
    while length > 0, [0x0A, 0x0D].contains(ns.character(at: lr.location + length - 1)) { length -= 1 }
    // Skip the indentation so the underline sits on the code.
    var lead = 0
    while lead < length, ns.character(at: lr.location + lead) == 0x20 || ns.character(at: lr.location + lead) == 0x09 { lead += 1 }
    return NSRange(location: lr.location + lead, length: max(0, length - lead))
  }

  /// Selects `range` of `file` in the editor and flashes it.
  func jump(to file: String, range: NSRange) {
    guard files[file] != nil else { return }
    selectedFile = file
    aside = aside == .revealed ? .revealed : aside
    reveal = EditorReveal(range: range)
  }

  /// Jumps to a diagnostic or failed check of the last report.
  func jump(to diagnostic: KataReport.Diagnostic) {
    guard let file = diagnostic.file, let source = files[file], let range = diagnostic.range(in: source) else { return }
    jump(to: file, range: range)
  }

  func jump(to check: KataReport.CheckResult) {
    guard let file = check.file, let line = check.line, let source = files[file],
      let range = Self.range(ofLine: line, in: source)
    else { return }
    jump(to: file, range: range)
  }

  private var cycle = 0

  /// ⌘': the next error, over every file.
  func jumpToNextDiagnostic() {
    var all: [(file: String, range: NSRange)] = []
    for name in fileNames { all += diagnostics(for: name).filter { $0.severity == .error }.map { (name, $0.range) } }
    guard !all.isEmpty else { return }
    let hit = all[cycle % all.count]
    cycle += 1
    jump(to: hit.file, range: hit.range)
  }

  // MARK: Running

  /// Runs the checks. A newer run supersedes one in flight.
  func run() async {
    runGeneration += 1
    let generation = runGeneration
    let files = orderedFiles()
    flushDraft()
    phase = .running
    runCount += 1
    noteActivity()
    ensureAttempt()
    syncAttempt()
    let clock = ContinuousClock()
    let began = clock.now
    do {
      let result = try await checker.run(files: files, kata: kata)
      guard generation == runGeneration else { return }
      let elapsed = clock.now - began
      lastRunMillis = Int(elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000)
      finish(with: result)
    } catch KataCheckError.noJDK {
      guard generation == runGeneration else { return }
      phase = .noJDK
    } catch is CancellationError {
      if generation == runGeneration { phase = .idle }
    } catch {
      guard generation == runGeneration else { return }
      phase = .failed(String(describing: error))
    }
  }

  /// Fire-and-forget run for buttons and the folder watcher.
  func startRun() {
    runTask?.cancel()
    runTask = Task { await self.run() }
  }

  private func finish(with result: KataReport) {
    report = result
    staleFiles = []
    phase = .idle
    guard result.allPassed(expecting: kata.checks), !passed else { return }
    passed = true
    passedFiles = files
    suggestedRating = KataGrader.suggest(
      hints: hintsShown, revealed: solutionRevealed, activeMillis: activeMillis, minutes: kata.minutes,
      runs: runCount)
    syncAttempt()
  }

  // MARK: Hints and solution

  func requestHint() { if hintsRemaining > 0 { confirmation = .hint } }

  func revealNextHint() {
    guard hintsRemaining > 0 else { return }
    hintsShown += 1
    noteActivity()
    ensureAttempt()
    syncAttempt()
  }

  func requestReveal() { confirmation = .reveal }

  func revealSolution() {
    solutionRevealed = true
    aside = .revealed
    noteActivity()
    ensureAttempt()
    syncAttempt()
  }

  func requestCopySolution() { confirmation = .copySolution }

  func copySolutionIntoEditor() {
    solutionRevealed = true
    replaceFiles(kata.solution)
    aside = .none
    ensureAttempt()
    syncAttempt()
  }

  func toggleAside(_ new: Aside) {
    switch new {
    case .reference: guard canCompare else { return }
    case .previous: guard canShowPrevious else { return }
    default: break
    }
    aside = aside == new ? .none : new
  }

  // MARK: Rating

  /// Schedules the kata with `rating` (the learner may override the suggestion).
  @discardableResult
  func rate(_ choice: Rating) -> SchedulingResult? {
    guard passed, rating == nil else { return nil }
    ensureAttempt()
    syncAttempt()
    guard let attemptID else { return nil }
    let result = store.recordKataPass(
      key, files: passedFiles, attempt: attemptID, rating: choice, scheduler: settings.scheduler, now: clock())
    rating = choice
    scheduled = result
    return result
  }

  func skipRating() {
    guard passed, rating == nil else { return }
    ratingSkipped = true
  }

  // MARK: Time

  /// Counts the time between two actions, ignoring long idle gaps.
  func noteActivity() {
    let now = clock()
    if let last = lastActivity {
      let gap = Int(now.timeIntervalSince(last) * 1000)
      if gap > 0, gap <= Self.idleLimitMillis { activeMillis += gap }
    }
    lastActivity = now
  }

  // MARK: Attempt and draft

  private func ensureAttempt() {
    if attemptID == nil {
      attemptID = store.startKataAttempt(key, isReview: isReview, mode: mode.rawValue, now: clock())
    }
  }

  private func syncAttempt() {
    guard let attemptID else { return }
    store.updateKataAttempt(
      attemptID, hintsUsed: hintsShown, revealedSolution: solutionRevealed, runCount: runCount,
      activeMillis: activeMillis, mode: mode.rawValue)
  }

  private func scheduleDraftSave() {
    draftTask?.cancel()
    draftTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      self?.flushDraft()
    }
  }

  /// Writes the draft now (autosave is 1 s after the last edit).
  func flushDraft() {
    draftTask?.cancel()
    draftTask = nil
    store.saveKataDraft(key, files: files, now: clock())
  }

  // MARK: IDE mode

  /// `~/Kata/workspaces/<topic>/<item>/`
  var workspaceDirectory: URL {
    workspaceRoot().appendingPathComponent("workspaces", isDirectory: true)
      .appendingPathComponent(key.topic, isDirectory: true)
      .appendingPathComponent(key.item, isDirectory: true)
  }

  var sourceDirectory: URL { workspaceDirectory.appendingPathComponent("src", isDirectory: true) }

  /// Writes the workspace, watches it and (when `launch`) opens it in `ide`.
  func startIDEMode(ide: IDE?, launch: Bool = true) async {
    ideError = nil
    do {
      try WorkspaceWriter.write(kata: kata, files: orderedFiles(), to: workspaceDirectory)
    } catch {
      ideError = "Could not write the workspace: \(error.localizedDescription)"
      return
    }
    watcher?.stop()
    let w = FolderWatcher(directory: sourceDirectory) { [weak self] _ in
      Task { @MainActor in self?.diskChanged() }
    }
    w.start()
    watcher = w
    self.ide = ide
    mode = .ide
    aside = aside == .revealed ? .revealed : .none
    ensureAttempt()
    syncAttempt()
    if launch, let ide {
      let main = sourceDirectory.appendingPathComponent(fileNames.first ?? "")
      do {
        try await IDELauncher.open(folder: workspaceDirectory, files: [main], with: ide)
      } catch {
        ideError = "Could not open \(ide.name): \(error.localizedDescription)"
      }
    }
  }

  func reportIDEUnavailable() {
    ideError = "No supported IDE was found. Install IntelliJ IDEA, Zed or Cursor, or choose another app in Settings \u{2192} IDE."
  }

  /// Takes the files from disk and returns to the built-in editor.
  func leaveIDEMode() {
    guard mode == .ide else { return }
    reloadFromDisk()
    watcher?.stop()
    watcher = nil
    mode = .builtIn
    ide = nil
    ensureAttempt()
    syncAttempt()
    flushDraft()
  }

  private func rewriteWorkspace() {
    // The learner reset or replaced the files while the IDE is open: put them on disk and make
    // sure that write is not reported back as an IDE save.
    let fm = FileManager.default
    let names = Set(fileNames)
    if let urls = try? fm.contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil) {
      for url in urls where url.pathExtension == "java" && !names.contains(url.lastPathComponent) {
        try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
        try? fm.removeItem(at: url)
      }
    }
    _ = try? WorkspaceWriter.write(kata: kata, files: orderedFiles(), to: workspaceDirectory)
    watcher?.rebaseline()
  }

  private func diskChanged() {
    guard mode == .ide else { return }
    reloadFromDisk()
    noteActivity()
    scheduleDraftSave()
    if recheckOnSave() { startRun() }
  }

  /// Reads `src/*.java`. The files on disk are the truth while the IDE is in charge.
  func reloadFromDisk() {
    let fm = FileManager.default
    guard let urls = try? fm.contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil) else { return }
    var disk: [String: String] = [:]
    for url in urls where url.pathExtension == "java" {
      guard var text = try? String(contentsOf: url, encoding: .utf8) else { continue }
      let name = url.lastPathComponent
      if kata.readOnly.contains(name), text.hasPrefix(Self.providedHeader) { text.removeFirst(Self.providedHeader.count) }
      disk[name] = text
    }
    guard !disk.isEmpty else { return }
    var names = fileNames.filter { disk[$0] != nil }
    for name in disk.keys.sorted() where !names.contains(name) { names.append(name) }
    for (name, text) in disk where files[name] != text { staleFiles.insert(name) }
    fileNames = names
    files = disk
    if !names.contains(selectedFile) { selectedFile = names.first ?? "" }
  }

  static let providedHeader = "// Provided \u{2014} do not edit\n"
}
