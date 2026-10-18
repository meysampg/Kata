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
| compare | 3–5 rows. `ref` must be an item id. Relations: `lookAlike`, `alternative`, `combines`, `oftenConfused`, `specializes`. Each `difference` states the *decisive* distinction in ≤ 40 words. |
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
