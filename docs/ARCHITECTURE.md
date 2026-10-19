# Kata architecture

Kata is an iOS 26+ SwiftUI app for mastering design patterns (and, later, other topics). It is calm, follows the system light and dark appearance, is English only, and shows one focus item per screen. This document is the contract for how it is built. The product plan is in [PLAN.md](PLAN.md).

## 1. Modules

```
┌──────────────────────────── Kata (iOS app target) ─────────────────────────────┐
│ App/            KataApp, AppModel (navigation, reminders), AppTab, RootView,    │
│                 DebugLaunch                                                     │
│ Notifications/  ReminderScheduler                                               │
│ DesignSystem/   Theme, GlassBottomBar, FeedbackPanel, ItemRow, HighlightedCode  │
│ Features/       Today, Path, Library, Deck, Practice, Search, Settings          │
│ Resources/      Assets.xcassets, Packs/*.kpack, PrivacyInfo.xcprivacy           │
└──────────────┬─────────────────────────────────────────────────────────────────┘
               │ import KataUI, KataStore, KataCore (and KataSRS, KataCode, KataDiagram)
┌──────────────▼──────────── Packages/KataKit (SPM, swift-tools 6.2) ────────────┐
│ KataSRS      FSRS-5 scheduler, DayKey, StreakCalculator            (Foundation) │
│ KataCode     Java lexer, HighlighterRegistry                       (Foundation) │
│ KataDiagram  Diagram model, class/sequence layouts, describer      (Foundation) │
│ KataCore     models, loader, learning engine, search, validation, authoring     │
│ KataStore    SwiftData (iOS + macOS): SchemaV1/V2, KataMigrationPlan,           │
│              PersistenceFactory, ProgressStore, AppSettings, StudyModel,        │
│              PracticeSessionModel                                               │
│ KataUI       SwiftUI renderers (iOS + macOS): CodeView, CodeWalkthroughView,    │
│              DiagramView, BlocksView, MasteryRing, RatingBar, HoldToConfirm,    │
│              Platform.swift (UIFont/NSFont, UIColor/NSColor shim)               │
│ kata-pack    CLI: build | validate | check-java                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
Content/topics/<topic>/  →  kata-pack build  →  Kata/Resources/Packs/<topic>.kpack
```

**Dependency direction:** app → KataUI, KataStore → KataCore → (KataSRS, KataCode, KataDiagram). The package targets iOS 26 and macOS 26. Only KataUI and the app import SwiftUI. SwiftData lives only in KataStore.

## 2. Data flow

- **Content** is immutable. `ContentLibrary.live(bundle: .main)` decodes every `*.kpack` in the bundle at launch. `AppModel` keeps the library and a set of `contentKeys` (items that have a body). Registry entries without a body appear as "Coming soon" in Path, Library and Search, and are excluded from practice and from "Continue your path".
- **Progress** is SwiftData, keyed by stable strings (`ItemKey.rawValue` = `design-patterns/strategy`, `ExerciseKey.rawValue` = `design-patterns/strategy#spot-1`). Content and progress never reference each other by object. Cards whose exercise disappeared from the pack are ignored, never deleted.
- **Engines are pure.** `FSRSScheduler`, `PracticeQueueBuilder`, `ReviewSessionEngine`, `ExerciseGrader`, `MasteryCalculator`, `LearningPath` and `StreakCalculator` are Sendable value types in the packages. They receive value snapshots (`FSRSCard`, `PracticeCardSnapshot`), never SwiftData models.
- **`ProgressStore`** is the only code that touches SwiftData. It conforms to KataCore's `ProgressRepository`.
- **`StudyModel`** (KataStore, shared with the Mac app) holds library, store, settings, `contentKeys` and `kataKeys`, and derives mastery (`masteryMap()`), the review queue (`reviewQueue()`), `dueCount(onDayOf:)` and `nextDueDate()` from store snapshots. Kata cards (exercise id `kata`) are never part of the review queue.
- **`AppModel`** (iOS) is the composition root: container, a `StudyModel` (`study`), reminders, navigation paths and the pending practice request. `library`, `store`, `settings` and the derived queries forward to `study`.
- **`PersistenceFactory.makeContainer(url:inMemory:)`** builds the container with `KataSchemaV2` and `KataMigrationPlan`. `url: nil` uses SwiftData's default location (iOS); the Mac passes an explicit URL.

### Learning model

1. Opening a deck creates the item's `ItemProgress` and marks the visible role as seen.
2. **Practice this pattern** (last card) runs a first-exposure session with all of the item's exercises. Each rating creates that exercise's FSRS card. When the session finishes, `studiedAt` is set.
3. Afterwards reviews come from the FSRS due queue (**Start review** on Today). `PracticeQueueBuilder` caps reviews (`dailyReviewLimit`), adds new exercises of studied items that have no card yet (`newExercisesPerDay`), buries siblings and never puts two exercises of one item back to back.
4. Grading: a wrong answer is **Again** with an explanation. A correct answer suggests **Good**; the learner can pick Hard or Easy. Recall is self-rated with four buttons and a key-point checklist that pre-selects a suggestion. Options and blocks are shuffled with a seed of `(exercise key, reps)`.

### Persistence (SwiftData, KataStore: `SchemaV1.swift`, `SchemaV2.swift`)

`KataSchemaV1: VersionedSchema` (1.0.0), no relationships:

| Model | Key fields |
|---|---|
| `ExerciseCard` | `@Attribute(.unique) key`, `topicId`, `itemId`, `stateRaw`, `stability`, `difficulty`, `due`, `lastReview`, `reps`, `lapses`, `createdAt`; `#Index([\.due], [\.itemId])` |
| `ReviewLogEntry` | `cardKey`, `ratingRaw`, `reviewedAt`, `elapsedDays`, `scheduledDays`, `stateBeforeRaw`, `wasCorrect: Bool?`, `responseMillis: Int?` |
| `ItemProgress` | `@Attribute(.unique) key`, `firstOpenedAt`, `lastOpenedAt`, `seenRoles`, `studiedAt`, `isBookmarked`, `bookmarkedAt`, `note` (at most 140 characters) |
| `DailyActivity` | `@Attribute(.unique) dayKey` (`yyyy-MM-dd`, gregorian, local), `reviewCount`, `studiedCount` |

`KataSchemaV2` (2.0.0) reuses the four V1 models unchanged and adds `KataAttempt` (itemKey, startedAt, passedAt, isReview, hintsUsed, revealedSolution, runCount, activeMillis, ratingRaw, modeRaw; indexed on itemKey and startedAt) and `KataSolution` (unique itemKey, external-storage `draftJSON` and `passedJSON`, passedAt, updatedAt). Both tables stay empty on iOS. `KataMigrationPlan` is `[V1, V2]` with one lightweight stage. A kata's FSRS card is an `ExerciseCard` keyed `<item>#kata`. To change the schema again, add `KataSchemaV3`, append it and add a stage. Never edit an existing version in place.

`ProgressStore` (public API in KataStore, including the kata draft/attempt/pass methods) rules: `@MainActor @Observable final class`; a `revision` counter is bumped on every explicit save and read in every query, so views refresh; no `@Query` in views. Streaks come from `StreakCalculator` over the days with any activity.

### Settings (`AppSettings`, KataStore)

`@MainActor @Observable`, UserDefaults-backed through `didSet`, keys `settings.*`, `init(defaults:)` for tests. Out-of-range stored values are clamped on load.

| Property | Default | Range |
|---|---|---|
| `remindersEnabled`, `reminderHour`, `reminderMinute` | off, 20:00 | |
| `desiredRetention` | 0.90 | 0.85 / 0.90 / 0.95 |
| `newExercisesPerDay` | 10 | 1...30 |
| `dailyReviewLimit` | 100 | 10...300 |
| `codeFontSize` | 14 | 12...18 |
| `showLineNumbers` | true | |

### Reminders

`ReminderScheduler` replaces seven one-shot `UNCalendarNotificationTrigger`s (`review-reminder-0...6`) on launch, when the app becomes active, after a session, and when settings change. `ReminderScheduler.plan(...)` is pure and unit tested: today is skipped when the time has passed, or when today has activity and nothing is due.

## 3. Concurrency rules (Swift 6, strict)

- `SWIFT_VERSION = 6.0`. Do **not** set `SWIFT_DEFAULT_ACTOR_ISOLATION` or `SWIFT_APPROACHABLE_CONCURRENCY`. The default stays nonisolated so Codable models and engines are not MainActor.
- Every `@Observable` class is a `@MainActor final class` (`AppModel`, `StudyModel`, `ProgressStore`, `AppSettings`, `PracticeSessionModel`).
- Domain types and engines are `Sendable` structs. `ContentLibrary` is a `final class: Sendable` with `let` properties only.
- SwiftData models are touched only on the main actor (`ProgressStore` uses `container.mainContext`). Model objects never leave the store.
- Pure helpers that must be callable from tests or other isolation domains are `nonisolated static` (for example `ReminderScheduler.plan`).
- No `static var`. Use `static let`.

## 4. Liquid Glass usage

Glass is for the floating control layer only. Content stays calm.

- Content surfaces: `.background(.background.secondary, in: .rect(cornerRadius: 20))` (`cardSurface()`), never `glassEffect`.
- Glass appears on: the deck's `GlassBottomBar` (inside a `GlassEffectContainer`), the walkthrough note panel, the `FeedbackPanel`, primary actions (`.buttonStyle(.glassProminent)`: Start review, Practice this pattern, Check, Continue, Done), secondary actions (`.buttonStyle(.glass)`: Hard / Easy, close), and `RatingBar` buttons tinted per rating.
- Never put `glassEffect` on rows or cards inside scrolling content (cost on older GPUs such as the iPhone 11's A13).
- Toolbars and the tab bar get glass automatically. `TabView` uses `.tabBarMinimizeBehavior(.onScrollDown)`; the deck hides the tab bar with `.toolbarVisibility(.hidden, for: .tabBar)`.
- Do not replace UIKit navigation bar appearances; that keeps the system glass.

## 5. Screens

`RootView` is a `TabView` with four tabs, each in its own `NavigationStack` whose path lives in `AppModel`: **Today**, **Path**, **Library**, **Search** (`Tab(role: .search)`). Settings is a sheet from the Today gear. Practice is a `.fullScreenCover(item:)`.

- **Today:** due count and **Start review** (or "All caught up" with the next review time), streak and today's count, **Continue your path**, recently studied, bookmarks (first five, then "All").
- **Path:** sections of the topic's path with `MasteryRing`, title and intent; the next item is highlighted; nothing is locked; "N / 70 studied".
- **Library:** goes straight to the topic when there is only one; categories with item rows; a Bookmarks filter.
- **Deck (`ItemDeckView`):** horizontal paging (`scrollTargetBehavior(.paging)` + `scrollPosition(id:)`), one card per screen. Toolbar: bookmark and a 140-character note popover; a Read / Walkthrough picker appears while a code card is showing. Bottom glass strip of role symbols. `kata:` links open the target deck (or say "Coming soon"). Card views: text (`BlocksView`), code (`CodeWalkthroughView`, which owns its vertical scroll, so it is never wrapped in another `ScrollView`), diagram (segmented control plus Expand to `ZoomableDiagramView`), lists, comparison (rows open the referenced item when it has content), references.
- **Practice:** `PracticeSessionModel` (KataStore; takes a `StudyModel` and an `onEnd` closure that the app uses to refresh reminders) wraps `ReviewSessionEngine` and persists each rating at once. Views: Identify, Choose, TapLine, Reorder (`List` + `.onMove`), Recall. `FeedbackPanel`, `RatingBar`, `PracticeSummaryView`.
- **Search:** `.searchable`, 200 ms debounce, results open the deck at the matched card.
- **Settings:** reminder, retention, limits, code font and preview, reset (`HoldToConfirmButton`), About (GitHub, MIT, privacy).

## 6. Repository layout and file naming

```
Config/Info.plist                  merged with the generated plist
Kata.xcodeproj                     objectVersion 77, synchronized groups (Kata/, KataTests/), local package
Packages/KataKit/                  the modules above, tests, Fixtures
Content/topics/<topic>/            authoring source (topic.json, items/<id>/item.json + *.java)
Kata/                              app target (this document, section 1)
KataTests/                         BundledPackSmokeTests, ReminderSchedulerTests
docs/                              PLAN.md, ARCHITECTURE.md
```

**Filename uniqueness.** Every filename inside `Kata/` and `KataTests/` must be unique: synchronized groups flatten resources into the bundle root, and two Swift files with the same name in different folders fail with "filename used twice". Packs are therefore named after their topic id.

Every kit type, property, init or function used by the app must be `public`; structs need an explicit `public init`.

## 7. Adding a topic

No Swift change is needed.

1. Create `Content/topics/<topic>/topic.json` with `schemaVersion`, `id`, `title`, `symbol`, `codeLanguage`, `roles`, `templates`, `requiredExercises`, `categories`, `items` (the registry) and `path`.
2. Add `items/<item-id>/item.json` and its code files (region markers `// [[id` ... `// ]]`). Items listed in the registry without a body show as "Coming soon".
3. Run `swift run --package-path Packages/KataKit kata-pack validate`, then `check-java` (when the topic uses Java), then `kata-pack build` to write `Kata/Resources/Packs/<topic>.kpack`.
4. Commit the built `.kpack`; CI rebuilds it and fails on a diff.
5. The app discovers every `*.kpack` in the bundle. With more than one topic the Library lists topics and the Path tab gets a topic menu.
6. Ids are stable forever: progress is keyed by `ItemKey` and `ExerciseKey`. Never rename them.

## 8. Patterns in Kata's own code

The app uses the patterns it teaches. Item ids refer to the in-app items (`kata:<id>` links).

| Pattern (item id) | Where |
|---|---|
| Strategy (`strategy`) | `SyntaxHighlighter` + `HighlighterRegistry` (`KataCode`) |
| Repository (`repository`) | `ProgressRepository`, implemented by `ProgressStore` and `InMemoryProgressRepository` |
| Factory (`factory-method`) | the card and exercise view switches in `CardPage` and `PracticeSessionView.exercise` |
| Observer (`observer`) | `@Observable` models observed by SwiftUI views |
| Builder (`builder`) | `PackBuilder` |
| Composite (`composite`) | `Block` lists inside cards and model answers |
| Command (`command`) | `ExerciseResponse` values submitted to the session, graded by `ExerciseGrader` |

## 9. Testing

- Host tests (macOS, Swift Testing): `swift test --package-path Packages/KataKit`.
- `KataStoreTests` (host): `ProgressStoreTests` (in-memory container), `AppSettingsTests` (suite-named UserDefaults), `MigrationTests` (an on-disk V1 store reopened with the V2 plan keeps its rows; kata API round trip).
- App tests (`KataTests`, Swift Testing, hosted by the app): `BundledPackSmokeTests` (the shipped pack decodes, 70 registry items, Strategy has every template role), `ReminderSchedulerTests` (pure planning).
- Build only: `xcodebuild build-for-testing -project Kata.xcodeproj -scheme Kata -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`.
- On the device (unlock the phone first): `xcodebuild test -project Kata.xcodeproj -scheme Kata -destination 'id=00008030-000511D93CC0202E' -derivedDataPath build -allowProvisioningUpdates`.

## 10. Debug launch (screenshots)

In DEBUG builds, `-KataDemo YES` swaps in an in-memory store seeded with a week of Strategy activity and a throwaway settings suite. `-KataScreen today|path|library|deck|practice|search|settings` routes straight to a screen (`deck:<role>` opens a given card, `search:<query>` sets the query). The real store and settings are never touched.
