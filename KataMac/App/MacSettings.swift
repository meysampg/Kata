import Foundation
import Observation

/// Mac-only settings, persisted in UserDefaults (`mac.*` keys). Settings shared with iOS live in
/// `AppSettings` (KataStore).
@MainActor @Observable
final class MacSettings {
  static let katasPerDayRange: ClosedRange<Int> = 1...5
  static let editorFontRange: ClosedRange<Int> = 11...20

  private let defaults: UserDefaults

  /// How many katas Today offers per day, counting the ones already done.
  var katasPerDay: Int {
    didSet { defaults.set(katasPerDay, forKey: "mac.katasPerDay") }
  }

  /// Font size of the kata editor.
  var editorFontSize: Int {
    didSet {
      let clamped = min(max(editorFontSize, Self.editorFontRange.lowerBound), Self.editorFontRange.upperBound)
      if clamped != editorFontSize { editorFontSize = clamped; return }
      defaults.set(editorFontSize, forKey: "mac.editorFontSize")
    }
  }

  /// Run the checks again when an IDE saves a file.
  var recheckOnSave: Bool {
    didSet { defaults.set(recheckOnSave, forKey: "mac.recheckOnSave") }
  }

  /// `JAVA_HOME` of the chosen JDK; nil means the system default (`java_home -v 21+`).
  var jdkHome: String? {
    didSet { Self.store(jdkHome, "mac.jdkHome", in: defaults) }
  }

  /// Bundle id of the chosen IDE; nil means the first one installed.
  var ideBundleID: String? {
    didSet { Self.store(ideBundleID, "mac.ideBundleID", in: defaults) }
  }

  /// An IDE picked with "Other…".
  var ideAppPath: String? {
    didSet { Self.store(ideAppPath, "mac.ideAppPath", in: defaults) }
  }

  /// Parent of `workspaces/`; nil means `~/Kata`.
  var workspaceRootPath: String? {
    didSet { Self.store(workspaceRootPath, "mac.workspaceRoot", in: defaults) }
  }

  var workspaceRoot: URL {
    if let path = workspaceRootPath, !path.isEmpty { return URL(fileURLWithPath: path, isDirectory: true) }
    return Self.defaultWorkspaceRoot
  }

  static var defaultWorkspaceRoot: URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Kata", isDirectory: true)
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let stored = defaults.object(forKey: "mac.katasPerDay") as? Int ?? 2
    katasPerDay = min(max(stored, Self.katasPerDayRange.lowerBound), Self.katasPerDayRange.upperBound)
    let font = defaults.object(forKey: "mac.editorFontSize") as? Int ?? 13
    editorFontSize = min(max(font, Self.editorFontRange.lowerBound), Self.editorFontRange.upperBound)
    recheckOnSave = defaults.object(forKey: "mac.recheckOnSave") as? Bool ?? true
    jdkHome = defaults.string(forKey: "mac.jdkHome")
    ideBundleID = defaults.string(forKey: "mac.ideBundleID")
    ideAppPath = defaults.string(forKey: "mac.ideAppPath")
    workspaceRootPath = defaults.string(forKey: "mac.workspaceRoot")
  }

  private static func store(_ value: String?, _ key: String, in defaults: UserDefaults) {
    if let value, !value.isEmpty { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
  }
}
