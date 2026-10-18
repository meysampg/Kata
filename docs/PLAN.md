# Kata: implementation plan

## 0. What I checked on this machine

- **AzBar** (`/Users/meysam/www/github/meysampg/AzBar`):
  - The Xcode project is **hand-written, not xcodegen or tuist** (neither is installed). It is `objectVersion = 77` with `PBXFileSystemSynchronizedRootGroup` folders, one `XCLocalSwiftPackageReference "Packages/AzBarKit"`, `GENERATE_INFOPLIST_FILE` plus `Config/Info.plist`, `SWIFT_VERSION = 6.0`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `DEVELOPMENT_TEAM = N9GSW3M5U8`, and bundle ids `com.github.meysampg.azbar[.tests]`.
  - There is one Foundation-only package `Packages/AzBarKit` (swift-tools 6.2, `.iOS(.v26), .macOS(.v15)`). It uses Swift Testing on the macOS host.
  - The app layer uses SwiftData `VersionedSchema` V1/V2 plus a migration plan. `ProgressStore` is a `@MainActor @Observable` class. `ReminderScheduler` schedules 7 one-shot `UNCalendarNotificationTrigger`s.
  - `DebugLaunch.swift` provides a demo mode (`-AzBarDemo YES -AzBarScreen x`). `Tools/capture_screenshots.sh` uses `devicectl` to capture screenshots from the phone.
  - CI has two jobs on `macos-26`: `swift test` and `xcodebuild build-for-testing CODE_SIGNING_ALLOWED=NO`.
  - `docs/ARCHITECTURE.md` is a very complete contract document covering concurrency rules, the Liquid Glass usage rules, and the "filenames unique under synchronized groups" rule.
- **FSRS**: `AzBarKit/Memorization/FSRSTypes.swift` (64 lines) and `FSRSScheduler.swift` (172 lines) implement FSRS-5 (19 weights, a 10-minute again-step, the same-day short-term path), with test vectors in `FSRSSchedulerTests`. Helpers: `DayKey.swift`, `StreakCalculator.swift`. The domain-free part is `ReviewSessionEngine` (requeue at +3, at most twice).
- **Renew alias** (`~/.zshrc:34`): `azbar-renew` runs `git pull`, `xcodebuild ... -destination id=00008030-000511D93CC0202E -derivedDataPath build -allowProvisioningUpdates`, `devicectl device install app`, then `devicectl device process launch`.
- **Tooling**:
  - `javac`/`java` are Temurin **26.0.2.1**, and `java_home` also lists 25, 24, 23, 19 and 17. So `javac --release 21` works locally.
  - `gh` 2.102 is installed.
  - Xcode is 27.1.
  - **The only simulator runtime is iOS 18.4**, which cannot run an iOS 26 app. Phase 0 must run `xcodebuild -downloadPlatform iOS` and create a simulator on the new runtime.
  - The iPhone 11 is paired, with UDID `00008030-000511D93CC0202E`.

### Reuse from AzBar

| AzBar item | What to do |
|---|---|
| pbxproj (synchronized groups, local package, settings) | Copy and rename AzBar to Kata. Bundle id `com.github.meysampg.kata`, display name "Kata", same team. Give the object ids a new prefix. |
| `FSRSTypes`/`FSRSScheduler` + tests | Copy verbatim into `KataSRS`, keeping the same test vectors. |
| `DayKey`, `StreakCalculator` + tests | Copy verbatim. |
| `ReviewSessionEngine` | Adapt: keyed by `ExerciseKey` instead of `CoupletKey`. |
| `PoemProgress.compute` | Adapt into `MasteryCalculator`, same weights. |
| SchemaV1 + `ProgressStore` pattern (revision counter, explicit save, no relationships) | Adapt. |
| `ReminderScheduler` | Copy, with English strings. |
| `AppSettings` (UserDefaults `didSet`) | Adapt. |
| `DebugLaunch` + `capture_screenshots.sh` | Adapt: `-KataDemo`, `-KataScreen`. |
| `RatingBar`, `HoldToConfirmButton`, `ProgressRing`, `IntervalFormatter` | Adapt, dropping Persian numbers and RTL. |
| Liquid Glass rules (glass only on the floating control layer; cards on `.background.secondary`) | Copy them into `docs/ARCHITECTURE.md`. |
| Swift 6 concurrency rules (`@MainActor @Observable final class`; Sendable struct engines; actor sources) | Copy. |
| CI workflow | Copy and add a `content` job. |
| `.gitignore`, LICENSE, PRIVACY, CONTRIBUTING, ISSUE_TEMPLATE | Copy and adapt. |
| Gamification (XP, badges, levels, sounds, confetti) | Do **not** copy. You asked for no XP. |

## 1. Architecture and module layout

```
Kata/                                 repo root (git init, MIT)
├─ Kata.xcodeproj                     objectVersion 77, synchronized groups Kata/ & KataTests/, local pkg
├─ Config/Info.plist
├─ Packages/KataKit/Package.swift     swift-tools 6.2, platforms .iOS(.v26), .macOS(.v15)
│  ├─ Sources/KataSRS/                FSRSTypes, FSRSScheduler, DayKey, StreakCalculator   (Foundation)
│  ├─ Sources/KataCode/               CodeToken, TokenKind, SyntaxHighlighter (protocol), JavaLexer,
│  │                                  PlainLexer, HighlighterRegistry, CodeLines            (Foundation)
│  ├─ Sources/KataDiagram/            Diagram model (Codable), TextMetrics, ClassDiagramLayout,
│  │                                  SequenceDiagramLayout, DiagramScene, DiagramDescriber (Foundation+CoreGraphics)
│  ├─ Sources/KataCore/               Models/, Loading/, Learning/, Search/, Validation/, Authoring/
│  │                                  (Foundation; depends on KataSRS, KataDiagram, KataCode)
│  ├─ Sources/KataUI/                 SwiftUI renderers: CodeView, CodeTheme, WalkthroughState,
│  │                                  DiagramView, ZoomableDiagramView, BlocksView, MasteryRing
│  ├─ Sources/kata-pack/              executable: build | validate | check-java   (no third-party deps)
│  └─ Tests/{KataSRSTests,KataCodeTests,KataDiagramTests,KataCoreTests(+Fixtures/mini-topic),ContentTests}
├─ Kata/                              app target
│  ├─ App/        KataApp, AppModel, RootView, AppTab, AppSettings, EnvironmentKeys, DebugLaunch
│  ├─ Persistence/SchemaV1, MigrationPlan, ProgressStore
│  ├─ Notifications/ReminderScheduler
│  ├─ DesignSystem/ Theme, Typography, GlassBottomBar, RatingBar, FeedbackPanel, HoldToConfirmButton
│  ├─ Features/   Today/ Path/ Library/ Deck/ Practice/ Search/ Settings/ About/
│  └─ Resources/  Assets.xcassets, Packs/design-patterns.kpack, PrivacyInfo.xcprivacy, Localizable.xcstrings
├─ KataTests/     ProgressStoreTests, BundledPackSmokeTests, AppSettingsTests, ReminderSchedulerTests
├─ Content/topics/design-patterns/topic.json + items/<id>/item.json + items/<id>/*.java   (authoring source)
├─ Tools/         JavaCheck.java, renew.sh, capture_screenshots.sh, make_app_icon.swift
├─ docs/          ARCHITECTURE.md, CONTENT_GUIDE.md, screenshots/
└─ .github/workflows/ci.yml
```

**Dependency direction:** app → KataUI → KataCore → (KataSRS, KataDiagram, KataCode). Only KataUI and the app import SwiftUI. SwiftData lives only in the app.

**Key types (KataCore):**
- `TopicID`, `ItemID` are `String`.
- `ItemKey` is `"design-patterns/strategy"` and `ExerciseKey` is `"design-patterns/strategy#spot-1"`. Both are stable forever and must never be renamed.
- `ContentLibrary` (`final class: Sendable`, `let` properties only):
  - `static func live(bundle:)` loads every `*.kpack` in the bundle.
  - It exposes `topics`, `pack(_:)`, `item(_:)` and `search(_:)`.
  - Packs load in a `PackLoader` actor: metadata eagerly, item bodies on first use.
- `LearningPath`: ordered sections; `next(after:progress:)` returns the next item.
- `MasteryCalculator.compute(cards:totalExercises:) -> Mastery` returns notStarted, learning, familiar or mastered, plus a fraction.
- `PracticeQueueBuilder`: takes due snapshots plus new candidates, a `newLimit`, a `reviewLimit` and a seed, and returns `[ExerciseKey]`. It buries siblings: at most one review per item per day, and no two exercises of the same item back-to-back.
- `ReviewSessionEngine` is adapted from AzBar.
- `ExerciseGrader.grade(_:response:) -> GradeResult(correct, suggestedRating, feedback)`.
- `ProgressRepository` is a protocol. The app implements it with SwiftData, and the tests use an in-memory version. This is a deliberate Repository-pattern example in the app's own code.

**Persistence: SwiftData**, the same approach as AzBar. It is proven in your setup, migrations are versioned, and no iCloud is needed. The data is small, so JSON files would also work, but SwiftData keeps both apps on one pattern.

`Kata/Persistence/SchemaV1.swift` (`KataSchemaV1: VersionedSchema`, no relationships):
- `ExerciseCard`:
  - Fields: `@Attribute(.unique) key`, `topicId`, `itemId`, `stateRaw`, `stability`, `difficulty`, `due`, `lastReview`, `reps`, `lapses`, `createdAt`.
  - Indexes: `#Index([\.due], [\.itemId])`.
- `ReviewLogEntry`: `cardKey`, `ratingRaw`, `reviewedAt`, `elapsedDays`, `scheduledDays`, `stateBeforeRaw`, `wasCorrect: Bool?`, `responseMillis`.
- `ItemProgress`:
  - Fields: `@Attribute(.unique) key`, `firstOpenedAt`, `lastOpenedAt`, `seenRoles: [String]`, `studiedAt: Date?`, `isBookmarked`, `bookmarkedAt`, `note: String` (at most 140 characters).
  - It is created on first open.
- `DailyActivity`: `dayKey`, `reviewCount`, `studiedCount`.
- Cards whose exercise id has disappeared from the pack are ignored, not deleted.

**Learning model:**
1. Reading an item's deck marks roles as seen.
2. Reaching the last card, or tapping **Practice this pattern**, runs a first-exposure session with all of the item's exercises. Each rating creates its FSRS card, and `studiedAt` is set.
3. After that, reviews come from the FSRS due queue. Settings cover new exercises per day (default 10), the review limit (100) and desired retention (0.9).

**Grading:**
- Wrong gives **Again** automatically, with an explanation.
- Correct shows the feedback panel with Hard/Good/Easy, and "Continue" means Good.
- Recall is self-rated with four buttons. A key-point checklist pre-selects a suggestion: all points → Good, half or more → Hard, fewer → Again.
- Options are shuffled with a seed of `(key, reps)` so you cannot memorise answer positions.

**Patterns in Kata's own code** (an `ARCHITECTURE.md` section that links to the in-app items):

| Pattern | Where |
|---|---|
| Strategy | `SyntaxHighlighter` + `HighlighterRegistry` |
| Repository | `ProgressRepository` |
| Factory | the card and exercise view switch |
| Observer | `@Observable` |
| Builder | `PackBuilder` |
| Composite | `Block` lists |
| Command | the exercise response actions |

## 2. Content pack format

**Authoring vs. shipping.** You author under `Content/topics/<topic>/`. `kata-pack build` compiles that into one minified `Kata/Resources/Packs/<topic>.kpack` (JSON):
- It strips the region markers from the Java and inlines the code.
- It computes region line ranges.
- It injects each card's `type` from its role spec.

The built `.kpack` is committed, like AzBar's `pack-*.json`. This avoids the problem of synchronized groups flattening nested folders. CI rebuilds it and fails on `git diff --exit-code`.

**Adding a topic needs no code change:** add `Content/topics/networking/`, run `kata-pack build`, and the app discovers any `*.kpack` in the bundle.

### 2a. `Content/topics/design-patterns/topic.json` (registry; abridged)

```json
{
  "schemaVersion": 1,
  "id": "design-patterns",
  "title": "Design Patterns",
  "subtitle": "GoF, concurrency, enterprise and resilience patterns in modern Java",
  "symbol": "square.stack.3d.up",
  "sortOrder": 0,
  "codeLanguage": "java",
  "javaRelease": 21,
  "roles": {
    "definition":     {"title": "Definition",        "symbol": "text.book.closed",          "type": "text"},
    "implementation": {"title": "Implementation",    "symbol": "chevron.left.forwardslash.chevron.right", "type": "code"},
    "example":        {"title": "Example of use",    "symbol": "building.2",                "type": "text"},
    "structure":      {"title": "Structure",         "symbol": "point.3.connected.trianglepath.dotted", "type": "diagram"},
    "tradeoffs":      {"title": "When to use",       "symbol": "scale.3d",                  "type": "lists"},
    "compare":        {"title": "Compare & relate",  "symbol": "arrow.left.arrow.right",    "type": "comparison"},
    "sightings":      {"title": "In the wild",       "symbol": "binoculars",                "type": "references"}
  },
  "templates": {
    "pattern":   {"roles": ["definition","implementation","example","structure","tradeoffs","compare","sightings"]},
    "principle": {"roles": ["definition","implementation","example","tradeoffs","compare","sightings"], "optionalRoles": ["structure"]}
  },
  "requiredExercises": [["identify"], ["choose"], ["tapLine","reorder"], ["recall"]],
  "categories": [
    {"id": "foundations", "title": "Foundations", "template": "principle", "summary": "Principles every pattern builds on."},
    {"id": "creational",  "title": "Creational",  "template": "pattern",   "summary": "How objects get made."},
    {"id": "structural",  "title": "Structural",  "template": "pattern"},
    {"id": "behavioral",  "title": "Behavioral",  "template": "pattern"},
    {"id": "concurrency", "title": "Concurrency", "template": "pattern"},
    {"id": "enterprise",  "title": "Enterprise & Architecture", "template": "pattern"},
    {"id": "resilience",  "title": "Resilience & Cloud", "template": "pattern"}
  ],
  "items": [
    {"id": "strategy", "title": "Strategy", "category": "behavioral", "difficulty": 1,
     "aliases": ["Policy"], "intent": "Swap one algorithm for another behind a single interface."}
  ],
  "path": [
    {"title": "Foundations", "items": ["srp","ocp","lsp","isp","dip","composition-over-inheritance","program-to-interface","tell-dont-ask"]},
    {"title": "First patterns", "items": ["strategy","factory-method","builder","adapter","decorator","observer"]}
  ]
}
```

**Item list (70) and path order:**

| Category | Count | Items |
|---|---|---|
| Foundations (principle template) | 8 | srp, ocp, lsp, isp, dip, composition-over-inheritance, program-to-interface, tell-dont-ask (with the Law of Demeter) |
| Creational | 5 | factory-method, abstract-factory, builder, prototype, singleton (with an "obsolete-ish" note: enum or holder idiom, DI scope) |
| Structural | 7 | adapter, bridge, composite, decorator, facade, flyweight, proxy |
| Behavioral | 11 | chain-of-responsibility, command, interpreter, iterator, mediator, memento, observer, state, strategy, template-method, visitor (with a note on sealed types + pattern-matching `switch`) |
| Concurrency | 10 | immutable-object, guarded-suspension (Monitor Object), producer-consumer, thread-pool, future-promise (CompletableFuture), read-write-lock, double-checked-locking (with a mostly-obsolete note: holder idiom), active-object, reactor, fork-join |
| Enterprise & architecture | 15 | layered-architecture, hexagonal (ports & adapters), mvc, mvvm, dependency-injection, service-locator (as the contrast case), repository, unit-of-work, data-mapper, active-record, specification, dto, domain-event, cqrs, event-sourcing |
| Resilience & cloud | 14 | timeout, retry-backoff (with jitter), circuit-breaker (with fallback), bulkhead, rate-limiter, idempotent-consumer, transactional-outbox, saga (choreography vs. orchestration), cache-aside, competing-consumers, api-gateway, sidecar, ambassador, strangler-fig |

**Path sections** (each section ordered easy to hard by `difficulty` 1–3):
1. Foundations
2. First patterns: strategy, factory-method, builder, adapter, decorator, observer, template-method, facade
3. Core GoF: iterator, command, state, composite, proxy, singleton, chain-of-responsibility, abstract-factory
4. Advanced GoF: bridge, mediator, memento, prototype, flyweight, visitor, interpreter
5. Application architecture: layered, dependency-injection, service-locator, dto, mvc, mvvm, hexagonal, repository, data-mapper, active-record, unit-of-work, specification, domain-event
6. Concurrency: immutable-object, thread-pool, future-promise, producer-consumer, guarded-suspension, read-write-lock, double-checked-locking, fork-join, active-object, reactor
7. Resilience: timeout, retry-backoff, circuit-breaker, bulkhead, rate-limiter, cache-aside, idempotent-consumer, competing-consumers
8. Distributed systems: api-gateway, sidecar, ambassador, strangler-fig, transactional-outbox, saga, cqrs, event-sourcing

### 2b. Generic card types (renderers), reusable by any topic

| type | Fields |
|---|---|
| `text` | `blocks: [Block]` |
| `code` | `file`, `language?` (defaults to the topic's), `expectedOutput?`, `walkthrough: [{region, note}]`. Built pack: `source`, `regions: {id: [startLine, endLine]}` |
| `diagram` | `diagrams: [Diagram]`, shown with a segmented control when there are several |
| `lists` | `lists: [{title, tone: positive\|negative\|warning\|info, items: [String]}]` |
| `comparison` | `rows: [{ref, relation: lookAlike\|alternative\|combines\|oftenConfused\|specializes, difference}]` |
| `references` | `entries: [{where, name, detail}]` (`where` is a free label: "JDK", "Spring", "Kubernetes") |

- **`Block`** is one of:
  - `{"type": "lead"|"p"|"heading", "text"}`
  - `{"type": "bullets"|"numbered", "items"}`
  - `{"type": "callout", "tone", "text"}`
  - `{"type": "code", "language", "lines": [..]}` (display only)
- **Inline text** is a Markdown subset parsed by `AttributedString(markdown:, options: .inlineOnlyPreservingWhitespace)`: `**bold**`, `*italic*`, `` `code` ``, and `[State](kata:state)` cross-links, which the deck handles with `OpenURLAction`.
- **Exercises** (generic `kind`), with common fields `id`, `kind`, `prompt`:
  - `identify`: `lines`, `options: [{ref|text, correct?, why}]`.
  - `choose`: `scenario`, `options: [{ref|text, correct?, why}]`.
  - `tapLine`: `lines`, `flawLines: [Int]` (1-based), `explanation`.
  - `reorder`: `blocks: [[String]]` in correct order, which the app shuffles; `explanation`.
  - `recall`: `modelAnswer: [Block]`, `keyPoints: [String]`.
- **Compiling exercise code** is optional: `"compile": {"template": [lines with "{{code}}"]}`. The validator substitutes the exercise code (the snippet, the flawed code, or the correctly ordered blocks) and compiles the result.

**Diagram model (KataDiagram):**
- `Diagram` is either:
  - `{"kind": "class", "title", "nodes": [{id, name, kind: class|interface|abstract|record|enum, role?, col, row, members: [String]}], "edges": [{from, to, rel: realizes|extends|association|aggregation|composition|dependency, label?}], "notes": [{attachTo, text}]}`, or
  - `{"kind": "sequence", "title", "participants": [{id, name, role?}], "messages": [{from, to, label, style: call|async|return|create}], "fragments": [{kind: alt|loop|opt, guard, from: msgIndex, to: msgIndex}]}`.
- `col` and `row` may be halves (`0.5`) so a node can be centred. Authors place nodes on a small grid. There is no auto-layout to fight with, and the result is deterministic.

### 2c. Complete worked example: `Content/topics/design-patterns/items/strategy/`

`Strategy.java` (the `// [[id` and `// ]]` marker lines are stripped by the build; there are no public types, so the file name is free):

```java
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Map;

// [[strategy
@FunctionalInterface
interface DiscountPolicy {
    BigDecimal apply(BigDecimal subtotal);
}
// ]]

// [[concrete
record PercentOff(int percent) implements DiscountPolicy {
    PercentOff {
        if (percent < 0 || percent > 100) throw new IllegalArgumentException("percent");
    }
    public BigDecimal apply(BigDecimal subtotal) {
        BigDecimal factor = BigDecimal.valueOf(100 - percent, 2);
        return subtotal.multiply(factor).setScale(2, RoundingMode.HALF_EVEN);
    }
}

record FlatOff(BigDecimal amount) implements DiscountPolicy {
    public BigDecimal apply(BigDecimal subtotal) {
        return subtotal.subtract(amount).max(BigDecimal.ZERO);
    }
}
// ]]

// [[context
final class Checkout {
    private final DiscountPolicy policy;

    Checkout(DiscountPolicy policy) { this.policy = policy; }

    BigDecimal total(List<BigDecimal> prices) {
        BigDecimal subtotal = prices.stream().reduce(BigDecimal.ZERO, BigDecimal::add);
        return policy.apply(subtotal);
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[lambda
        DiscountPolicy none = subtotal -> subtotal;
        // ]]
        // [[select
        Map<String, DiscountPolicy> byCode = Map.of(
            "NONE", none,
            "SPRING10", new PercentOff(10),
            "WELCOME", new FlatOff(new BigDecimal("7.50")));
        // ]]
        var prices = List.of(new BigDecimal("19.99"), new BigDecimal("30.01"));
        for (String code : List.of("NONE", "SPRING10", "WELCOME")) {
            // [[client
            var checkout = new Checkout(byCode.get(code));
            System.out.println(code + " -> " + checkout.total(prices));
            // ]]
        }
    }
}
```

`item.json`:

```json
{
  "id": "strategy",
  "cards": [
    {"role": "definition", "blocks": [
      {"type": "lead", "text": "Define a family of interchangeable algorithms behind one interface, and let the caller choose one at runtime."},
      {"type": "p", "text": "A **context** holds a **strategy** and delegates one varying decision to it. The context never learns which concrete strategy it has, so a new algorithm means a new class or lambda, not an edit to the context."},
      {"type": "bullets", "items": [
        "**Varies:** one algorithm or policy (pricing, sorting, retry, compression).",
        "**Stays stable:** the code that uses it.",
        "**Chosen by:** the client or configuration, usually once per use."]},
      {"type": "callout", "tone": "info", "text": "In Java 8+ a one-method strategy is a functional interface, so a lambda or method reference is a complete strategy."}
    ]},
    {"role": "implementation", "file": "Strategy.java",
     "expectedOutput": "NONE -> 50.00\nSPRING10 -> 45.00\nWELCOME -> 42.50",
     "walkthrough": [
      {"region": "strategy", "note": "The strategy interface: one method. `@FunctionalInterface` lets lambdas implement it and makes the compiler enforce that."},
      {"region": "concrete", "note": "Concrete strategies as records: immutable, validated in the compact constructor, each knowing only its own rule."},
      {"region": "context", "note": "The context takes a strategy in its constructor and delegates the one varying step. No `switch`, no `instanceof`."},
      {"region": "lambda", "note": "A lambda is a full strategy. Trivial rules need no class at all."},
      {"region": "select", "note": "Selection lives at the edge, in a map from promo code to policy. A new promo touches this map, never `Checkout`."},
      {"region": "client", "note": "The client pairs context with strategy and calls the context. The same `Checkout` prints three different totals."}
    ]},
    {"role": "example", "blocks": [
      {"type": "lead", "text": "Shipping quotes in an online shop."},
      {"type": "p", "text": "Each carrier prices parcels differently: weight tables, zones, surcharges. The customer picks a carrier at checkout, finance wants to A/B test a flat rate, and a new carrier arrives every quarter. Each rule becomes a `ShippingQuote` strategy with its own unit tests, and the checkout service stays unchanged."},
      {"type": "code", "language": "java", "lines": [
        "interface ShippingQuote { Money quote(Parcel p, Address to); }",
        "",
        "ShippingQuote dhl  = new DhlTableRate(rates);",
        "ShippingQuote flat = (p, to) -> Money.eur(\"4.90\");",
        "ShippingQuote chosen = flags.on(\"flat-shipping\", user) ? flat : dhl;",
        "Money price = checkout.quoteWith(chosen, cart, address);"]},
      {"type": "callout", "tone": "positive", "text": "Payoff: a new carrier is a new class plus one registry line. The flat-rate experiment is one lambda behind a flag."}
    ]},
    {"role": "structure", "diagrams": [
      {"kind": "class", "title": "Class", "nodes": [
        {"id": "checkout", "name": "Checkout", "kind": "class", "role": "Context", "col": 0.5, "row": 0,
         "members": ["- policy: DiscountPolicy", "+ total(prices): BigDecimal"]},
        {"id": "policy", "name": "DiscountPolicy", "kind": "interface", "role": "Strategy", "col": 0.5, "row": 1,
         "members": ["+ apply(subtotal): BigDecimal"]},
        {"id": "pct", "name": "PercentOff", "kind": "record", "role": "ConcreteStrategy", "col": 0, "row": 2,
         "members": ["+ apply(subtotal)"]},
        {"id": "flat", "name": "FlatOff", "kind": "record", "role": "ConcreteStrategy", "col": 1, "row": 2,
         "members": ["+ apply(subtotal)"]}],
       "edges": [
        {"from": "checkout", "to": "policy", "rel": "aggregation", "label": "policy"},
        {"from": "pct", "to": "policy", "rel": "realizes"},
        {"from": "flat", "to": "policy", "rel": "realizes"}],
       "notes": [{"attachTo": "policy", "text": "a lambda also implements it"}]},
      {"kind": "sequence", "title": "Sequence", "participants": [
        {"id": "client", "name": "Client"}, {"id": "checkout", "name": "Checkout", "role": "Context"},
        {"id": "policy", "name": "PercentOff", "role": "Strategy"}],
       "messages": [
        {"from": "client", "to": "checkout", "label": "new Checkout(policy)", "style": "create"},
        {"from": "client", "to": "checkout", "label": "total(prices)", "style": "call"},
        {"from": "checkout", "to": "policy", "label": "apply(subtotal)", "style": "call"},
        {"from": "policy", "to": "checkout", "label": "discounted", "style": "return"},
        {"from": "checkout", "to": "client", "label": "total", "style": "return"}]}
    ]},
    {"role": "tradeoffs", "lists": [
      {"title": "Use when", "tone": "positive", "items": [
        "Several variants of one algorithm must be swappable at runtime.",
        "A growing `switch` on a type or code picks behaviour.",
        "You want each rule unit-tested in isolation."]},
      {"title": "Avoid when", "tone": "negative", "items": [
        "There are two variants that will never change: an `if` is clearer.",
        "Variants need different inputs, so one interface cannot fit them all."]},
      {"title": "Pitfalls", "tone": "warning", "items": [
        "Context checking `instanceof` on its strategy, which defeats the pattern.",
        "Clients must now know every strategy; hide the choice behind a registry or factory.",
        "Stateful strategies shared across threads."]},
      {"title": "Overuse smells", "tone": "warning", "items": [
        "An interface plus classes for a rule that a lambda would cover.",
        "A `StrategyFactoryProvider` with a single implementation."]},
      {"title": "Modern Java", "tone": "info", "items": [
        "Functional interfaces and lambdas replace most strategy class hierarchies.",
        "For a closed set of data-driven rules, a sealed interface plus `switch` pattern matching can be simpler."]}
    ]},
    {"role": "compare", "rows": [
      {"ref": "state", "relation": "lookAlike", "difference": "Same shape, different intent. With State the object switches its own state as events arrive and the states know each other. With Strategy the client chooses and strategies are independent."},
      {"ref": "template-method", "relation": "alternative", "difference": "Template Method varies steps through inheritance, fixed at compile time. Strategy varies the whole algorithm through composition, at runtime."},
      {"ref": "command", "relation": "oftenConfused", "difference": "A command packages a request to run, queue or undo later. A strategy answers *how* to do one job right now."},
      {"ref": "decorator", "relation": "alternative", "difference": "Decorator changes an object's behaviour by wrapping it from the outside; Strategy replaces its internals."},
      {"ref": "factory-method", "relation": "combines", "difference": "A factory or registry often picks the strategy from configuration, and DI injects it."}
    ]},
    {"role": "sightings", "entries": [
      {"where": "JDK", "name": "java.util.Comparator", "detail": "Passed to `List.sort`, `TreeMap` and `Collections.max` to choose the ordering algorithm."},
      {"where": "JDK", "name": "RejectedExecutionHandler", "detail": "`ThreadPoolExecutor` delegates overflow to a policy: `AbortPolicy`, `CallerRunsPolicy`, `DiscardPolicy`."},
      {"where": "Spring Security", "name": "PasswordEncoder", "detail": "`BCryptPasswordEncoder` and `Argon2PasswordEncoder` are interchangeable; `DelegatingPasswordEncoder` picks one per stored hash."},
      {"where": "Jackson", "name": "PropertyNamingStrategies", "detail": "`SNAKE_CASE` and `KEBAB_CASE` change how property names map to JSON."},
      {"where": "Kubernetes", "name": "Deployment spec.strategy", "detail": "`RollingUpdate` or `Recreate`: the same controller with a different rollout algorithm."}
    ]}
  ],
  "exercises": [
    {"id": "spot-1", "kind": "identify", "prompt": "Which pattern is this?",
     "lines": [
      "final class BackupJob {",
      "    private final Codec codec;",
      "    BackupJob(Codec codec) { this.codec = codec; }",
      "",
      "    void run(Path file) throws IOException {",
      "        byte[] raw = Files.readAllBytes(file);",
      "        Path out = file.resolveSibling(file.getFileName() + codec.extension());",
      "        Files.write(out, codec.encode(raw));",
      "    }",
      "}",
      "// GzipCodec, ZstdCodec, NoopCodec; chosen from the --codec flag"],
     "options": [
      {"ref": "strategy", "correct": true, "why": "The job delegates one varying algorithm (encoding) to an injected, interchangeable `Codec`."},
      {"ref": "state", "why": "Nothing transitions: the codec is fixed for the job's life and never replaces itself."},
      {"ref": "bridge", "why": "There is no second abstraction hierarchy being developed independently; it is one job with one pluggable step."},
      {"ref": "template-method", "why": "There is no abstract superclass with overridable steps; the variation comes through composition."}],
     "compile": {"template": [
      "import java.io.IOException;", "import java.nio.file.*;",
      "interface Codec { String extension(); byte[] encode(byte[] raw); }",
      "{{code}}"]}},
    {"id": "pick-1", "kind": "choose",
     "scenario": "A tax engine computes VAT differently per country. The rule is chosen at checkout from the shipping address, new countries are added monthly, and a rule never changes during one calculation.",
     "prompt": "Which pattern fits best?",
     "options": [
      {"ref": "strategy", "correct": true, "why": "One varying algorithm, selected from outside per request, with new variants added without touching the engine."},
      {"ref": "state", "why": "There is no lifecycle and no transitions; the rule does not change itself as events arrive."},
      {"ref": "template-method", "why": "A subclass per country fixes the choice at compile time and couples every rule to one base-class skeleton."},
      {"ref": "chain-of-responsibility", "why": "The responsible rule is known up front from the address; there is nothing to pass along a chain."}]},
    {"id": "flaw-1", "kind": "tapLine", "prompt": "Tap the line that breaks the Strategy pattern.",
     "lines": [
      "final class Checkout {",
      "    private final DiscountPolicy policy;",
      "",
      "    Checkout(DiscountPolicy policy) { this.policy = policy; }",
      "",
      "    BigDecimal total(BigDecimal subtotal) {",
      "        if (policy instanceof PercentOff p && p.percent() > 50) {",
      "            return subtotal; // block deep discounts",
      "        }",
      "        return policy.apply(subtotal);",
      "    }",
      "}"],
     "flawLines": [7],
     "explanation": "The context inspects a concrete strategy, so every new policy can force an edit here. Put the cap in a decorating policy, e.g. `capped(policy, 50)`, or in the strategy itself.",
     "compile": {"template": [
      "import java.math.BigDecimal;",
      "interface DiscountPolicy { BigDecimal apply(BigDecimal s); }",
      "record PercentOff(int percent) implements DiscountPolicy { public BigDecimal apply(BigDecimal s) { return s; } }",
      "{{code}}"]}},
    {"id": "order-1", "kind": "reorder", "prompt": "Order the request flow so that each line only uses what came before.",
     "blocks": [
      ["String code = request.promoCode();"],
      ["DiscountPolicy policy = policies.getOrDefault(code, s -> s);"],
      ["Checkout checkout = new Checkout(policy);"],
      ["BigDecimal total = checkout.total(cart.prices());"],
      ["receipt.print(total);"]],
     "explanation": "Read the input, resolve the strategy at the edge, inject it into the context, then delegate. The context never sees the promo code.",
     "compile": {"template": [
      "import java.math.BigDecimal;", "import java.util.*;",
      "interface DiscountPolicy { BigDecimal apply(BigDecimal s); }",
      "final class Checkout { private final DiscountPolicy p; Checkout(DiscountPolicy p) { this.p = p; }",
      "  BigDecimal total(List<BigDecimal> xs) { return p.apply(xs.stream().reduce(BigDecimal.ZERO, BigDecimal::add)); } }",
      "record Request(String promoCode) {}", "record Cart(List<BigDecimal> prices) {}",
      "interface Receipt { void print(BigDecimal total); }",
      "class Snippet { void run(Request request, Map<String, DiscountPolicy> policies, Cart cart, Receipt receipt) {",
      "{{code}}", "} }"]}},
    {"id": "recall-1", "kind": "recall",
     "prompt": "Explain Strategy in your own words: what varies, who chooses, and how it differs from State.",
     "modelAnswer": [
      {"type": "p", "text": "Strategy pulls one varying algorithm out of a class behind an interface. The context delegates to whatever strategy it was given, and the client or configuration chooses it, usually at construction. Unlike State, strategies don't know each other and the context doesn't swap them in response to its own events."}],
     "keyPoints": [
      "One varying algorithm behind one interface",
      "Context delegates and never inspects the concrete type",
      "The client or config chooses, often by injection",
      "State changes itself and knows the transitions; Strategy is chosen from outside",
      "In modern Java a lambda can be the strategy"]}
  ]
}
```

### 2d. Validation tooling: `swift run --package-path Packages/KataKit kata-pack <cmd>`

`kata-pack` reuses the same KataCore decoders as the app, so there is one source of truth.

**`validate [--topic id] [--items a,b] [--allow-missing]`** returns `[ValidationIssue(severity, path, message)]`. It checks:
- **Schema and ids:** strict decode with unknown keys rejected; ids are kebab-case and unique; registry entries match `items/` directories one to one (the check is skipped with `--allow-missing` while batches are in progress).
- **Path:** contains every item exactly once.
- **Cards:** exactly the template roles, in template order.
- **Code cards:**
  - Every walkthrough `region` exists, regions do not overlap, and there are 3 to 7 steps.
  - Code is at most 70 lines (warning above 70, error above 90), with columns at most 80 (warning) or 100 (error).
- **Diagrams:**
  - Unique node ids, edges that resolve, and no two nodes in one grid cell.
  - At most 8 nodes, at most 10 edges, at most 2 columns (3 is a warning).
  - The layout engine reports no overlaps.
  - Sequence diagrams have at most 5 participants and at most 10 messages.
- **References:** every `ref` and `kata:` link resolves in the registry.
- **Exercises:**
  - `requiredExercises` is satisfied.
  - `identify` and `choose` have exactly one correct option, 3 or 4 options, and a `why` on each.
  - `flawLines` are within range.
  - `reorder` has 3 to 8 blocks with unique text.
  - `recall` has 3 to 5 key points.
- **Text limits** (warnings): word counts per card, from the content guide.

**`check-java [--items ...]`**:
- Writes each unit (the code-card file, plus each exercise `compile.template` with its code substituted) to a temporary directory.
- Runs `java Tools/JavaCheck.java <dir>`, a single-file launcher that uses `javax.tools.JavaCompiler` in one JVM, which is fast. It compiles each unit separately with `--release 21 -Xlint:all`, then runs the `main` of code cards and diffs stdout against `expectedOutput`.
- Prints a JSON report.

**`build [--topic id]`** writes `Kata/Resources/Packs/<id>.kpack`.

**Tests:** `Tests/ContentTests/ContentValidationTests.swift` locates `Content/` via `#filePath`, runs the validator in strict mode, and calls `check-java` logic with `.enabled(if: JavaToolchain.isAvailable)` (true here; in CI via `actions/setup-java` temurin 21). It also asserts that the built `.kpack` equals a fresh build.

## 3. Java syntax highlighting (`KataCode`, no dependencies)

- **Types:**
  - `public protocol SyntaxHighlighter: Sendable { func tokenize(_ source: String) -> [CodeToken] }`
  - `HighlighterRegistry.shared.highlighter(for: "java")`, which falls back to `PlainLexer`. Future packs can add `yaml`, `go`, `http` and so on. This is the Strategy pattern again.
  - `TokenKind`: `keyword, type, function, identifier, annotation, string, number, comment, docComment, operator, punctuation, whitespace`.
  - `CodeToken { kind; text: String }`.
  - `CodeLines.split(tokens) -> [[CodeToken]]` splits multi-line tokens (block comments, text blocks) per line.
- **`JavaLexer`:** a single pass over `Array(source.unicodeScalars)` with a cursor. It handles:
  - `//`, `/* */` and `/** */` comments
  - text blocks `"""…"""`
  - strings and chars with escapes
  - numbers: hex, binary, octal, underscores, `L/f/d` suffixes, exponents
  - `@Annotation` (but not `@interface`)
  - identifiers via `Character.isLetter`, `_` and `$`
- **Classification:**
  - Reserved keywords, plus contextual keywords as keywords: `record sealed permits non-sealed var yield when module`.
  - An identifier starting with an uppercase letter is a `type`.
  - An identifier followed by `(` is a `function`.
  - `>>` is emitted as two `>` for generics.
  - An unterminated literal runs to end of line, never crashes.
- **Rendering** (KataUI `CodeView`):
  - Each line is one `Text(AttributedString)` with `.lineLimit(1)` and `.fixedSize(horizontal: true, vertical: false)`, inside `ScrollView(.horizontal)` with a `LazyVStack(alignment: .leading)`.
  - The line-number gutter sits outside the horizontal scroll, so it stays put.
  - Font: `.system(size: settings.codeFontSize, design: .monospaced)`, default 14, range 12–18.
  - `CodeTheme` has light and dark palettes per `TokenKind` in a muted, Xcode-like style, chosen via `colorScheme`.
  - Tokens are cached per card.
- **Walkthrough mode:**
  - `WalkthroughState { steps, index }`.
  - Active-region lines get a tinted background; other lines drop to opacity 0.35.
  - `ScrollViewReader` scrolls to the region's first line.
  - The note appears in a bottom glass panel with Prev and Next (`step 2 of 6`).
  - A toolbar toggle switches between "Read" and "Walkthrough".

## 4. Screens and navigation

`RootView` is a `TabView`, each tab with its own `NavigationStack`:
- **Today**
- **Path**
- **Library**
- **Search** (`Tab(role: .search)`)

Settings opens from a gear in the Today toolbar. Practice is a `.fullScreenCover`.

1. **Today**:
   - A glass card with "N reviews due" and **Start review** (`.glassProminent`), or "All caught up · next review in 3h".
   - Streak line ("5-day streak") and today's count.
   - **Continue path**: the next suggested item, with intent and difficulty dots.
   - Recently studied items.
   - Bookmarks (the first five, then "All").
2. **Path**:
   - A calm vertical list grouped by section, not a game map.
   - Each row has a `MasteryRing` with 4 states, the title and a one-line intent. The "Next" item is highlighted.
   - Everything is tappable, with no locks. The header shows section progress such as "12 / 70 studied".
3. **Library**:
   - The topic list appears only if there is more than one topic; otherwise it goes straight to the topic.
   - Categories, then item rows with the mastery ring, a bookmark glyph and your note in secondary text.
   - A Bookmarks filter chip.
4. **Item deck** (`ItemDeckView`, pushed full screen with the tab bar hidden):
   - One card per screen, paged horizontally: `ScrollView(.horizontal)` + `.scrollTargetBehavior(.paging)` + `.scrollPosition(id:)`.
   - The top bar shows the item title, a bookmark toggle and a note button. The note is a one-line `TextField` popover limited to 140 characters, saved on submit.
   - The bottom glass strip shows role symbols as page indicators (tap to jump) and chevrons.
   - Each card scrolls vertically if it is too tall.
   - The last card ends with **Practice this pattern**.
   - Card views: `TextCardView`, `CodeCardView` (Read and Walkthrough), `DiagramCardView`, `ListsCardView` (tone-coloured headers), `ComparisonCardView` (rows link to other items), `ReferencesCardView`.
5. **Diagram**:
   - Fit-to-width preview, with a segmented control for Class or Sequence.
   - Tapping a node highlights its edges and shows its role ("Context").
   - "Expand" opens `ZoomableDiagramView`: a 2-axis `ScrollView` with `MagnifyGesture`.
   - For VoiceOver, `DiagramDescriber` produces a text description ("Checkout has a DiscountPolicy; PercentOff implements DiscountPolicy").
6. **Practice session**:
   - Top: close (with a confirmation), "3 of 12" and a thin progress bar.
   - Exercise views:
     - `IdentifyExerciseView`: code, then 4 option buttons.
     - `ChooseExerciseView`: scenario card, then options.
     - `TapLineExerciseView`: tappable code lines, with the chosen line outlined.
     - `ReorderExerciseView`: draggable code blocks in a `List` with `.onMove`, plus "Check".
     - `RecallExerciseView`: prompt, then "Reveal", then the model answer and a key-point checklist.
   - `FeedbackPanel`: correct or incorrect, the `why` of the chosen option and of the correct one, then `RatingBar` (from AzBar) or Continue.
   - `PracticeSummaryView`: counts and streak, then Done.
7. **Search**: `.searchable` with a 200 ms debounce. Results show the title, a matched snippet and the category, and open the deck at the matching card.
8. **Settings**:
   - Daily reminder (toggle and time; it requests notification permission).
   - Desired retention (85, 90 or 95%), new exercises per day, review limit.
   - Code font size and a live preview, line numbers on or off.
   - Reset progress (`HoldToConfirmButton`).
   - About: GitHub link, MIT licence, privacy statement, version.

## 5. Content authoring strategy

1. **C0, done by the lead agent (Opus) before any batch:**
   - `docs/CONTENT_GUIDE.md`.
   - The complete `topic.json` registry: all 70 ids, titles, intents, difficulty, path.
   - `items/strategy`, the gold standard.
   - You review Strategy on the device, then **schema v1 is frozen**.
2. **Guide limits** (iPhone 11 is 414 pt wide; at 14 pt monospaced about 45 columns are visible):

   | Card | Limits |
   |---|---|
   | Definition | lead ≤ 25 words; body ≤ 90 words; ≤ 4 bullets |
   | Implementation | ≤ 70 lines, ≤ 80 columns, 4-space indent, Java 21, compiles and runs with `expectedOutput`, 3–7 walkthrough steps, notes ≤ 35 words |
   | Example | a realistic domain different from the sample; ≤ 120 words + ≤ 8 code lines |
   | Diagram | ≤ 8 nodes, ≤ 2 columns, GoF role names in `role` |
   | Trade-offs | 2–4 bullets per list, ≤ 18 words each; a "Modern Java" list when relevant (obsolete or replaced by language features) |
   | Compare | 3–5 rows |
   | Sightings | 3–6 entries, only well-known and verifiable APIs or products, with exact names; no invented classes; when unsure, omit |

   Exercises:
   - 5 per item: identify, choose, tapLine or reorder (the other one optional), and recall.
   - Distractors must be plausible, and each `why` must be crisp.
   - Snippets do not name the pattern.
   - Tone: calm, precise, second person, no hype, US English.
3. **Batches** (Sonnet subagents, 4 in parallel, then 4 more):

   | Batch | Items |
   |---|---|
   | B1 | foundations (8) |
   | B2 | creational + structural (12) |
   | B3 | behavioral except Strategy (10) |
   | B4 | concurrency (10) |
   | B5 | enterprise A: layered, hexagonal, mvc, mvvm, DI, service-locator, dto, specification |
   | B6 | enterprise B: repository, UoW, data-mapper, active-record, domain-event, cqrs, event-sourcing |
   | B7 | resilience A: timeout, retry, circuit-breaker, bulkhead, rate-limiter, cache-aside, idempotent-consumer |
   | B8 | resilience B: competing-consumers, api-gateway, sidecar, ambassador, strangler-fig, outbox, saga |

   Each subagent's prompt includes the guide, the Strategy files and the registry. Rules for subagents:
   - Write only under `Content/topics/design-patterns/items/<your ids>/`. The directories are disjoint, so there are no conflicts.
   - Iterate until `kata-pack validate --items … --allow-missing` and `kata-pack check-java --items …` are clean.
   - Return a report that lists any sighting it was unsure about.
4. **Verification:**
   - Per batch, an independent reviewer subagent (Opus) checks technical accuracy, idiomatic Java, unambiguous exercises, sightings, limits and tone, and applies fixes.
   - The lead agent runs strict `validate`, `check-java` and `build`, and commits one commit per batch.
   - You spot-check one item per batch in the app.

## 6. Phased milestones

| Phase | Work | Acceptance |
|---|---|---|
| **P0 Scaffold** | • `git init` with MIT LICENSE, `.gitignore`, `CONTRIBUTING`, `PRIVACY.md` adapted from AzBar.<br>• Copy and rename `AzBar.xcodeproj` to `Kata.xcodeproj` and the scheme.<br>• Package skeleton with all targets, CI (`kit-tests`, `content` with setup-java 21, `app-build`).<br>• `xcodebuild -downloadPlatform iOS`; create a simulator (`xcrun simctl list runtimes`, then `simctl create "iPhone 17" …`).<br>• `Tools/renew.sh` + `alias kata-renew='~/www/github/meysampg/Kata/Tools/renew.sh'` (the AzBar recipe with Kata names). | `swift test` is green (empty).<br>`build-for-testing` for generic iOS Simulator passes.<br>A placeholder app launches on the simulator and the iPhone 11. |
| **P1 Engine + tests** | • KataSRS copied with its vectors.<br>• KataCode lexer.<br>• KataDiagram layouts.<br>• KataCore models, loader, builder, validator, mastery, queue, grader, search.<br>• `kata-pack` and `JavaCheck.java`.<br>• `Fixtures/mini-topic` with 2 items, one per card type and exercise kind. | All host tests are green.<br>`kata-pack validate/build/check-java` succeed on the fixture.<br>A deliberately broken fixture produces the expected issues. |
| **P2 UI** | • Design system, tabs, all screens, all card and exercise views.<br>• SwiftData store, reminders, settings.<br>• `DebugLaunch` demo mode, using the fixture pack. | All flows work on the simulator.<br>On the device, horizontal page swipe and horizontal code scroll coexist (if not, switch to the fallback in §8).<br>Light and dark mode and Dynamic Type up to XXL are checked. |
| **P3 Strategy end-to-end** | Strategy content, `build`, practice of all 5 exercises through FSRS. | `check-java` passes and the output matches.<br>Due dates appear after rating.<br>Mastery ring and streak update.<br>**You approve the format, tone and lengths, and schema v1 is frozen.** |
| **P4 Content** | C0 registry, B1–B8, reviews, strict validation. | 70 items; 0 errors.<br>All Java compiles and runs.<br>`.kpack` is up to date.<br>Pack decode under 150 ms on the iPhone 11 (signpost). |
| **P5 Device** | • `kata-renew` install.<br>• App icon (adapt `make_app_icon.swift`).<br>• Performance pass on the A13 (glass only on controls).<br>• Basic VoiceOver labels. | 3 days of real use without crashes.<br>The reminder fires.<br>App tests run on the device: `xcodebuild test -project Kata.xcodeproj -scheme Kata -destination id=00008030-000511D93CC0202E -allowProvisioningUpdates`. |
| **P6 Publish** | • README (features, card and exercise types, architecture, "Adding a topic", build).<br>• Screenshots via `Tools/capture_screenshots.sh`.<br>• **After you confirm**: `gh repo create meysampg/Kata --public --source . --push`. | CI badge is green and the repo is public. |

## 7. Testing

Host tests use Swift Testing: `swift test --package-path Packages/KataKit`.

| Suite | What it covers |
|---|---|
| `KataSRSTests` | AzBar's FSRS vectors, interval ordering, `preview == next`, streak today, gap and yesterday cases. |
| `KataCodeTests` | Concatenated token text equals the source (also for fuzzed random input).<br>Keywords vs. identifiers, `non-sealed`, text blocks, comment markers inside strings, `List<Map<String,Integer>>`, `0x1F_FFL`, `@interface`, unterminated strings.<br>Multi-line token splitting.<br>2,000 lines in under 50 ms. |
| `KataDiagramTests` | Strategy class layout: no node overlap, edge endpoints on node borders, deterministic output.<br>Fractional columns are centred.<br>Sequence layout: message y-positions increase monotonically, self-messages and returns.<br>Describer text. |
| `KataCoreTests` | Pack decode, including the custom `type` discriminator and unknown-key rejection.<br>Builder: region-marker stripping and line ranges.<br>Validator: one test per rule using broken fixtures.<br>`MasteryCalculator` boundaries.<br>`PracticeQueueBuilder`: limits, sibling burying, no adjacent siblings, seeded determinism.<br>`ReviewSessionEngine` requeue rules.<br>`ExerciseGrader` for each kind, including reorder.<br>Search ranking (title, then alias, then body) and case/diacritic folding. |
| `ContentTests` | Strict validation of `Content/`, Java compile and run (enabled when a JDK is present), freshness of the `.kpack`. |

App tests (`KataTests`):
- `ProgressStore`: upsert, due queries, `studiedAt`, bookmark and note persistence.
- Bundled pack smoke test: 70 items, every template role present.
- `AppSettings` with a suite-named UserDefaults.
- Reminder scheduling rules (pending-request ids).

Commands:
- Simulator: `xcodebuild test -project Kata.xcodeproj -scheme Kata -destination 'platform=iOS Simulator,name=iPhone 17'`. This needs the new runtime.
- Device: the command in P5.

CI: `kit-tests` + `content` (setup-java 21) + `app-build` (`CODE_SIGNING_ALLOWED=NO build-for-testing`).

## 8. Risks and open decisions

**Risks:**
- **Gesture conflict** between horizontal card paging and horizontal code scroll. Mitigations:
  - The code pane is the only inner horizontal scroll, and swiping outside it pages.
  - Chevrons and the role strip also page.
  - Diagrams are fit-to-width, with zoom in a sheet.
  - Fallback: page cards vertically.
  - Prototype this on the device in P2.
- **Content accuracy**, especially sightings and subtle concurrency or distributed claims. Mitigated by the "omit if unsure" rule, an Opus review pass, and your spot checks. The code itself is protected by the compile-and-run check.
- **Review load:** 350 exercises. Mitigated by the daily new limit, sibling burying, and per-item enrolment only after studying.
- **Answer memorisation:** the same snippet every time. Shuffled options help in v1; v1.1 could add variant exercises per kind.
- **Diagram legibility at 375–414 pt.** Mitigated by the 2-column and 8-node limits, monospaced metrics (`TextMetrics` measured once from the real font) and the zoom sheet.
- **Toolchain:** no iOS 26+ simulator runtime yet (a download of several GB). Building against the iOS 27 SDK with a 26.0 deployment target means no APIs newer than 26.0.
- **Free signing:** apps must be re-signed every 7 days (`kata-renew`), and a free account can have a limited number of active app ids (AzBar + Kata is fine).
- **Liquid Glass cost on the A13.** Keep glass on controls only and avoid `glassEffect` on scrolling content.
- **Schema evolution:** `schemaVersion` in the pack. The app rejects unknown major versions. Ids are stable forever. SwiftData has `MigrationPlan` from V1.

**Open decisions (my recommendation first):**
1. Java `--release` 21 (LTS; records, sealed types, pattern-matching switch, virtual threads) or 25 (newer LTS). **21**.
2. FSRS-5 copied from AzBar (with its tested vectors) or FSRS-6. **FSRS-5 now**.
3. Whether the 8 Foundations items count toward the ~70 (the list above has 62 patterns plus 8 principles).
4. 5 exercises per item, with tapLine or reorder at minimum one.
5. Commit the built `.kpack` (recommended) or generate it in a build phase (script sandboxing makes that harder).
6. Tabs: Today, Path, Library, Search, with Settings from Today.
7. Bundle id `com.github.meysampg.kata`, display name "Kata".
8. Publishing the public repo needs your explicit go-ahead at P6.

### Critical Files for Implementation
- /Users/meysam/www/github/meysampg/AzBar/AzBar.xcodeproj/project.pbxproj (the template for `Kata.xcodeproj`)
- /Users/meysam/www/github/meysampg/AzBar/Packages/AzBarKit/Sources/AzBarKit/Memorization/FSRSScheduler.swift and FSRSTypes.swift (copied into `KataSRS`, with `Tests/AzBarKitTests/FSRSSchedulerTests.swift`)
- /Users/meysam/www/github/meysampg/AzBar/AzBar/Persistence/ProgressStore.swift and SchemaV1.swift (the pattern for Kata's store)
- /Users/meysam/www/github/meysampg/AzBar/docs/ARCHITECTURE.md (the contract style and concurrency/glass rules to carry over)
- /Users/meysam/www/github/meysampg/AzBar/.github/workflows/ci.yml, /Users/meysam/www/github/meysampg/AzBar/Tools/capture_screenshots.sh, /Users/meysam/www/github/meysampg/AzBar/AzBar/App/DebugLaunch.swift, /Users/meysam/www/github/meysampg/AzBar/AzBar/Notifications/ReminderScheduler.swift
- New, central to Kata: `/Users/meysam/www/github/meysampg/Kata/Content/topics/design-patterns/topic.json`, `/Users/meysam/www/github/meysampg/Kata/Packages/KataKit/Sources/KataCore/Validation/PackValidator.swift`, `/Users/meysam/www/github/meysampg/Kata/Packages/KataKit/Sources/KataCode/JavaLexer.swift`, `/Users/meysam/www/github/meysampg/Kata/Packages/KataKit/Sources/KataDiagram/ClassDiagramLayout.swift`, `/Users/meysam/www/github/meysampg/Kata/Tools/JavaCheck.java`

## Decisions confirmed by the owner (2026-10-18)
- Java `--release 21`. FSRS-5 copied from AzBar. 8 Foundations principles + 62 patterns = 70 items.
- Build P0–P3 (scaffold, engine, UI, Strategy end-to-end on device), then PAUSE for the owner to approve the card format before content batches.
- Publishing to GitHub as public `meysampg/Kata` is approved by the owner.
- No iOS 26+ simulator runtime is installed; verify on the paired iPhone 11 (UDID 00008030-000511D93CC0202E) and with host `swift test`.
