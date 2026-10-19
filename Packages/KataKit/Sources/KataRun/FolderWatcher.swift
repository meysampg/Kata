#if os(macOS)
  import CoreServices
  import CryptoKit
  import Foundation

  /// Watches a workspace folder for real changes to the learner's source files (MAC_PLAN §5.4).
  ///
  /// FSEvents reports file events; the watcher debounces them and compares SHA-256 hashes of the
  /// files with the last snapshot, so a save that wrote identical bytes, a backup file, or an IDE's
  /// "safe write" (write a temp file, rename over the original) produces exactly one callback for
  /// a real change and none otherwise.
  ///
  /// `@unchecked Sendable`: this is the one documented exception. Every mutable property is
  /// touched only on `queue`, which is also the FSEvents callback queue.
  public final class FolderWatcher: @unchecked Sendable {
    public typealias Filter = @Sendable (_ relativePath: String) -> Bool

    /// Only Java sources count, in any sub-folder, never inside a hidden folder.
    public static let javaFiles: Filter = { $0.hasSuffix(".java") && !$0.split(separator: "/").contains { $0.hasPrefix(".") } }

    public let directory: URL
    private let debounce: TimeInterval
    private let filter: Filter
    private let onChange: @Sendable ([String]) -> Void
    private let queue = DispatchQueue(label: "com.github.meysampg.kata.folderwatcher")
    private var stream: FSEventStreamRef?
    private var snapshot: [String: String] = [:]
    private var pending: DispatchWorkItem?

    /// - Parameters:
    ///   - debounce: quiet time after the last event before the folder is compared (seconds).
    ///   - onChange: called on a private queue with the relative paths that changed.
    public init(
      directory: URL, debounce: TimeInterval = 0.3, filter: @escaping Filter = FolderWatcher.javaFiles,
      onChange: @escaping @Sendable ([String]) -> Void
    ) {
      self.directory = directory.standardizedFileURL
      self.debounce = debounce; self.filter = filter; self.onChange = onChange
    }

    deinit { stopLocked() }

    public var isRunning: Bool { queue.sync { stream != nil } }

    /// Takes the baseline snapshot and starts listening. Calling it twice is a no-op.
    public func start() {
      queue.sync {
        guard stream == nil else { return }
        snapshot = takeSnapshot()
        var context = FSEventStreamContext(
          version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil,
          copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
          guard let info else { return }
          Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue().eventsArrived()
        }
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        guard
          let created = FSEventStreamCreate(
            nil, callback, &context, [directory.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.05, flags)
        else { return }
        FSEventStreamSetDispatchQueue(created, queue)
        FSEventStreamStart(created)
        stream = created
      }
    }

    public func stop() { queue.sync { stopLocked() } }

    /// Forgets what changed so far: the next comparison starts from the files as they are now.
    /// Call after writing the files yourself so your own write is not reported back.
    public func rebaseline() { queue.sync { snapshot = takeSnapshot() } }

    private func stopLocked() {
      pending?.cancel()
      pending = nil
      guard let stream else { return }
      FSEventStreamStop(stream)
      FSEventStreamInvalidate(stream)
      FSEventStreamRelease(stream)
      self.stream = nil
    }

    // Runs on `queue`.
    private func eventsArrived() {
      pending?.cancel()
      let item = DispatchWorkItem { [weak self] in self?.compare() }
      pending = item
      queue.asyncAfter(deadline: .now() + debounce, execute: item)
    }

    private func compare() {
      pending = nil
      let now = takeSnapshot()
      guard now != snapshot else { return }
      let changed = Set(now.keys).union(snapshot.keys).filter { now[$0] != snapshot[$0] }.sorted()
      snapshot = now
      onChange(changed)
    }

    private func takeSnapshot() -> [String: String] {
      var out: [String: String] = [:]
      guard
        let e = FileManager.default.enumerator(
          at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
      else { return out }
      let base = directory.path.hasSuffix("/") ? directory.path : directory.path + "/"
      for case let url as URL in e {
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(base) else { continue }
        let relative = String(path.dropFirst(base.count))
        guard filter(relative), let data = try? Data(contentsOf: url) else { continue }
        out[relative] = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
      }
      return out
    }
  }
#endif
