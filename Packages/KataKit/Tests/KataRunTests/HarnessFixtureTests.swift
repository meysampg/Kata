#if os(macOS)
  import Foundation
  import Testing

  @testable import KataCore
  @testable import KataRun

  /// Runs the real harness on small fixture katas (MAC_PLAN §9). Needs a JDK 21+.
  enum Harness {
    static let jdk: JDK? = JDKLocator.default(minimum: 21)

    static func run(
      src: [String: String], tests: [String: String], timeoutSeconds: Int = 10, allowance: Int = 3,
      jvm: [String] = [], repeatCount: Int = 1
    ) async throws -> KataReport {
      let request = KataRunRequest(
        files: src.sorted { $0.key < $1.key }.map { KataFile(name: $0.key, source: $0.value) },
        tests: tests.sorted { $0.key < $1.key }.map { KataFile(name: $0.key, source: $0.value) },
        jdk: jdk!, repeatCount: repeatCount, timeoutSeconds: timeoutSeconds, compileAllowanceSeconds: allowance,
        extraJVMArguments: jvm)
      return try await KataCheckRunner().run(request)
    }

    static func test(_ checks: String, imports: String = "") -> [String: String] {
      ["T.java": "import kata.*;\n\(imports)\nclass T {\n\(checks)\n}\n"]
    }
  }

  @Suite(.enabled(if: Harness.jdk != nil, "needs a JDK 21+"), .serialized)
  struct HarnessFixtureTests {
    @Test func passingKata() async throws {
      let r = try await Harness.run(
        src: ["A.java": "class A { int two() { return 2; } }\n"],
        tests: Harness.test(#"@Check(id = "two") void two() { Expect.equal(2, new A().two(), "two"); }"#))
      #expect(r.compileOK == true && !r.crashed)
      #expect(r.checks.map(\.id) == ["two"] && r.checks[0].status == .pass)
      #expect(r.doneMillis != nil)
    }

    @Test func compileErrorPointsAtTheBadToken() async throws {
      let source = "class A { int x = ; }\n"
      let r = try await Harness.run(
        src: ["A.java": source],
        tests: Harness.test(#"@Check(id = "x") void x() { }"#))
      #expect(r.compileOK == false && r.checks.isEmpty && !r.crashed)
      let d = try #require(r.errors.first)
      #expect(d.file == "A.java" && d.line == 1)
      let range = try #require(d.range(in: source))
      #expect((source as NSString).substring(with: range) == ";")
    }

    @Test func compileErrorOffsetsSurviveEmoji() async throws {
      let source = "// \u{1F600}\u{1F600} héllo\nclass A { int x = ; }\n"
      let r = try await Harness.run(
        src: ["A.java": source], tests: Harness.test(#"@Check(id = "x") void x() { }"#))
      let d = try #require(r.errors.first)
      let range = try #require(d.range(in: source))
      #expect((source as NSString).substring(with: range) == ";")
      #expect(d.line == 2)
    }

    @Test func failingTestReportsMessage() async throws {
      let r = try await Harness.run(
        src: ["A.java": "class A { int two() { return 3; } }\n"],
        tests: Harness.test(#"@Check(id = "two") void two() { Expect.equal(2, new A().two(), "two()"); }"#))
      let c = try #require(r.checks.first)
      #expect(c.status == .fail)
      #expect(c.message == "two(): expected 2 but got 3")
    }

    @Test func exceptionInUserCodeIsAnErrorAtItsLine() async throws {
      let r = try await Harness.run(
        src: ["A.java": "class A {\n  int boom() {\n    throw new IllegalStateException(\"bad\");\n  }\n}\n"],
        tests: Harness.test(#"@Check(id = "boom") void boom() { new A().boom(); }"#))
      let c = try #require(r.checks.first)
      #expect(c.status == .error && c.message.contains("IllegalStateException: bad"))
      #expect(c.file == "A.java" && c.line == 3)
    }

    @Test func designCheckFailureNamesTheLine() async throws {
      let src = """
        class Checkout {
          String name(int x) {
            switch (x) {
              case 1: return "one";
              default: return "many";
            }
          }
        }

        """
      let r = try await Harness.run(
        src: ["Checkout.java": src],
        tests: Harness.test(
          #"@Check(id = "no-switch", kind = Kind.DESIGN) void noSwitch() { Expect.none(Source.type("Checkout").switches(), "Checkout still switches"); }"#
        ))
      let c = try #require(r.checks.first)
      #expect(c.status == .fail && c.kind == .design)
      #expect(c.message.hasPrefix("Checkout still switches") && c.file == "Checkout.java" && c.line == 3)
    }

    @Test func missingTypeInTestBlocksOnlyThatFile() async throws {
      var tests = Harness.test(#"@Check(id = "fine") void fine() { }"#)
      tests["U.java"] = """
        import kata.*;
        class U {
          @Check(id = "needs-type") void needsType() { new DiscountPolicy(); }
        }

        """
      let r = try await Harness.run(src: ["A.java": "class A { }\n"], tests: tests)
      #expect(r.compileOK == true)
      let blocked = try #require(r.result(for: "needs-type"))
      #expect(blocked.status == .blocked)
      #expect(blocked.message.contains("cannot find symbol") && blocked.message.contains("DiscountPolicy"))
      #expect(!blocked.message.contains("needsType"))
      #expect(r.result(for: "fine")?.status == .pass)
    }

    @Test func infiniteLoopTimesOutAndLaterChecksStillRun() async throws {
      let src = "class A { static void spin() { while (true) { } } }\n"
      let r = try await Harness.run(
        src: ["A.java": src],
        tests: Harness.test(
          """
          @Check(id = "spin", timeoutMs = 300) void spin() { A.spin(); }
          @Check(id = "after") void after() { }
          """))
      let spin = try #require(r.result(for: "spin"))
      #expect(spin.status == .timeout)
      #expect(spin.millis >= 300 && spin.millis <= 300 + 250)
      #expect(spin.file == "A.java" && spin.line == 1)
      let after = try #require(r.result(for: "after"))
      #expect(after.status == .pass && after.affected)
      #expect(!r.crashed && r.doneMillis != nil)
    }

    @Test func deadlockIsReportedWithBothThreads() async throws {
      let src = """
        class Locks {
          static final Object A = new Object(), B = new Object();
          static void deadlock() throws Exception {
            java.util.concurrent.CountDownLatch bothHoldOne = new java.util.concurrent.CountDownLatch(2);
            Thread t1 = new Thread(() -> take(A, B, bothHoldOne), "first-thread");
            Thread t2 = new Thread(() -> take(B, A, bothHoldOne), "second-thread");
            t1.setDaemon(true); t2.setDaemon(true);
            t1.start(); t2.start();
            t1.join();
          }
          static void take(Object x, Object y, java.util.concurrent.CountDownLatch latch) {
            synchronized (x) {
              latch.countDown();
              try { latch.await(); } catch (InterruptedException e) { return; }
              synchronized (y) { }
            }
          }
        }

        """
      let r = try await Harness.run(
        src: ["Locks.java": src],
        tests: Harness.test(#"@Check(id = "dead", timeoutMs = 500) void dead() throws Exception { Locks.deadlock(); }"#))
      let c = try #require(r.checks.first)
      #expect(c.status == .timeout)
      #expect(c.message.contains("Deadlock") && c.message.contains("first-thread") && c.message.contains("second-thread"))
    }

    @Test func systemExitThroughReflectionIsReported() async throws {
      let src = """
        class Sneaky {
          static void leave() throws Exception {
            Class.forName("java.lang.System").getMethod("exit", int.class).invoke(null, 3);
          }
        }

        """
      let r = try await Harness.run(
        src: ["Sneaky.java": src],
        tests: Harness.test(#"@Check(id = "leave") void leave() throws Exception { Sneaky.leave(); }"#))
      let c = try #require(r.checks.first)
      #expect(c.status == .exited)
      #expect(r.doneMillis != nil && !r.crashed)
    }

    @Test func systemExitLiteralIsRefusedBeforeRunning() async throws {
      let r = try await Harness.run(
        src: ["A.java": "class A {\n  static void f() { System.exit(1); }\n}\n"],
        tests: Harness.test(#"@Check(id = "f") void f() { A.f(); }"#))
      #expect(r.compileOK == false && r.checks.isEmpty)
      let d = try #require(r.errors.first)
      #expect(d.isPolicyViolation && d.file == "A.java" && d.line == 2)
    }

    @Test func outputFloodIsCappedAndTimesOut() async throws {
      let src = "class Flood { static void go() { while (true) System.out.println(\"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\"); } }\n"
      let r = try await Harness.run(
        src: ["Flood.java": src],
        tests: Harness.test(#"@Check(id = "flood", timeoutMs = 500) void flood() { Flood.go(); }"#))
      let c = try #require(r.checks.first)
      #expect(c.status == .timeout)
      #expect(c.output.hasSuffix("[output truncated]"))
      #expect(c.output.utf8.count <= 64 * 1024 + 30)
      #expect(!r.crashed)
    }

    @Test func outOfMemoryIsAnErrorAndTheRunContinues() async throws {
      let src = """
        import java.util.*;
        class Hog { static void eat() { List<long[]> keep = new ArrayList<>(); while (true) keep.add(new long[1_000_000]); } }

        """
      let r = try await Harness.run(
        src: ["Hog.java": src],
        tests: Harness.test(
          """
          @Check(id = "oom", timeoutMs = 5000) void oom() { Hog.eat(); }
          @Check(id = "after") void after() { }
          """))
      let oom = try #require(r.result(for: "oom"))
      #expect(oom.status == .error && oom.message.contains("OutOfMemoryError"))
      #expect(r.result(for: "after")?.status == .pass)
    }

    @Test func stackOverflowIsAnError() async throws {
      let r = try await Harness.run(
        src: ["R.java": "class R { static int down(int n) { return down(n + 1) + 1; } }\n"],
        tests: Harness.test(#"@Check(id = "deep") void deep() { R.down(0); }"#))
      let c = try #require(r.checks.first)
      #expect(c.status == .error && c.message.contains("StackOverflowError"))
      #expect(c.file == "R.java")
    }

    @Test func leakedNonDaemonThreadDoesNotKeepTheProcessAlive() async throws {
      let src = """
        class Leak {
          static void start() { Thread t = new Thread(() -> { while (true) { } }); t.start(); }
        }

        """
      let r = try await Harness.run(
        src: ["Leak.java": src],
        tests: Harness.test(#"@Check(id = "leak") void leak() { Leak.start(); }"#), timeoutSeconds: 5)
      #expect(r.checks.first?.status == .pass)
      #expect(!r.crashed && !r.timedOut && r.doneMillis != nil)
      #expect(r.wallMillis < 5000)
    }

    @Test func wallClockKillReportsCrashed() async throws {
      let r = try await Harness.run(
        src: ["A.java": "class A { }\n"], tests: Harness.test(#"@Check(id = "x") void x() { }"#),
        timeoutSeconds: 1, allowance: 0, jvm: ["-Dkata.test.hang=true"])
      #expect(r.crashed && r.timedOut && r.compileOK == nil && r.checks.isEmpty)
      #expect(r.wallMillis >= 900 && r.wallMillis < 4000)
    }

    @Test func testsReachPackagePrivateMembers() async throws {
      let src = """
        class Vault {
          private int secret = 7;
          int open() { return secret; }
          static final class Inner { String name() { return "inner"; } }
        }

        """
      let r = try await Harness.run(
        src: ["Vault.java": src],
        tests: Harness.test(
          """
          @Check(id = "package-private") void pp() throws Throwable {
            Expect.equal(7, new Vault().open(), "open");
            Expect.equal("inner", new Vault.Inner().name(), "inner");
            var f = Types.onlyFieldOfType(Types.named("Vault"), int.class);
            Expect.equal(7, f.get(new Vault()), "the private field");
            Expect.equal("inner", Types.call(Types.method(Types.named("Inner"), "name"), new Vault.Inner()), "via Types");
          }
          """))
      #expect(r.checks.first?.status == .pass, "\(r.checks.first?.message ?? "")")
    }

    @Test func repeatedChecksStopAtTheFirstFailure() async throws {
      let src = "class Counter { static int n; static int next() { return ++n; } }\n"
      let r = try await Harness.run(
        src: ["Counter.java": src],
        tests: Harness.test(
          #"@Check(id = "third-fails", repeat = 5) void c() { Expect.isTrue(Counter.next() < 3, "Counter reached " + Counter.n); }"#
        ))
      let c = try #require(r.checks.first)
      #expect(c.status == .fail && c.run == 3 && c.message == "Counter reached 3")
    }

    @Test func secondRunCancelsTheFirst() async throws {
      let runner = KataCheckRunner()
      let slowRequest = KataRunRequest(
        files: [KataFile(name: "A.java", source: "class A { static void spin() { while (true) { } } }\n")],
        tests: [KataFile(name: "T.java", source: "import kata.*;\nclass T { @Check(id = \"s\", timeoutMs = 20000) void s() { A.spin(); } }\n")],
        jdk: Harness.jdk!, timeoutSeconds: 30)
      let quick = KataRunRequest(
        files: [KataFile(name: "A.java", source: "class A { }\n")],
        tests: [KataFile(name: "T.java", source: "import kata.*;\nclass T { @Check(id = \"q\") void q() { } }\n")],
        jdk: Harness.jdk!)
      _ = try await runner.cache.ensure(jdk: Harness.jdk!)
      let first = Task { try await runner.run(slowRequest) }
      try await Task.sleep(for: .milliseconds(1200))
      let second = try await runner.run(quick)
      #expect(second.checks.first?.status == .pass)
      await #expect(throws: CancellationError.self) { try await first.value }
    }

    // The Double-Checked Locking sketch (MAC_PLAN §2.5): deterministic races, held monitors and
    // source queries together.
    static let dclTests = """
      import kata.*;
      class DclTest {
        @Check(id = "one-instance-under-contention", timeoutMs = 5000, repeat = 5)
        void oneInstance() {
          Types.setStatic(Config.class, "instance", null);
          Config.CREATED.set(0);
          Config.onConstruct = () -> Stress.pause(20);
          var all = Stress.race(8, Config::get);
          Expect.equal(1, Config.CREATED.get(), "constructor calls");
          Expect.equal(1, new java.util.HashSet<>(all).size(), "distinct instances");
        }
        @Check(id = "fast-path-does-not-lock")
        void fastPath() throws Exception {
          Config.get();
          try (var h = Stress.holdMonitor(Config.class)) {
            Expect.completesWithin(300, Config::get, "Config.get() while another thread holds the class monitor");
          }
        }
        @Check(id = "instance-is-volatile", kind = Kind.DESIGN)
        void isVolatile() {
          var f = Types.onlyStaticFieldOfType(Config.class, Config.class);
          Expect.isTrue(java.lang.reflect.Modifier.isVolatile(f.getModifiers()), "Config.instance should be volatile");
        }
        @Check(id = "single-read-on-fast-path", kind = Kind.DESIGN)
        void singleRead() {
          var reads = Source.type("Config").method("get").fieldReads("instance").stream()
              .filter(h -> !h.insideSynchronized()).toList();
          Expect.atMost(1, reads, "Read instance once into a local");
        }
      }

      """

    static let dclStarter = """
      import java.util.Map;
      import java.util.concurrent.atomic.AtomicInteger;

      final class Config {
          static final AtomicInteger CREATED = new AtomicInteger();
          static volatile Runnable onConstruct = () -> { };
          private static Config instance;
          private final Map<String, String> settings;
          private Config() { onConstruct.run(); CREATED.incrementAndGet(); settings = Map.of("mode", "prod"); }
          static Config get() {
              if (instance == null) {
                  synchronized (Config.class) {
                      instance = new Config();
                  }
              }
              return instance;
          }
          String mode() { return settings.get("mode"); }
      }

      """

    static let dclFixed = """
      import java.util.Map;
      import java.util.concurrent.atomic.AtomicInteger;

      final class Config {
          static final AtomicInteger CREATED = new AtomicInteger();
          static volatile Runnable onConstruct = () -> { };
          private static volatile Config instance;
          private final Map<String, String> settings;
          private Config() { onConstruct.run(); CREATED.incrementAndGet(); settings = Map.of("mode", "prod"); }
          static Config get() {
              Config local = instance;
              if (local == null) {
                  synchronized (Config.class) {
                      local = instance;
                      if (local == null) {
                          instance = local = new Config();
                      }
                  }
              }
              return local;
          }
          String mode() { return settings.get("mode"); }
      }

      """

    @Test(arguments: [1, 4])
    func dclReferencePassesUnderContention(cpus: Int) async throws {
      for _ in 0..<3 {
        let r = try await Harness.run(
          src: ["Config.java": Self.dclFixed], tests: ["DclTest.java": Self.dclTests],
          jvm: ["-XX:ActiveProcessorCount=\(cpus)"])
        #expect(r.compileOK == true)
        #expect(r.checks.map(\.status) == [.pass, .pass, .pass, .pass], "\(r.checks.map { "\($0.id): \($0.message)" })")
      }
    }

    @Test func dclStarterFailsEveryTime() async throws {
      for _ in 0..<3 {
        let r = try await Harness.run(src: ["Config.java": Self.dclStarter], tests: ["DclTest.java": Self.dclTests])
        #expect(r.result(for: "one-instance-under-contention")?.status == .fail)
        #expect(r.result(for: "fast-path-does-not-lock")?.status == .pass)
        #expect(r.result(for: "instance-is-volatile")?.status == .fail)
        #expect(r.result(for: "single-read-on-fast-path")?.status == .fail)
      }
    }
  }

  @Suite(.enabled(if: Harness.jdk != nil, "needs a JDK 21+"), .serialized)
  struct HarnessCacheTests {
    @Test func buildsOnceAndReusesTheBuild() async throws {
      let root = FileManager.default.temporaryDirectory.appendingPathComponent("hc-\(UUID().uuidString)")
      defer { try? FileManager.default.removeItem(at: root) }
      let cache = HarnessCache(root: root)
      let first = try await cache.ensure(jdk: Harness.jdk!)
      #expect(FileManager.default.fileExists(atPath: first.jar.path))
      #expect(first.archive != nil, "the CDS warm-up should have produced an archive")
      let again = try await HarnessCache(root: root).ensure(jdk: Harness.jdk!)
      #expect(again == first)
    }
  }
#endif
