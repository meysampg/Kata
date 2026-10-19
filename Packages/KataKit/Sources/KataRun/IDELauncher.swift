#if os(macOS)
  import AppKit
  import Foundation

  /// An installed editor that can open a kata workspace.
  public struct IDE: Sendable, Hashable, Codable, Identifiable {
    public var bundleID: String
    public var name: String
    public var appURL: URL

    public var id: String { bundleID }

    public init(bundleID: String, name: String, appURL: URL) {
      self.bundleID = bundleID; self.name = name; self.appURL = appURL
    }
  }

  /// Finds the IDEs on this Mac and opens a workspace folder in one (MAC_PLAN §5.4).
  public enum IDELauncher {
    /// Bundle ids of the editors Kata knows, in the order they are offered.
    public static let knownBundleIDs: [String] = [
      "com.jetbrains.intellij", "com.jetbrains.intellij.ce", "dev.zed.Zed", "com.todesktop.230313mzl4w4u92",
    ]

    /// Display name used when the app bundle gives none.
    static let fallbackNames: [String: String] = [
      "com.jetbrains.intellij": "IntelliJ IDEA", "com.jetbrains.intellij.ce": "IntelliJ IDEA CE",
      "dev.zed.Zed": "Zed", "com.todesktop.230313mzl4w4u92": "Cursor",
    ]

    /// The known IDEs that are installed.
    public static func installed() -> [IDE] {
      knownBundleIDs.compactMap { id in
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: id).map { ide(id: id, at: $0) }
      }
    }

    /// An application the user picked ("Other…").
    public static func ide(at appURL: URL) -> IDE? {
      guard let id = Bundle(url: appURL)?.bundleIdentifier else { return nil }
      return ide(id: id, at: appURL)
    }

    /// The IDE with this bundle id, if the system can find it.
    public static func ide(bundleID: String) -> IDE? {
      NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { ide(id: bundleID, at: $0) }
    }

    private static func ide(id: String, at url: URL) -> IDE {
      let shown = FileManager.default.displayName(atPath: url.path)
      let name = shown.isEmpty ? (fallbackNames[id] ?? id) : shown
      return IDE(bundleID: id, name: name, appURL: url)
    }

    /// Opens `folder` (and `files` in it) with `ide`; the same as `open -b <id> <folder> <files>`
    /// but with real errors.
    @MainActor
    public static func open(folder: URL, files: [URL] = [], with ide: IDE) async throws {
      let configuration = NSWorkspace.OpenConfiguration()
      configuration.activates = true
      try await NSWorkspace.shared.open([folder] + files, withApplicationAt: ide.appURL, configuration: configuration)
    }
  }
#endif
