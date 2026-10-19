# Plan: Kata for Mac with offline-checked coding katas

I read the code and the content before writing this. Facts below come from the repo, except where I mark something as an assumption.

- **Platform guards in KataUI.** Every KataUI view is wrapped in `#if os(iOS)`. Only two files use UIKit:
  - `MonoMetrics.swift` uses `UIFont.monospacedSystemFont`.
  - `DiagramView.swift` uses `Color(uiColor: .secondarySystemBackground)`.
  - Everything else is plain SwiftUI. That includes `.glass`, `sensoryFeedback` and `@ScaledMetric`, which all exist on macOS 26.
- **Platforms.** `Package.swift` declares `.macOS(.v15)`. The package needs `.macOS(.v26)` because of the glass APIs.
- **App layer.** The app target holds `SchemaV1`, `MigrationPlan` (V1 only, no stages), `ProgressStore`, `AppSettings` and `AppModel`. `AppModel` holds both navigation and the derived learning state (`masteryMap`, `reviewQueue`, `dueCount`).
- **Kata cards stay out of iOS reviews.** `AppModel.liveSnapshots()` keeps only cards where `library.exercise(key) != nil`. A kata card keyed `…#kata` is therefore excluded from the existing practice queue with no code change.
- **Pack loading.** `ContentLibrary.live` decodes every `*.kpack` in the bundle. `Item` decoding is strict (`rejectUnknownKeys`).
- **Project file.** `Kata.xcodeproj` is objectVersion 77, hand-written, with IDs `CA7A…`, two synchronized groups (`Kata/`, `KataTests/`) and one shared scheme. The pack is `Kata/Resources/Packs/design-patterns.kpack` (917 KB).
- **JDKs.** `java_home -V` lists Temurin 26 (default), Temurin 25, OpenJDK 24, Corretto 23, 19, 17 (×3), 11 and 8. **No JDK 21 is installed.** `java_home -v 21+` resolves to 26, which is fine because the build uses `--release 21`.
- **IDE bundle ids.** `com.jetbrains.intellij`, `dev.zed.Zed`, `com.todesktop.230313mzl4w4u92` (Cursor).
- **`Tools/JavaCheck.java`** compiles in-process with `javax.tools` and runs `Main` on a thread with a 10 s timeout. The kata harness follows the same pattern but runs in its own process.

---

## 1. Architecture

### 1.1 Targets: add a separate `KataMac` target to the same project (recommended)

I recommend a native macOS app target rather than one multiplatform target:
- The iOS app is built around `TabView`, `fullScreenCover`, `.topBarTrailing`, glass bottom bars and paging. A multiplatform target would spread `#if os` through every screen.
- The Mac app needs build settings iOS must not get: no App Sandbox, hardened runtime, and a different bundle id.
- Two thin app targets over a shared package keep the iOS target almost unchanged. That is the main protection against regressions.

```
Kata.xcodeproj
├─ Kata          (iOS, unchanged product; imports KataCore, KataUI, KataStore)
├─ KataTests     (iOS hosted: BundledPackSmokeTests, ReminderSchedulerTests, V2 container smoke)
├─ KataMac       (macOS 26.0, com.github.meysampg.kata.mac)  ← new, synchronized group KataMac/
└─ KataMacTests  (macOS hosted unit tests + optional UI smoke)  ← new, synchronized group KataMacTests/
Packages/KataKit
├─ KataSRS, KataCode, KataDiagram           (unchanged; KataCode gains Indentation.swift)
├─ KataCore     + Models/Kata.swift, Authoring/KataLoader.swift, Validation/KataValidator.swift,
│                 Learning/KataGrader.swift, Learning/KataQueue.swift
├─ KataUI       de-iOS-ified (all platforms) + moved leaf card/exercise views (P2)
├─ KataStore    NEW (iOS+macOS, SwiftData): SchemaV1, SchemaV2, KataMigrationPlan, ProgressStore,
│                 AppSettings, StudyModel (derived learning state), PracticeSessionModel
├─ KataRun      NEW (macOS only, Foundation): JDKLocator, HarnessCache, KataProcess, KataCheckRunner,
│                 KataReport, WorkspaceWriter, IDELauncher, FolderWatcher; resources Harness/*.java
├─ KataEditor   NEW (macOS only, AppKit): CodeEditorView (NSViewRepresentable), CodeTextView,
│                 LineNumberRuler, EditorHighlighter
└─ kata-pack    depends on KataCore + KataRun (check-java runs katas through the same runner)
```

Dependency direction:
- KataStore → KataCore and KataSRS.
- KataRun → KataCore.
- KataEditor → KataCode.
- KataMac → all of them.
- iOS → KataCore, KataUI, KataStore.

### 1.2 Shared app-layer code: the new `KataStore` package module

| Moves from `Kata/` | To `KataStore` | Notes |
|---|---|---|
| `Persistence/SchemaV1.swift` | `KataStore/SchemaV1.swift` | Unchanged except for `public` on models, properties and inits. Version 1.0.0 stays the same, so the stored schema does not change. |
| `Persistence/MigrationPlan.swift` | `KataStore/MigrationPlan.swift` | Gains V2 (§1.4). |
| `Persistence/ProgressStore.swift` | `KataStore/ProgressStore.swift` | `public`. Adds the kata API (§1.4). |
| `App/AppSettings.swift` | `KataStore/AppSettings.swift` | Same `settings.*` keys, so iOS settings survive. Mac-only settings live in `MacSettings` in the KataMac target. |
| Derived parts of `App/AppModel.swift` (`masteryMap`, `liveSnapshots`, `newCandidates`, `reviewQueue`, `dueCount`, `nextDueDate`) | `KataStore/StudyModel.swift` | `@MainActor @Observable public final class StudyModel { library, store, settings, contentKeys, kataKeys }`. iOS `AppModel` keeps navigation and reminders and forwards to `study`. |
| `Features/Practice/PracticeSessionModel.swift` | `KataStore/PracticeSessionModel.swift` | Needed by both apps. |
| New | `KataStore/PersistenceFactory.swift` | `makeContainer(url: URL?, inMemory: Bool)`. The Mac passes an explicit URL (see the warning below). |

> **Mac store location.** A non-sandboxed macOS app that uses the default `ModelConfiguration` writes to `~/Library/Application Support/default.store`, a path any non-sandboxed SwiftData app can share. KataMac must use `ModelConfiguration(url: ~/Library/Application Support/com.github.meysampg.kata.mac/Kata.store)`.

Tests also move:
- `ProgressStoreTests` and `AppSettingsTests` go from `KataTests` to `Packages/KataKit/Tests/KataStoreTests`. They then run on the macOS host with `swift test`, which is faster and covered by CI.
- `KataTests` keeps the bundle and pack smoke tests plus a container-opens-V2 test.

### 1.3 KataUI views that need macOS ports

Replace `#if os(iOS)` with a cross-platform shim in `KataUI/Platform.swift`:

```swift
#if canImport(UIKit)
import UIKit; typealias PlatformFont = UIFont; typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit; typealias PlatformFont = NSFont; typealias PlatformColor = NSColor
#endif
extension Color { static var kataSecondaryBackground: Color { /* .secondarySystemBackground | .controlBackgroundColor */ } }
```

| File | Port |
|---|---|
| `MonoMetrics.swift` | `PlatformFont.monospacedSystemFont`. `lineHeight` on iOS; `ascender - descender + leading` on macOS (`NSLayoutManager.defaultLineHeight(for:)`). Also replace `private static var cache` with a `Mutex`-guarded cache or a per-size `static let` table. It is already `@MainActor`, but it breaks the "no static var" rule. |
| `DiagramView.swift` | Drop `import UIKit` and use `Color.kataSecondaryBackground`. Layout already uses the `TextMetrics` abstraction from KataDiagram. |
| `CodeView`, `CodeWalkthroughView`, `BlocksView`, `ToneStyle`, `MasteryRing`, `RatingBar` | Remove the guard. `@ScaledMetric` returns the base value on macOS. `.glass` works on macOS 26. |
| `HoldToConfirmButton` | `onLongPressGesture` works with a mouse. `sensoryFeedback` is a no-op on Macs without haptics. On macOS, prefer a confirmation dialog: `#if os(macOS)` → `Button` + `.confirmationDialog`. |

In P2, the leaf card views (`TextCardView`, `ListsCardView`, `ComparisonCardView`, `ReferencesCardView`, `CodeCardView`, `DiagramCardView`) and the exercise views (`Identify`, `Choose`, `TapLine`, `Reorder`, `Recall`, `FeedbackPanel`, `ExerciseCommon`) move into KataUI. They take values and closures (for example `onOpenItem: (ItemKey) -> Void`) instead of `AppModel`, so both apps render the same views. Screens such as Today, Path and Deck stay per-app.

### 1.4 Persistence: SwiftData schema V2

Add `KataStore/SchemaV2.swift`. Version 2.0.0 reuses the four V1 model classes unchanged and adds two models:

```swift
public enum KataSchemaV2: VersionedSchema {
  public static let versionIdentifier = Schema.Version(2, 0, 0)
  public static var models: [any PersistentModel.Type] {
    [KataSchemaV1.ExerciseCard.self, KataSchemaV1.ReviewLogEntry.self, KataSchemaV1.ItemProgress.self,
     KataSchemaV1.DailyActivity.self, KataAttempt.self, KataSolution.self]
  }
  /// One run-to-completion (or abandoned) attempt of an item's kata.
  @Model public final class KataAttempt {
    #Index<KataAttempt>([\.itemKey], [\.startedAt])
    public var itemKey: String          // ItemKey.rawValue
    public var startedAt: Date
    public var passedAt: Date?
    public var isReview: Bool
    public var hintsUsed: Int           // 0...3
    public var revealedSolution: Bool
    public var runCount: Int
    public var activeMillis: Int        // editing time, idle > 2 min excluded
    public var ratingRaw: Int?          // set when rated
    public var modeRaw: String          // "editor" | "ide"
  }
  /// Draft and last passing solution per item (files as JSON [name: source]).
  @Model public final class KataSolution {
    @Attribute(.unique) public var itemKey: String
    @Attribute(.externalStorage) public var draftJSON: Data
    @Attribute(.externalStorage) public var passedJSON: Data?
    public var passedAt: Date?
    public var updatedAt: Date
  }
}
enum KataMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] { [KataSchemaV1.self, KataSchemaV2.self] }
  static var stages: [MigrationStage] { [.lightweight(fromVersion: KataSchemaV1.self, toVersion: KataSchemaV2.self)] }
}
```

- **FSRS card.** The kata's FSRS card reuses `ExerciseCard` with key `ExerciseKey(item:, exercise: "kata")`, e.g. `design-patterns/strategy#kata`. The validator reserves the exercise id `kata`.
- **Effect on the iOS queue.** The regular queue drops these cards automatically (`library.exercise` is nil for them).
- **Mac mastery.** On the Mac, `StudyModel.masteryMap` adds the kata card and `totalExercises + 1` when the item has a kata.

New `ProgressStore` API:
- `kataDraft(_ item: ItemKey) -> [String: String]?`
- `saveKataDraft(_:files:)` (debounced 1 s by the caller)
- `startKataAttempt(_:isReview:mode:) -> PersistentIdentifier`
- `updateKataAttempt(…)`
- `recordKataPass(_ item:, files:, attempt:, rating:, now:)` creates or updates the `#kata` FSRS card through the same scheduler path as `record(...)`, appends a `ReviewLogEntry` with `responseMillis = activeMillis`, bumps `DailyActivity`, and sets `passedJSON`.
- `lastPassedSolution(_:)`
- `kataCards() -> [CardRecord]`
- `resetAllProgress()` also deletes the two new models.

V2 ships in P0, so iOS migrates once, early, on the device, before any Mac work. Its two new tables stay empty on iOS.

---

## 2. Kata content schema

### 2.1 Layout: a `kata/` subfolder per item, built into a separate Mac-only file

```
Content/topics/design-patterns/items/strategy/
  item.json, Strategy.java                 (unchanged)
  kata/kata.json
  kata/starter/Checkout.java
  kata/solution/Checkout.java  kata/solution/DiscountPolicy.java  kata/solution/Discounts.java
  kata/tests/StrategyKataTest.java
```

`kata-pack build` writes:
- `Kata/Resources/Packs/design-patterns.kpack`. Byte-identical to today, because katas are **not** added to `Item`.
- `KataMac/Resources/Katas/design-patterns.kkata`, encoding `KataPack { topicId, katas: [Kata] }`. The different extension matters: `ContentLibrary.live` would try to decode any `*.kpack` as a `Pack`.

The iOS app never loads katas, so there is no change to iOS decode cost or to the pack's CI diff. The Mac target adds the `.kpack` as an explicit `PBXFileReference` and `PBXBuildFile` in its Resources phase. That avoids moving the file, which would ripple into kata-pack, ContentTests, CI and the scripts.

`ContentLibrary` gains `public let katas: [ItemKey: Kata]`, an `init(packs:kataPacks:)`, and `static func live(bundle:includeKatas:)`.

### 2.2 `kata.json` (strict decoding, like everything else)

```jsonc
{
  "kind": "refactor",                 // refactor | implement | fix
  "title": "Take the promotions out of Checkout",       // ≤ 60 chars
  "minutes": 20,                      // target time for the rating suggestion, 10...40
  "task": [Block],                    // existing Block types, ≤ 180 words, must name every type/method tests rely on
  "starter":  ["Checkout.java"],      // files under kata/starter, editable unless listed in readOnly
  "readOnly": [],                     // e.g. given interfaces in implement katas
  "solution": ["Checkout.java", "DiscountPolicy.java", "Discounts.java"],
  "tests":    ["StrategyKataTest.java"],
  "checks": [                         // must equal the @Check ids the harness reports, in order
    {"id": "known-codes", "kind": "behaviour", "title": "Known codes give the same totals"},
    …
  ],
  "hints": [[Block], [Block], [Block]],   // exactly 3, progressive
  "timeoutSeconds": 10,               // whole-run wall clock (harness + Swift kill), ≤ 30
  "stressRuns": 20                    // optional; tooling repeats this many times (default 5)
}
```

Swift model in `KataCore/Models/Kata.swift`:
- `public struct Kata: Sendable, Codable, Equatable { itemId, kind: KataKind, title, minutes, task: [Block], starter: [KataFile], readOnly: Set<String>, solution: [KataFile], tests: [KataFile], checks: [KataCheckSpec], hints: [[Block]], timeoutSeconds, stressRuns }`
- `KataFile { name, source }`. Sources are embedded at build time, the same way code cards are.
- `KataCheckSpec { id, kind: CheckKind (.behaviour | .design), title }`

### 2.3 Harness API that tests use (package `kata`, bundled with the harness)

| Type | Members |
|---|---|
| `@Check(id, kind = Kind.BEHAVIOUR, timeoutMs = 2000, repeat = 1)` | A method annotation. Order comes from source position, read from the parsed tree. |
| `Expect` | `equal(expected, actual, what)`, `isTrue(cond, msg)`, `fail(msg)`, `raises(Class<T>, ThrowingRunnable, what)`, `none(List<Hit>, msg)`, `atMost(n, List<Hit>, msg)`, `completesWithin(ms, ThrowingSupplier, what)` |
| `Types` | `named("DiscountPolicy")` (fails with "No type named DiscountPolicy in your files"), `singleAbstractMethod`, `onlyFieldOfType`, `fieldsOfType`, `onlyStaticFieldOfType`, `setStatic`, `constructor(cls, params…)`, `method(cls, name, params…)`, `staticMethod`, `implement(iface, Function<Object[], Object>)` (a `java.lang.reflect.Proxy` that also handles `Object` methods and defaults). Everything uses `setAccessible(true)` and unwraps `InvocationTargetException`. |
| `Source` | `type("Checkout") → Shape`, `Shape.method("get") → Shape`, `switches()`, `instanceofs()`, `comparedStrings()` (string literals in `equals`, `equalsIgnoreCase`, `case` labels or `==`), `calls("name")`, `fieldReads("f")` returning `Hit { file, line, column, insideSynchronized }`, `news("Type")`, `mentions("Identifier")`. Built on `com.sun.source.util.TreePathScanner` over the trees the harness keeps from compiling the user's files. |
| `Stress` | `race(threads, Callable)` (start gate latch, joins with timeout, returns results), `pause(ms)` (only to widen a window, ≤ 50 ms), `holdMonitor(obj)` (an `AutoCloseable`; another thread holds the monitor until it is closed), `holdLock(Lock)` |

Two rules for refactor katas:
- **Behaviour checks compile against the stable API that exists in the starter.** They must pass on the starter: "tests stay green".
- **Design checks never reference new types at compile time.** They use only `Types` and `Source`, so a half-done refactor still compiles against the hidden tests.

### 2.4 Worked example: Strategy (refactor kind)

**`kata/starter/Checkout.java`**
```java
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

// Marketing adds a promotion every month, and every time this class changes.
final class Checkout {
    private final String code;

    Checkout(String code) { this.code = code; }

    BigDecimal total(List<BigDecimal> prices) {
        BigDecimal subtotal =
            prices.stream().reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal result;
        if (code.equals("NONE")) {
            result = subtotal;
        } else if (code.equals("SPRING10")) {
            result = subtotal.multiply(new BigDecimal("0.90"));
        } else if (code.equals("WELCOME")) {
            result = subtotal.subtract(new BigDecimal("7.50"))
                .max(BigDecimal.ZERO);
        } else if (code.equals("BULK")) {
            result = subtotal.compareTo(new BigDecimal("100.00")) >= 0
                ? subtotal.multiply(new BigDecimal("0.85"))
                : subtotal;
        } else {
            throw new IllegalArgumentException("unknown code: " + code);
        }
        return result.setScale(2, RoundingMode.HALF_EVEN);
    }
}

// Callers use this entry point. Keep its signature and behaviour.
final class Pricing {
    private Pricing() { }

    static BigDecimal total(String code, List<BigDecimal> prices) {
        return new Checkout(code).total(prices);
    }
}
```

**`kata/tests/StrategyKataTest.java`** (hidden)
```java
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.math.BigDecimal;
import java.util.List;
import kata.*;

class StrategyKataTest {
    static final List<BigDecimal> CART =
        List.of(new BigDecimal("19.99"), new BigDecimal("30.01"));

    static String total(String code, List<BigDecimal> prices) {
        return Pricing.total(code, prices).toPlainString();
    }

    @Check(id = "known-codes")
    void knownCodes() {
        Expect.equal("50.00", total("NONE", CART), "NONE");
        Expect.equal("45.00", total("SPRING10", CART), "SPRING10");
        Expect.equal("42.50", total("WELCOME", CART), "WELCOME");
    }

    @Check(id = "flat-floors-at-zero")
    void flatFloorsAtZero() {
        Expect.equal("0.00", total("WELCOME", List.of(new BigDecimal("5.00"))),
            "WELCOME on a 5.00 cart");
    }

    @Check(id = "bulk-threshold")
    void bulkThreshold() {
        Expect.equal("99.99", total("BULK", List.of(new BigDecimal("99.99"))), "BULK below 100");
        Expect.equal("85.00", total("BULK", List.of(new BigDecimal("100.00"))), "BULK at 100");
    }

    @Check(id = "unknown-code")
    void unknownCode() {
        Expect.raises(IllegalArgumentException.class,
            () -> Pricing.total("BOGUS", CART), "an unknown code");
    }

    @Check(id = "policy-interface", kind = Kind.DESIGN)
    void policyInterface() {
        Class<?> policy = Types.named("DiscountPolicy");
        Expect.isTrue(policy.isInterface(), "DiscountPolicy should be an interface");
        Method apply = Types.singleAbstractMethod(policy);
        Expect.equal("apply", apply.getName(), "the method name");
        Expect.equal(List.of(BigDecimal.class), List.of(apply.getParameterTypes()), "apply's parameters");
        Expect.equal(BigDecimal.class, apply.getReturnType(), "apply's return type");
    }

    @Check(id = "checkout-holds-policy", kind = Kind.DESIGN)
    void checkoutHoldsPolicy() {
        Class<?> policy = Types.named("DiscountPolicy");
        Class<?> checkout = Types.named("Checkout");
        Field f = Types.onlyFieldOfType(checkout, policy);
        int m = f.getModifiers();
        Expect.isTrue(Modifier.isPrivate(m) && Modifier.isFinal(m),
            "Checkout." + f.getName() + " should be private final");
        Expect.isTrue(Types.fieldsOfType(checkout, String.class).isEmpty(),
            "Checkout should no longer keep the discount code");
        Types.constructor(checkout, policy);   // fails: "Checkout needs a constructor Checkout(DiscountPolicy)"
    }

    @Check(id = "checkout-does-not-branch", kind = Kind.DESIGN)
    void checkoutDoesNotBranch() {
        var checkout = Source.type("Checkout");
        Expect.none(checkout.comparedStrings(), "Checkout still compares discount codes");
        Expect.none(checkout.switches(), "Checkout still switches on the discount");
        Expect.none(checkout.instanceofs(), "Checkout inspects the policy's concrete type");
    }

    @Check(id = "any-policy-works", kind = Kind.DESIGN)
    void anyPolicyWorks() throws Exception {
        Class<?> policy = Types.named("DiscountPolicy");
        Object half = Types.implement(policy, args -> ((BigDecimal) args[0]).divide(BigDecimal.TWO));
        Constructor<?> c = Types.constructor(Types.named("Checkout"), policy);
        Object checkout = c.newInstance(half);
        Method total = Types.method(checkout.getClass(), "total", List.class);
        Expect.equal("25.00", ((BigDecimal) total.invoke(checkout, CART)).toPlainString(),
            "Checkout with a policy it has never seen");
    }

    @Check(id = "lookup-in-discounts", kind = Kind.DESIGN)
    void lookupInDiscounts() throws Exception {
        Class<?> policy = Types.named("DiscountPolicy");
        Method forCode = Types.staticMethod(Types.named("Discounts"), "forCode", String.class);
        Expect.isTrue(policy.isAssignableFrom(forCode.getReturnType()),
            "Discounts.forCode should return a DiscountPolicy");
        Expect.isTrue(policy.isInstance(forCode.invoke(null, "SPRING10")),
            "SPRING10 should resolve to a policy");
    }
}
```

On the starter, the 4 behaviour checks pass. The design checks fail, starting at `policy-interface` ("No type named DiscountPolicy in your files").

**`kata/solution/DiscountPolicy.java`**
```java
import java.math.BigDecimal;

@FunctionalInterface
interface DiscountPolicy {
    BigDecimal apply(BigDecimal subtotal);
}

record PercentOff(int percent) implements DiscountPolicy {
    PercentOff {
        if (percent < 0 || percent > 100) {
            throw new IllegalArgumentException("percent");
        }
    }
    public BigDecimal apply(BigDecimal subtotal) {
        return subtotal.multiply(BigDecimal.valueOf(100 - percent, 2));
    }
}

record FlatOff(BigDecimal amount) implements DiscountPolicy {
    public BigDecimal apply(BigDecimal subtotal) {
        return subtotal.subtract(amount).max(BigDecimal.ZERO);
    }
}

record AtLeast(BigDecimal threshold, DiscountPolicy then) implements DiscountPolicy {
    public BigDecimal apply(BigDecimal subtotal) {
        return subtotal.compareTo(threshold) >= 0 ? then.apply(subtotal) : subtotal;
    }
}
```

**`kata/solution/Discounts.java`**
```java
import java.math.BigDecimal;
import java.util.Map;

final class Discounts {
    private static final Map<String, DiscountPolicy> BY_CODE = Map.of(
        "NONE", subtotal -> subtotal,
        "SPRING10", new PercentOff(10),
        "WELCOME", new FlatOff(new BigDecimal("7.50")),
        "BULK", new AtLeast(new BigDecimal("100.00"), new PercentOff(15)));

    private Discounts() { }

    static DiscountPolicy forCode(String code) {
        DiscountPolicy policy = BY_CODE.get(code);
        if (policy == null) {
            throw new IllegalArgumentException("unknown code: " + code);
        }
        return policy;
    }
}
```

**`kata/solution/Checkout.java`**
```java
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Objects;

final class Checkout {
    private final DiscountPolicy policy;

    Checkout(DiscountPolicy policy) {
        this.policy = Objects.requireNonNull(policy, "policy");
    }

    BigDecimal total(List<BigDecimal> prices) {
        BigDecimal subtotal =
            prices.stream().reduce(BigDecimal.ZERO, BigDecimal::add);
        return policy.apply(subtotal).setScale(2, RoundingMode.HALF_EVEN);
    }
}

final class Pricing {
    private Pricing() { }

    static BigDecimal total(String code, List<BigDecimal> prices) {
        return new Checkout(Discounts.forCode(code)).total(prices);
    }
}
```

The `"policy"` literal is an argument to `requireNonNull`, not a comparison, so `comparedStrings()` does not flag it. That is why the check is "compared strings" rather than "any literal".

**`kata.json` excerpt**
```json
{
  "kind": "refactor",
  "title": "Take the promotions out of Checkout",
  "minutes": 20,
  "task": [
    {"type": "lead", "text": "Every new promotion is another branch in `Checkout`."},
    {"type": "p", "text": "Refactor so a new promotion is a new **strategy**, not an edit to `Checkout`. `Pricing.total(code, prices)` must keep returning exactly what it returns now."},
    {"type": "bullets", "items": [
      "Add `interface DiscountPolicy` with one method, `BigDecimal apply(BigDecimal subtotal)`.",
      "`Checkout(DiscountPolicy)` sums the prices, delegates, and rounds to 2 places.",
      "Resolve codes in `Discounts.forCode(String)`; unknown codes throw `IllegalArgumentException`."]}
  ],
  "starter": ["Checkout.java"], "readOnly": [],
  "solution": ["Checkout.java", "DiscountPolicy.java", "Discounts.java"],
  "tests": ["StrategyKataTest.java"],
  "checks": [
    {"id": "known-codes", "kind": "behaviour", "title": "Known codes give the same totals"},
    {"id": "flat-floors-at-zero", "kind": "behaviour", "title": "A flat discount never goes below zero"},
    {"id": "bulk-threshold", "kind": "behaviour", "title": "BULK applies from 100.00"},
    {"id": "unknown-code", "kind": "behaviour", "title": "Unknown codes are rejected"},
    {"id": "policy-interface", "kind": "design", "title": "DiscountPolicy is a one-method interface"},
    {"id": "checkout-holds-policy", "kind": "design", "title": "Checkout holds a private final policy"},
    {"id": "checkout-does-not-branch", "kind": "design", "title": "Checkout has no code branches"},
    {"id": "any-policy-works", "kind": "design", "title": "Checkout accepts a policy it has never seen"},
    {"id": "lookup-in-discounts", "kind": "design", "title": "Codes are resolved in Discounts"}
  ],
  "hints": [
    [{"type": "p", "text": "Find what varies: the rule that turns a subtotal into a total. `Checkout` should only know that *some* rule does that. Give that rule a name."}],
    [{"type": "p", "text": "Give `Checkout` a `private final DiscountPolicy` set in its constructor. The string code belongs where policies are chosen, not where they are used."}],
    [{"type": "p", "text": "Back `Discounts.forCode` with a `Map<String, DiscountPolicy>`. Then:"},
     {"type": "code", "language": "java", "lines": [
       "static BigDecimal total(String code, List<BigDecimal> prices) {",
       "    return new Checkout(Discounts.forCode(code)).total(prices);",
       "}"]}]
  ],
  "timeoutSeconds": 10
}
```

### 2.5 Sketch: Double-Checked Locking (fix kind, deterministic concurrency)

The starter has three bugs and a documented test seam:

```java
final class Config {
    static final AtomicInteger CREATED = new AtomicInteger();
    static volatile Runnable onConstruct = () -> { };   // test hook: keep it
    private static Config instance;                     // bug 1: not volatile
    private final Map<String, String> settings;
    private Config() { onConstruct.run(); CREATED.incrementAndGet(); settings = Map.of("mode", "prod"); }
    static Config get() {
        if (instance == null) {
            synchronized (Config.class) {
                instance = new Config();                // bug 2: no second check
            }
        }
        return instance;                                // bug 3: second racy read of the field
    }
    String mode() { return settings.get("mode"); }
}
```

Checks:

| id | kind | How it is deterministic |
|---|---|---|
| `one-instance-under-contention` (`timeoutMs=5000, repeat=10`) | behaviour | Reset through `Types.setStatic`. Set `onConstruct = () -> Stress.pause(20)` and run `Stress.race(8, Config::get)`. The 8 threads are released together and all pass the outer `null` check while the first constructor sleeps. Without the inner check, `CREATED` is 8 on every run. Expect `CREATED == 1` and one identity. |
| `fast-path-does-not-lock` | behaviour | Call `Config.get()` once. Then, inside `try (var h = Stress.holdMonitor(Config.class))`, `Expect.completesWithin(300, Config::get, …)`. This fails the tempting "fix" of making `get()` `synchronized`. It passes on the starter, which is fine: it guards against regressions. |
| `instance-is-volatile` | design | `Modifier.isVolatile(Types.onlyStaticFieldOfType(Config.class, Config.class))`. A missing `volatile` is a memory-model bug that tests cannot observe reliably, so it is a design check. |
| `single-read-on-fast-path` | design | `Expect.atMost(1, Source.type("Config").method("get").fieldReads("instance").stream().filter(h -> !h.insideSynchronized()).toList(), "Read instance once into a local")` |

Tooling runs the starter 20 times and requires it to fail `one-instance` every time. It runs the reference 20 times each with `-XX:ActiveProcessorCount=1` and `=4`, and requires a pass every time.

### 2.6 Sketch: Builder (implement kind)

- **Task.** Build an immutable `HttpRequest(method, uri, headers, body, timeout)` through `HttpRequest.builder(String uri)`, with fluent `method`, `header(name, value)` (repeatable, order kept), `body`, `timeout` and `build()`. Defaults are `GET` and 30 s. `build()` throws `IllegalStateException` for a GET with a body, a non-positive timeout or a blank URI.
- **Starter.** The record and a `static final class Builder` with the signatures already declared, every body `throw new UnsupportedOperationException("TODO")`. Implement-kind starters must compile, so hidden tests can call the API directly and feedback stays useful.
- **Behaviour checks:** `defaults`, `fluent-chain`, `headers-keep-order-and-repeats`, `rejects-get-with-body`, `rejects-bad-timeout`, `builder-reusable` (two `build()` calls give equal but independent products).
- **Design checks:**
  - `product-immutable`: all fields private final, `headers()` unmodifiable (adding to it raises `UnsupportedOperationException`).
  - `defensive-copy`: changing the builder after `build()` does not change the product.
  - `fluent-returns-builder`: every non-`build` public method on the Builder returns the Builder type.
  - `no-telescoping-constructor`: `HttpRequest` has no non-private constructor except the record's canonical one, and `Builder`'s constructor is private.

---

## 3. Validation and tooling

### 3.1 Loader and validator

- **Loader.** `KataLoader.load(itemDir:)` is called from `PackBuilder.load` when `kata/` exists. It reads `kata.json` and embeds the file sources. `PackBuilder.buildKatas(topicDirectory:) -> KataPack` and `encodeKatas` give sorted, reproducible output.
- **`KataValidator` rules.** Errors unless marked as a warning:
  - The kind is known.
  - `title` ≤ 60 characters. `task` ≤ 180 words. `minutes` is in 10...40.
  - There are exactly 3 hints. Each hint is ≤ 50 words, and code blocks only in hint 3, ≤ 10 lines.
  - Every listed file exists, ends in `.java`, and there are no stray files.
  - Starter files are ≤ 120 lines and solution files ≤ 150 lines. Columns: ≤ 100 is an error, ≤ 80 is a warning.
  - `readOnly` ⊆ `starter`, and read-only files are identical in the starter and the solution.
  - Test files declare no top-level type whose name also appears in the solution.
  - Check ids are kebab-case and unique.
  - Kind-specific minimums:
    - refactor: ≥ 2 behaviour checks and ≥ 2 design checks.
    - implement: ≥ 4 checks in total.
    - fix: ≥ 1 behaviour check.
  - `timeoutSeconds` ≤ 30.
  - The exercise id `kata` is reserved.
  - `kata:` links in task and hints resolve.
  - There is no `System.exit` in the starter or solution.
  - When `requireAllKatas` is on, every registry item has a kata.

### 3.2 `kata-pack check-java`, extended

```
kata-pack check-java [--items a,b] [--no-katas] [--kata-runs N] [--jdk <home>] [--timing]
kata-pack kata-workspace --items strategy [--solution] --out <dir>   # authors iterate in IntelliJ
```

For each kata, using the same `KataCheckRunner` as the app (shared harness, so the CLI and the app agree):
1. **Reference** (solution files): every check passes on each of N runs. N is `stressRuns` or 5. Concurrency-category katas also run under `-XX:ActiveProcessorCount=1` and `=4`.
2. **Starter**, by kind:
   - refactor: compiles, every behaviour check passes, at least one design check fails, every run.
   - fix: compiles, at least one behaviour check fails, every run.
   - implement: compiles, at least one check fails. A starter that fails to compile is allowed only with `"starterCompiles": false`; the default is true.
3. **Consistency**: the reported check ids equal `checks[].id` in the same order. No check reports `timeout` on the reference. The median wall time is printed with `--timing`; a median above 2 s is a warning.
4. Output is JSON, as today. The exit code is 1 on any failure.

### 3.3 ContentTests and CI

- `ContentTests`:
  - `katasValidateStrictly`
  - `kkataIsUpToDate` (builds into a temp dir and compares bytes with `KataMac/Resources/Katas/*.kkata`)
  - `everyItemHasKata` (gated by `let requireAllKatas = false` until P4 finishes)
  - `kataReferencesPassAndStartersFail`, enabled when `JDKLocator.default(minimum: 21)` finds a JDK; 3 runs in CI.
- **New `KataRunTests`** (host): harness fixtures (§9) and NDJSON parser and diagnostics-mapping unit tests that need no JDK.
- `.github/workflows/ci.yml`:
  - `content` already installs Temurin 21, so kata checks run there.
  - Add a step `swift run --package-path Packages/KataKit kata-pack build && git diff --exit-code Kata/Resources/Packs KataMac/Resources/Katas`.
  - New job `mac-build`: `xcodebuild -project Kata.xcodeproj -scheme KataMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet build-for-testing`.
  - `kit-tests` gains `setup-java` 21 so `KataRunTests` run.

---

## 4. The Java harness

### 4.1 Files (`Packages/KataKit/Sources/KataRun/Harness/`, a `.copy` resource)

`KataHarness.java` (main, unnamed package) plus `kata/Check.java`, `kata/Kind.java`, `kata/Expect.java`, `kata/Types.java`, `kata/Source.java`, `kata/Stress.java` and `kata/CheckFailure.java`.

### 4.2 Harness cache

`HarnessCache.ensure(jdk:) -> URL`:
- Key: `sha256(harness sources) + JDK release` (from `<home>/release` `JAVA_VERSION`).
- Directory: `~/Library/Caches/com.github.meysampg.kata.mac/harness/<key>/classes`.
- Built once with `javac --release 21 -d …`.
- The CDS archive sits next to it: `harness.jsa`.

### 4.3 Per-check process

One fresh JVM per check:

```
<jdk>/bin/java -XX:+UseSerialGC -Xmx256m -Xss1m -XX:TieredStopAtLevel=1 -XX:-UsePerfData
  -XX:+AutoCreateSharedArchive -XX:SharedArchiveFile=<cache>/harness.jsa
  -Djava.awt.headless=true -Dfile.encoding=UTF-8 -cp <cache>/classes
  KataHarness --src <run>/src --tests <run>/tests --classes <run>/classes
              --report <run>/report.ndjson --release 21 [--repeat N]
```

Process setup: `cwd` is the run directory (`~/Library/Caches/…/runs/<uuid>`, deleted afterwards). The environment is minimal: `PATH=/usr/bin:/bin`, `HOME`, `LANG=en_US.UTF-8`, `TMPDIR` set to the run directory, and no `JAVA_TOOL_OPTIONS`.

Inside the harness:
1. **Compile in-process** with `JavacTool` and `JavacTask` (`parse → analyze → generate`) over user and test sources together. Options: `--release 21 -Xlint:all -proc:none -g -encoding UTF-8`, classpath set to the harness classes. Trees of the user files are kept for `Source`.
   - If any error is in a test file, compile the user files alone. User-file errors become `compile` diagnostics. Checks in the failing test files become `blocked`, with the sanitized message, for example "needs: cannot find symbol DiscountPolicy". Hidden test lines are never shown.
2. **Policy scan** of the user trees: `System.exit`, `Runtime.getRuntime().exit/halt`, `ProcessBuilder` and `Runtime.exec` become error diagnostics at their positions, and the run stops before execution.
3. **Load** user and test classes with **one** `URLClassLoader(classesDir, parent = harness loader)`. Tests and user code must share a runtime package so package-private access works.
4. **Run each check** on a fresh test instance in a new daemon platform thread `kata-check-<id>`, then `join(timeoutMs)`.
   - Status is one of `pass | fail | error | timeout | blocked | exited`.
   - The failure location is the first stack frame in a user file (file and line). An `Expect` with `Hit`s uses the hit's position.
   - On timeout, include the check thread's stack and `ThreadMXBean.findDeadlockedThreads()` lock-owner info. Deadlock reports matter for the concurrency katas. Remaining checks still run, and are flagged as possibly affected when a previous check timed out.
5. **Output capture.** `System.setOut`/`setErr` point to a thread-safe capped stream: 64 KB per check and 1 MB per run, then `[output truncated]`. Captured text is attached to the check.
6. **Report.** One NDJSON line per event, flushed:
   - `{"type":"compile","ok":true|false,"diagnostics":[{"severity","file","line","column","start","end","code","message"}]}`
   - `{"type":"check","id","kind","status","message","file","line","millis","output","run"}`
   - `{"type":"done","millis"}`
7. **Shutdown hook.** It writes `{"type":"check","id":<current>,"status":"exited"}` and `done`. Shutdown hooks run on `System.exit`, so an exit that slips past the scan (for example through reflection) is still reported.
8. **End.** Write `done`, then `Runtime.getRuntime().halt(0)`, which kills lingering daemon threads from timed-out checks.

### 4.4 Swift side (`KataRun`)

- **`JDKLocator`.**
  - Parses `/usr/libexec/java_home -X` (a plist of `JVMHomePath`, `JVMVersion`, `JVMVendor`, `JVMName`) and keeps major version ≥ 21 that have `bin/javac`. Here that finds 26, 25, 24 and 23.
  - The default is `java_home -v 21+`.
  - The Settings choice is stored as a home path; if it disappears, fall back to the default.
- **`KataProcess`.**
  - `Process` with `standardOutput`/`standardError` pipes read through `readabilityHandler` into capped buffers (4 MB). Going over the cap kills the process.
  - Wall-clock deadline = `timeoutSeconds` + 3 s compile allowance. When it passes, `kill(pid, SIGKILL)`.
  - Run it as an `actor`, bridging callbacks with `AsyncStream` (Swift 6 strict concurrency).
  - Stray children are rare. `ProcessBuilder` is blocked by the policy scan, and SIGKILL to the JVM is enough.
- **`KataCheckRunner` (actor).**
  - `func run(_ request: KataRunRequest) async throws -> KataReport`. The request carries `files`, `tests`, `jdk`, `repeat` and `timeout`.
  - Writes the files, spawns the process, and parses NDJSON with `KataReport.parse` (pure and unit-tested; a missing `done` gives `crashed = true` plus the stderr tail).
  - Allows one run at a time per session; a new ⌘R cancels the run in flight.
- **Diagnostics to the editor.** The harness emits javac `getStartPosition()`/`getEndPosition()`. Those are **char offsets, which are UTF-16 code units, the same unit as `NSString`**, so they map straight to an `NSRange` in the editor. `line`/`column` are for display only (javac expands tabs in columns). Diagnostics in hidden tests map to "Hidden test" rows with no jump.

### 4.5 Performance

- **Target: under 2 s per check** on an M-series Mac.
- **Budget:** JVM start with AppCDS ≈ 0.1 s, in-process javac on about 300 lines while cold ≈ 0.5–0.9 s, checks ≈ 0.1–0.5 s (concurrency katas up to 1–2 s by design).
- **P1 acceptance:** median of 10 Strategy runs under 2 s, measured and logged with `--timing`.
- **Later (not in v1):**
  - A warm daemon, `KataHarness --serve` (NDJSON requests on stdin, the same request and report shapes, a fresh classloader per run).
  - On a timeout or exit, kill and respawn it.
  - Expected time per check: about 150–300 ms.

---

## 5. Mac UX

### 5.1 Scenes

- `WindowGroup(id: "main")`: minimum size 960×640, frame autosaved.
- `Settings { MacSettingsView() }` (⌘,).
- `.commands { KataCommands(); SidebarCommands(); TextEditingCommands() }`.

### 5.2 Main window: `NavigationSplitView`

- **Sidebar** (`MacSidebar`):
  - Today, Path, Library (with categories expandable to their items), Search (the `.searchable` toolbar field), Bookmarks.
  - Badges on Today: N reviews due, M katas due.
- **Content column** (Path, Library, Search): a list of `ItemRow` equivalents with mastery rings.
- **Today** uses the detail area directly:
  - A "Reviews" card with **Start review**.
  - A "Katas due" card listing the due katas. `KataQueue` caps them at `katasPerDay`, default 2.
  - Streak, continue your path, recently studied.
- **Item detail (`MacItemView`):**
  - Toolbar segmented control: **Cards · Practice · Kata**.
    - Cards: role picker with symbols. ⌥⌘1…⌥⌘7 jump to a role; ⌘[ and ⌘] step pages. Content has a readable width (≤ 760 pt) and reuses the KataUI card views. Code cards use `CodeWalkthroughView` with ↑/↓ to step. Diagrams zoom with pinch or ⌘+/⌘−.
    - Practice: the shared exercise views. Return checks the answer, 1–4 rate, Space reveals the recall answer.
    - Kata is disabled with a tooltip until the item's exercises have been practised. This is a soft gate: "Recommended after the cards" plus an Override button.
  - Bookmark and note in the toolbar.

### 5.3 Kata screen (`KataView`, driven by `KataSessionModel`)

```
┌ Task (280–420) ─────────┬ Editor ────────────────────────────┬ Results (300–440) ──────────┐
│ title · kind badge      │ [Checkout.java][+]  editing ◉ IDE ○│ ▶ Run  ⌘R   0.9 s  ✓ 7/9    │
│ task blocks             │ 1 │ final class Checkout {         │ Compiler (1)                 │
│ Checks (pending/✓/✗)    │ 2 │   ...                          │  ✗ Checkout.java:14 cannot…  │ ← click jumps
│ Hints: 1 of 3 shown     │   │  (error underline, gutter dot) │ Behaviour  ✓✓✓✓              │
│ [Show hint ⇧⌘H]         │                                    │ Design     ✓✗✓✓✗  (msg + line)│
│ [Reveal solution ⌥⌘S]   │ status: Ln 14, Col 9 · Java · 4sp  │ Output ▸ (captured stdout)   │
└─────────────────────────┴────────────────────────────────────┴──────────────────────────────┘
```

- **Layout.** `HSplitView` with three panes. The results pane collapses to the bottom below 1200 pt of width (`ViewThatFits`).
- **When every check passes:** a banner "All 9 checks pass · 12:40 · 0 hints", then `RatingBar` with the suggested rating, then **Compare with reference** (read-only reference beside the user's code) and **Previous solution** (the last `passedJSON`).
- **Hints.** Up to three, revealed in order, each confirmed once. After the third, **Reveal solution** opens the reference read-only with a "Copy into editor" action. Revealing marks the attempt.
- **Review mode.** When a kata card is due, opening it **starts from the starter**: the draft is reset and the previous solution is hidden until the user passes. "Practice again" is always available. If the card is not due, it does not change FSRS unless the user chooses Rate.
- **Rating suggestion** (`KataGrader.suggest(hints:revealed:activeMillis:minutes:runs:) -> Rating`, pure and tested):
  - Solution revealed, or 3 hints → **Again**.
  - 1–2 hints → **Hard**.
  - 0 hints, ≤ 0.6 × minutes and ≤ 3 runs → **Easy**.
  - 0 hints, ≤ 1.5 × minutes → **Good**.
  - Anything slower → **Hard**.
  - The user may override, as on iOS.
- **Built-in editor** (`KataEditor`): the comparison and choice are in the table below.

| Option | Verdict |
|---|---|
| SwiftUI `TextEditor(text: Binding<AttributedString>)` (macOS 26) | No line-number gutter, no hook for Tab or auto-indent other than `onKeyPress` hacks, whole-string rehighlighting on every keystroke disturbs the selection and undo, and no reliable scroll-to-range. **Rejected for v1.** |
| `NSTextView` (TextKit 1) in `NSViewRepresentable` | Mature `NSRulerView` gutter, find bar, undo, `insertTab`/`insertNewline` overrides, temporary attributes for highlighting that never touch undo. **Chosen.** Move to TextKit 2 later if needed. |

- **`CodeTextView: NSTextView` details:**
  - Monospaced font at `MacSettings.editorFontSize`, 11–20, default 13.
  - Smart quotes, dashes and substitutions off; spell checking off; `usesFindBar = true`.
  - Tab inserts 4 spaces, and ⇧Tab outdents the selection.
  - Newline copies the current indentation and adds 4 after `{`, `(` or `->`. Typing `}` on a blank line outdents. ⌘/ toggles `//`.
  - These rules live in pure `KataCode/Indentation.swift`, unit-tested.
- **`EditorHighlighter`:** on `textStorage(_:didProcessEditing:)`, re-lex with `JavaLexer`. Kata files are ≤ 150 lines, so lexing takes well under 1 ms. Apply `layoutManager.addTemporaryAttribute` only to token ranges that changed (a diff of the token arrays). Colors come from KataUI `CodeTheme` (light and dark).
- **Diagnostics:** red or yellow squiggles as temporary underline attributes, gutter markers with a tooltip, and `scrollTo(range:)` with a selection flash.
- **Files:** a tab per file, `+` adds a `.java` file (refactor and implement only), read-only files are shown greyed. The draft autosaves 1 s after the last edit.

### 5.4 IDE mode

- **Workspace.** `WorkspaceWriter.write(kata:item:files:) → ~/Kata/workspaces/<topic>/<item>/`. The root is configurable.
  - `src/*.java`: the user's current files. Read-only files get a `// Provided — do not edit` header and are made non-writable (`chmod 444`).
  - `README.md`: task, check titles, and "Results appear in Kata. Save to re-check."
  - IntelliJ project files: `.idea/modules.xml`, `.idea/misc.xml` (`languageLevel="JDK_21"`, no project JDK name, so IntelliJ uses its default SDK or prompts), and `<item>.iml` (`src` as a source root, `inheritedJdk`).
  - `.vscode/settings.json` with `{"java.project.sourcePaths": ["src"]}`, which jdtls in Cursor and the Zed Java extension read.
  - `.gitignore`.
  - **No pom or Gradle file**: they would trigger network resolution in IntelliJ. This is an open decision (§10).
- **Launch.** `IDELauncher` detects installed IDEs with `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` for `com.jetbrains.intellij`, `com.jetbrains.intellij.ce`, `dev.zed.Zed` and `com.todesktop.230313mzl4w4u92`. An "Other…" app picker is also offered. It opens the folder with `NSWorkspace.shared.open([folder, mainFile], withApplicationAt:configuration:)`, which is equivalent to `open -a` with better errors.
- **Watching.** `FolderWatcher` uses an FSEvents stream (`kFSEventStreamCreateFlagFileEvents`, 0.3 s latency) on `src/`. It ignores `.idea` and temp or backup files, and handles IntelliJ's atomic "safe write" renames. A content hash skips no-op saves. Each real change re-runs checks when "Re-check on save" is on (the default), debounced by 500 ms.
- **While in IDE mode:**
  - The built-in editor becomes a **read-only mirror** of the disk, with the banner "Editing in IntelliJ IDEA · watching for saves · [Back to built-in editor]".
  - Switching back imports the disk files into the draft.
  - Results always show in the app.

### 5.5 Commands (`KataCommands`, routed with `@FocusedValue(\.kataSession)`)

| Command | Shortcut |
|---|---|
| Run checks | ⌘R |
| Show next hint | ⇧⌘H |
| Open in IDE (default IDE; submenu for the others) | ⌘O |
| Reveal solution | ⌥⌘S |
| Reset to starter (confirm) | ⇧⌘⌫ |
| Next / previous card | ⌘] / ⌘[ |
| Go to Today / Path / Library / Search | ⌘1 / ⌘2 / ⌘3 / ⌘4 (⌘F focuses search) |
| Start review | ⇧⌘R |
| Jump to next diagnostic | ⌘' |
| Editor font bigger / smaller | ⌘+ / ⌘− (when the editor is focused) |

### 5.6 Settings (`MacSettingsView`, `TabView`)

- **General:** retention, new exercises per day, review limit, katas per day (1...5, default 2).
- **Editor:** font size, line numbers, re-check on save, a live preview.
- **Java:**
  - A JDK picker listing "Default (java_home -v 21+) — Temurin 26.0.2" plus each detected JDK ≥ 21.
  - **Test** runs `javac -version`, compiles the harness, and runs a tiny sample kata, showing a timing.
  - A "No JDK 21+ found" state with `brew install --cask temurin@21` guidance.
- **IDE:** a picker of detected IDEs plus "Other…", the workspace root (Choose…, Reveal in Finder), and "Clean workspaces".
- Light and dark follow the system. The app accent and code theme come from KataUI.

### 5.7 Signing and runtime

KataMac build settings:
- `SDKROOT = macosx`, `MACOSX_DEPLOYMENT_TARGET = 26.0`, `SUPPORTED_PLATFORMS = macosx`
- `ENABLE_APP_SANDBOX = NO`, `ENABLE_HARDENED_RUNTIME = YES`
- `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM = N9GSW3M5U8`
- `PRODUCT_BUNDLE_IDENTIFIER = com.github.meysampg.kata.mac`
- `GENERATE_INFOPLIST_FILE = YES`, `INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.education`

What the free Apple ID means here:
- Apple Development signing with the personal team works for a Mac app run on this Mac.
- The app uses no capabilities, so no restricted entitlements and no provisioning profile are needed.
- The 7-day expiry of free provisioning that drives `Tools/renew.sh` applies to iOS, not here.
- A locally built app is not quarantined, so Gatekeeper lets it run. No notarization is needed for local use.
- Notarization needs a paid Developer ID. Copies given to other Macs would need right-click → Open, or `xattr -dr com.apple.quarantine`.
- Hardened runtime does not prevent spawning `java`. Library validation applies only to Kata's own process. No `cs.*` exceptions are needed.

---

## 6. iOS impact and regression safety

1. **The iOS pack is byte-identical** because katas live in a separate `.kkata` that iOS never bundles. CI's diff check enforces this.
2. **P0 module moves:** iOS imports `KataStore` and the code is unchanged. Guards:
   - `ProgressStoreTests` and `AppSettingsTests` (now host tests) stay green.
   - A new `MigrationTests` writes an on-disk V1 store in a temp directory using a V1-only container, inserts every model, reopens it with the V2 migration plan, and asserts the rows are intact.
   - **On-device upgrade test:** before P0, note the due count, streak and studied count on the iPhone 11. Install the P0 build over it (`Tools/install.sh`) and check that all of them are identical.
3. **KataUI de-guarding:** run `Tools/capture_screenshots.sh` before and after P0 and P2 and compare the images pixel for pixel, for example with a small `compare` step or a Swift diff in `Tools/`. Any difference must be explained.
4. **Kata hint on iOS:** hidden in P0–P4, so there is no iOS UI change. In P5, optionally add one footnote under **Practice this pattern**: "A coding kata for this item is in Kata for Mac." It would sit behind a constant, since all 70 items will have katas.
5. **`KataTests`** keeps `BundledPackSmokeTests` (still 70 items, Strategy has every role) and `ReminderSchedulerTests`, and adds `ContainerV2SmokeTests`. CI's `app-build` job is unchanged.
6. **Filename uniqueness** (synchronized groups flatten resources): Mac files use a `Mac` prefix (`MacAppModel`, `MacSidebar`, `MacSettingsView`). The `.kkata` name is unique.

---

## 7. Authoring 70 katas

### 7.1 Kind per item (27 refactor · 30 implement · 13 fix)

| Category | refactor | implement | fix |
|---|---|---|---|
| **Foundations** | `srp` (report service doing parse, format and send), `ocp` (shape `switch` → polymorphism), `isp` (fat `Machine` → role interfaces), `dip` (service `new`s its repository → port), `program-to-interface` (`ArrayList`-typed APIs; tests swap the implementation), `tell-dont-ask` (getter-chasing client → behaviour on `Account`) | — | `lsp` (`Square extends Rectangle` breaks the contract tests), `composition-over-inheritance` (`InstrumentedSet extends HashSet` double-counts `addAll` → forwarding wrapper) |
| **Creational** | `factory-method` (type `switch` in an exporter) | `abstract-factory` (two widget families; interfaces given), `builder` | `prototype` (shallow copy shares a mutable list), `singleton` (racy lazy init → holder or enum; reflection and serialization checks) |
| **Structural** | `bridge` (Shape×Renderer class explosion), `decorator` (subclass explosion of compression and encryption streams), `facade` (client orchestrates four subsystems), `flyweight` (per-glyph style objects; checks count instances) | `adapter` (legacy sensor → `Thermometer`), `composite` (file sizes over a `Node` tree), `proxy` (lazy, caching image proxy; checks count real loads) | — |
| **Behavioral** | `chain-of-responsibility` (nested approval `if`s), `mediator` (widgets referencing each other), `state` (status enum `switch` in every method), `strategy`, `template-method` (two near-duplicate importers; template method must be `final`) | `command` (editor with undo and redo), `interpreter` (boolean expression AST), `iterator` (ring buffer `Iterable`, fail-fast), `memento` (snapshots without exposing state), `visitor` (pricing and printing visitors over a sealed AST) | `observer` (mutating listeners during notify → CME; unsubscribe handle) |
| **Concurrency** | `future-promise` (blocking `get()` chain → `CompletableFuture` composition; design check: no `get`/`join` in the pipeline) | `guarded-suspension` (a slot with `while`-guarded wait or `Condition`), `thread-pool` (tiny fixed pool over a `BlockingQueue` with shutdown), `active-object` (single-thread scheduler; every call runs on one thread), `reactor` (in-memory demultiplexer and handler registry), `fork-join` (a `RecursiveTask` with a threshold) | `immutable-object` (leaks a mutable list and `Date`, non-final fields), `producer-consumer` (no poison pill → consumers never end; exercises timeouts), `read-write-lock` (read→write lock upgrade **deadlocks every time**; the harness reports the deadlock), `double-checked-locking` |
| **Enterprise** | `layered-architecture` (controller does data access; `Source` checks forbid presentation → data references), `hexagonal` (domain calls SMTP and the clock directly → ports), `dependency-injection` (hard-wired `new` and static singletons), `data-mapper` (entity with `toRow`/`fromRow`), `specification` (`findByAAndBAndC` explosion), `domain-event` (`Order.place()` calls services), `cqrs` (one service mixing reads and writes → handler plus projection) | `mvc`, `mvvm` (ViewModel exposes observable state and never references a view), `service-locator` (typed registry that fails fast), `repository`, `unit-of-work` (new/dirty/removed tracking, commit order, rollback), `active-record`, `event-sourcing` (rebuild an aggregate from events) | `dto` (API leaks an entity's `passwordHash` → DTO mapping) |
| **Resilience** | `transactional-outbox` (dual write → outbox plus relay), `sidecar` (cross-cutting concerns tangled into the handler → wrapper component), `strangler-fig` (route between legacy and new behind a facade) | `retry-backoff` (fake sleeper, capped exponential backoff, seeded jitter, retryable exceptions only), `circuit-breaker` (fake clock, half-open), `bulkhead` (semaphore with latches), `rate-limiter` (token bucket, fake clock), `saga` (compensate in reverse), `competing-consumers`, `api-gateway` (prefix routing, auth, aggregation), `ambassador` (client-side proxy with retry and timeout) | `timeout` (unbounded blocking call → bounded and cancelled), `idempotent-consumer` (duplicates processed twice, including concurrent duplicates), `cache-aside` (stale read after a write → invalidate; null caching) |

Totals: Foundations 6R/2F, Creational 1R/2I/2F, Structural 4R/3I, Behavioral 5R/5I/1F, Concurrency 1R/5I/4F, Enterprise 7R/7I/1F, Resilience 3R/8I/3F. That is 27 + 30 + 13 = 70.

### 7.2 Additions to `CONTENT_GUIDE.md` (written in P1 with Strategy as the gold standard)

- **File layout and schema** (§2), with a pointer to `items/strategy/kata/`.
- **Choosing the kind:**
  - refactor when the pattern removes a smell from working code.
  - implement when the pattern is a construction with a crisp contract.
  - fix when the pattern's classic failure is the lesson.
- **Task rules:** ≤ 180 words. Name every type and method signature the tests rely on. State what must not change.
- **Test rules:**
  - Behaviour checks in refactor katas use only the stable API. Design checks use only `Types`/`Source`.
  - Messages are actionable and name the type, for example "Checkout still compares discount codes", and they point to a line through `Hit`s.
  - There are 6–10 checks. Each check tests one idea.
- **Concurrency determinism:**
  - Make failures certain through seams (documented hooks such as `onConstruct`) and start gates (`Stress.race`).
  - Never rely on timing for correctness. `Stress.pause` only widens a window and is ≤ 50 ms.
  - Per-check `timeoutMs` ≤ 5000. The reference must pass with `ActiveProcessorCount` 1 and 4. Use `stressRuns: 20`.
  - Memory-model bugs that cannot be observed reliably become design checks (for example `volatile`).
- **Hint ladder:**
  - H1 names the concept or what varies.
  - H2 gives the structural direction, naming the types.
  - H3 is nearly the solution with ≤ 10 code lines.
  - None of them pastes the full answer.
- **Limits:** starter ≤ 120 lines, solution ≤ 150 lines, ≤ 80 columns (warning), Java 21, no `public` types, no `System.exit`, deterministic.
- **Verification:** `kata-pack validate --items …` and `kata-pack check-java --items … --kata-runs 5`. Authors iterate with `kata-pack kata-workspace --items x --out /tmp/x` in IntelliJ.

### 7.3 Batches (10 Sonnet subagents: 5 in parallel, then 5 more; Strategy is done in P1)

Concurrency is split in two because those katas are the hardest and most likely to be flaky.

| Batch | Items |
|---|---|
| K1 | foundations (8) |
| K2 | creational (5) |
| K3 | structural (7) |
| K4 | behavioral except Strategy (10) |
| K5 | concurrency A: immutable-object, guarded-suspension, producer-consumer, thread-pool, future-promise |
| K6 | concurrency B: read-write-lock, double-checked-locking, active-object, reactor, fork-join |
| K7 | enterprise A: layered, hexagonal, mvc, mvvm, dependency-injection, service-locator, dto, specification |
| K8 | enterprise B: repository, unit-of-work, data-mapper, active-record, domain-event, cqrs, event-sourcing |
| K9 | resilience A: timeout, retry-backoff, circuit-breaker, bulkhead, rate-limiter, cache-aside, idempotent-consumer |
| K10 | resilience B: competing-consumers, api-gateway, sidecar, ambassador, strangler-fig, transactional-outbox, saga |

- **Each prompt includes:** the guide's kata section, all Strategy kata files, the harness API reference (`kata/*.java` Javadoc), the item's existing `item.json` and code card (the kata should echo the card's domain *or* use the example card's domain, never a third one), the kind from §7.1, and the DCL and Builder sketches.
- **Subagents:**
  - Write only under `items/<ids>/kata/`.
  - Iterate until `validate` and `check-java --kata-runs 5` are clean (20 runs for K5 and K6).
  - Report median timings and any check they consider weak.
- **Opus review per batch:**
  - Is the task unambiguous? Do the checks enforce *the pattern*, not one particular spelling of it? Try two alternative correct solutions, for example a lambda-only Strategy or `enum` strategies.
  - Do the design checks stay free of false positives? Do the hints climb properly?
  - Are the concurrency checks deterministic? Run them 50 times.
  - The reviewer applies fixes. The lead runs a strict `validate`, `check-java`, then `build`, and makes one commit per batch.
  - The user spot-checks one kata per batch in the Mac app.

---

## 8. Phased milestones

| Phase | Work | Acceptance |
|---|---|---|
| **P0: Shared modules** | Package to `.macOS(.v26)`. Create the `KataStore` target (move Persistence, AppSettings, StudyModel, PracticeSessionModel; make them public). Add SchemaV2 with the lightweight stage. Port tests to `KataStoreTests` and add `MigrationTests`. De-guard KataUI with the `Platform.swift` shim. iOS `AppModel` composes `StudyModel`. Update ARCHITECTURE §1–2. | `swift test` green (KataUITests now also run on macOS). iOS `build-for-testing` green. **On-device upgrade over existing data keeps due count, streak and studied count.** Screenshots pixel-identical. CI green. |
| **P1: Harness, schema, tooling, Strategy** | `Kata` models, loader, validator, `KataGrader`, `KataQueue`. `.kkata` build. `KataRun` (JDKLocator, HarnessCache, KataProcess, KataCheckRunner, KataReport). Harness Java sources. `check-java` kata mode, `kata-workspace`. Strategy kata. Draft the CONTENT_GUIDE kata section. ContentTests and CI updates. Harness fixture tests. | `kata-pack check-java --items strategy`: reference 5/5 pass; starter keeps behaviour green and fails design checks 5/5. Every fixture gives its expected status (§9). Strategy median < 2 s over 10 runs, logged. CI green with Temurin 21. |
| **P2: Mac shell and cards** | KataMac and KataMacTests targets in the pbxproj (new `CA7A…` IDs, synchronized groups `KataMac/` and `KataMacTests/`, explicit `.kpack` and `.kkata` resource references, `KataMac.xcscheme`, signing settings from §5.7). `MacAppModel`, `MacSidebar`, Today/Path/Library/Search, `MacItemView` (cards and practice). Leaf card and exercise views move into KataUI. Settings General tab. Store at an explicit URL. `DebugLaunch` for the Mac (`-KataDemo`, `-KataScreen`). | Runs locally signed with team N9GSW3M5U8. All 70 items browsable. A practice session rates cards and FSRS due dates update, the mastery ring moves. Light and dark. Resizable down to 960×640. Every §5.5 shortcut works. iOS screenshots still identical. `mac-build` CI job green. |
| **P3: Kata screen** | `KataEditor` (NSTextView, highlighting, indentation, gutter, diagnostics). `KataSessionModel`, `KataView` (three panes, results, hints, reveal, rating → FSRS, review from blank, previous solution, compare). IDE mode (WorkspaceWriter, IDELauncher, FolderWatcher). Settings Java, IDE and Editor tabs. Today "Katas due". | Strategy end to end in the built-in editor: design checks fail → refactor → pass → rate → `#kata` card due. The same through IntelliJ: a save re-runs within ~1 s and results show in the app. Zed and Cursor open the workspace. Clicking a compile error jumps to the line. An injected infinite loop reports `timeout` within its limit + 1 s and the UI stays responsive. `System.exit` is reported. Debug "Make due now" → review restores the starter; the previous solution shows only after passing. No JDK → clear empty state. |
| **⏸ PAUSE** | **The user approves the kata format, editor feel, hint ladder, rating suggestion and the IDE workflow.** Kata schema v1 is frozen after this. | Written approval. |
| **P4: 69 katas** | Batches K1–K10, Opus reviews, strict validation. Turn on `requireAllKatas`. Rebuild `.kkata`. | 70 katas, 0 errors. Each reference passes 5× (concurrency 20× at 1 and 4 CPUs). Each starter fails the way its kind requires on every run. All medians < 2 s, or each slow kata listed and justified. CI green. One spot-check per batch. |
| **P5: Docs and release** | README: a Mac section, JDK requirement, build and run instructions, screenshots of the kata screen. Update the poster through `Tools/make_poster.swift`. ARCHITECTURE and CONTENT_GUIDE final. Mac app icon (extend `Tools/make_app_icon.swift`). `Tools/install_mac.sh` (`xcodebuild -scheme KataMac -configuration Release` → copy to `/Applications`). Optional iOS footnote. Tag a release. | A fresh clone builds both apps. README steps verified. Tag pushed. |

---

## 9. Testing

**Host tests** (`swift test`):
- `KataStoreTests`: store, settings, V1→V2 migration, kata store API, `resetAll`.
- `KataCoreTests`: `Kata` decoding and strict-key rejection, `KataValidator` against fixtures (`Fixtures/kata-good`, `kata-bad-*`), `KataGrader` rating table, `KataQueue` cap and order, `.kkata` reproducibility.
- `KataCodeTests`: `Indentation` (tab, newline after `{`, `}` outdent, comment toggle).
- `KataRunTests`:
  - Without a JDK: `KataReport.parse` (partial NDJSON, missing `done`, garbage lines), `JDKLocator` plist parsing (a recorded `java_home -X` sample), diagnostics → `NSRange` mapping including emoji and surrogate pairs, WorkspaceWriter output tree, FolderWatcher debounce (temp directory plus an atomic rename).
  - With a JDK, `.enabled(if: JDKLocator.default(minimum: 21) != nil)`, harness fixtures under `Tests/KataRunTests/Fixtures/harness/`:

| Fixture | Expected |
|---|---|
| `compile-error` | `compile.ok=false`, the diagnostic's start and end offsets point at the bad token |
| `test-needs-missing-type` | checks `blocked` with a sanitized message, user code still compiled |
| `infinite-loop` | `timeout` within `timeoutMs` + 200 ms, later checks still run, process ends |
| `deadlock` (two locks) | `timeout` plus a deadlock report naming both threads |
| `system-exit` (via reflection, bypassing the scan) | current check `exited`, `done` present |
| `system-exit-literal` | policy diagnostic, nothing executed |
| `output-flood` (`while(true) print`) | output truncated at 64 KB, check `timeout`, Swift-side 4 MB cap never reached |
| `oom` (`-Xmx256m`) | `error: OutOfMemoryError`, the run continues |
| `stack-overflow` | `error: StackOverflowError` |
| `thread-leak` (non-daemon thread spinning) | process still exits through `halt` |
| `wall-clock-kill` (harness made to hang in static init) | Swift SIGKILLs at the deadline, report `crashed` |
| `package-private-access` | tests reach package-private user members |

- **Content:** ContentTests as in §3.3.
- **Mac app** (`KataMacTests`, hosted): `MacAppModel` with an in-memory container, `KataSessionModel` state machine (hints → suggestion, reveal → Again, review resets the draft), using a fake `KataChecking` protocol so no JDK is needed.
- **Mac UI smoke** (`KataMacUITests`, local only because it needs a JDK): launch with `-KataDemo YES -KataScreen kata:strategy`, press ⌘R, assert the results list shows 9 rows. Also navigate the sidebar and open a card.
- **Performance:** `kata-pack check-java --timing` in P1 and P4. A `Signpost` around `KataCheckRunner.run` in the app.

---

## 10. Risks and open decisions

**Risks and mitigations:**

| Risk | Mitigation |
|---|---|
| Running user code without a sandbox. It is the user's own code on their own machine, and SecurityManager is gone on JDK 24+ (JEP 486, which includes this machine's default JDK 26). | Separate process; temp `cwd`; minimal environment; `-Xmx256m`; per-check and wall-clock timeouts with SIGKILL; output caps; a policy scan for `System.exit`, `halt`, `exec` and `ProcessBuilder`. Optional later: run under a `sandbox-exec` profile (no network, writes only to the run directory). It works but is deprecated, so this is an open decision. |
| `System.exit` | Static scan, plus a shutdown hook that marks the check `exited`. `Runtime.halt` is caught by the scan; reflection-based halt can only be detected as `crashed`. |
| No suitable JDK (none ≥ 21) or the JDK is removed | `JDKLocator` empty state, the Settings Test button, fallback to the default. Cards and practice keep working without a JDK. |
| Flaky concurrency katas | Seams and gates in the guide, tooling at 20 runs × 2 CPU counts, the Opus reviewer runs 50 times, CI runs 3 times. Memory-model bugs go to design checks. |
| Design checks reject valid alternative solutions | Reviewers try two alternatives. Checks enforce roles, not names, beyond what the task specifies. Task wording names the required types explicitly. |
| IDE friction: IntelliJ may ask for an SDK; Zed's Java extension downloads jdtls (network). | README guidance. The built-in editor is always available. A `pom.xml` remains an option. |
| FSEvents with atomic saves, or IntelliJ "safe write" | Watch the directory with file events and compare content hashes. |
| Hand-written pbxproj mistakes | Follow the existing `CA7A…` ID scheme. Verify with `plutil -lint`, `xcodebuild -list`, and both schemes building in CI. |
| Store collision on macOS | Explicit store URL (§1.2). |
| Swift 6 strictness around `Process`/FSEvents callbacks | Isolate in actors and bridge with `AsyncStream`. No `@unchecked Sendable` except one documented wrapper around an `FSEventStreamRef`. |
| Hidden tests are readable in the app bundle | Accepted. "Hidden" is a UX choice, not a secret. |
| Mac Development signing certificate expiry | Xcode renews it automatically. No weekly renewal as on iOS. |

**Open decisions for the user:**
1. Gate the Kata tab until the item's exercises are practised: a soft gate (proposed) or always open.
2. `katasPerDay` default (proposed 2), and whether katas count toward the daily streak (proposed yes, as a review).
3. IDE project files: minimal `.idea` plus `.vscode/settings.json` (proposed), or also a `pom.xml`.
4. Whether to wrap runs in `sandbox-exec` (proposed: no for v1).
5. Bundle id `com.github.meysampg.kata.mac` (proposed) or the same id as iOS.
6. Mac reminders (`UNUserNotificationCenter` works on macOS): proposed not in v1.
7. Whether the iOS footnote ("…on Kata for Mac") ships in P5.
8. The warm-JVM daemon: build it in P3 only if the measured median goes over 2 s; otherwise defer.

### Critical Files for Implementation
- `/Users/meysam/www/github/meysampg/Kata/Packages/KataKit/Package.swift`: new targets KataStore, KataRun, KataEditor; macOS 26; resources.
- `/Users/meysam/www/github/meysampg/Kata/Kata.xcodeproj/project.pbxproj`: the KataMac and KataMacTests targets, synchronized groups, resource references, signing and sandbox settings.
- `/Users/meysam/www/github/meysampg/Kata/Kata/Persistence/SchemaV1.swift`, `MigrationPlan.swift`, `ProgressStore.swift`: move to KataStore; add SchemaV2 and the kata API.
- `/Users/meysam/www/github/meysampg/Kata/Packages/KataKit/Sources/KataCore/Authoring/PackBuilder.swift`, `Validation/PackValidator.swift`, `Sources/kata-pack/main.swift`: kata loading, validation, `.kkata` build, `check-java` kata mode.
- `/Users/meysam/www/github/meysampg/Kata/Packages/KataKit/Sources/KataUI/MonoMetrics.swift` and `DiagramView.swift`: the only UIKit dependencies blocking the macOS port. Also `Tools/JavaCheck.java` as the pattern for the new `KataRun/Harness/KataHarness.java`.

## Decisions confirmed by the owner (2026-10-19)
- Native macOS target `KataMac` (bundle `com.github.meysampg.kata.mac`), sharing KataKit; progress separate per device.
- Editor: built-in (NSTextView) **and** "Open in IDE" (IntelliJ / Zed / Cursor) with folder watching; minimal IDE files (no Maven).
- Installed JDK (≥ 21 via `java_home`), samples compiled with `--release 21`.
- One kata per item, kind per §7.1 mapping; review = redo from blank; 3-step hint ladder lowering the suggested rating.
- Soft gate (recommended after cards/exercises, with Override); 2 katas due per day; katas count toward the streak.
- No `sandbox-exec` in v1; no Mac reminders in v1.
- Build P0–P3 then PAUSE for approval of the Strategy kata on the Mac before authoring the other 69.
