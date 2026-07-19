# M1B1 acceptance plan

Status: **TO VALIDATE — gate opened, not yet accepted**

M1A remains the stable rollback baseline. M1B1 cannot merge, clean its branches,
or proceed to M1B2 until the product owner accepts the public preview on a real
iPhone Safari session.

## Contract and backend

| ID | Acceptance criterion | Current status |
| --- | --- | --- |
| M1B1-01 | Godot calls only same-origin `/api/compile-weapon`; no third-party key or endpoint is embedded | **TO VALIDATE** |
| M1B1-02 | Provider-neutral request/response contract includes every required field | **TO VALIDATE** |
| M1B1-03 | Backend limits and validates request types, lengths and drawing-summary bounds | **TO VALIDATE** |
| M1B1-04 | Structured adapter output is repaired by schema, allow-list and PowerBudget gates | **TO VALIDATE** |
| M1B1-05 | Secrets exist only as server-side secret environment values and never appear in build, Git or logs | **TO VALIDATE** |
| M1B1-06 | Logs omit raw input, full provider output, secrets and unnecessary personal data | **TO VALIDATE** |

## Player flow

| ID | Acceptance criterion | Current status |
| --- | --- | --- |
| M1B1-07 | Normal player can draw, enter free text and forge without selecting an attack pattern | **TO VALIDATE** |
| M1B1-08 | Five M1A buttons are hidden by default and visible only in Developer/Test Mode or MODIFY INTERPRETATION | **TO VALIDATE** |
| M1B1-09 | Loading state, duplicate-request lock and CANCEL are visible and operable | **TO VALIDATE** |
| M1B1-10 | Review shows name, summary, pattern, element, damage, speed, range, ability, status, weakness and Power Score | **TO VALIDATE** |
| M1B1-11 | CONFIRM enters combat; MODIFY revalidates a manual correction; TRY AGAIN cannot reroll higher numeric power | **TO VALIDATE** |
| M1B1-12 | “Result not suitable” feedback is visible and does not publish or retain raw content | **TO VALIDATE** |

## Reliability

| ID | Acceptance criterion | Current status |
| --- | --- | --- |
| M1B1-13 | Blank, long, ambiguous, misspelled, mixed-language and multi-concept input resolve safely | **TO VALIDATE** |
| M1B1-14 | Prompt injection, code requests, unsupported abilities and budget-bypass requests cannot alter execution boundaries | **TO VALIDATE** |
| M1B1-15 | Bad JSON, missing fields, timeout, offline, 429, 5xx and unavailable backend produce a validated fallback without a crash | **TO VALIDATE** |
| M1B1-16 | At most one safe retry occurs and cancellation preserves drawing and text | **TO VALIDATE** |
| M1B1-17 | Identical concepts stay in a stable Power range and every final score is at most 100 | **TO VALIDATE** |

## Matrix and quality targets

| ID | Acceptance criterion | Current status |
| --- | --- | --- |
| M1B1-18 | At least 40 human-labelled normal, creative, ambiguous, extreme, unsafe and transport cases are recorded | **TO VALIDATE** |
| M1B1-19 | Final Schema pass rate is 100%; allow-list pass rate is 100%; Power pass rate is 100% | **TO VALIDATE** |
| M1B1-20 | Labelled normal attack-pattern and element accuracy is at least 90% | **TO VALIDATE** |
| M1B1-21 | Chinese and English normal concepts both succeed | **TO VALIDATE** |
| M1B1-22 | Each case records interpretation, final spec, repairs, fallback, latency and cost (`UNKNOWN` when unavailable) | **TO VALIDATE** |
| M1B1-23 | Real-provider median latency target is at most 5 s and P95 target is at most 10 s; failures are reported honestly | **TO VALIDATE** |

## Regression and delivery

| ID | Acceptance criterion | Current status |
| --- | --- | --- |
| M1B1-24 | All M1A compiler, five-attack, four-element and target-lab tests remain green | **TO VALIDATE** |
| M1B1-25 | 844×390, 852×393, 915×412, portrait gate, iOS keyboard and Safari-toolbar flows remain usable | **TO VALIDATE** |
| M1B1-26 | Godot parse, unit, worker, Web build, Chromium and WebKit regression pass without new application errors | **TO VALIDATE** |
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
