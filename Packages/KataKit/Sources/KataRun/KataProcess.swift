#if os(macOS)
  import Foundation
  import Synchronization

  /// What a finished (or killed) child process left behind.
  public struct ProcessOutcome: Sendable, Equatable {
    public var exitStatus: Int32
    /// True when the process ended through a signal (including our SIGKILL).
    public var terminatedBySignal: Bool
    public var stdout: Data
    public var stderr: Data
    /// The wall-clock deadline passed and the process was killed.
    public var timedOut: Bool
    /// Combined output went over the cap and the process was killed.
    public var outputCapExceeded: Bool
    public var wallMillis: Int

    public var stderrText: String { String(decoding: stderr, as: UTF8.self) }
    public var stdoutText: String { String(decoding: stdout, as: UTF8.self) }
  }

  /// Runs one child process with a wall-clock deadline and an output cap (MAC_PLAN §4.4).
  /// Exceeding either sends SIGKILL. Cancelling the calling task kills the process too.
  public actor KataProcess {
    public static let defaultOutputCap = 4 * 1024 * 1024

    private let executable: URL
    private let arguments: [String]
    private let directory: URL
    private let environment: [String: String]
    private let timeout: Duration
    private let outputCap: Int
    private var started = false

    public init(
      executable: URL, arguments: [String], currentDirectory: URL, environment: [String: String],
      timeout: Duration, outputCap: Int = KataProcess.defaultOutputCap
    ) {
      self.executable = executable; self.arguments = arguments; self.directory = currentDirectory
      self.environment = environment; self.timeout = timeout; self.outputCap = outputCap
    }

    /// Runs the process to completion. Throws if it cannot be launched or the task is cancelled.
    public func run() async throws -> ProcessOutcome {
      precondition(!started, "a KataProcess runs once")
      started = true
      let state = ProcessState(cap: outputCap)
      let process = Process()
      process.executableURL = executable
      process.arguments = arguments
      process.currentDirectoryURL = directory
      process.environment = environment
      process.standardInput = FileHandle.nullDevice
      let out = Pipe(), err = Pipe()
      process.standardOutput = out
      process.standardError = err
      out.fileHandleForReading.readabilityHandler = { h in
        let d = h.availableData
        if d.isEmpty { h.readabilityHandler = nil; state.closed(stderr: false) } else { state.append(d, stderr: false) }
      }
      err.fileHandleForReading.readabilityHandler = { h in
        let d = h.availableData
        if d.isEmpty { h.readabilityHandler = nil; state.closed(stderr: true) } else { state.append(d, stderr: true) }
      }
      process.terminationHandler = { p in
        state.exited(status: p.terminationStatus, signaled: p.terminationReason == .uncaughtSignal)
      }
      let clock = ContinuousClock()
      let start = clock.now
      do {
        try process.run()
      } catch {
        out.fileHandleForReading.readabilityHandler = nil
        err.fileHandleForReading.readabilityHandler = nil
        throw error
      }
      state.started(pid: process.processIdentifier)
      let timeout = self.timeout
      let watchdog = Task {
        try? await Task.sleep(for: timeout)
        if !Task.isCancelled { state.kill(.timeout) }
      }
      await withTaskCancellationHandler {
        await state.wait()
      } onCancel: {
        state.kill(.cancelled)
      }
      watchdog.cancel()
      let millis = Int((clock.now - start) / .milliseconds(1))
      let result = state.result(wallMillis: millis)
      if result.cancelled { throw CancellationError() }
      return result.outcome
    }
  }

  /// Shared mutable state of one run; all access goes through the mutex.
  private final class ProcessState: Sendable {
    enum KillReason { case timeout, cap, cancelled }

    struct Inner {
      var out = Data()
      var err = Data()
      var outClosed = false
      var errClosed = false
      var exited = false
      var status: Int32 = 0
      var signaled = false
      var pid: Int32 = 0
      var timedOut = false
      var capExceeded = false
      var cancelled = false
      var done = false
      var waiter: CheckedContinuation<Void, Never>?
    }

    let inner = Mutex(Inner())
    let cap: Int

    init(cap: Int) { self.cap = cap }

    func started(pid: Int32) {
      let killNow = inner.withLock { s -> Bool in
        s.pid = pid
        return s.timedOut || s.capExceeded || s.cancelled
      }
      if killNow { Darwin.kill(pid, SIGKILL) }
    }

    func append(_ data: Data, stderr: Bool) {
      let overflow = inner.withLock { s -> Int32? in
        if s.capExceeded { return nil }  // already killed; drop what is still in the pipe
        if stderr { s.err.append(data) } else { s.out.append(data) }
        if s.out.count + s.err.count > cap, !s.capExceeded {
          s.capExceeded = true
          // Do not keep more than the cap in memory.
          if s.out.count > cap { s.out = s.out.prefix(cap) }
          if s.err.count > cap { s.err = s.err.prefix(cap) }
          return s.pid
        }
        return nil
      }
      if let pid = overflow, pid > 0 { Darwin.kill(pid, SIGKILL) }
    }

    func closed(stderr: Bool) {
      inner.withLock { if stderr { $0.errClosed = true } else { $0.outClosed = true } }
      finishIfReady()
    }

    func exited(status: Int32, signaled: Bool) {
      inner.withLock { $0.exited = true; $0.status = status; $0.signaled = signaled }
      finishIfReady()
      // A stray grandchild could keep a pipe open; do not wait for it forever.
      DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [self] in
        inner.withLock { $0.outClosed = true; $0.errClosed = true }
        finishIfReady()
      }
    }

    func kill(_ reason: KillReason) {
      let pid = inner.withLock { s -> Int32 in
        switch reason {
        case .timeout: s.timedOut = !s.exited
        case .cap: s.capExceeded = true
        case .cancelled: s.cancelled = true
        }
        return s.exited ? 0 : s.pid
      }
      if pid > 0 { Darwin.kill(pid, SIGKILL) }
    }

    func wait() async {
      await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
        let resumeNow = inner.withLock { s -> Bool in
          if s.done { return true }
          s.waiter = c
          return false
        }
        if resumeNow { c.resume() }
      }
    }

    private func finishIfReady() {
      let waiter = inner.withLock { s -> CheckedContinuation<Void, Never>? in
        guard s.exited, s.outClosed, s.errClosed, !s.done else { return nil }
        s.done = true
        let w = s.waiter
        s.waiter = nil
        return w
      }
      waiter?.resume()
    }

    func result(wallMillis: Int) -> (outcome: ProcessOutcome, cancelled: Bool) {
      inner.withLock { s in
        (
          ProcessOutcome(
            exitStatus: s.status, terminatedBySignal: s.signaled, stdout: s.out, stderr: s.err,
            timedOut: s.timedOut, outputCapExceeded: s.capExceeded, wallMillis: wallMillis),
          s.cancelled
        )
      }
    }
  }
#endif
