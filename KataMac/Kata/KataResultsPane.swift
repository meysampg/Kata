import AppKit
import KataCore
import KataRun
import KataSRS
import KataUI
import SwiftUI

/// Run button, pass banner with the rating, and the compiler, behaviour, design and output sections.
struct KataResultsPane: View {
  @Bindable var session: KataSessionModel
  @Environment(MacAppModel.self) private var model

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if session.phase == .noJDK || model.toolchain.isMissing {
            NoJDKView()
          } else {
            if session.passed { PassBanner(session: session) }
            if case .failed(let message) = session.phase {
              Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.callout)
            }
            if let report = session.report, report.crashed || report.harnessError != nil { crashCard(report) }
            if session.report != nil { compilerSection }
            checksSection(.behaviour, "Behaviour")
            checksSection(.design, "Design")
            if session.report == nil && !session.isRunning {
              Text("Press Run or \u{2318}R to compile your code and run the checks.")
                .font(.footnote).foregroundStyle(.secondary)
            }
            outputSection
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
      }
    }
    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
  }

  // MARK: Header

  private var header: some View {
    HStack(spacing: 10) {
      Button { session.startRun() } label: {
        Label("Run", systemImage: "play.fill")
      }
      .buttonStyle(.borderedProminent)
      .disabled(model.toolchain.isMissing)
      .help("Run checks (\u{2318}R)")
      if session.isRunning {
        ProgressView().controlSize(.small)
        Text("Running\u{2026}").font(.footnote).foregroundStyle(.secondary)
      } else if let report = session.report, report.compileOK == true {
        let total = session.kata.checks.count
        Label("\(report.passedCount)/\(total)", systemImage: report.passedCount == total ? "checkmark.circle.fill" : "xmark.circle")
          .foregroundStyle(report.passedCount == total ? .green : .secondary)
          .font(.subheadline.weight(.medium))
          .accessibilityLabel("\(report.passedCount) of \(total) checks pass")
      }
      if let ms = session.lastRunMillis, !session.isRunning {
        Text(String(format: "%.1f s", Double(ms) / 1000)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
      }
      Spacer()
      #if DEBUG
      debugMenu
      #endif
    }
    .padding(.horizontal, 14).padding(.vertical, 10)
  }

  #if DEBUG
  private var debugMenu: some View {
    Menu {
      Button("Make due now") {
        model.store.setKataDue(session.key, to: .now.addingTimeInterval(-60))
        model.resetKataSession(session.key)
      }
      Button("Load reference solution") { session.replaceFiles(session.kata.solution) }
    } label: {
      Image(systemName: "ladybug")
    }
    .menuStyle(.borderlessButton).fixedSize()
    .help("Debug")
  }
  #endif

  // MARK: Compiler

  @ViewBuilder
  private var compilerSection: some View {
    if let report = session.report {
      VStack(alignment: .leading, spacing: 6) {
        sectionTitle(
          "Compiler", detail: report.diagnostics.isEmpty ? "clean" : "\(report.diagnostics.count)",
          tint: report.compileOK == false ? .red : .secondary)
        if report.diagnostics.isEmpty {
          Label("Compiles without messages", systemImage: "checkmark").font(.footnote).foregroundStyle(.secondary)
        } else {
          ForEach(Array(report.diagnostics.enumerated()), id: \.offset) { _, d in diagnosticRow(d) }
        }
      }
    }
  }

  private func diagnosticRow(_ d: KataReport.Diagnostic) -> some View {
    let jumpable = session.isUserFile(d.file) && d.start >= 0
    return Button {
      session.jump(to: d)
    } label: {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(systemName: d.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
          .foregroundStyle(d.severity == .error ? Color.red : Color.orange)
          .frame(width: 16)
        VStack(alignment: .leading, spacing: 2) {
          Text(location(d)).font(.caption.monospaced()).foregroundStyle(.secondary)
          Text(d.message).font(.callout).multilineTextAlignment(.leading)
        }
        Spacer(minLength: 0)
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(!jumpable)
    .help(jumpable ? "Show in the editor" : "This message comes from a hidden test")
  }

  private func location(_ d: KataReport.Diagnostic) -> String {
    guard let file = d.file else { return "Compiler" }
    return session.isUserFile(file) ? "\(file):\(d.line)" : "Hidden test"
  }

  // MARK: Checks

  private func checksSection(_ kind: CheckKind, _ title: String) -> some View {
    let specs = session.kata.checks.filter { $0.kind == kind }
    let passed = specs.filter { session.report?.result(for: $0.id)?.passed == true }.count
    return VStack(alignment: .leading, spacing: 8) {
      sectionTitle(title, detail: session.report?.checks.isEmpty == false ? "\(passed)/\(specs.count)" : nil, tint: .secondary)
      ForEach(specs, id: \.id) { spec in CheckRow(session: session, spec: spec) }
    }
  }

  // MARK: Output and crashes

  @ViewBuilder
  private var outputSection: some View {
    let outputs = (session.report?.checks ?? []).filter { !$0.output.isEmpty }
    if !outputs.isEmpty {
      DisclosureGroup {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(outputs, id: \.id) { check in
            VStack(alignment: .leading, spacing: 2) {
              Text(check.id).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
              Text(check.output).font(.caption.monospaced()).textSelection(.enabled)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
      } label: {
        Text("Output").font(.subheadline.weight(.semibold))
      }
    }
  }

  private func crashCard(_ report: KataReport) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(
        report.timedOut ? "The run was stopped" : "The run did not finish",
        systemImage: "exclamationmark.octagon.fill"
      )
      .font(.subheadline.weight(.semibold)).foregroundStyle(.red)
      if report.timedOut {
        Text("It went over the time limit of \(session.kata.timeoutSeconds) s. Look for a loop that never ends.")
          .font(.footnote)
      }
      if let error = report.harnessError { Text(error).font(.footnote) }
      if !report.stderrTail.isEmpty {
        Text(report.stderrTail).font(.caption.monospaced()).textSelection(.enabled).lineLimit(8)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.red.opacity(0.08), in: .rect(cornerRadius: 10))
  }

  private func sectionTitle(_ title: String, detail: String?, tint: Color) -> some View {
    HStack {
      Text(title).font(.subheadline.weight(.semibold))
      if let detail { Text(detail).font(.caption).foregroundStyle(tint).monospacedDigit() }
      Spacer()
    }
  }
}

// MARK: - Check row

private struct CheckRow: View {
  let session: KataSessionModel
  let spec: KataCheckSpec

  var body: some View {
    let result = session.report?.result(for: spec.id)
    let jumpable = result.map { !$0.passed && session.isUserFile($0.file) && $0.line != nil } ?? false
    Button {
      if let result { session.jump(to: result) }
    } label: {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        icon(result).frame(width: 16)
        VStack(alignment: .leading, spacing: 2) {
          Text(spec.title).font(.callout).multilineTextAlignment(.leading)
          if let result, !result.passed {
            Text(detail(result)).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
              .textSelection(.enabled)
            if let file = result.file, let line = result.line, session.isUserFile(file) {
              Text("\(file):\(line)").font(.caption2.monospaced()).foregroundStyle(.tertiary)
            }
          }
        }
        Spacer(minLength: 0)
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(!jumpable)
    .accessibilityLabel("\(spec.title), \(label(result))")
  }

  private func detail(_ r: KataReport.CheckResult) -> String {
    switch r.status {
    case .timeout: "Timed out. " + r.message
    case .exited: "Your code called System.exit. " + r.message
    case .blocked: "Waiting for your code to compile or for a missing type. " + r.message
    default: r.message
    }
  }

  private func label(_ r: KataReport.CheckResult?) -> String {
    guard let r else { return "not run" }
    return r.passed ? "passed" : r.status.rawValue
  }

  @ViewBuilder
  private func icon(_ r: KataReport.CheckResult?) -> some View {
    switch r?.status {
    case nil:
      Image(systemName: session.isRunning ? "circle.dotted" : "circle").foregroundStyle(.tertiary)
    case .pass: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
    case .fail: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
    case .timeout: Image(systemName: "clock.badge.exclamationmark.fill").foregroundStyle(.orange)
    case .exited: Image(systemName: "power.circle.fill").foregroundStyle(.red)
    case .blocked: Image(systemName: "lock.circle").foregroundStyle(.secondary)
    case .error: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
    }
  }
}

// MARK: - Pass banner

private struct PassBanner: View {
  @Bindable var session: KataSessionModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(summary, systemImage: "checkmark.seal.fill")
        .font(.headline).foregroundStyle(.green)
      if let rating = session.rating {
        scheduledView(rating)
      } else if session.ratingSkipped {
        Text("Not rescheduled.").font(.subheadline).foregroundStyle(.secondary)
      } else {
        if session.cardIsNotDue {
          Text("This kata is not due yet. Rating it reschedules it.").font(.footnote).foregroundStyle(.secondary)
        }
        RatingBar(previews: session.ratingPreviews(), now: .now, suggested: session.suggestedRating) {
          _ = session.rate($0)
        }
        if let suggestion = session.suggestedRating { Text(reason(suggestion)).font(.caption).foregroundStyle(.secondary) }
        if session.cardIsNotDue {
          Button("Don't reschedule") { session.skipRating() }.buttonStyle(.link).font(.footnote)
        }
      }
      HStack {
        Button("Compare with reference") { session.toggleAside(.reference) }
        if session.canShowPrevious { Button("Previous solution") { session.toggleAside(.previous) } }
        Button("Practice again") { session.practiceAgain() }
      }
      .controlSize(.small)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.green.opacity(0.10), in: .rect(cornerRadius: 12))
  }

  private var summary: String {
    let total = session.kata.checks.count
    let hints = session.hintsShown == 1 ? "1 hint" : "\(session.hintsShown) hints"
    return "All \(total) checks pass \u{00B7} \(Self.time(session.activeMillis)) \u{00B7} \(hints)"
  }

  private func scheduledView(_ rating: Rating) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Rated \(rating.title)").font(.subheadline.weight(.semibold))
      if let result = session.scheduled {
        Text("Next review in \(IntervalFormatter.short(result, from: .now)).").font(.subheadline).foregroundStyle(.secondary)
      }
    }
  }

  private func reason(_ rating: Rating) -> String {
    if session.solutionRevealed { return "Suggested \(rating.title): you revealed the solution." }
    if session.hintsShown > 0 { return "Suggested \(rating.title): \(session.hintsShown) of \(session.kata.hints.count) hints used." }
    return "Suggested \(rating.title) from your time (target \(session.kata.minutes) min) and \(session.runCount) run\(session.runCount == 1 ? "" : "s")."
  }

  static func time(_ millis: Int) -> String {
    let seconds = max(0, millis / 1000)
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}

// MARK: - No JDK

/// Shown instead of results when no JDK 21+ is installed.
struct NoJDKView: View {
  private let command = "brew install --cask temurin@21"
  @Environment(MacAppModel.self) private var model

  var body: some View {
    ContentUnavailableView {
      Label("No JDK found", systemImage: "cup.and.saucer")
    } description: {
      Text("Kata runs your code with an installed JDK, version 21 or newer. Cards and practice work without one.")
    } actions: {
      Text(command).font(.callout.monospaced()).textSelection(.enabled)
      HStack {
        Button("Copy command") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(command, forType: .string)
        }
        Button("Look again") { Task { await model.toolchain.refresh() } }
        SettingsLink { Text("Open Settings") }
      }
    }
    .padding(.top, 20)
  }
}
