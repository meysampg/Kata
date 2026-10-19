#if os(macOS)
  import Foundation

  /// An installed JDK (one that has `bin/javac`).
  public struct JDK: Sendable, Hashable, Codable, Identifiable {
    public var home: URL
    /// Feature release (21, 25, 26...).
    public var major: Int
    /// `JVMVersion` as reported by the system, e.g. `26.0.2.1`.
    public var version: String
    public var vendor: String
    public var name: String

    public var id: String { home.path }
    public var java: URL { home.appendingPathComponent("bin/java") }
    public var javac: URL { home.appendingPathComponent("bin/javac") }
    public var jar: URL { home.appendingPathComponent("bin/jar") }

    public init(home: URL, major: Int, version: String, vendor: String = "", name: String = "") {
      self.home = home; self.major = major; self.version = version
      self.vendor = vendor; self.name = name
    }

    /// Text for pickers, e.g. `Temurin 26.0.2.1`.
    public var displayName: String {
      name.contains(version) ? name : "\(name.isEmpty ? "JDK" : name) \(version)"
    }
  }

  /// Finds JDKs through `/usr/libexec/java_home` (MAC_PLAN §4.4).
  public enum JDKLocator {
    static let javaHome = URL(fileURLWithPath: "/usr/libexec/java_home")

    /// Parses `java_home -X` output (a plist array of dictionaries). Entries without
    /// `JVMHomePath`/`JVMVersion` are skipped; the result is sorted newest first.
    public static func parse(javaHomePlist data: Data) throws -> [JDK] {
      guard let list = try PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]]
      else { return [] }
      var seen = Set<String>()
      var jdks: [JDK] = []
      for entry in list {
        guard let path = entry["JVMHomePath"] as? String, let version = entry["JVMVersion"] as? String,
          let major = major(ofVersion: version), seen.insert(path).inserted
        else { continue }
        jdks.append(
          JDK(
            home: URL(fileURLWithPath: path, isDirectory: true), major: major, version: version,
            vendor: entry["JVMVendor"] as? String ?? "", name: entry["JVMName"] as? String ?? ""))
      }
      return jdks.sorted { ($0.major, $0.version) > ($1.major, $1.version) }
    }

    /// `26.0.2.1` -> 26, `1.8.0_201` -> 8, `17` -> 17.
    public static func major(ofVersion version: String) -> Int? {
      let parts = version.split(whereSeparator: { $0 == "." || $0 == "_" || $0 == "-" || $0 == "+" })
      guard let first = parts.first.flatMap({ Int($0) }) else { return nil }
      if first == 1, parts.count > 1, let second = Int(parts[1]) { return second }
      return first
    }

    /// Every installed JDK with a compiler and a feature release of at least `minimum`.
    /// Blocking (spawns `java_home`); call off the main actor.
    public static func installed(minimum: Int = 21) -> [JDK] {
      guard let out = capture(javaHome, ["-X"]), let jdks = try? parse(javaHomePlist: out) else { return [] }
      return jdks.filter { $0.major >= minimum && FileManager.default.isExecutableFile(atPath: $0.javac.path) }
    }

    /// What `java_home -v <minimum>+` picks, falling back to `$JAVA_HOME` (CI runners put their
    /// toolchain there). Nil when no suitable JDK exists. Blocking.
    public static func `default`(minimum: Int = 21) -> JDK? {
      if let out = capture(javaHome, ["-v", "\(minimum)+"]),
        let path = String(data: out, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
        !path.isEmpty
      {
        let home = URL(fileURLWithPath: path, isDirectory: true)
        if let found = installed(minimum: minimum).first(where: {
          $0.home.standardizedFileURL == home.standardizedFileURL
        }) ?? jdk(at: home, minimum: minimum) {
          return found
        }
      }
      if let env = ProcessInfo.processInfo.environment["JAVA_HOME"], !env.isEmpty {
        return jdk(at: URL(fileURLWithPath: env, isDirectory: true), minimum: minimum)
      }
      return nil
    }

    /// A JDK at an explicit home (a Settings choice or `--jdk`), read from its `release` file.
    public static func jdk(at home: URL, minimum: Int = 21) -> JDK? {
      guard FileManager.default.isExecutableFile(atPath: home.appendingPathComponent("bin/javac").path),
        let release = releaseFile(at: home), let version = release["JAVA_VERSION"],
        let major = major(ofVersion: version), major >= minimum
      else { return nil }
      return JDK(
        home: home, major: major, version: version, vendor: release["IMPLEMENTOR"] ?? "",
        name: "JDK")
    }

    /// Key=value pairs of `<home>/release`, with quotes removed.
    static func releaseFile(at home: URL) -> [String: String]? {
      guard let text = try? String(contentsOf: home.appendingPathComponent("release"), encoding: .utf8)
      else { return nil }
      var out: [String: String] = [:]
      for line in text.split(separator: "\n") {
        guard let eq = line.firstIndex(of: "=") else { continue }
        let key = String(line[..<eq])
        var value = String(line[line.index(after: eq)...])
        if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 { value = String(value.dropFirst().dropLast()) }
        out[key] = value
      }
      return out
    }

    private static func capture(_ executable: URL, _ arguments: [String]) -> Data? {
      let p = Process()
      p.executableURL = executable
      p.arguments = arguments
      let out = Pipe()
      p.standardOutput = out
      p.standardError = FileHandle.nullDevice
      p.standardInput = FileHandle.nullDevice
      do { try p.run() } catch { return nil }
      let data = out.fileHandleForReading.readDataToEndOfFile()
      p.waitUntilExit()
      return p.terminationStatus == 0 ? data : nil
    }
  }
#endif
