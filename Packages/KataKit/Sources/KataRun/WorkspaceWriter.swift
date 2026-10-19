#if os(macOS)
  import Foundation
  import KataCore

  /// Writes a kata as a folder an IDE can open (MAC_PLAN §5.4): `src/*.java` plus minimal
  /// IntelliJ and VS Code project files, and no build file.
  public enum WorkspaceWriter {
    public struct Options: Sendable {
      /// Also write the hidden tests and the harness API, so an author can run them in the IDE.
      public var includeTests: Bool
      public init(includeTests: Bool = false) { self.includeTests = includeTests }
    }

    /// Writes the workspace into `directory` (created if needed) and returns its `src` folder.
    @discardableResult
    public static func write(
      kata: Kata, files: [KataFile], to directory: URL, options: Options = .init()
    ) throws -> URL {
      let fm = FileManager.default
      let src = directory.appendingPathComponent("src", isDirectory: true)
      try fm.createDirectory(at: src, withIntermediateDirectories: true)

      for f in files {
        let url = src.appendingPathComponent(f.name)
        if fm.fileExists(atPath: url.path) { try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path) }
        let readOnly = kata.readOnly.contains(f.name)
        let text = readOnly ? "// Provided \u{2014} do not edit\n" + f.source : f.source
        try text.write(to: url, atomically: true, encoding: .utf8)
        if readOnly { try fm.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path) }
      }

      var sourceRoots = ["src"]
      if options.includeTests {
        let tests = directory.appendingPathComponent("tests", isDirectory: true)
        try fm.createDirectory(at: tests, withIntermediateDirectories: true)
        for f in kata.tests { try f.source.write(to: tests.appendingPathComponent(f.name), atomically: true, encoding: .utf8) }
        let harness = directory.appendingPathComponent("harness/kata", isDirectory: true)
        try fm.createDirectory(at: harness, withIntermediateDirectories: true)
        let kataSources = HarnessCache.bundledSources.appendingPathComponent("kata", isDirectory: true)
        for url in try fm.contentsOfDirectory(at: kataSources, includingPropertiesForKeys: nil)
        where url.pathExtension == "java" {
          let dest = harness.appendingPathComponent(url.lastPathComponent)
          try? fm.removeItem(at: dest)
          try fm.copyItem(at: url, to: dest)
        }
        sourceRoots += ["tests", "harness"]
      }

      try readme(kata: kata, options: options).write(
        to: directory.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
      try write(".gitignore", "out/\n.idea/workspace.xml\n", in: directory)
      try write(
        ".vscode/settings.json", "{\n  \"java.project.sourcePaths\": [\(sourceRoots.map { "\"\($0)\"" }.joined(separator: ", "))]\n}\n",
        in: directory)
      let name = kata.itemId
      try write(
        ".idea/modules.xml",
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <project version="4">
          <component name="ProjectModuleManager">
            <modules>
              <module fileurl="file://$PROJECT_DIR$/\(name).iml" filepath="$PROJECT_DIR$/\(name).iml" />
            </modules>
          </component>
        </project>

        """, in: directory)
      try write(
        ".idea/misc.xml",
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <project version="4">
          <component name="ProjectRootManager" version="2" languageLevel="JDK_21" />
        </project>

        """, in: directory)
      let roots = sourceRoots.map {
        "    <sourceFolder url=\"file://$MODULE_DIR$/\($0)\" isTestSource=\"\($0 == "tests" ? "true" : "false")\" />"
      }.joined(separator: "\n")
      try write(
        "\(name).iml",
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <module type="JAVA_MODULE" version="4">
          <component name="NewModuleRootManager" inherit-compiler-output="true">
            <exclude-output />
            <content url="file://$MODULE_DIR$">
        \(roots)
            </content>
            <orderEntry type="inheritedJdk" />
            <orderEntry type="sourceFolder" forTests="false" />
          </component>
        </module>

        """, in: directory)
      return src
    }

    private static func write(_ path: String, _ text: String, in directory: URL) throws {
      let url = directory.appendingPathComponent(path)
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func readme(kata: Kata, options: Options) -> String {
      var out = "# \(kata.title)\n\n"
      for block in kata.task {
        switch block {
        case .lead(let t), .paragraph(let t): out += plain(t) + "\n\n"
        case .heading(let t): out += "## \(plain(t))\n\n"
        case .bullets(let items): out += items.map { "- " + plain($0) }.joined(separator: "\n") + "\n\n"
        case .numbered(let items):
          out += items.enumerated().map { "\($0.offset + 1). " + plain($0.element) }.joined(separator: "\n") + "\n\n"
        case .callout(_, let t): out += "> " + plain(t) + "\n\n"
        case .code(_, let lines): out += "```java\n" + lines.joined(separator: "\n") + "\n```\n\n"
        }
      }
      out += "## Checks\n\n"
      out += kata.checks.map { "- \($0.title) (\($0.kind.rawValue))" }.joined(separator: "\n") + "\n\n"
      out += options.includeTests
        ? "Run `kata-pack check-java --items \(kata.itemId)` to run them.\n"
        : "Results appear in Kata. Save a file to re-check.\n"
      return out
    }

    private static func plain(_ markdown: String) -> String { markdown }
  }
#endif
