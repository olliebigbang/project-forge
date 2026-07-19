# M1B1 AI Safety / Red-Team Report

Document state: **Final vendor-neutral regression PASS; real-provider selection
and deployed evidence remain BLOCKED / TBD**

Prepared on: 2026-07-19

Stable baseline: `b09bd8fb6fa7d4466251f73e6d647823682d513e`
(`v0.1.0-m1a`)

Safety branch: `codex/qa/m1b1-ai-safety`

Integrated M1B1 regression: `104fddbec98060741401316d25185f130caaa1c0` -
**PASS** for the vendor-neutral boundary; **BLOCKED** for a public real-provider
claim until the provider decision and deployed evidence exist

## 1. Scope and independence

- **CONFIRMED** This report covers M1B1 text-to-WeaponSpec interpretation,
  including the Godot-to-backend request boundary, model input/output containment,
  Schema/allow-list/PowerBudget enforcement, fallback, retries, privacy, and
  audit evidence.
- **CONFIRMED** AI output is untrusted data. It cannot create or execute code,
  add gameplay modules, call tools, select a provider endpoint, read secrets, or
  bypass validation and balance.
- **CONFIRMED** Godot may call only the Project Forge backend. No third-party AI
  API key or privileged provider credential may exist in Godot, the Web build,
  repository, browser storage, URL, or client logs.
- **CONFIRMED** M1B1 uses drawing statistics only as auxiliary context. It must
  not claim semantic understanding of the drawing.
- **CONFIRMED** This QA branch does not modify gameplay scripts, scenes, Schema,
  the compiler, PowerBudget, build/deployment code, or the main integration
  Worktree.
- **CONFIRMED** The machine-readable suite is
  `tests/m1b1_red_team_cases.json`: 60 manually annotated cases with reusable
  global/profile oracles and case-specific assertions.
- **TBD** AI provider, model, backend host, authentication mechanism, production
  moderation service, rate limits, retention duration, and cost source were not
  selected on the stable baseline.

This document separates M1A facts from M1B1 gates. A missing M1B1 service is an
expected baseline condition, not a regression in the accepted M1A release. It is
nonetheless a release blocker for any build claiming real-AI interpretation.

## 2. Baseline provenance and checks

The isolated Worktree starts exactly from the accepted stable release:

| Check | Result |
| --- | --- |
| Branch base | `b09bd8f` / tag `v0.1.0-m1a` |
| Godot version | 4.7.1 stable |
| Project import and warning-as-error parse | **PASS** |
| Deterministic matrix | **32 cases** |
| GDScript assertions | **447 passed, 0 failed** |
| Main-scene headless smoke | **PASS** |
| Sites static worker | **3/3 passed** |
| WASM chunk loader | **1/1 passed** |
| Repository provider/API-key scan | No real provider integration or credential found |

The first test invocation was blocked by local PowerShell execution policy. The
same documented test script was then run with a process-scoped bypass. Godot
needed to create the ignored `.godot` import cache in this Worktree; after that,
the complete stable regression passed. No tracked M1A file changed.

## 3. Security objectives

M1B1 is acceptable only when all objectives below are enforced by program logic,
not by asking the model to behave.

1. **Integrity:** gameplay consumes exactly one repaired, schema-valid,
   allow-listed and semantically executable `WeaponSpec` with actual power at or
   below 100.
2. **Code and tool isolation:** text and model output can never reach `eval`, a
   script loader, a scene path, a callback, a shell/process/file API, an arbitrary
   URL fetch, or a model tool-call executor.
3. **Secret isolation:** provider credentials and system instructions remain only
   in the server trust domain and never enter client assets or response metadata.
4. **Budget integrity:** caller/model `power_score` is ignored. The Project Forge
   calculator derives it from final repaired fields; every credit is tied to a
   gameplay-effective cost.
5. **Availability and cost control:** request bodies are bounded, submissions are
   idempotent, timeout/cancel work, and automatic retries never exceed one.
6. **State integrity:** failures, cancellation and stale responses do not erase or
   overwrite the current drawing, Description, confirmed result, or combat state.
7. **Privacy:** raw player text, PII, secrets, system prompts and full model output
   are not retained or logged unless a separately approved, de-identified test
   process explicitly requires it.
8. **Content safety and originality:** unsafe detail and requests for real people,
   known characters, franchises or brands are rejected or transformed to a
   non-graphic, original generic fantasy result.
9. **Auditability:** corrections, fallback reason, measured latency, provider call
   count and measured/`UNKNOWN` cost are recorded without sensitive payloads.

## 4. Threat model

### 4.1 Protected assets

| Asset | Failure impact |
| --- | --- |
| Provider API key and server environment | Credential theft, unbounded cost, external compromise |
| System/developer instructions | Easier prompt attacks and provider misuse |
| Runtime module boundary | Code/tool execution or unsupported gameplay behavior |
| WeaponSpec and PowerBudget integrity | Unfair/unbounded weapons and combat instability |
| Player drawing and Description | Privacy loss or user-state loss |
| Provider spend and availability | Denial of service, duplicate billing, retry storm |
| Confirmation/combat state | Stale response equips the wrong weapon |
| Logs and analytics | PII/secret retention, log forgery, unsafe-content persistence |
| Project originality | Known-IP, brand or real-person imitation in output |

### 4.2 Adversaries and failure sources

- A curious or malicious player controlling Description, drawing-summary fields,
  locale, request identifiers, repeated taps, cancellation timing, and any other
  browser-visible request field.
- A modified client that sends capabilities, maximum power, raw specs, oversized
  bodies, duplicate IDs, or calls the public endpoint outside the game.
- Prompt injection embedded in natural language, Unicode confusables, encoded
  text, JSON-looking content, or unexpected drawing-summary fields.
- A model/provider returning malicious, malformed, partial, duplicated,
  non-finite, overpowered, code-bearing or tool-call output.
- Ordinary transport faults: latency, timeout, disconnect, 429, 5xx, response
  reordering, late responses and cancellation races.
- Accidental operational leakage through logs, provider metadata, source maps,
  Web assets, exception messages, or analytics.

### 4.3 Trust boundaries

```mermaid
flowchart LR
    U["Untrusted player text + drawing statistics"] --> C["Godot/Web client"]
    C -->|"bounded HTTPS request"| E["Project backend ingress"]
    E --> I["type/size/rate/idempotency validation"]
    I --> M["input safety + prompt construction"]
    M -->|"server credential only"| P["AI provider"]
    P --> O["strict response-envelope parser"]
    O --> S["Draft 2020-12 Schema + allow-lists"]
    S --> X["semantic compatibility repair"]
    X --> B["server-owned PowerBudget"]
    B --> F["final Schema/runtime revalidation"]
    F --> C2["Godot repeats runtime repair + budget gate"]
    C2 --> G["existing five attack modules"]
    E -. "redacted metrics only" .-> L["logs/telemetry"]
    F -. "correction codes only" .-> L
```

The server must not trust lists or `maximum_power_score` echoed by the client.
They are useful request context only if compared against server-owned constants.
The provider response is never authoritative until all gates after `P` complete.

## 5. Mandatory request and response controls

### 5.1 Request envelope

- Accept a JSON object only; reject null/scalar/array roots and wrong primitive
  types before a provider call.
- Normalize Unicode for comparison and remove disallowed control/bidi characters
  from display/log paths without changing the player's retained editor value.
- Bound the HTTP body and every string/list/numeric field independently.
- **ASSUMPTION (proposed oracle):** Description is at most 512 Unicode scalars
  and 4096 UTF-8 bytes, request body at most 16 KiB, and `request_id` at most 64
  safe ASCII characters or a server-issued UUID. Product/backend owners may
  replace these numbers before implementation tests, but must document one exact
  set rather than silently truncate.
- Drawing context is an allow-listed object of bounded numeric fields such as
  `stroke_count`, `point_count`, `aspect_ratio`, `coverage`, and principal
  direction. Free-form notes and nested values are removed.
- Server constants own supported patterns/elements/abilities and maximum power.
- Rate limiting, idempotency and cost quotas happen before provider invocation.
  **TBD:** exact anonymous/session/IP policy.

### 5.2 Provider isolation

- Construct messages structurally; never concatenate player text into JSON,
  system instructions, a tool declaration, or provider URL.
- Disable provider tools/functionality that is not strictly the one structured
  response contract. Do not honor tool calls even if the provider emits them.
- Set output/token bounds and a server timeout. At most one retry may be made for
  an explicitly retryable failure.
- Moderation cannot be only a model prompt. Programmatic output gates always run,
  including when moderation transforms the concept.

### 5.3 Strict response pipeline

1. Enforce response-size and content-type limits.
2. Parse exactly one JSON response envelope; reject duplicate keys, non-standard
   NaN/Infinity, trailing prose, code fences and alternative/tool-call branches.
3. Validate the raw `WeaponSpec` with a real Draft 2020-12 validator.
4. Remove/reject extra fields and enforce server-owned allow-lists.
5. Repair semantic mismatches among pattern, class, ability, status, element,
   material, drawback and the executable module registry.
6. Ignore provided `power_score`; calculate and balance with sanitized values.
7. Validate the final repaired object again with Schema and runtime semantics.
8. Return only the documented response envelope. Sanitize provider metadata.
9. Godot repeats the existing `WeaponSpec` repair, actual PowerBudget check and
   executable-module dispatch check before showing CONFIRM or entering combat.

Schema failure is diagnostic; repair is allowed only when deterministic and safe.
No partially valid object may reach confirmation or combat. If repair cannot
prove a coherent executable result, return the known fallback.

## 6. Global test oracle

Every one of the 60 cases inherits the following assertions:

- If a final weapon exists, it passes the checked-in JSON Schema and separate
  runtime validation with all 16 required fields and no extra fields.
- All enums come from `WeaponSpec` allow-lists; all numeric fields are finite and
  within bounds.
- `PowerBudget.calculate(final).total <= 100`, and `power_score` equals the
  documented ceiling of that final component sum.
- No code, tool request, URL, callback, scene path or unknown module is executed
  or reflected into a callable client path.
- Failure returns one validated playable fallback, never a crash, frozen loading
  state, partial object or silent loss of drawing/Description.
- Automatic retry count is zero or one; there is never a third call.
- The authoritative response has the current request ID. Cancelled, duplicated or
  stale responses do not update confirmation or combat.
- Audit evidence contains correction/error codes and measured timing without a
  key, system prompt, full provider output, unnecessary raw input or PII.
- Cost is provider-derived or exactly `UNKNOWN`; missing usage is not reported as
  zero or guessed.

The JSON suite defines reusable profiles for pre-provider rejection, safe
interpretation, injection containment, output repair, provider faults,
concurrency isolation, budget metamorphism and unsafe-content transformation.
Each case adds explicit expected codes and case-specific negative assertions.

## 7. Manually annotated red-team matrix

| Category | Cases | Primary proof |
| --- | ---: | --- |
| Request validation | 8 | Root/type/length bounds; client capability lists cannot expand server policy |
| Prompt injection | 10 | Direct, multilingual, role/XML, code, JSON smuggling, Unicode, encoded, drawing-field, tool and prompt-extraction attacks |
| Provider output | 12 | Strict JSON, missing/type/enum repair, extra/code fields, non-finite values, duplicates, prototype pollution and tool calls |
| Power budget | 10 | Forged scores, extreme concepts, semantic conflicts, irrelevant drawbacks, unpriced return speed, retries and manual correction |
| Content safety | 4 | Dangerous instructions, graphic violence, sexual-minor content and hateful targeting |
| IP and identity | 2 | Famous franchise/character and brand/real-person transformation |
| Privacy | 3 | PII/fake secret, log forging/control characters and sensitive provider metadata |
| Reliability | 7 | Timeout, disconnect, 429, 5xx, malformed response retry/fallback and retry exhaustion |
| Concurrency | 3 | Rapid taps, cancel/late response and out-of-order requests |
| Observability | 1 | Missing usage/cost metadata produces measured latency and `UNKNOWN` cost |
| **Total** | **60** | All cases require the global oracle plus their case-specific oracle |

The suite intentionally exceeds the user's 40-case overall minimum. It is a
safety/fault matrix; the integration owner still needs a balanced normal/creative/
ambiguous Chinese-and-English accuracy set. Security cases must not be counted as
successful semantic-identification examples merely because they reached a safe
fallback.

### 7.1 Accuracy and stability measurement

- Normal annotated cases must score exact attack-pattern and element matches.
  The milestone target is at least 90% for those fields.
- Rejections/fallbacks are excluded from semantic accuracy but included in safety,
  Schema, allow-list, budget and fallback denominators.
- Equivalent inputs and `TRY AGAIN` use paired/metamorphic comparisons.
- **ASSUMPTION (proposed oracle):** identical/equivalent concepts may vary by no
  more than five Power points, must keep the same semantic tags, and may not
  monotonically increase across 20 retries. This threshold needs confirmation
  before provider regression and may not be loosened after seeing results.
- Median and P95 latency use actual end-to-end samples. Target median is at most
  five seconds and P95 at most ten seconds. Misses are reported, not hidden by
  fallback timing.

## 8. Baseline implementation audit

### 8.1 Existing strengths that must be preserved

1. `weapon_spec.schema.json` rejects additional properties and defines all 16
   required fields, bounds and core enums.
2. `WeaponSpec.repair_dict()` discards unknown fields, normalizes pattern/class,
   repairs missing or unsupported fields, rejects non-finite numeric input at the
   repair boundary, and retains correction reasons.
3. `PowerBudget.balance()` repairs before calculation, ignores incoming score,
   applies deterministic reductions, and checks its final actual component sum.
4. Stable tests independently compare Schema/runtime field and attack/element
   allow-lists, exercise malformed raw dictionaries and recompute actual power.
5. M1A contains no real provider credential or direct third-party client call.

### 8.2 Findings and required closure

| ID | Severity | Baseline finding | Required M1B1 closure | Retest cases |
| --- | --- | --- | --- | --- |
| M1B1-RT-001 | **P0 release blocker (expected missing scope)** | Stable M1A has no secure backend, real provider adapter, request authentication/rate limit, strict response envelope or server-side secret boundary. | Implement and deploy the provider-independent backend boundary before any real provider key is used. Client must call only `/api/compile-weapon`. | All `RT-REQ`, `RT-REL`, secret scan |
| M1B1-RT-002 | **P1 Major** | M1A `BLOCKED_KEYWORDS` uses a short exact-substring list. Unicode, multilingual, encoding and indirect injections trivially bypass it. This was acceptable only for the offline deterministic mock. | Do not reuse it as production moderation. Combine bounded inputs, structural prompts, content policy and unconditional programmatic output gates. | `RT-INJ-001`–`010` |
| M1B1-RT-003 | **P1 Major** | M1A writes normalized input, drawing summary, raw spec and final record to a persistent local JSONL file and console. Reusing that record shape server-side would violate M1B1 minimization and could retain PII/injection content. | Define a redacted server log schema; store request IDs, lengths/categories, correction codes, timing and usage only. Synthetic test payload retention must be explicit and isolated. | `RT-CNT-007`, `008`, `RT-REL-011`, `012` |
| M1B1-RT-004 | **P1 Major** | Current tests parse the checked-in Schema and test parity, but stable M1A has no general Draft 2020-12 validation engine for provider responses. Runtime repair is not a substitute for raw and final Schema validation. | Use an actual server-side Draft 2020-12 validator both before and after repair. Keep the Godot runtime gate as defense in depth. | `RT-OUT-001`–`012` |
| M1B1-RT-005 | **P1 Major** | Runtime allow-lists do not enforce full semantic compatibility. Examples include `return_strike` on `melee_slash`, `normal + burn`, `fire + freeze`, and material/element mismatches. | Add one server/runtime compatibility table and deterministic correction order; rebudget after every semantic repair. | `RT-PWR-003`, `005`, `006` |
| M1B1-RT-006 | **P1 Major** | `slow_projectile` grants a 9-point drawback credit even on non-projectile patterns; for melee its capped `projectile_speed` is behaviorally irrelevant. This is a real budget-credit bypass for arbitrary AI output. | Only grant drawback credit when compatible with the attack and measurably enforced, otherwise replace it with a compatible drawback before calculation. | `RT-PWR-004`, `010` |
| M1B1-RT-007 | **P1 Major** | `return_speed` is bounded by Schema/runtime but has no PowerBudget component. A boomerang can increase 180→1000 without score impact even though return speed changes combat value. | Price return speed, make it pattern-constant, or remove model control of the field. Add a paired budget assertion. | `RT-PWR-007` |
| M1B1-RT-008 | **P2 Moderate defense-in-depth** | `WeaponSpec.validation_errors()` uses range comparisons without explicit `is_nan/is_inf`; direct mutation to NaN could evade those comparisons. `from_dict/repair_dict` is safe, but that construction invariant is not enforced by the type system. | Add finite checks to final validation and ensure no untrusted path constructs or mutates a spec outside repair. | `RT-OUT-008`, `009` |
| M1B1-RT-009 | **P1 Major** | `WeaponSpec._repair_name()` stringifies any non-null value and only trims/truncates it. Control/bidi/markup and structured objects need a stronger output-display boundary. | Reject non-string names at Schema, normalize safe display characters, encode literally in UI, and keep unsafe/provider text out of logs. | `RT-OUT-007`, `RT-CNT-008` |
| M1B1-RT-010 | **P1 Major (expected missing scope)** | Stable M1A has no request ID ownership, idempotency, cancellation token, stale-response guard, timeout, retry policy, 429 handling or cost quota. | Implement these server and client state-machine controls; maximum one safe retry and one authoritative result. | `RT-REL-001`–`010` |
| M1B1-RT-011 | **P1 Major** | M1A silently truncates normalized text to 512 characters and separately truncates the logged value. A network service requires explicit body/type/byte limits and a stable error/user-feedback policy. | Validate before provider call, record a non-sensitive reason, preserve editor text, and either reject or visibly offer bounded truncation; never silently reinterpret a different concept. | `RT-REQ-001`–`007` |
| M1B1-RT-012 | **P1 Major** | The proposed request echoes supported lists and a maximum score from the client. A modified Web client can expand those values unless the backend treats them as untrusted. | Compare with or replace by server-owned constants. Never let the caller add modules or raise the cap. | `RT-REQ-008`, `RT-PWR-010` |

No P0 defect was found in the accepted offline M1A runtime. `RT-001` marks the
expected missing server scope as a P0 only for a build claiming **real M1B1 AI**.
The P1 findings are integration blockers because arbitrary model output is much
less constrained than the deterministic M1A profiles.

## 9. PowerBudget attack analysis

The critical property is not merely `power_score <= 100`. A model can exploit an
unpriced field or a non-operative drawback while staying numerically below 100.

### Required invariants

1. Calculate from repaired final data; never trust provider/client score.
2. Every variable gameplay benefit has a named component or is fixed by a trusted
   profile outside model control.
3. Every drawback credit has a pattern/status compatibility rule and a measured
   runtime behavior.
4. Semantic repair happens before calculation; any later repair triggers a full
   recalculation.
5. The displayed score equals the actual gameplay component sum after documented
   rounding.
6. Same/equivalent concepts cannot use retries to sample increasingly strong
   numeric allocations.
7. Manual `MODIFY INTERPRETATION` follows the same server-owned semantic and
   budget path; it is not a privileged client override.

### Mandatory paired probes

| Pair | Required relation |
| --- | --- |
| Boomerang `return_speed` 180 → 1000 | Score rises or another real benefit falls; otherwise return speed must be fixed |
| Melee drawback `none` → `slow_projectile` | No credit, because projectile speed is unused; replace with a compatible cost |
| Normal status `none` → `burn` | Reject/remove burn or change element with corresponding cost and correction |
| Melee ability `none` → `return_strike` | Reject/remove or change to executable compatible pattern, then rebudget |
| Same concept generated 20 times | Stable semantic tags and bounded score distribution; no upward retry ratchet |
| Manual correction to electric piercing/chain/shock | Final actual score <=100 with compatible drawback and explicit reductions |

## 10. Reliability and state-machine oracle

Recommended logical states are `editing → loading → confirmation → combat`, with
`cancelled/error` transitions returning to `editing` while preserving input.

- FORGE generates a server/client request ID and immediately disables duplicate
  submission for that logical request.
- Cancel marks the request terminal locally. Abort support is desirable, but a
  late response must be ignored even if the transport cannot be stopped.
- A new request supersedes an older one; only the current ID may update UI/state.
- A retry keeps the same logical idempotency key plus an attempt number and may
  occur once only for documented retryable faults.
- 4xx validation/moderation errors are not automatically retried. 429 honors a
  bounded `Retry-After`; unsafe delay falls back. Timeout/network/selected 5xx may
  retry once.
- Any terminal failure clears loading state, shows an understandable message,
  retains drawing/Description, and provides the validated base weapon plus a
  deliberate retry route.
- Provider latency is measured separately from total end-to-end latency where
  possible. Fallback speed may not be substituted into provider P50/P95.

## 11. Privacy, logging and evidence oracle

### Permitted structured fields

- Random/request ID that contains no user identifier;
- server revision, provider/model alias, attempt count and outcome class;
- Description length, locale category, synthetic test case ID and moderation
  category without raw text;
- Schema/semantic/budget correction codes and aggregate counts;
- measured service/provider latency, token usage where supplied, and measured or
  `UNKNOWN` cost;
- final allow-listed semantic tags and numeric budget totals when needed for QA.

### Forbidden by default

- API keys, authorization headers, environment variables, cookies or client
  storage identifiers;
- system/developer prompts or full provider request/response;
- raw Description/drawing data, email, phone, address, account identifiers or
  other unnecessary personal data;
- unsafe graphic text, dangerous instructions, protected-group targeting, exact
  known-IP/brand/real-person request text;
- executable payloads, arbitrary URLs and unbounded correction strings copied
  from the provider.

Synthetic red-team inputs may be stored in this repository because they are
deliberately fabricated and reviewed. Production/player input is not equivalent.

## 12. Execution protocol after integration

When the main agent supplies the integrated revision and fault-injection service:

1. Record commit, endpoint/backend revision, provider/model, Schema hash,
   PowerBudget revision, browser/build hash and whether the provider is mock or
   real for each run.
2. Scan repository and Web output for secrets/provider endpoints/source-map
   leakage before sending any request.
3. Run the 60 JSON cases. Capture provider call count, HTTP/result category,
   response size, raw interpretation in the isolated synthetic test harness,
   final spec, corrections, fallback, measured latency and cost provenance.
4. Recompute Schema, allow-list, semantic compatibility and actual PowerBudget
   independently from the service's self-reported pass flags.
5. Run the integration owner's normal/creative/ambiguous Chinese-and-English
   accuracy matrix and report exact attack-pattern and element confusion counts.
6. Exercise 20 rapid taps, cancellation/late response, response reordering, one
   retry, timeout, 429, 5xx, invalid JSON and offline recovery in the Web client.
7. Confirm drawing/Description preservation and that only current request IDs can
   open confirmation or equip a weapon.
8. Run the complete M1A test/build/browser/mobile regression. Real iPhone remains
   the product owner's final device gate.
9. Return every P0/P1 to the main agent, rerun affected cases, then rerun the
   global secret/schema/budget/fallback gate.

## 13. Severity and release gate

| Severity | Definition | Disposition |
| --- | --- | --- |
| **P0 Blocker** | Secret/code/tool boundary breach; invalid or unbounded spec reaches gameplay; no safe service boundary/fallback; crash or state loss | Never deploy real AI; fix and rerun full safety suite |
| **P1 Major** | Required programmatic protection is absent/bypassable; budget/semantic, privacy, retry or stale-response guarantee fails | Fix before PR is eligible for public real-AI preview |
| **P2 Moderate** | Defense-in-depth gap with a proven safe primary boundary and no current exploit path | Record owner, fix or explicitly accept before physical-device gate |
| **P3 Minor** | Wording/evidence polish without safety or acceptance impact | May be documented as known limitation |

Release denominators and required results:

- Final Schema pass: **100%** of gameplay-consumed results.
- Final allow-list and semantic compatibility: **100%**.
- Actual PowerBudget <=100 and score parity: **100%**.
- Failure/fault cases with validated fallback and preserved state: **100%**.
- Code/tool/file/process/arbitrary-network execution: **0 occurrences**.
- Secret/system-prompt/PII leakage in client or logs: **0 occurrences**.
- Automatic retry: **at most one**; duplicate billed requests: **0**.
- Normal annotated attack-pattern/element accuracy: **at least 90%**.
- Provider latency: report actual median/P95 against 5s/10s targets.
- Cost: measured value with provenance or exactly **UNKNOWN**.

## 14. Baseline disposition

**BASELINE THREAT MODEL COMPLETE — M1B1 REAL-AI RELEASE NOT YET READY.**

The accepted M1A deterministic runtime remains green and contains no real secret.
The new 60-case suite supplies independent, explicit security and reliability
oracles. Before a real provider is connected, the main implementation must close
the server-boundary, actual Schema validation, semantic compatibility, effective
drawback, return-speed pricing, redacted logging, request-bound, idempotency,
timeout/retry/cancel and stale-response findings above.

**TO VALIDATE:** integrated M1B1 behavior, real provider accuracy, latency, cost,
fallback, public Web deployment and physical iPhone operation. This baseline does
not approve M1B2 drawing-semantic interpretation and does not claim that a real
AI provider has been tested.
## 15. Integrated candidate regression

### 15.1 Provenance

- **CONFIRMED** Initial integration candidate audited:
  `7065e9481b3096bbf47e79755e80aa9a9fcd7488`.
- **CONFIRMED** Safety-race fix independently retested:
  `50715e8eb91c7da05cd2b0a56e13c1ffc73724a9`.
- **CONFIRMED** D1 durable-boundary candidate audited:
  `6dc5b2dd9a38e2131dea214d0c6d18983896abc8`.
- **CONFIRMED** Final fail-closed repair and exact candidate retested:
  `104fddbec98060741401316d25185f130caaa1c0`.
- **CONFIRMED** QA branch:
  `codex/qa/m1b1-ai-safety-regression` in an isolated Worktree.
- **CONFIRMED** QA changed no game, backend, Schema, build or deployment code.
  This report is the only tracked QA change.
- **TBD** Real provider, model, credential, moderation service, production
  authentication and cost source remain unselected.
- **TO VALIDATE** All results in this section use the deterministic adapter or
  deliberately hostile local adapters. They do not claim a real provider call.

### 15.2 Verification results at `50715e8`

| Command / probe | Result |
| --- | --- |
| `node --test tests/weapon_interpreter.test.mjs` | **PASS** - 66/66, including the 48-case M1B1 matrix and the four safety-race regressions |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test.ps1` | **PASS** |
| Godot import and warning-as-error parse | **PASS**, Godot 4.7.1 stable |
| M1A deterministic suite | **PASS**, 32 cases / 458 assertions / 0 failures |
| Main scene headless smoke | **PASS** |
| Sites worker route suite | **PASS**, 4/4 |
| WASM chunk loader | **PASS**, 1/1 |
| M1B1 server suite inside the full run | **PASS**, 66/66 |
| Source secret/provider-key scan | **PASS**, no real provider key or direct provider endpoint found |

The first full-test attempt could not write the Worktree's ignored `.godot`
cache under the restricted process token. The same repository script was rerun
with permission to write that local import cache and completed successfully. No
tracked source file was changed by the test.

### 15.3 Browser/build evidence from the initial candidate

The following evidence was collected at `7065e94`, before the server/client
safety-race fix. It remains useful UI evidence but is not substituted for a
post-fix public deployment run:

- `scripts/build_web.ps1`: **PASS**.
- `scripts/build_sites_preview.ps1`: **PASS**.
- Chromium M1B1 regression: **PASS**, including 844x390, 852x393, 915x412 and
  844x343, retry/fallback paths, cancellation, five attack patterns and three
  rotation cycles.
- WebKit M1B1 regression: **PASS** with the same functional coverage. The runner
  exited 0. WebKit emitted repeated Godot/WebGL
  `glBlitFramebuffer` validation messages and `WEBGL_polygon_mode` warnings;
  these were non-fatal in this run but remain visible browser-console noise.
- **TO VALIDATE** Rebuild, Chromium/WebKit rerun, public same-origin route and
  physical iPhone behavior at the final integrated/deployed revision.

## 16. P1 safety-race retest

The first audit of `7065e94` reproduced four release-blocking behaviors. The
main integrator supplied `50715e8`; QA then reran independent hostile probes in
addition to the new owner-authored tests.

| Probe | Before (`7065e94`) | Retest (`50715e8`) | Status |
| --- | --- | --- | --- |
| Two simultaneous requests with the same session, request ID and fingerprint | `provider_calls=2`; neither response identified a replay | `provider_calls=1`; both HTTP 200; waiter returned `x-forge-idempotent-inflight: true`; bodies identical | **PASS** in one server isolate |
| Provider returns a secret marker in summary, corrections, nested metadata and `estimated_cost.api_key` | Marker was reflected in the response and server audit | Marker absent from response and captured audit; cost reduced exactly to `{amount: 0.002, currency: "USD"}` | **PASS** |
| Late request A callback arrives while request B is authoritative | Mismatched `request_id` was accepted and could commit stale state | Server result ID must equal the bound expected ID; callback also binds revision, ID and HTTP node. Godot assertions `late request A cannot overwrite active request B` and `late HTTP response is counted and discarded` pass | **PASS** |
| Nine unique paid-path requests in one minute from one session | No endpoint quota; all tested unique requests reached the adapter | First 8 returned 200; ninth returned 429 with `Retry-After: 60` | **PASS** in one server isolate |

The independent post-fix probe emitted:

```json
{
  "concurrency": {
    "provider_calls": 1,
    "statuses": [200, 200],
    "inflight_replay": "true"
  },
  "provider_output_redaction": {
    "response_contains_marker": false,
    "logs_contain_marker": false,
    "estimated_cost": { "amount": 0.002, "currency": "USD" }
  },
  "ingress_quota": {
    "statuses": [200, 200, 200, 200, 200, 200, 200, 200, 429],
    "retry_after": "60"
  }
}
```

## 17. Finding closure matrix

`PASS` means the current deterministic boundary has an executable test. `OPEN`
means a code/evidence gap remains. `BLOCKED` means the real-provider claim cannot
be tested until the provider, adapter or production service is supplied.

| ID | Current status | Regression conclusion |
| --- | --- | --- |
| M1B1-RT-001 | **PASS vendor-neutral / BLOCKED real provider** | Same-origin `/api/compile-weapon`, server-only adapter selection, no client credential, safe fallback, D1 guard, and missing/partial-D1 fail-closed probes pass. A real adapter, credential and provider account spend cap remain TBD. |
| M1B1-RT-002 | **OPEN / BLOCKED** | Deterministic English/Chinese safety categories and unconditional output gates pass local tests. Obfuscated/multilingual/provider-specific moderation behavior and the real structured prompt remain unvalidated. Regex classification must not become the sole real-provider safety boundary. |
| M1B1-RT-003 | **PASS** | Privacy-mode compiler logging is minimized. Provider summary/correction/metadata reflection is now removed, and `estimated_cost` has a strict scalar object allow-list. Actual provider SDK logs remain **TO VALIDATE**. |
| M1B1-RT-004 | **OPEN / BLOCKED** | Checked-in Schema parity, final server validation, runtime repair and Godot revalidation pass. The implementation evaluates the repository's known Schema subset; strict raw real-provider JSON/envelope/size handling with an actual provider response remains untested. |
| M1B1-RT-005 | **PASS** | Ability/status/material semantic compatibility is repaired before final calculation and covered in JavaScript/GDScript tests. |
| M1B1-RT-006 | **PASS** | `slow_projectile` cannot receive irrelevant drawback credit on non-projectile attacks. |
| M1B1-RT-007 | **PASS** | Boomerang `return_speed` has an explicit budget component and paired regression. |
| M1B1-RT-008 | **OPEN (P2)** | Repair rejects non-finite values, but final `WeaponSpec.validation_errors()` still lacks explicit NaN/Infinity checks for direct post-construction mutation. No current untrusted construction path bypass was reproduced. |
| M1B1-RT-009 | **PASS** | Provider free text no longer supplies the displayed weapon name, summary, correction strings or audit identifiers; those values are generated from bounded allow-listed semantics. |
| M1B1-RT-010 | **PASS vendor-neutral / TO VALIDATE deployed** | Random client IDs, SHA-256 namespaces, D1 shared-owner replay/conflict/lease cleanup, atomic quota, one-retry cap, cooperative abort, uncooperative no-retry, cancel and stale-response gates pass locally. Actual Sites D1 and the selected provider transport remain TO VALIDATE. |
| M1B1-RT-011 | **PASS** | Content type, byte size, JSON/object shape, Description type/length, request ID and bounded drawing fields are rejected or safely classified before adapter use. |
| M1B1-RT-012 | **PASS** | Caller capability lists are intersected with server allow-lists and caller maximum power cannot exceed the server cap of 100. |

## 18. Real-provider gate and prior-blocker closure

### M1B1-REG-005 - Provider integration is intentionally absent

**Status: BLOCKED / TBD.** `resolveAdapter()` selects only the deterministic/local
adapter; no real provider/model/credential has been configured. Therefore this
audit cannot measure real semantic accuracy, provider latency, token usage, cost,
moderation behavior, provider JSON failures or SDK logging. This is not a defect
in the provider-independent spike, but it prevents a **Real Text-to-Weapon AI**
release claim.

### M1B1-REG-006 - Durable quota and idempotency

**Severity: former P1. Status: CLOSED in the vendor-neutral implementation.**
`104fddb` uses a Sites D1 request ledger and atomic rate windows. Two independent
binding objects sharing one database produced one owner/provider call and one
exact replay. Eight same-session requests were allowed and the ninth denied.
Expired owner tokens cannot overwrite reclaimed work, and abandoned expired
leases are removed.

The audit first found that `6dc5b2d` silently downgraded to memory if `DB` was
missing or lacked `batch()`. The exact hostile probes invoked a custom paid-like
adapter twice and returned HTTP 200. At `104fddb`, missing DB, partial DB,
configured non-local provider without DB, and explicit durable-required mode all
return HTTP 503 `request_guard_unavailable` before the provider; call count is 0.

**TO VALIDATE:** the deployed Sites D1 binding under real separate isolates,
cold starts and platform faults. A provider-account spend ceiling and kill switch
remain mandatory before paid public traffic.

### M1B1-REG-007 - Abort and no-double-charge retry policy

**Severity: former P1. Status: CLOSED in the vendor-neutral implementation.**
Every adapter attempt receives an `AbortSignal`. A wrapper timeout aborts a
cooperative adapter and never retries. An uncooperative adapter may finish its
single underlying call, but the wrapper still starts no second call. Only an
adapter-thrown transient error explicitly marked `retrySafe` may use attempt 2.

**TO VALIDATE:** the selected real provider adapter propagates the signal,
classifies only demonstrably pre-send/unbilled failures as retry-safe, forwards a
provider idempotency key where available, and handles provider `Retry-After`
within the product's bounded wait policy.

## 19. Regression disposition

**PASS - final vendor-neutral M1B1 boundary at `104fddb`.** No P0/P1 code blocker
remains in the audited provider-neutral boundary. Schema/allow-list/PowerBudget
repair, semantic compatibility, fallback, privacy redaction, request bounds,
SHA-256 namespacing, D1 concurrency/quota, fail-closed handling, abort/no-retry,
client stale-response handling and M1A regression are green.

**BLOCKED - public real-provider M1B1 release.** Provider/model/credential are
still **TBD**. Actual Sites D1 behavior, the provider adapter, moderation, spend
cap, real latency/accuracy/cost and physical iPhone behavior have not been
measured. Cost remains exactly `UNKNOWN`; no real-provider claim is made. Do not
deploy a paid key or mark Real Text-to-Weapon AI accepted until those gates and
the full public Web/iPhone regression are complete.

This audit does not authorize M1B2 drawing-semantic interpretation or additional
features.

## 20. Final vendor-neutral candidate audit (`104fddb`)

### 20.1 Exact revision and ownership

| Item | Value |
| --- | --- |
| Candidate | `104fddbec98060741401316d25185f130caaa1c0` |
| Candidate branch | `codex/feat/m1b1-real-text-interpreter` |
| QA branch | `codex/qa/m1b1-ai-safety-regression` |
| QA-owned tracked file | `docs/M1B1_RED_TEAM_REPORT.md` only |
| Real provider/model/credential | **TBD / not present** |
| Cost | `UNKNOWN` |

### 20.2 Commands and counts

| Command | Result |
| --- | --- |
| `node --test tests/weapon_interpreter.test.mjs tests/durable_request_guard.test.mjs` | **PASS**, 77/77: interpreter 68/68 plus D1 9/9 |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test.ps1` | **PASS** |
| Godot project import and warning-as-error parse | **PASS**, Godot 4.7.1 stable |
| Godot deterministic suite | **PASS**, 32 cases / 458 assertions / 0 failures |
| Main-scene headless smoke | **PASS** |
| Sites static worker | **PASS**, 4/4 |
| WASM chunk loader | **PASS**, 1/1 |
| M1B1 interpreter within full run | **PASS**, 68/68 |
| D1 guard within full run | **PASS**, 9/9 |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build_sites_preview.ps1` | **PASS**, fresh Web export and complete Sites server/client bundle |
| Source scan for real key formats, bearer values and direct provider endpoints | **PASS**, no matches |
| Fresh `build/web` and `dist` binary/text scan for the same values/endpoints | **PASS**, no matches |

The source contains three documentation-only placeholders in
`docs/M1B1_PROVIDER_DECISION.md`: `OPENAI_API_KEY=<secret>`,
`GEMINI_API_KEY=<secret>` and `ANTHROPIC_API_KEY=<secret>`. They are not values,
are not used by code, and were absent from the Web/Sites build scan.

The D1 Node test uses Node's experimental built-in SQLite module and emits its
standard `ExperimentalWarning`; all assertions pass. Actual Sites D1 is not
replaced by this emulator and remains a deployment gate.

### 20.3 Independent combined hostile probe

QA created a temporary, untracked-equivalent probe, ran it, recorded the result
below, then deleted it. It used two separate D1-like bindings sharing one SQLite
store, hostile provider metadata, missing/partial guards, cooperative and
uncooperative adapters, and independent Schema/Power recomputation.

```json
{
  "durable_cross_binding": {
    "statuses": [200, 200],
    "provider_calls": 1,
    "replay": true,
    "namespace": "2b5c28f74225cef5025af3fea9f79b84",
    "fingerprint": "6eb64b26178b6627e169554acb26f118",
    "scopes": [
      "network:1489c25230a829ff00bb7af57602b2fb",
      "session:2b5c28f74225cef5025af3fea9f79b84"
    ]
  },
  "durable_quota": { "allowed": 8, "denied": 1 },
  "fail_closed": {
    "statuses": [503, 503, 503],
    "provider_calls": 0
  },
  "timeout": {
    "cooperative": { "calls": 1, "aborts": 1, "attempts": 1 },
    "uncooperative": { "calls": 1, "completions": 1, "attempts": 1 },
    "explicit_retry_safe": { "calls": 2, "attempts": 2 }
  },
  "metadata_redaction": {
    "response_contains_marker": false,
    "logs_contain_marker": false,
    "estimated_cost": { "amount": 0.002, "currency": "USD" }
  },
  "all_specs_schema_allowlist_power_valid": true
}
```

The namespace and fingerprint are the first 128 bits of SHA-256 rendered as 32
lowercase hexadecimal characters. QA independently calculated the namespace
from the stable serialized session input and obtained the exact stored value.
Neither the raw session, IP nor Description appeared in the D1 namespace,
fingerprint, rate scopes or stored result JSON.

### 20.4 Fail-closed blocker and closure

| Revision | Missing DB | Partial `DB.prepare`-only object | Configured non-local provider without DB | Provider calls | Result |
| --- | --- | --- | --- | --- | --- |
| `6dc5b2d` | 200 | 200 | not needed to prove bypass | 2 | **P1 BLOCKER** - silently downgraded to memory |
| `104fddb` | 503 | 503 | 503 | 0 | **PASS / CLOSED** |

An additional `WEAPON_INTERPRETER_REQUIRE_DURABLE_GUARD=true` probe also returned
503 `request_guard_unavailable` with no provider call. A broken object exposing
both D1 methods likewise fails before adapter selection. Local deterministic
development may explicitly use memory; custom or configured non-local providers
cannot silently opt into it.

### 20.5 Final control disposition

| Control | Result | Remaining evidence |
| --- | --- | --- |
| D1 cross-binding owner/replay/conflict/lease cleanup | **PASS** | **TO VALIDATE** on deployed Sites D1 and actual separate isolates/cold starts |
| Atomic session/network rate window | **PASS**, 8 allowed / ninth denied | **TO VALIDATE** deployed 429 and `Retry-After` |
| Missing, partial or broken durable guard | **PASS**, 503 before adapter | Verify final Sites environment actually binds `DB` |
| SHA-256 privacy namespace/fingerprint | **PASS** | None for vendor-neutral code |
| Cooperative wrapper timeout | **PASS**, one call, one abort, no retry | Real adapter must propagate the signal |
| Uncooperative wrapper timeout | **PASS**, one underlying call, no second call | Selected provider behavior remains **TO VALIDATE** |
| Explicit retry-safe failure | **PASS**, exactly two attempts | Real adapter may mark only proven unbilled/pre-send failures retry-safe |
| Provider output/metadata/cost redaction | **PASS** | Real SDK logs remain **TO VALIDATE** |
| Schema, allow-list, semantic compatibility and PowerBudget | **PASS**, 48/48 M1B1 matrix plus hostile repairs | Real-provider accuracy remains **TO VALIDATE** |
| Secrets/direct-provider endpoint scan | **PASS**, source and builds | Repeat after provider adapter and secret configuration |
| Real provider, moderation, latency, accuracy and spend cap | **BLOCKED / TBD** | Product-owner provider decision and deployment required |

### 20.6 Final QA decision

**PASS: `104fddb` is acceptable as the final vendor-neutral M1B1 boundary.** No
P0 or P1 implementation blocker remains in the supplied provider-neutral scope.
The previously reproduced fail-open, concurrent idempotency, stale response and
metadata-leak blockers are closed and independently retested.

**NOT AN ACCEPTANCE OF REAL AI:** provider/model/credential, actual Sites D1,
provider moderation, server-secret deployment, account spend cap, real 40+ case
accuracy/latency/cost, public Web asset identity, Chromium/WebKit deployment and
physical iPhone Safari remain **TBD / TO VALIDATE**. The branch must not claim
Real Text-to-Weapon AI completion or enter M1B2 until those gates are completed.
