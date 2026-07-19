# M1B1 acceptance plan

Status: **TO VALIDATE — provider-neutral gate passed; real-provider and physical-device gates remain open**

M1A remains the stable rollback baseline. M1B1 cannot merge, clean its branches,
or proceed to M1B2 until the product owner accepts the public preview on a real
iPhone Safari session.

## Contract and backend

| ID | Acceptance criterion | Current status |
| --- | --- | --- |
| M1B1-01 | Godot calls only same-origin `/api/compile-weapon`; no third-party key or endpoint is embedded | **CONFIRMED (source + browser)** |
| M1B1-02 | Provider-neutral request/response contract includes every required field | **CONFIRMED** |
| M1B1-03 | Backend limits and validates request types, lengths and drawing-summary bounds | **CONFIRMED (Node + red team)** |
| M1B1-04 | Structured adapter output is repaired by schema, allow-list and PowerBudget gates | **CONFIRMED (deterministic adapter)** |
| M1B1-05 | Secrets exist only as server-side secret environment values and never appear in build, Git or logs | **CONFIRMED (boundary, leak probe, and secret scan); TO VALIDATE with real deployment** |
| M1B1-06 | Logs omit raw input, full provider output, secrets and unnecessary personal data | **CONFIRMED (malicious nested-metadata leak regression)** |

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
| M1B1-15 | Bad JSON, missing fields, timeout, offline, 429, 5xx and unavailable backend produce a validated fallback without a crash | **CONFIRMED (simulated faults)** |
| M1B1-16 | At most one explicitly safe retry occurs; wrapper timeouts abort and do not retry; cancellation preserves drawing/text; durable idempotency shares one provider operation across worker bindings | **CONFIRMED (Node D1/abort probes + Chromium + WebKit + late-A-after-B client probe); TO VALIDATE on Sites** |
| M1B1-17 | Identical concepts stay in a stable Power range and every final score is at most 100 | **CONFIRMED (deterministic adapter); TO VALIDATE with real model** |

## Matrix and quality targets

| ID | Acceptance criterion | Current status |
| --- | --- | --- |
| M1B1-18 | At least 40 human-labelled normal, creative, ambiguous, extreme, unsafe and transport cases are recorded | **CONFIRMED (48 main + 60 red-team cases)** |
| M1B1-19 | Final Schema pass rate is 100%; allow-list pass rate is 100%; Power pass rate is 100% | **CONFIRMED (provider-neutral); TO VALIDATE with real model** |
| M1B1-20 | Labelled normal attack-pattern and element accuracy is at least 90% | **TO VALIDATE** |
| M1B1-21 | Chinese and English normal concepts both succeed | **TO VALIDATE** |
| M1B1-22 | Each case records interpretation, final spec, repairs, fallback, latency and cost (`UNKNOWN` when unavailable) | **CONFIRMED for local adapter; TO VALIDATE with real provider usage** |
| M1B1-23 | Real-provider median latency target is at most 5 s and P95 target is at most 10 s; failures are reported honestly | **TO VALIDATE** |

## Regression and delivery

| ID | Acceptance criterion | Current status |
| --- | --- | --- |
| M1B1-24 | All M1A compiler, five-attack, four-element and target-lab tests remain green | **CONFIRMED (458 assertions)** |
| M1B1-25 | 844×390, 852×393, 915×412, portrait gate, iOS keyboard and Safari-toolbar flows remain usable | **CONFIRMED (emulated); TO VALIDATE on physical iPhone M1B1** |
| M1B1-26 | Godot parse, unit, worker, D1 guard, Web build, Chromium and WebKit regression pass without new application errors | **CONFIRMED (`104fddb`: Godot 458, interpreter 68/68, D1 9/9, Chromium/WebKit; app console errors 0)** |
| M1B1-27 | PR and CI pass; a new uncached public deployment is verified by HTTP and resource hash | **TO VALIDATE** |
| M1B1-28 | Product owner accepts the new public build on physical iPhone Safari | **TO VALIDATE** |

## Measurement rules

- Accuracy denominator contains only cases with an explicit expected pattern and
  element; transport/fallback cases cannot inflate it.
- Latency is measured end-to-end at the backend and reported from real requests.
- P95 uses the nearest-rank percentile over successful real-provider requests;
  timeout/failure counts are reported separately.
- Cost remains `UNKNOWN` unless verified provider usage and pricing data exist.
- A fallback counts as reliability success only when its final spec passes all
  three programmatic gates; it does not count as semantic-accuracy success.
