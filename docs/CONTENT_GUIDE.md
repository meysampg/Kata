# Kata content guide

The single standard every item in `Content/topics/design-patterns/` follows. The gold standard is
`items/strategy/` — read its `item.json` and `Strategy.java` before writing anything, and match its
depth, tone and length.

## Reader

A seasoned engineer (Java, Python, Go) who wants *professional command*, not an introduction.
Assume they know OOP and Java syntax. Explain *why* and *when*, show the mechanism, name the trade-offs.
Never pad. Never hype.

## Tone

Calm, precise, second person where natural, US English, no exclamation marks, no emoji.
Use `**bold**` for the 2–3 key terms of a card, `` `code` `` for identifiers, and
`[Title](kata:<item-id>)` to cross-link another item (only ids that exist in `topic.json`).

## Files per item

```
items/<id>/item.json      cards + exercises (schema: see strategy and docs/PLAN.md §2)
items/<id>/<Name>.java    the implementation card's file (no public types, so any file name works)
items/<id>/kata/          the coding kata for Kata for Mac (see "Katas" below; optional until all 70 exist)
```

The Java file is one compilation unit with a `class Main { public static void main(...) }` that prints a
deterministic result; `expectedOutput` in the code card must match it exactly. Mark 3–7 walkthrough
regions with `// [[region-id` and `// ]]` lines (the build strips them). Regions must not overlap.

## Cards — order comes from the template

`pattern` template: definition, implementation, example, structure, tradeoffs, compare, sightings.
`principle` template (Foundations): definition, implementation, example, tradeoffs, compare, sightings;
`structure` optional — include it only if a diagram truly helps (e.g. DIP before/after).

| Card | Limits and rules |
|---|---|
| definition | `lead` ≤ 25 words (the intent in one sentence). Body ≤ 90 words. ≤ 4 bullets. Optional one `callout` (≤ 40 words). |
| implementation | Java 21, ≤ 70 lines (hard max 90), ≤ 80 columns, 4-space indent. Compiles with `-Xlint:all` and runs. Walkthrough 3–7 steps, each note ≤ 35 words. Modern Java where it helps (records, sealed, lambdas, `var`, switch patterns, virtual threads) — but show the pattern's real mechanism, not a one-liner that hides it. |
| example | A realistic production scenario in a **different domain** from the implementation. `lead` (the situation in ≤ 12 words) + ≤ 120 words + optional ≤ 8 lines of display code + one `positive` callout stating the payoff. |
| structure | Class diagram with GoF role names in `role`; ≤ 8 nodes, ≤ 2 columns (use `0.5` to center), ≤ 10 edges. Keep member lines short (≤ 28 chars) — the phone is narrow. Add a sequence diagram (≤ 5 participants, ≤ 10 messages) when the runtime interaction is the point (Observer, Chain, Proxy, Saga, Circuit Breaker…). |
| tradeoffs | Lists with tones: "Use when" (positive), "Avoid when" (negative), "Pitfalls" (warning), optionally "Overuse smells" (warning) and "Modern Java" (info) — say plainly when a pattern is obsolete or replaced by a language/library feature. 2–4 items per list, ≤ 18 words each. |
| compare | 3–5 rows. `ref` must be an item id. Relations: `lookAlike`, `alternative`, `combines`, `oftenConfused`, `specializes`. The row reads "<ref> · Specializes", so `specializes` means **the referenced item is a special case of this item** (in Thread Pool: `{"ref": "fork-join", "relation": "specializes"}`). If this item is the special case, use `lookAlike` or `alternative` and say so in `difference`. Each `difference` states the *decisive* distinction in ≤ 40 words. |
| sightings | 3–6 entries of **real, verifiable** APIs/products with exact names (JDK, Spring, Jakarta EE, Guava, Netty, Kafka, Kubernetes, Resilience4j, Hibernate, Envoy, Istio…). If you are not certain a class/feature exists with that exact name and behavior, omit it. Never invent. |

## Exercises — exactly these 5 per item (ids fixed)

| id | kind | Rules |
|---|---|---|
| `spot-1` | identify | 6–14 lines of Java that **do not name the pattern** (no `Strategy`, `Observer`… in identifiers). 4 options, 1 correct, each with a crisp `why`. Distractors are plausible look-alikes. Add `compile.template` so the snippet compiles. |
| `pick-1` | choose | A 2–4 sentence real design problem. 4 options, 1 correct; each wrong `why` says why it loses *here*. |
| `flaw-1` | tapLine | 8–14 lines implementing the pattern with exactly one (rarely two) line that breaks it. `flawLines` 1-based. `explanation` says what breaks and the fix. Add `compile.template`. |
| `order-1` | reorder | 4–7 blocks (each 1–3 lines) whose order is forced by data/logic dependencies, not taste. `explanation` ≤ 40 words. Add `compile.template` when feasible. |
| `recall-1` | recall | A "explain in your own words" prompt hitting the core insight and the main confusion. `modelAnswer` ≤ 80 words. 3–5 `keyPoints`. |

`compile.template` lines must contain `{{code}}` exactly once; provide the minimum stub types/imports so
the unit compiles under `--release 21`.

## Category notes

- **Foundations** (principles, not patterns): the implementation shows a *before → after* refactoring in
  one file (e.g. a `Before` and an `After` section, both runnable from `Main`). Sightings are places the
  principle is visible in well-known APIs.
- **Concurrency**: samples must be deterministic in output (join/await everything; no timing-dependent
  prints). Prefer `java.util.concurrent` and virtual threads where idiomatic. Mention memory-model
  guarantees precisely (happens-before, `volatile`, `final` fields).
- **Enterprise & architecture**: keep it in-memory (no frameworks). Show the seam (interfaces/ports) in
  plain Java; mention Spring/Jakarta equivalents in sightings.
- **Resilience & cloud**: simulate time and failures deterministically (an injected `Clock`/counter or a
  scripted fake), never `Thread.sleep` for real waits longer than a few ms. Infrastructure patterns
  (sidecar, ambassador, api-gateway, strangler-fig) still get a small Java sample of the core idea
  (e.g. a routing facade, a proxying client) plus sightings in Envoy/Istio/Kubernetes/etc.

## Verification (must be clean before you finish)

```bash
K=Packages/KataKit/.build/debug/kata-pack
$K validate --items <ids> --allow-missing   # 0 errors; fix warnings unless clearly justified
$K check-java --items <ids>                  # every unit "ok", output matches
```

## Katas (draft, Mac only)

Every item gets one hands-on coding kata, checked offline against a local JDK 21+. The gold standard
is `items/strategy/kata/`: read it before writing one. Katas never enter the iOS `.kpack`; `kata-pack
build` writes them to `KataMac/Resources/Katas/<topic>.kkata`.

### Layout

```
items/<id>/kata/kata.json            strict schema, below
items/<id>/kata/starter/*.java       what the learner starts from
items/<id>/kata/solution/*.java      the reference; must pass every check
items/<id>/kata/tests/*.java         hidden tests (use the `kata.*` harness API)
```

`kata.json` keys (unknown keys are errors): `kind` (`refactor` | `implement` | `fix`), `title`
(at most 60 characters), `minutes` (10 to 40, the target time that drives the rating suggestion), `task`
(blocks), `starter`, `readOnly` (optional, subset of `starter`), `solution`, `tests` (file names),
`checks` (`id`, `kind` `behaviour` | `design`, `title`), `hints` (exactly 3, each a block list),
`timeoutSeconds` (optional, default 10, at most 30), `stressRuns` (optional, default 5) and
`starterCompiles` (optional, default `true`; `false` only for an `implement` kata whose skeleton cannot
compile). `checks` must list the `@Check` ids of the tests in source order; the validator compares them.

### Choosing the kind

| Kind | Use when | Starter | Starter must |
|---|---|---|---|
| `refactor` | the pattern removes a smell from working code | working code with the smell | pass every behaviour check and fail at least one design check |
| `implement` | the pattern is a construction with a crisp contract | compiles, bodies throw `UnsupportedOperationException("TODO")` | fail at least one check |
| `fix` | the pattern's classic failure is the lesson | code with real bugs | fail at least one behaviour check |

Minimum checks: refactor 2 behaviour and 2 design; implement 4 in total; fix 1 behaviour. Aim for 6 to 10
checks, each testing one idea. Echo the domain of the item's code card, or of its example card, never a third.

### Task, starter and solution

- Task: at most 180 words. Name every type and method signature the tests rely on. Say what must not change.
- Starter at most 120 lines, each solution file at most 150. Lines of more than 80 columns warn, more than
  100 fail. Java 21, 4 spaces, no `public` top-level types, no `System.exit`, deterministic.
- Do not fix things the task does not mention. In a refactor kata the starter's behaviour is the contract,
  including its quirks; change it only if it is a real bug, and then say so in the task.
- Test files declare no top-level type that the solution also declares.

### Tests: the harness API

Tests are package-private classes in the default package with `import kata.*;`. Each `@Check(id = "...",
kind = Kind.DESIGN, timeoutMs = 2000, repeat = 1)` method runs on a fresh instance in its own thread.

| Type | Use |
|---|---|
| `Expect` | `equal(expected, actual, what)`, `isTrue`, `fail`, `raises(Class, runnable, what)`, `none(hits, msg)`, `atMost(n, hits, msg)`, `completesWithin(ms, supplier, what)` |
| `Types` | `named("X")` (fails with "No type named X in your files"), `singleAbstractMethod`, `onlyFieldOfType`, `fieldsOfType`, `onlyStaticFieldOfType`, `setStatic`, `getStatic`, `constructor`, `method`, `staticMethod`, `call`, `create`, `implement(iface, handler)` |
| `Source` | `type("X")` then `method("m")`, `switches()`, `instanceofs()`, `comparedStrings()`, `calls("n")`, `fieldReads("f")`, `news("T")`, `mentions("I")`; each returns `Hit`s with file, line and `insideSynchronized` |
| `Stress` | `race(threads, task)`, `pause(ms)` (at most 50), `holdMonitor(obj)`, `holdLock(lock)` |

Rules:

- Behaviour checks in a refactor kata compile against the stable API that exists in the starter. Design checks
  never name new types at compile time; they use only `Types` and `Source`, so a half-done refactor still
  compiles against the hidden tests.
- A check that cannot compile is reported as "blocked" with the missing symbol, never with test source.
- Messages are actionable and name the type ("Checkout still compares discount codes"). Pass `Hit`s so the
  learner is pointed at a line.
- Check roles, not names, beyond what the task specifies. Try two correct solutions (for example a
  lambda-only Strategy and an `enum` Strategy) before you call a design check done.

### Concurrency determinism

- Make failures certain with seams (a documented hook such as `onConstruct`, left in the starter) and start
  gates (`Stress.race`). Never rely on timing for correctness; `Stress.pause` only widens a window.
- Per-check `timeoutMs` is at most 5000. The reference must pass with 1 and 4 processors, 20 times each
  (`stressRuns: 20`).
- Memory-model bugs that tests cannot observe reliably become design checks (for example `volatile`).

### Hint ladder

Exactly three hints, each at most 50 words. H1 names the concept or what varies. H2 gives the structural
direction and names the types. H3 is nearly the solution, with at most 10 lines of code (only H3 may have a
code block). None pastes the full answer. Using hints lowers the suggested rating.

### Verification

```bash
K=Packages/KataKit/.build/debug/kata-pack
$K validate --items <ids>                              # 0 errors, 0 warnings
$K check-java --items <ids> --kata-runs 5 --timing     # reference passes, starter fails by kind
$K kata-workspace --items <id> --out /tmp/<id>         # open in IntelliJ to iterate
$K build                                               # rewrites the .kpack (unchanged) and the .kkata
```

`check-java` runs the reference solution `--kata-runs` times (and again with 1 and 4 processors for
concurrency katas), then the starter, through the same runner the Mac app uses. The median wall time per
run should stay under 2 seconds.
