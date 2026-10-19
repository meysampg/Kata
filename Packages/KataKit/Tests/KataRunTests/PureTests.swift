#if os(macOS)
  import Foundation
  import Testing

  @testable import KataCore
  @testable import KataRun

  @Suite struct KataReportTests {
    let full = """
      {"type":"compile","ok":true,"diagnostics":[{"severity":"warning","file":"A.java","line":3,"column":5,"start":10,"end":14,"code":"w","message":"careful"}]}
      {"type":"check","id":"a","kind":"behaviour","status":"pass","message":"","millis":12,"output":""}
      {"type":"check","id":"b","kind":"design","status":"fail","message":"nope","file":"A.java","line":7,"millis":3,"output":"hi\\n","run":2}
      {"type":"done","millis":99}
      """

    @Test func parsesAFullReport() {
      let r = KataReport.parse(ndjson: full)
      #expect(r.compileOK == true)
      #expect(r.diagnostics.count == 1 && r.diagnostics[0].severity == .warning)
      #expect(r.checks.map(\.id) == ["a", "b"])
      #expect(r.checks[1].kind == .design && r.checks[1].status == .fail && r.checks[1].line == 7)
      #expect(r.checks[1].output == "hi\n" && r.checks[1].run == 2)
      #expect(r.doneMillis == 99 && !r.crashed && r.ignoredLines == 0)
      #expect(r.passedCount == 1)
    }

    @Test func missingDoneMeansCrashedWithStderrTail() {
      let partial = full.split(separator: "\n").dropLast().joined(separator: "\n")
      let stderr = (1...40).map { "line \($0)" }.joined(separator: "\n")
      let r = KataReport.parse(ndjson: partial, stderr: stderr)
      #expect(r.crashed && r.doneMillis == nil)
      #expect(r.checks.count == 2)
      #expect(r.stderrTail.hasSuffix("line 40") && !r.stderrTail.contains("line 10\n"))
    }

    @Test func truncatedAndGarbageLinesAreSkipped() {
      let text = "garbage\n{\"type\":\"check\",\"id\":\"a\",\"kind\":\"behaviour\",\"status\":\"pass\"}\n{\"type\":\"che"
      let r = KataReport.parse(ndjson: text)
      #expect(r.checks.count == 1)
      #expect(r.ignoredLines == 2 && r.crashed)
    }

    @Test func emptyReportIsCrashed() {
      let r = KataReport.parse(ndjson: "", stderr: "boom")
      #expect(r.crashed && r.compileOK == nil && r.stderrTail == "boom")
    }

    @Test func allPassedNeedsMatchingIdsInOrder() {
      let specs = [
        KataCheckSpec(id: "a", kind: .behaviour, title: "A"), KataCheckSpec(id: "b", kind: .design, title: "B"),
      ]
      let ok = KataReport.parse(
        ndjson: """
          {"type":"compile","ok":true,"diagnostics":[]}
          {"type":"check","id":"a","kind":"behaviour","status":"pass"}
          {"type":"check","id":"b","kind":"design","status":"pass"}
          {"type":"done","millis":1}
          """)
      #expect(ok.allPassed(expecting: specs))
      #expect(!ok.allPassed(expecting: specs.reversed()))
      #expect(!ok.allPassed(expecting: [specs[0]]))
    }

    @Test func diagnosticRangesAreUTF16UnitsIncludingEmojiAndSurrogates() {
      // "😀" is two UTF-16 units; javac offsets count chars, the same unit as NSString.
      let source = "// 😀😀\nint x = ;\n"
      let semicolon = (source as NSString).range(of: ";")
      let d = KataReport.Diagnostic(
        severity: .error, file: "A.java", line: 2, column: 9, start: semicolon.location,
        end: semicolon.location, code: "x", message: "illegal start of expression")
      let r = d.range(in: source)
      #expect(r == NSRange(location: semicolon.location, length: 1))
      #expect((source as NSString).substring(with: r!) == ";")
      // Swift's Character count differs, so a naive String.Index mapping would be off.
      #expect(source.count < (source as NSString).length)
    }

    @Test func rangesAreClampedAndUnknownOffsetsAreNil() {
      let d = KataReport.Diagnostic(
        severity: .error, file: nil, line: 0, column: 0, start: 50, end: 80, code: "", message: "")
      #expect(d.range(in: "abc") == NSRange(location: 3, length: 0))
      let none = KataReport.Diagnostic(
        severity: .error, file: nil, line: 0, column: 0, start: -1, end: -1, code: "", message: "")
      #expect(none.range(in: "abc") == nil)
    }
  }

  @Suite struct JDKLocatorTests {
    @Test func parsesRecordedJavaHomeOutput() throws {
      let url = Bundle.module.resourceURL!.appendingPathComponent("Fixtures/java_home.plist")
      let jdks = try JDKLocator.parse(javaHomePlist: Data(contentsOf: url))
      #expect(jdks.map(\.major) == [26, 25, 17, 8])  // the entry without a home is skipped
      #expect(jdks[0].home.path.hasSuffix("temurin-26.jdk/Contents/Home"))
      #expect(jdks[0].vendor == "Eclipse Adoptium" && jdks[0].version == "26.0.2.1")
      #expect(jdks[0].javac.lastPathComponent == "javac")
    }

    @Test func majorVersions() {
      #expect(JDKLocator.major(ofVersion: "26.0.2.1") == 26)
      #expect(JDKLocator.major(ofVersion: "1.8.0_201") == 8)
      #expect(JDKLocator.major(ofVersion: "21") == 21)
      #expect(JDKLocator.major(ofVersion: "17.0.14+7") == 17)
      #expect(JDKLocator.major(ofVersion: "oops") == nil)
    }

    @Test func malformedInputGivesAnErrorOrNothing() throws {
      #expect(try JDKLocator.parse(javaHomePlist: Data("nope".utf8)).isEmpty)
      #expect { try JDKLocator.parse(javaHomePlist: Data("<plist><array>".utf8)) } throws: { _ in true }
    }
  }

  @Suite struct KataProcessTests {
    let tmp = FileManager.default.temporaryDirectory
    let env = ["PATH": "/usr/bin:/bin"]

    @Test func capturesOutputAndExitStatus() async throws {
      let p = KataProcess(
        executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "echo out; echo err >&2; exit 3"],
        currentDirectory: tmp, environment: env, timeout: .seconds(10))
      let o = try await p.run()
      #expect(o.stdoutText == "out\n" && o.stderrText == "err\n")
      #expect(o.exitStatus == 3 && !o.timedOut && !o.terminatedBySignal)
    }

    @Test func killsAtTheDeadline() async throws {
      let p = KataProcess(
        executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"], currentDirectory: tmp,
        environment: env, timeout: .milliseconds(500))
      let o = try await p.run()
      #expect(o.timedOut && o.terminatedBySignal)
      #expect(o.wallMillis < 5000)
    }

    @Test func killsWhenOutputExceedsTheCap() async throws {
      let p = KataProcess(
        executable: URL(fileURLWithPath: "/usr/bin/yes"), arguments: [], currentDirectory: tmp,
        environment: env, timeout: .seconds(20), outputCap: 100_000)
      let o = try await p.run()
      #expect(o.outputCapExceeded && !o.timedOut)
      #expect(o.stdout.count <= 100_000)
    }

    @Test func cancellationKillsTheProcess() async throws {
      let p = KataProcess(
        executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"], currentDirectory: tmp,
        environment: env, timeout: .seconds(60))
      let task = Task { try await p.run() }
      try await Task.sleep(for: .milliseconds(200))
      task.cancel()
      await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func missingExecutableThrows() async {
      let p = KataProcess(
        executable: URL(fileURLWithPath: "/nonexistent/binary"), arguments: [], currentDirectory: tmp,
        environment: env, timeout: .seconds(5))
      await #expect { try await p.run() } throws: { _ in true }
    }
  }

  @Suite struct WorkspaceWriterTests {
    func kata() -> Kata {
      Kata(
        itemId: "demo", kind: .implement, title: "Demo", minutes: 10, task: [.lead("Do it."), .bullets(["one"])],
        starter: [KataFile(name: "A.java", source: "class A {}\n"), KataFile(name: "Api.java", source: "interface Api {}\n")],
        readOnly: ["Api.java"], solution: [KataFile(name: "A.java", source: "class A {}\n")],
        tests: [KataFile(name: "T.java", source: "class T {}\n")],
        checks: [KataCheckSpec(id: "x", kind: .behaviour, title: "X works")], hints: [[.paragraph("h")]])
    }

    @Test func writesTheProjectTree() throws {
      let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ws-\(UUID().uuidString)")
      defer { try? FileManager.default.removeItem(at: dir) }
      let k = kata()
      try WorkspaceWriter.write(kata: k, files: k.starter, to: dir)
      let fm = FileManager.default
      for path in [
        "src/A.java", "src/Api.java", "README.md", ".gitignore", ".idea/modules.xml", ".idea/misc.xml",
        "demo.iml", ".vscode/settings.json",
      ] {
        #expect(fm.fileExists(atPath: dir.appendingPathComponent(path).path), "missing \(path)")
      }
      #expect(!fm.fileExists(atPath: dir.appendingPathComponent("tests").path))
      let api = try String(contentsOf: dir.appendingPathComponent("src/Api.java"), encoding: .utf8)
      #expect(api.hasPrefix("// Provided"))
      let attrs = try fm.attributesOfItem(atPath: dir.appendingPathComponent("src/Api.java").path)
      #expect((attrs[.posixPermissions] as? Int) == 0o444)
      let misc = try String(contentsOf: dir.appendingPathComponent(".idea/misc.xml"), encoding: .utf8)
      #expect(misc.contains("JDK_21") && !misc.contains("project-jdk-name"))
      // Rewriting over read-only files works.
      try WorkspaceWriter.write(kata: k, files: k.starter, to: dir)
    }

    @Test func authorModeIncludesTestsAndHarnessApi() throws {
      let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ws-\(UUID().uuidString)")
      defer { try? FileManager.default.removeItem(at: dir) }
      let k = kata()
      try WorkspaceWriter.write(kata: k, files: k.solution, to: dir, options: .init(includeTests: true))
      #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("tests/T.java").path))
      #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("harness/kata/Expect.java").path))
      let iml = try String(contentsOf: dir.appendingPathComponent("demo.iml"), encoding: .utf8)
      #expect(iml.contains("/tests\" isTestSource=\"true\""))
    }
  }
#endif
