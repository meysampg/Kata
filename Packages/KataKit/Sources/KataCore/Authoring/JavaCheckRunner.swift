import Foundation

public struct JavaCheckReport: Sendable, Codable, Equatable {
  public struct Diagnostic: Sendable, Codable, Equatable {
    public var kind: String
    public var file: String?
    public var line: Int?
    public var message: String
  }
  public struct UnitReport: Sendable, Codable, Equatable {
    public var name: String
    public var ok: Bool
    public var diagnostics: [Diagnostic]
    public var error: String?
    public var output: String?
    public var expected: String?
  }
  public var ok: Bool
  public var units: [UnitReport]

  public var failures: [UnitReport] { units.filter { !$0.ok } }
}

#if os(macOS)
  public enum JavaCheckRunner {
    public struct Failure: Error, CustomStringConvertible, Sendable {
      public var description: String
    }

    /// True when `javac` and `java` run on this machine.
    public static var isJavaAvailable: Bool {
      (try? run(["javac", "-version"]).status) == 0 && (try? run(["java", "-version"]).status) == 0
    }

    /// Writes units to a temp directory and runs `java <script> <dir>`.
    public static func check(units: [JavaUnit], script: URL) throws -> JavaCheckReport {
      let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("kata-javacheck-\(UUID().uuidString)", isDirectory: true)
      try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: tmp) }
      try JavaUnits.write(units, to: tmp)
      let result = try run(["java", script.path, tmp.path])
      guard let data = result.stdout.data(using: .utf8),
        let report = try? JSONDecoder().decode(JavaCheckReport.self, from: data)
      else {
        throw Failure(description: "JavaCheck produced no report (exit \(result.status)): \(result.stderr)")
      }
      return report
    }

    static func run(_ args: [String]) throws -> (status: Int32, stdout: String, stderr: String) {
      let p = Process()
      p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      p.arguments = args
      let out = Pipe(), err = FileManager.default.temporaryDirectory
        .appendingPathComponent("kata-java-\(UUID().uuidString).err")
      FileManager.default.createFile(atPath: err.path, contents: nil)
      let errHandle = try FileHandle(forWritingTo: err)
      defer { try? FileManager.default.removeItem(at: err) }
      p.standardOutput = out
      p.standardError = errHandle
      try p.run()
      let data = out.fileHandleForReading.readDataToEndOfFile()
      p.waitUntilExit()
      try? errHandle.close()
      let errText = (try? String(contentsOf: err, encoding: .utf8)) ?? ""
      return (p.terminationStatus, String(decoding: data, as: UTF8.self), errText)
    }
  }
#endif
