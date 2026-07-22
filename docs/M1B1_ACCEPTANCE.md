# M1B1 acceptance plan

Status: **CONFIRMED complete and released**

Historical record — superseded by the v0.3.0 Weapon Physics B1 closure.

The product owner accepted the public M1B1 preview on a real iPhone Safari
session on 2026-07-20. PR #4, CI, stable deployment, smoke, tag, and rollback
verification subsequently completed. M1B1.1 and M1B1.2 also completed; M1B2 has
not started.

The prior public candidate was reopened after physical-iPhone discovery of two
P0 failures: keyboard focus could move the Canvas outside the visible viewport,
and the projectile path could throw the complete held weapon. Automated v20
evidence is green and the product owner independently passed both repaired paths
on the physical device.

## Contract and backend

| ID | Acceptance criterion | Current status |
| --- | --- | --- |
| M1B1-01 | Godot calls only same-origin `/api/compile-weapon`; no third-party key or endpoint is embedded | **CONFIRMED (source + browser)** |
| M1B1-02 | Provider-neutral request/response contract includes every required field | **CONFIRMED** |
| M1B1-03 | Backend limits and validates request types, lengths and drawing-summary bounds | **CONFIRMED (Node + red team)** |
| M1B1-04 | Native structured adapter output is repaired by schema, allow-list and PowerBudget gates | **CONFIRMED (Anthropic adapter offline tests)** |
| M1B1-05 | Secrets exist only as server-side secret environment values and never appear in build, Git or logs | **CONFIRMED (Sites secret metadata, deployed-asset boundary, leak probe, and secret scan)** |
| M1B1-06 | Logs omit raw input, full provider output, secrets and unnecessary personal data | **CONFIRMED (malicious nested-metadata leak regression)** |
| M1B1-06A | Provider/model are exactly Anthropic / `claude-haiku-4-5-20251001` through native Messages + Structured Outputs; no upgrade/fallback/compatibility route | **CONFIRMED (17 adapter tests + public live canary)** |
| M1B1-06B | Worker + D1 enforce the lifetime USD 5 cap before invocation and conservatively handle unknown billing | **CONFIRMED (14 budget tests + deployed D1 reserve/settle audit)** |

## Player flow

| ID | Acceptance criterion | Current status |
| --- | --- | --- |
| M1B1-07 | Normal player can draw, enter free text and forge without selecting an attack pattern | **CONFIRMED (Chromium + WebKit)** |
| M1B1-08 | Five M1A buttons are hidden by default and visible only in Developer/Test Mode or MODIFY INTERPRETATION | **CONFIRMED (Chromium + WebKit)** |
| M1B1-09 | Loading state, duplicate-request lock and CANCEL are visible and operable | **CONFIRMED (simulated async faults)** |
| M1B1-10 | Review shows name, summary, pattern, element, damage, speed, range, ability, status, weakness and Power Score | **CONFIRMED (Chromium + WebKit)** |
| M1B1-11 | CONFIRM enters combat; MODIFY revalidates a manual correction; TRY AGAIN cannot reroll higher numeric power | **CONFIRMED (deterministic adapter)** |
| M1B1-12 | “Result not suitable” feedback is visible and does not publish or retain raw content | **CONFIRMED (local/browser)** |

## Reliability

| ID | Acceptance criterion | Current status |
| --- | --- | --- |
| M1B1-13 | Blank, long, ambiguous, misspelled, mixed-language and multi-concept input resolve safely | **CONFIRMED (deterministic adapter + matrices)** |
| M1B1-14 | Prompt injection, code requests, unsupported abilities and budget-bypass requests cannot alter execution boundaries | **CONFIRMED (60-case red-team corpus)** |
| M1B1-15 | Blank input, bad JSON, missing fields, timeout, offline, 429, 5xx, unavailable backend, no provider invocation, or zero confidence produce an explicit non-equipable error without a crash | **CONFIRMED (simulated faults + live success gate)** |
| M1B1-16 | Anthropic makes one attempt only; wrapper timeouts abort and do not retry; cancellation preserves drawing/text; durable idempotency shares one provider operation across worker bindings | **CONFIRMED (adapter/D1/abort probes + deployed Sites safe/live probes + current Chromium/WebKit + late-A-after-B client probe)** |
| M1B1-17 | Identical concepts stay in a stable Power range and every final score is at most 100 | **CONFIRMED (deterministic suites + 42-case real-model matrix)** |

## Matrix and quality targets

| ID | Acceptance criterion | Current status |
| --- | --- | --- |
| M1B1-18 | At least 40 human-labelled normal, creative, ambiguous, extreme, unsafe and transport cases are recorded | **CONFIRMED (48 main + 60 red-team cases)** |
| M1B1-19 | Final Schema pass rate is 100%; allow-list pass rate is 100%; Power pass rate is 100% | **CONFIRMED (42/42 real-provider cases at 100% for all three gates)** |
| M1B1-20 | Labelled normal attack-pattern and element accuracy is at least 90% | **CONFIRMED (24 eligible cases; pattern 100%, element 100%)** |
| M1B1-21 | Chinese and English normal concepts both succeed | **CONFIRMED (real-provider matrix)** |
| M1B1-22 | Each case records interpretation, final spec, repairs, fallback, latency and cost (`UNKNOWN` when unavailable) | **CONFIRMED (privacy-bounded 42-case real-provider artifact)** |
| M1B1-23 | Real-provider median latency target is at most 5 s and P95 target is at most 10 s; failures are reported honestly | **CONFIRMED (median 1.318 s; P95 4.846 s; 29/29 provider calls succeeded)** |

## Regression and delivery

| ID | Acceptance criterion | Current status |
| --- | --- | --- |
| M1B1-24 | All M1A compiler, five-attack, four-element and target-lab tests remain green | **CONFIRMED (629 assertions)** |
| M1B1-25 | 844×390, 852×393, 915×412, 844×343 toolbar stress, portrait gate, keyboard and Safari-toolbar flows remain usable | **CONFIRMED (Chromium + WebKit + physical iPhone Safari)** |
| M1B1-26 | Godot parse, unit, worker, both D1 guards, Web build, Chromium and WebKit regression pass without new application errors | **CONFIRMED (Godot 629, Worker/WASM/Interpreter/D1/Anthropic/security suites, canonical Sites bundle, Chromium/WebKit app console 0)** |
| M1B1-27 | PR and CI pass; a new uncached public deployment is verified by HTTP and resource hash | **CONFIRMED: runtime `6d5ba3a` / Sites v19 acceptance evidence, PR #4 release, and later stable deployment/rollback closure completed** |
| M1B1-28 | Product owner accepts the new public build on physical iPhone Safari | **CONFIRMED on 2026-07-20 using the Sites v19 / runtime `6d5ba3a` public build** |
| M1B1-29 | Description and numeric drawing state are atomically frozen with a visible request ID; the POST and confirmation snapshot match | **CONFIRMED (Chromium/WebKit + two live blocker cases)** |
| M1B1-30 | Grenade is visibly thrown on an arc before a landing explosion; bow remains held and emits a separate velocity-facing arrow | **CONFIRMED (Godot + Chromium/WebKit + physical iPhone)** |
| M1B1-31 | Every player-ink visual uses actual stroke bounds and uniform scale with at most 2% aspect error; procedural projectiles never copy the held ink | **CONFIRMED (Godot + Chromium/WebKit + physical iPhone visual acceptance)** |
| M1B1-32 | Keyboard focus keeps a stable visible Canvas, exposes Description/clear/Done inside the Visual Viewport and safe area, and restores normal layout after blur, toolbar change and three rotation cycles | **CONFIRMED with Chromium/WebKit and the real iOS keyboard** |
| M1B1-33 | Visual roles are deterministic: bow 10/10 held-arrow attacks, grenade centred arc/blast/restore, sword zero projectiles, and same-instance boomerang return | **CONFIRMED in Chromium/WebKit and on physical iPhone Safari** |

## Measurement rules

- Accuracy denominator contains only cases with an explicit expected pattern and
  element; transport/fallback cases cannot inflate it.
- Latency is measured end-to-end at the backend and reported from real requests.
- P95 uses the nearest-rank percentile over successful real-provider requests;
  timeout/failure counts are reported separately.
- Cost remains `UNKNOWN` unless verified provider usage and pricing data exist.
- A provider or validation failure counts as reliability success only when it
  produces the explicit non-equipable error flow, preserves input, and cannot
  expose CONFIRM or combat. It never counts as semantic-accuracy success.
