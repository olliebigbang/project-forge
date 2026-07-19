# M1B1 Mobile Regression Plan and Test Results

## 1. Report status

- **Current state:** `TO VALIDATE — BASELINE AND TEST PLAN ONLY`
- **QA branch:** `codex/qa/m1b1-mobile-regression`
- **QA worktree:** `C:\\Users\\Eddie L\\Documents\\project-forge-m1b1-mobile`
- **Baseline source:** `b09bd8fb6fa7d4466251f73e6d647823682d513e`
- **Baseline tag:** `v0.1.0-m1a`
- **Implementation under test:** `TBD — main integrator has not handed off an M1B1 build`
- **Public preview under test:** `TBD`
- **Physical iPhone Safari gate:** `TO VALIDATE — product owner owns final device acceptance`

This first revision records the accepted M1A baseline and the independent M1B1
mobile/UI regression plan. It does **not** claim that an M1B1 implementation,
backend, real provider, or preview has passed. QA owns only this report and the
two `tests/browser/m1b1_*_regression.js` scripts; QA does not modify Godot scenes,
gameplay scripts, backend behavior, or production hosting.

## 2. Sources and confirmed baseline

The plan was prepared after completely reading:

- `AGENTS.md`;
- the product-owner M1B1 request;
- `artifacts/V9_MOBILE_USABILITY_RESULTS.md`;
- `docs/V9_MOBILE_USABILITY_QA.md`;
- `artifacts/M1A_TEST_RESULTS.md`;
- all four existing M1A/v9 Chromium and WebKit browser regression scripts.

`CONFIRMED` M1A v9 was accepted on physical iPhone Safari. The owner reported
PASS for the portrait gate, automatic landscape recovery, usable drawing area,
Description editing, real iOS keyboard open/close, `×`, RESET, repeated mode
switching, all five COMPILE/ATTACK/REFORGE paths, BACK/re-entry, repeated
orientation changes, and Safari toolbar expansion/collapse.

`CONFIRMED` the stable public v9 package had PCK SHA-256
`0BDD31A387B3373C90C88D8F4DB19F8F9369BA0B143900324810F7F9BF4191F9`.
That evidence is the comparison baseline; a future M1B1 preview must use a new
resource version/hash and must not replace the accepted evidence.

`CONFIRMED` Compact Landscape is based on actual CSS/`visualViewport` geometry,
not only the 1280×720 Godot logical viewport. The accepted v9 measurements were:

| CSS viewport | Drawing height | Touch-row height | Result |
|---|---:|---:|---|
| 844×390 | 194.08 px | 46.03 px | PASS |
| 852×393 | 195.59 px | 46.39 px | PASS |
| 915×412 | 214.88 px | 46.34 px | PASS |
| 844×343 toolbar stress | 154.73 px | 44.30 px | PASS |

## 3. M1B1 QA scope and non-goals

The mobile workstream validates:

- normal-player attack-pattern controls are hidden before interpretation;
- Developer/Test Mode and `MODIFY INTERPRETATION` expose the five controls
  without leaking them into normal forge or combat screens;
- loading, duplicate-submit prevention, cancellation, timeout, at most one safe
  retry, fallback, recovery, and understandable error feedback;
- the result-confirmation screen and its required fields/actions;
- Description editing and keyboard recovery;
- Compact Landscape, safe areas, portrait gating, toolbar resizing, and desktop
  non-regression;
- all five accepted M1A attack modules still compile, confirm, enter combat,
  attack, and reforge.

`CONFIRMED` QA will not validate visual image understanding in M1B1. The drawing
may contribute only a bounded `drawing_summary`. Voice, accounts, cloud saves,
sharing, community, monetization, multiplayer, production art, and M1B2 are out
of scope.

`TO VALIDATE` real-provider semantic accuracy, cost, and latency are reported by
the integrator's 40-case interpreter matrix. This browser plan verifies that
measured latency/cost/fallback metadata are presented and propagated safely; it
does not invent provider data.

## 4. Release gate and severity

| Severity | Definition | Representative M1B1 defect | Release effect |
|---|---|---|---|
| P0 | Page/session is unusable, unsafe, or data is irrecoverably lost | stuck loading overlay, touch lock, crash, secret in browser, late response overwrites newer request | blocks preview/device handoff |
| P1 | Required mobile flow cannot complete or produces an unvalidated weapon | duplicate requests, no cancel, retry loop, selectors visible in normal mode, confirmation bypasses validation, clipped action | blocks preview/device handoff |
| P2 | Material feedback/layout defect with a reliable workaround | ambiguous error, weak focus/selected state, isolated spacing issue | fix or explicitly accept before device gate |
| P3 | Cosmetic issue without correctness/usability impact | minor alignment/copy inconsistency | may be documented |

The candidate may be handed to the product owner only when:

1. repository tests, Godot import/parse, Web export, Chromium, and WebKit pass;
2. no P0/P1 remains open;
3. public HTML and critical resources return HTTP 200 with a new version/hash;
4. browser console capture contains no new application error/warning;
5. failure paths always end in a validated result/fallback or a recoverable idle
   state while preserving the current drawing and Description;
6. physical iPhone Safari remains explicitly `TO VALIDATE` until the owner runs it.

## 5. Testability contract

The existing native Web Description controls are expected to remain available as
`#forge-description-input` and `#forge-description-clear` on the forge screen.
They must remain absent/hidden in portrait-gate and combat screens.

`ASSUMPTION` the integrator will provide a QA-only bridge when `?qa=m1b1` is
present, or an equivalent documented console/DOM contract. The draft browser
scripts expect `window.__forgeM1B1Test` with:

- `state()` — screen/phase, request ID/count/attempt count/in-flight status,
  Description and drawing count, mode visibility, developer/modify flags,
  message/fallback reason, interpretation result, runtime/schema validity,
  Power Score, late-response/attack/feedback counters, and a
  `confirmation_fields` map reflecting the fields actually rendered to the user;
- `controls()` — CSS rectangles for canvas, forge, reset, cancel, confirm,
  modify, try-again, attack, reforge, back, and five pattern buttons;
- `setScenario(name, options)` — deterministic local success, delayed success,
  timeout, network error, rate limit, invalid JSON, missing fields, unsupported
  ability, and backend-unavailable paths;
- `setDeveloperMode(enabled)` — enables/disables the retained M1A test controls.

The bridge must not contain secrets or enable provider calls. `TBD` whether this
contract is compiled only into QA builds or is inert unless the query flag is
present. If the implementation provides a different stable contract, QA will
adapt its two owned scripts before execution.

## 6. State-machine oracles

```text
FORGE_IDLE --FORGE--> INTERPRETING --valid result--> CONFIRMATION
    ^                    |   |                         |   |   |
    |                    |   +--failure--> one retry--+   |   +--TRY AGAIN--> INTERPRETING
    |                    +--CANCEL------------------------+   |
    |                                                      MODIFY
    +------------------------------REFORGE/BACK-------------+--CONFIRM--> COMBAT

terminal provider failure --> validated fallback or recoverable error
portrait --> rotate gate; landscape --> prior valid state restored
```

Required invariants:

- one gesture creates at most one logical request ID;
- repeated FORGE taps while in flight never create another request;
- automatic retry count is never greater than one;
- CANCEL invalidates the active request, and its late response cannot navigate or
  overwrite a later result;
- Description and drawing survive cancel, timeout, network/backend failure, and
  TRY AGAIN;
- every displayed/fought result is schema-valid, allow-listed, runtime-valid,
  and has `power_score <= 100`;
- manual modification is revalidated/rebudgeted before CONFIRM is enabled;
- no modal/invisible layer captures the entire screen after any transition.

## 7. Detailed regression matrix

All M1B1 rows are `TO VALIDATE` until a specific implementation SHA/build is
recorded. Baseline rows marked PASS are evidence from accepted M1A v9 only.

### 7.1 Player flow and mode visibility

| ID | Pri | Procedure | Expected result | Status |
|---|---|---|---|---|
| MB-UI-01 | P1 | Open normal-player forge. | Five attack-pattern buttons are absent/hidden; drawing, Description, RESET and FORGE are usable. | TO VALIDATE |
| MB-UI-02 | P1 | Draw and type without choosing a pattern. | FORGE is available; no hidden/default manual choice is required from the player. | TO VALIDATE |
| MB-UI-03 | P1 | Enable Developer/Test Mode. | Exactly five mutually exclusive pattern buttons appear on forge only. | TO VALIDATE |
| MB-UI-04 | P1 | Disable Developer/Test Mode. | Pattern buttons disappear and no transparent hit regions remain. | TO VALIDATE |
| MB-UI-05 | P1 | Receive a result in normal mode. | Confirmation appears; pattern controls remain hidden until MODIFY is pressed. | TO VALIDATE |
| MB-UI-06 | P1 | Press MODIFY INTERPRETATION. | Five mutually exclusive controls appear with current AI pattern selected. | TO VALIDATE |
| MB-UI-07 | P1 | Switch all five forward, reverse, then 20 times. | One selected state, no lock, no duplicate correction. | TO VALIDATE |
| MB-UI-08 | P1 | Choose another pattern in MODIFY. | Spec is revalidated/rebudgeted; corrections explain the manual change; score stays ≤100. | TO VALIDATE |
| MB-UI-09 | P1 | Exit MODIFY without accepting a change. | Original validated result remains; no stale hidden selection leaks. | TO VALIDATE |
| MB-UI-10 | P1 | CONFIRM and enter combat. | Pattern controls are not visible/clickable in combat. | TO VALIDATE |
| MB-UI-11 | P1 | REFORGE after combat. | Normal forge returns with pattern buttons hidden and Description/drawing policy applied consistently. | TO VALIDATE |
| MB-UI-12 | P1 | BACK/re-enter forge repeatedly. | No stale modifier, overlay, focus trap, or developer controls leak into normal mode. | TO VALIDATE |

### 7.2 Loading, cancellation, retry, failure and recovery

| ID | Pri | Procedure | Expected result | Status |
|---|---|---|---|---|
| MB-R-01 | P1 | Submit a delayed-success request. | Clear “AI is interpreting” loading state and CANCEL are visible; editable data is retained. | TO VALIDATE |
| MB-R-02 | P1 | Tap FORGE repeatedly during loading. | Exactly one request ID/provider operation exists; button is disabled or duplicate taps are ignored. | TO VALIDATE |
| MB-R-03 | P1 | Tap CANCEL once. | Returns to usable forge; active request is invalidated; drawing/Description remain. | TO VALIDATE |
| MB-R-04 | P0 | Let a cancelled response arrive late. | It cannot open confirmation, overwrite state, compile, or navigate. | TO VALIDATE |
| MB-R-05 | P1 | CANCEL then immediately submit a new success. | New request has a new ID and is the only response allowed to win. | TO VALIDATE |
| MB-R-06 | P1 | Trigger timeout. | Friendly timeout feedback appears; automatic retry is at most once. | TO VALIDATE |
| MB-R-07 | P0 | Observe timeout for longer than two attempts. | No third request, retry storm, infinite spinner, or page lock occurs. | TO VALIDATE |
| MB-R-08 | P1 | Exhaust timeout retry. | Validated fallback or recoverable error is shown; drawing/Description remain. | TO VALIDATE |
| MB-R-09 | P1 | Trigger network disconnect. | Safe failure/fallback; no crash; current creative input remains. | TO VALIDATE |
| MB-R-10 | P1 | Restore network and press TRY AGAIN. | One new request succeeds without refresh and without duplicate submission. | TO VALIDATE |
| MB-R-11 | P1 | Trigger HTTP/API rate limit. | Understandable rate-limit feedback, bounded retry policy, safe fallback/recovery. | TO VALIDATE |
| MB-R-12 | P1 | Trigger backend unavailable. | Understandable service error, no direct third-party client call, safe fallback/recovery. | TO VALIDATE |
| MB-R-13 | P1 | Return malformed JSON. | No crash; rejected/repaired result is logged; only validated fallback/result is displayed. | TO VALIDATE |
| MB-R-14 | P1 | Return required fields missing. | Deterministic repair or fallback; confirmation never exposes an invalid spec. | TO VALIDATE |
| MB-R-15 | P1 | Return unsupported ability/enum. | Allow-list repair/fallback is visible in corrections and remains ≤100. | TO VALIDATE |
| MB-R-16 | P1 | Rapid CANCEL/FORGE/TRY AGAIN sequence. | No crossed response, duplicate request, stuck state, or lost input. | TO VALIDATE |
| MB-R-17 | P1 | Turn portrait during loading, then landscape. | Correct loading/cancel state restores without duplicate request. | TO VALIDATE |
| MB-R-18 | P1 | Background/restore page during loading where automation permits. | Request resolves/cancels deterministically; no stale overlay or double result. | TO VALIDATE |

### 7.3 Confirmation and safe result presentation

| ID | Pri | Procedure | Expected result | Status |
|---|---|---|---|---|
| MB-C-01 | P1 | Complete normal success. | Confirmation shows name, interpretation summary, pattern, element, damage, attack speed, range, ability, status, weakness and Power Score. | TO VALIDATE |
| MB-C-02 | P1 | Inspect actions. | CONFIRM, MODIFY INTERPRETATION and TRY AGAIN are visible, distinct and touchable. | TO VALIDATE |
| MB-C-03 | P1 | Inspect validated result/audit. | Schema, allow-list and runtime validation pass; Power Score ≤100. | TO VALIDATE |
| MB-C-04 | P1 | Inspect strong result. | A corresponding drawback/stat cost is visible and budgeted. | TO VALIDATE |
| MB-C-05 | P1 | Inspect corrections/fallback. | Repair/fallback reason is understandable and does not expose raw provider payload or secrets. | TO VALIDATE |
| MB-C-06 | P1 | Press TRY AGAIN rapidly. | Exactly one new request starts; it cannot be used as a duplicate-request race. | TO VALIDATE |
| MB-C-07 | P1 | Repeat same concept via TRY AGAIN. | Result remains within valid/stable Power bounds; no unbounded “reroll stronger” path. | TO VALIDATE |
| MB-C-08 | P1 | Press CONFIRM while repair/rebudget is pending. | Action is disabled/ignored until final validation completes. | TO VALIDATE |
| MB-C-09 | P1 | Confirm fallback result. | Existing attack module executes it; fallback metadata remains auditable. | TO VALIDATE |
| MB-C-10 | P1 | Use “result inappropriate” feedback entry. | Feedback action is reachable; no community/share surface or personal-data leak is created. | TO VALIDATE |

### 7.4 Description, keyboard, touch ownership and layout

| ID | Pri | Procedure | Expected result | Status |
|---|---|---|---|---|
| MB-M-01 | P1 | Tap Description on WebKit/physical iPhone. | Focus and real iOS keyboard open; text/caret/delete work. | TO VALIDATE — physical owner gate |
| MB-M-02 | P1 | Edit mixed Chinese/English text. | Exact text remains synchronized to request state. | TO VALIDATE |
| MB-M-03 | P1 | Tap `×`. | Only Description clears; drawing remains; input stays recoverably editable. | TO VALIDATE |
| MB-M-04 | P1 | Press RESET. | Drawing and Description clear; in-flight state is safely cancelled/absent. | TO VALIDATE |
| MB-M-05 | P1 | Draw at canvas edges and tap adjacent controls. | Canvas consumes only its rectangle; no accidental button/request. | TO VALIDATE |
| MB-M-06 | P1 | Open/close keyboard five times. | Compact layout restores; all actions remain usable. | TO VALIDATE |
| MB-M-07 | P1 | Test 844×390. | All forge/loading/confirmation actions visible; no scroll, clipping or overlap. | TO VALIDATE |
| MB-M-08 | P1 | Test 852×393. | Same compact oracle. | TO VALIDATE |
| MB-M-09 | P1 | Test 915×412. | Same compact oracle. | TO VALIDATE |
| MB-M-10 | P1 | Stress 844×343 toolbar-height viewport. | Drawing remains about ≥150 px; controls remain reachable. | TO VALIDATE |
| MB-M-11 | P1 | Expand/collapse toolbar via viewport resize. | Layout recomputes and returns without stale overlay/focus. | TO VALIDATE |
| MB-M-12 | P1 | Rotate landscape→portrait→landscape three times. | Rotate gate toggles automatically; prior safe state restores; no refresh/lock. | TO VALIDATE |
| MB-M-13 | P1 | Rotate while confirmation is open. | Confirmation returns with same validated result and actions usable. | TO VALIDATE |
| MB-M-14 | P1 | Inspect safe-area bounds. | No action sits under notch, rounded corners, toolbar or home indicator. | TO VALIDATE |
| MB-M-15 | P1 | Test desktop 1280×720. | Spacious desktop layout remains usable and normal-player modes stay hidden. | TO VALIDATE |
| MB-M-16 | P1 | Capture browser console through every state. | No new application error/warning; known runner GPU noise is separated. | TO VALIDATE |

### 7.5 Existing attack-module regression

| ID | Pri | Procedure | Expected result | Status |
|---|---|---|---|---|
| MB-A-01 | P1 | Interpret/modify to `melee_slash`, confirm, attack, reforge. | Runtime-valid melee behavior remains distinct. | TO VALIDATE |
| MB-A-02 | P1 | Repeat for `straight_projectile`. | Projectile stops/hits according to accepted module behavior. | TO VALIDATE |
| MB-A-03 | P1 | Repeat for `boomerang`. | Outbound/return behavior remains distinct. | TO VALIDATE |
| MB-A-04 | P1 | Repeat for `area_blast`. | Area behavior affects grouped targets distinctly. | TO VALIDATE |
| MB-A-05 | P1 | Repeat for `piercing`. | Projectile continues through targets/shield behavior remains distinct. | TO VALIDATE |
| MB-A-06 | P1 | Exercise all five in Developer/Test Mode. | Test controls work but remain absent from normal/combat screens. | TO VALIDATE |
| MB-A-07 | P1 | BACK/REFORGE between every pattern. | Transient attacks/cooldowns/results cannot corrupt the next forge. | TO VALIDATE |
| MB-A-08 | P1 | Repeat five paths in WebKit. | No Safari-engine input/navigation regression or application console error. | TO VALIDATE |

## 8. Execution environments and evidence

| Environment | Viewports | Required evidence |
|---|---|---|
| Chromium touch | 844×390, 852×393, 915×412, 844×343 | state/audit JSON, request counts, geometry, screenshots, console |
| Playwright WebKit | same plus 390×844 portrait | cancellation/timeout/retry/fallback, keyboard-resize simulation, five attacks, console |
| Chromium desktop | 1280×720 | normal-player hidden controls and full success flow |
| Public Chromium/WebKit | deployed URL with new hash | HTTP/resource identity, full smoke, no app errors |
| Physical iPhone Safari | owner device | real keyboard, safe areas/toolbars, orientation, touch cancellation and final flow |

Retain at minimum:

- implementation and test commit SHAs;
- public URL, deployment/version ID and PCK/JS/WASM hashes;
- request ID, attempt count, cancellation/late-response disposition, timeout and
  fallback reason for each reliability case;
- final WeaponSpec, corrections, runtime/schema/allow-list result, Power Score,
  measured latency, and provider-reported/`UNKNOWN` cost;
- screenshots of normal forge (selectors hidden), loading/cancel, confirmation,
  MODIFY selectors, timeout/fallback, 844×390, portrait gate and combat;
- complete console errors/warnings with known WebKit runner noise separated.

## 9. Planned commands

After the integrator hands off a specific build:

```powershell
./scripts/test.ps1
./scripts/build_web.ps1
./scripts/build_sites_preview.ps1
```

Then the QA-owned scripts will be run through the repository's Playwright CLI
workflow against the freshly served local build and again against the public
candidate:

- `tests/browser/m1b1_mobile_regression.js` in Chromium touch context;
- `tests/browser/m1b1_webkit_regression.js` in WebKit/iPhone context.

## 10. Current risks and handoff blockers

| Risk | Severity | Current status |
|---|---|---|
| Godot canvas exposes no stable way to observe async request count/state or control CSS rectangles | P1 testability | `TO VALIDATE` — QA bridge/equivalent requested from integrator |
| Cancelled/old response can overwrite a newer request | P0 | `TO VALIDATE` |
| Hidden selectors retain transparent touch hit regions | P1 | `TO VALIDATE` |
| Loading/confirmation consumes too much compact height | P1 | `TO VALIDATE` |
| Keyboard/toolbar resize corrupts async UI state | P1 | `TO VALIDATE` |
| Windows WebKit emits known Godot/WebGL runner messages | P2 runner limitation | `CONFIRMED` baseline limitation; app errors must still be zero |
| Real iOS keyboard/safe-area behavior cannot be proven by desktop WebKit | P1 device gate | `TO VALIDATE — product owner` |

## 11. Baseline decision

The M1A mobile baseline is healthy and accepted. No M1B1 code or preview has yet
been handed to this QA branch, so the correct current outcome is:

**`TO VALIDATE — TEST PLAN READY; EXECUTION PENDING IMPLEMENTATION HANDOFF`.**

No M1B1 acceptance, provider performance, physical iPhone behavior, or release
readiness is claimed by this revision.
