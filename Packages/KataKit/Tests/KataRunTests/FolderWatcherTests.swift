#if os(macOS)
  import Foundation
  import Synchronization
  import Testing

  @testable import KataRun

  /// FSEvents against a real temporary folder.
  @Suite(.serialized) struct FolderWatcherTests {
    final class Hits: Sendable {
      private let store = Mutex<[[String]]>([])
      func add(_ v: [String]) { store.withLock { $0.append(v) } }
      var all: [[String]] { store.withLock { $0 } }
    }

    static func makeDirectory() throws -> URL {
      let dir = FileManager.default.temporaryDirectory.appendingPathComponent("kata-watch-\(UUID().uuidString)", isDirectory: true)
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      return dir.resolvingSymlinksInPath()
    }

    func wait(_ hits: Hits, count: Int, seconds: Double = 3) async {
      let end = Date().addingTimeInterval(seconds)
      while hits.all.count < count, Date() < end { try? await Task.sleep(for: .milliseconds(25)) }
    }

    @Test func reportsAChangedFile() async throws {
      let dir = try Self.makeDirectory()
      defer { try? FileManager.default.removeItem(at: dir) }
      try "class A {}".write(to: dir.appendingPathComponent("A.java"), atomically: true, encoding: .utf8)
      let hits = Hits()
      let watcher = FolderWatcher(directory: dir, debounce: 0.2) { hits.add($0) }
      watcher.start()
      defer { watcher.stop() }
      try await Task.sleep(for: .milliseconds(200))
      try "class A { int x; }".write(to: dir.appendingPathComponent("A.java"), atomically: false, encoding: .utf8)
      await wait(hits, count: 1)
      #expect(hits.all == [["A.java"]])
    }

    @Test func survivesAnAtomicSafeWriteAndIgnoresIdenticalContent() async throws {
      let dir = try Self.makeDirectory()
      defer { try? FileManager.default.removeItem(at: dir) }
      let file = dir.appendingPathComponent("A.java")
      try "class A {}".write(to: file, atomically: true, encoding: .utf8)
      let hits = Hits()
      let watcher = FolderWatcher(directory: dir, debounce: 0.2) { hits.add($0) }
      watcher.start()
      defer { watcher.stop() }
      try await Task.sleep(for: .milliseconds(200))

      // Same bytes through an atomic rename: not a change.
      try "class A {}".write(to: file, atomically: true, encoding: .utf8)
      try await Task.sleep(for: .milliseconds(700))
      #expect(hits.all.isEmpty)

      // IntelliJ style: write a temp file, then rename it over the original.
      let temp = dir.appendingPathComponent("___jb_tmp___")
      try "class A { int y; }".write(to: temp, atomically: false, encoding: .utf8)
      _ = try FileManager.default.replaceItemAt(file, withItemAt: temp)
      await wait(hits, count: 1)
      try await Task.sleep(for: .milliseconds(500))
      #expect(hits.all == [["A.java"]])
    }

    @Test func burstsOfWritesAreOneCallback() async throws {
      let dir = try Self.makeDirectory()
      defer { try? FileManager.default.removeItem(at: dir) }
      let file = dir.appendingPathComponent("A.java")
      try "0".write(to: file, atomically: true, encoding: .utf8)
      let hits = Hits()
      let watcher = FolderWatcher(directory: dir, debounce: 0.3) { hits.add($0) }
      watcher.start()
      defer { watcher.stop() }
      try await Task.sleep(for: .milliseconds(200))
      for i in 1...5 {
        try "\(i)".write(to: file, atomically: false, encoding: .utf8)
        try await Task.sleep(for: .milliseconds(40))
      }
      await wait(hits, count: 1)
      try await Task.sleep(for: .milliseconds(600))
      #expect(hits.all.count == 1)
    }

    @Test func ignoresNonJavaAndHiddenFilesAndSeesNewAndDeletedOnes() async throws {
      let dir = try Self.makeDirectory()
      defer { try? FileManager.default.removeItem(at: dir) }
      let hits = Hits()
      let watcher = FolderWatcher(directory: dir, debounce: 0.2) { hits.add($0) }
      watcher.start()
      defer { watcher.stop() }
      try await Task.sleep(for: .milliseconds(200))
      try "x".write(to: dir.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
      try FileManager.default.createDirectory(at: dir.appendingPathComponent(".idea"), withIntermediateDirectories: true)
      try "x".write(to: dir.appendingPathComponent(".idea/B.java"), atomically: true, encoding: .utf8)
      try await Task.sleep(for: .milliseconds(700))
      #expect(hits.all.isEmpty)

      try "class B {}".write(to: dir.appendingPathComponent("B.java"), atomically: true, encoding: .utf8)
      await wait(hits, count: 1)
      try FileManager.default.removeItem(at: dir.appendingPathComponent("B.java"))
      await wait(hits, count: 2)
      #expect(hits.all == [["B.java"], ["B.java"]])
    }

    @Test func stopSilencesTheWatcher() async throws {
      let dir = try Self.makeDirectory()
      defer { try? FileManager.default.removeItem(at: dir) }
      let hits = Hits()
      let watcher = FolderWatcher(directory: dir, debounce: 0.1) { hits.add($0) }
      watcher.start()
      #expect(watcher.isRunning)
      watcher.stop()
      #expect(!watcher.isRunning)
      try "class C {}".write(to: dir.appendingPathComponent("C.java"), atomically: true, encoding: .utf8)
      try await Task.sleep(for: .milliseconds(500))
      #expect(hits.all.isEmpty)
    }
  }
#endif
