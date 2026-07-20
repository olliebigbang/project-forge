# M1B1 Mobile Regression Test Results

## Anthropic integration mobile QA addendum (pre-integration design)

- **Prepared:** 2026-07-20 (Australia/Sydney)
- **QA branch:** `codex/qa/m1b1-anthropic-mobile`
- **QA worktree:** `C:\Users\Eddie L\Documents\project-forge-m1b1-anthropic-mobile`
- **Baseline source revision:** `d41511c9c65c0c9760d79b62ee7bc9f7e78951b6`
- **Selected provider/model:** Anthropic / `claude-haiku-4-5-20251001`
- **Real Anthropic call in this QA workstream:** **NOT RUN**
- **Current disposition:** **TEST DESIGN READY; INTEGRATED ANTHROPIC CANDIDATE TO VALIDATE**

The executable QA design is
`tests/browser/run_m1b1_anthropic_mobile_regression.mjs`. Its default
`simulated` mode intercepts only the same-origin project endpoint and returns
bounded provider-shaped responses. It does not read a Sites secret, send an
Anthropic header, call Anthropic, or spend provider budget. A separate
`live-one-call` mode is hard-disabled unless the integrator explicitly sets
`M1B1_QA_ALLOW_LIVE_PROVIDER=one-paid-call`; this QA branch did not set it.

`CONFIRMED` on the provider-neutral baseline, Chromium simulated HTTP regression
passes the complete flow described below. This proves the browser/UI oracles and
test harness, not Anthropic Structured Outputs, real D1 budget enforcement,
provider quality, latency, billing, or deployed Safari behavior.

### Anthropic mobile acceptance matrix

| ID | Area | Automated oracle | Pre-integration status |
|---|---|---|---|
| AN-M-01 | Normal UI | Five attack-pattern controls have no visible/clickable rectangles before MODIFY or Developer/Test Mode | PASS Chromium; TO VALIDATE integrated WebKit/public |
| AN-M-02 | Layout | 844×390 keeps canvas/input/clear/RESET/FORGE in bounds, canvas >= 40% and about 150 CSS px, no document scroll | PASS Chromium |
| AN-M-03 | Layout | 852×393 meets the same geometry and touch-target rules | PASS Chromium |
| AN-M-04 | Layout | 915×412 meets the same geometry and touch-target rules | PASS Chromium |
| AN-M-05 | Safari toolbar stress | 844×343 remains usable after a reduced `visualViewport` | PASS Chromium simulation; physical Safari TO VALIDATE |
| AN-M-06 | Description | Native HTML overlay focuses, edits, deletes, clears, and synchronizes to Godot | PASS Chromium; real iOS keyboard TO VALIDATE |
| AN-M-07 | Drawing | Stroke is accepted only within the reported canvas and survives request lifecycle changes | PASS Chromium touch |
| AN-P-01 | Client boundary | Godot calls only same-origin `/api/compile-weapon` | PASS intercepted HTTP |
| AN-P-02 | Secret boundary | Client sends no `Authorization`, `x-api-key`, or `anthropic-version` header | PASS intercepted HTTP |
| AN-P-03 | Drawing privacy | Request carries bounded numeric `drawing_summary`, never raw point/stroke geometry | PASS intercepted HTTP |
| AN-P-04 | Request identity | Browser request IDs match the random 128-bit `m1b1-<32 hex>` form | PASS intercepted HTTP |
| AN-R-01 | Loading | Delayed request exposes a reachable CANCEL and does not duplicate the logical request | PASS Chromium |
| AN-R-02 | Active rotation | Portrait gate appears during an active request; returning to landscape restores loading without refresh | PASS Chromium |
| AN-R-03 | Background/resume | Temporary tab background/foreground does not lose text, drawing, or lock the UI | PASS Chromium tab simulation; real iOS suspension TO VALIDATE |
| AN-R-04 | Cancel | CANCEL returns to idle and preserves Description/drawing | PASS Chromium |
| AN-R-05 | Late response | Cancelled late response cannot commit or navigate | PASS Chromium |
| AN-R-06 | Wrapper timeout | Timeout reaches a validated fallback with exactly one recorded provider attempt; no automatic retry | PASS simulated response; Worker/Anthropic TO VALIDATE |
| AN-R-07 | TRY AGAIN | User action creates exactly one new logical request ID and preserves creative input | PASS Chromium |
| AN-R-08 | Explicit safe retry | One logical request may record exactly two provider attempts only for a fixture explicitly marked retry-safe | PASS simulated response; adapter classification TO VALIDATE |
| AN-C-01 | Confirmation | Result/fallback is schema-, allow-list-, runtime-, and PowerBudget-valid before presentation | PASS Chromium |
| AN-C-02 | Confirmation rotation | Portrait and landscape round-trip restores the same confirmation and creative input | PASS Chromium |
| AN-C-03 | MODIFY | Only MODIFY exposes five mutually exclusive controls; all five repairs remain valid | PASS Chromium |
| AN-C-04 | Touch stress | Twenty additional mode changes do not lock the page | PASS Chromium |
| AN-C-05 | Combat | Confirmed corrected boomerang enters combat, hides selector, and executes boomerang attack | PASS Chromium |
| AN-C-06 | Safe retry result | A two-attempt retry-safe result preserves data and keeps normal-player selector hidden | PASS Chromium simulated response |
| AN-B-01 | Chromium console | Any application error/warning fails; exact GPU `ReadPixels`/context-lifecycle signatures are retained separately | PASS; 0 application messages |
| AN-B-02 | WebKit console | Same functional flow and console policy, with exact Windows WebGL signatures separated | TO VALIDATE on integrated candidate |
| AN-L-01 | Live provider smoke | One paid request must report provider/model, one attempt, bounded USD cost, expected boomerang/electric semantics, then attack | NOT RUN by QA; requires integrator authorization and live guarded deployment |
| AN-L-02 | Public identity | Public HTML/PCK/JS/WASM hashes must match the tested deployment, not query-only cache busting | TO VALIDATE after deployment |
| AN-L-03 | Physical Safari | Real keyboard, finger drawing, safe areas, toolbar, active-request rotation/background, confirmation rotation | TO VALIDATE on product-owner iPhone |

### Pre-integration execution result

Command shape (no provider credential and no real provider request):

```powershell
$env:PLAYWRIGHT_MODULE_PATH = '<local Playwright module>'
node .\tests\browser\run_m1b1_anthropic_mobile_regression.mjs `
  chromium http://127.0.0.1:18071/ '' simulated
```

Chromium result: **PASS**.

| CSS viewport | Canvas height | Description height | Scroll/clipping |
|---|---:|---:|---|
| 844×390 | 237.25 px | 46.03 px | none |
| 852×393 | 239.08 px | 46.39 px | none |
| 915×412 | 258.07 px | 46.34 px | none |
| 844×343 | 195.32 px | 44.30 px | none |

The run observed four same-origin simulated compile requests. Loading rotation,
CANCEL, late-response rejection, timeout without automatic retry, TRY AGAIN,
confirmation rotation, all five MODIFY choices, twenty touch switches, corrected
combat, and explicitly retry-safe two-attempt metadata passed. Description and
drawing state were retained across every required cancellation/failure/retry
boundary. Application console errors/warnings were zero; four exact Chromium
`ReadPixels` GPU performance warnings were retained as renderer evidence.

The first WebKit attempt was **INCONCLUSIVE / HARNESS ENVIRONMENT**, not a product
failure: the cached Playwright JavaScript package expected WebKit revision 2311,
while only revision 2327 remained installed. Launching 2327 through the older
package did not complete inside 120 seconds. The integrated follow-up must run
with a matching Playwright package/browser revision before WebKit can pass.

Tested local asset identity:

| Asset | SHA-256 |
|---|---|
| `index.html` | `1050C12712C4AE4D62F46BA2DFCB6C5C1E9BD0BDE19E8169FDB1023237F009B5` |
| `index.js` | `68586D6DAAFC93C6E697B3FB258976874AA7459B8931165EBB1DC3C9614CC42C` |
| `index.pck` | `5462FE85920D9E1ACD07E5705C525FE76868A5319ACE2CC2B8D5F4636BB5122D` |
| `index.wasm` | `35116F68540AC41ACF7D71EA457ADDED91B5E960A9CCA3E2ACC72918EAF01277` |

### Integration blockers and required follow-up

- **P1 gate:** run the new matrix against the integrator's Anthropic + D1 commit
  in both Chromium and a version-matched Playwright WebKit runtime.
- **P1 gate:** prove the Worker timeout records one attempt and never invokes an
  automatic retry; prove a second attempt occurs only under an adapter fixture
  explicitly classified retry-safe.
- **P1 gate:** prove D1 fail-closed and USD 5 budget responses recover to a usable
  mobile forge without losing text/drawing. Browser QA must not attempt to spend
  through the full cap.
- **P1 gate:** deploy new asset hashes and repeat public Chromium/WebKit smoke.
- **Physical device gate:** real iPhone Safari remains authoritative for keyboard,
  finger drawing, toolbar/safe area, background suspension, and active-request or
  confirmation orientation transitions.
- **Not a provider claim:** all PASS entries in this addendum are simulated or
  inherited browser behavior unless explicitly rerun in `live-one-call` mode.

## 1. Gate summary

- **Test date:** 2026-07-20 (Australia/Sydney)
- **Current state:** `PASS WITH KNOWN QA-HARNESS LIMITATION - AUTOMATED MOBILE GATE`
- **Implementation under test:** `104fddbec98060741401316d25185f130caaa1c0`
- **QA branch:** `codex/qa/m1b1-mobile-regression-final`
- **QA worktree:** `C:\Users\Eddie L\Documents\project-forge-m1b1-mobile`
- **Stable comparison baseline:** `v0.1.0-m1a`
- **Public preview:** `TBD - not deployed or tested by this QA workstream`
- **Physical iPhone Safari:** `TO VALIDATE - product owner owns final device acceptance`

`CONFIRMED` the candidate passes the repository test suite, Godot import and
parse checks, Web export, Chromium touch regression, and Playwright WebKit
regression. No P0 or P1 blocker was observed in the automated paths.

The 64-case mobile plan has the following authoritative disposition:

| Disposition | Count | Meaning |
|---|---:|---|
| PASS | 60 | Covered by deterministic browser automation, repository tests, source-level invariant checks, or the accepted unchanged M1A baseline |
| TO VALIDATE | 4 | A dedicated mid-transition lifecycle action was not exercised by the final runner |
| Physical sub-gate | 2 | The automated portion passed, but real iOS keyboard and non-zero hardware safe-area behavior still require an iPhone |

This report does not claim public deployment, real-provider quality, or physical
iPhone acceptance. It does show that the candidate is suitable for public
preview deployment and owner device testing.

## 2. QA isolation and scope

QA did not modify Godot scenes, gameplay scripts, interpreter behavior, backend
code, or hosting code during this final pass. This revision updates only this
report. Browser evidence was produced by the already integrated QA runners:

- `tests/browser/m1b1_mobile_regression.js`
- `tests/browser/m1b1_webkit_regression.js`
- `tests/browser/run_m1b1_regression.mjs`

The mobile workstream covers normal-player selector visibility, Developer/Test
Mode and MODIFY behavior, async loading/cancel/retry/fallback behavior,
confirmation safety, Description input, compact layouts, orientation recovery,
console health, and all five M1A attack modules. Visual image understanding,
voice, accounts, cloud saves, sharing, monetization, multiplayer, production art,
and M1B2 remain out of scope.

## 3. Commands and results

### 3.1 Repository and Godot checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test.ps1
```

Result: **PASS**.

- Godot 4.7.1 import and parse: PASS
- M1A deterministic matrix: 32 cases, 458 assertions, 0 failures
- Main scene smoke test: PASS
- Static Worker route tests: 4/4 PASS
- WebAssembly loader test: 1/1 PASS
- M1B1 interpreter matrix: 48 cases PASS
- M1B1 interpreter/HTTP suite: 68/68 PASS
- Durable request guard/D1 suite: 9/9 PASS

The final suite includes explicit checks for a 128-bit per-client idempotency
namespace, matching and mismatched server `request_id`, late request A losing to
active request B, and late HTTP responses being counted and discarded. It also
passes concurrent idempotent-request coalescing, per-session idempotency
namespacing, provider metadata leak prevention, and per-session ingress quota.
The final durable-boundary suite also verifies runtime D1 schema/migration,
cross-binding atomic ownership and quota, expired-lease reclamation, abandoned
lease removal, cross-isolate provider-operation coalescing, fail-closed behavior
for a broken guard, and no memory downgrade when D1 is missing or partial.

### 3.2 Web build

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build_web.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build_sites_preview.ps1
```

Result: **PASS** for both the direct Godot Web export and the Sites preview
bundle. The Sites package contains the client, split-WASM loader/chunks, and the
final fail-closed durable server boundary. The two WASM chunks total 39,513,091
bytes, exactly matching the source `index.wasm` size.

The freshly built candidate was served locally at
`http://127.0.0.1:18064/`; HTML, JS, PCK, and WASM each returned HTTP 200,
`Cache-Control: no-store`, the correct content type, and the expected
`Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: require-corp` headers. The temporary server was
stopped after the run, and its stderr log was empty.

### 3.3 Chromium touch regression

```powershell
$env:PLAYWRIGHT_MODULE_PATH = 'C:\Users\Eddie L\Documents\Codex\2026-06-27\new-chat\node_modules\playwright'
node .\tests\browser\run_m1b1_regression.mjs chromium http://127.0.0.1:18064/ .\output\playwright\m1b1-final-104fddb\chromium-rerun-result.json
```

Result: **PASS**, exit code 0, approximately 90 seconds.

`TO VALIDATE` the first Chromium attempt exposed a runner sampling limitation:
the deterministic `rate_limit` path completed two bounded attempts and reached a
validated fallback in 6 ms, before the runner's 50 ms poll observed the transient
`loading` state. The captured terminal state was safe (`request_count = 1`,
`request_attempts = 2`, `provider_rate_limited`, runtime/schema valid, Power 17).
The unchanged runner immediately passed end to end on the same build. No product
code or test code was modified. This is not a client regression, but the runner
should eventually accept either observable loading or an already-safe terminal
state for intentionally immediate scenarios.

### 3.4 WebKit regression

```powershell
$env:PLAYWRIGHT_MODULE_PATH = 'C:\Users\Eddie L\AppData\Local\npm-cache\_npx\31e32ef8478fbf80\node_modules\playwright'
node .\tests\browser\run_m1b1_regression.mjs webkit http://127.0.0.1:18064/ .\output\playwright\m1b1-final-104fddb\webkit-result.json
```

Result: **PASS**, exit code 0, approximately 103 seconds. The cached Playwright
module matches installed WebKit revision 2327; this run did not download or
replace browser binaries.

The JSON outputs are intentionally under ignored `output/` paths and are not
committed as release assets.

## 4. Browser evidence

### 4.1 Compact Landscape geometry

Both Chromium and WebKit passed the same geometry oracles. All required controls
were within the viewport, the canvas did not overlap input/actions, touch targets
met the compact minimum, and the document did not scroll.

| CSS viewport | Canvas height | Description height | Scroll/clipping |
|---|---:|---:|---|
| 844x390 | 237.25 px | 46.03 px | none |
| 852x393 | 239.08 px | 46.39 px | none |
| 915x412 | 258.07 px | 46.34 px | none |
| 844x343 toolbar stress | 195.32 px | 44.30 px | none |

Additional layout results:

- `viewport-fit=cover` is present;
- keyboard-like viewport shrink/restore returns the input to its prior geometry;
- three landscape/portrait/landscape cycles restore the forge without refresh;
- portrait hides the native Description overlay behind the rotation gate;
- desktop 1280x720 has no scroll regression and does not expose normal-player
  attack selectors.

### 4.2 Description, drawing, and touch ownership

Chromium and WebKit both passed Description focus, mixed-language synchronization,
caret/end deletion, explicit clear-button behavior, drawing input, and
Description/drawing preservation across cancellation and failure. Repository
tests independently verify that RESET clears drawing and Description and permits
immediate new text and strokes.

`TO VALIDATE` desktop WebKit focus and viewport-shrink simulation do not prove
that a physical iPhone opens the real iOS keyboard. That remains part of the
owner device gate.

### 4.3 Loading, cancellation, retry, and recovery

Both engines passed:

- a clear loading state with a reachable CANCEL action;
- repeated FORGE taps producing only one logical request;
- CANCEL preserving drawing and Description;
- a cancelled late response being ignored;
- a later successful request winning cleanly;
- timeout retrying exactly once (`request_attempts = 2`), then producing a
  validated fallback;
- network failure recovery through TRY AGAIN without refresh or input loss;
- rate-limit, unavailable-backend, malformed JSON, missing-field, and unsupported
  ability paths ending in a bounded validated result/fallback;
- no third retry, infinite spinner, stale navigation, or page lock.

Representative terminal results:

| Engine | Scenario | Attempts | Result/fallback reason | Power |
|---|---|---:|---|---:|
| Chromium | rate limit | 2 | `provider_rate_limited` | 17 |
| Chromium | backend unavailable | 2 | `backend_unavailable` | 17 |
| Chromium | invalid JSON | 1 | `invalid_provider_response` | 17 |
| Chromium | missing fields | 1 | `invalid_provider_response` | 17 |
| Chromium | unsupported ability | 1 | `provider_output_repaired` | 59 |
| WebKit | network error | 2 | `network_unavailable` | 17 |
| WebKit | rate limit | 2 | `provider_rate_limited` | 17 |
| WebKit | invalid JSON | 1 | `invalid_provider_response` | 17 |
| WebKit | missing fields | 1 | `invalid_provider_response` | 17 |
| WebKit | unsupported ability | 1 | `provider_output_repaired` | 59 |

### 4.4 Confirmation and attack modules

Normal mode keeps the five deterministic pattern selectors hidden. MODIFY and
Developer/Test Mode expose exactly five mutually exclusive controls; repeated
switching stays responsive, each change produces a schema/allow-list/runtime
valid result with `power_score <= 100`, and selectors remain hidden in combat.

Every attack module completed forge, confirmation, combat, and ATTACK in both
Chromium and WebKit:

| Pattern | Power | Runtime valid |
|---|---:|---|
| `melee_slash` | 33 | true |
| `straight_projectile` | 46 | true |
| `boomerang` | 56 | true |
| `area_blast` | 49 | true |
| `piercing` | 77 | true |

Confirmation evidence contains weapon name, interpretation summary, attack
pattern, element, damage, attack speed, range, special ability, status effect,
weakness, Power Score, and the required actions. Feedback registration,
TRY AGAIN duplicate suppression, manual revalidation, and combat selector hiding
also passed.

### 4.5 Browser console

| Engine | Application errors | Application warnings | Known renderer-only messages |
|---|---:|---:|---:|
| Chromium | 0 | 0 | 4 `ReadPixels`/GPU performance warnings |
| WebKit | 0 | 0 | 198 `glBlitFramebuffer` errors and 14 `WEBGL_polygon_mode` warnings |

The WebKit counts are known Windows Godot/WebGL runner noise. The WebKit runner
filters only those exact signatures and fails on any remaining error or warning;
none remained. These messages must not be treated as evidence for physical
Safari console health.

## 5. Authoritative 64-case disposition

The detailed plan IDs are fully accounted for below. PASS may combine browser,
repository, source-invariant, and accepted unchanged M1A evidence. The four open
items are explicitly listed in the next table.

| Area | Planned | PASS IDs | TO VALIDATE IDs |
|---|---:|---|---|
| Player flow and mode visibility | 12 | MB-UI-01..08, MB-UI-10..12 | MB-UI-09 |
| Loading/cancel/retry/recovery | 18 | MB-R-01..16 | MB-R-17, MB-R-18 |
| Confirmation and safe presentation | 10 | MB-C-01..10 | none |
| Description/touch/layout | 16 | MB-M-01..12, MB-M-14..16 | MB-M-13 |
| Existing attack modules | 8 | MB-A-01..08 | none |
| **Total** | **64** | **60** | **4** |

Open lifecycle cases:

| ID | Status | Reason and next check |
|---|---|---|
| MB-UI-09 | `TO VALIDATE` | No dedicated automation exits MODIFY without accepting; verify the original result remains and no hidden selection leaks. |
| MB-R-17 | `TO VALIDATE` | Loading and three rotation cycles pass independently, but rotation during an active request was not exercised. |
| MB-R-18 | `TO VALIDATE` | Browser background/suspend during an active request was not simulated by the final runner. |
| MB-M-13 | `TO VALIDATE` | Confirmation and rotation pass independently, but rotation while confirmation is open was not exercised. |

Physical sub-gates attached to otherwise passing automated cases:

| ID | Automated result | Physical requirement |
|---|---|---|
| MB-M-01 | PASS: WebKit focus, edit, caret/delete, synchronization, and keyboard-like resize | `TO VALIDATE`: real iOS keyboard opens/closes and leaves all actions usable |
| MB-M-14 | PASS: `viewport-fit=cover`, control bounds, compact viewport, no scroll | `TO VALIDATE`: non-zero notch/home-indicator insets and live Safari toolbar on hardware |

## 6. Candidate Web asset identity

The following SHA-256 values identify the locally tested build. A public preview
must serve these exact assets, or QA must rerun against the deployed hashes.

| Asset | SHA-256 |
|---|---|
| `build/web/index.html` | `ADF9AA1ED7763499F5DEDE1BE0261AF91CD26B104E7F5267E8AD7955FAC46597` |
| `build/web/index.js` | `68586D6DAAFC93C6E697B3FB258976874AA7459B8931165EBB1DC3C9614CC42C` |
| `build/web/index.pck` | `5879035ED5AF4CBD02B275C25AF01EC29BFC9E69E821BBD0B9B0786C6BF92B44` |
| `build/web/index.wasm` | `35116F68540AC41ACF7D71EA457ADDED91B5E960A9CCA3E2ACC72918EAF01277` |

Final Sites-package boundary identities:

| Asset | SHA-256 |
|---|---|
| `dist/client/index.html` | `4A18851E84F82DF527A907AD57FAC792C39EA45B8B56C360C1FCD3B7F9A0281E` |
| `dist/client/index.pck` | `5879035ED5AF4CBD02B275C25AF01EC29BFC9E69E821BBD0B9B0786C6BF92B44` |
| `dist/server/index.js` | `DEA11283AD97246B71AC9938D8BAC0ABF1B4B52C28929D4ED150EDB42DB307BA` |
| `dist/server/weapon_interpreter.mjs` | `76615B8CFB47E98B0A391D348F9FBD273DDEC0E348D12F0637E87E46336A2680` |
| `dist/server/durable_request_guard.mjs` | `1B4D221EFC9D9262771E7731F120756E9C97973AA8D533041EB3FDAB3F28ADD7` |

## 7. Known limitations and handoff decision

- `TO VALIDATE` no public URL was deployed or tested by this QA workstream.
- `TO VALIDATE` real-provider latency, cost, quality, and failure semantics require
  configured server-side provider credentials and the integrator's provider gate.
- `TO VALIDATE` physical iPhone keyboard, hardware safe area, toolbar, background
  suspension, and the four lifecycle cases above remain owner/device checks.
- `CONFIRMED` Windows WebKit emits renderer messages described in section 4.5;
  application-level console errors and warnings are zero.
- `CONFIRMED` the Chromium first-attempt failure described in section 3.3 is a
  transient-state sampling limitation; the safe terminal state and unchanged
  end-to-end rerun both passed.
- Browser JSON outputs are ignored local evidence; release/deployment automation
  should retain equivalent logs and screenshots with the public build identity.

Automated mobile recommendation:

**`PASS - CANDIDATE 104fddb MAY PROCEED TO PUBLIC PREVIEW AND PHYSICAL IPHONE SAFARI VALIDATION.`**

Do not mark physical mobile acceptance complete until the owner validates the
real iOS keyboard/safe areas and the remaining lifecycle actions on the deployed
asset hashes.
