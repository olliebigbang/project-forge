# M1B1 Mobile Regression Test Results

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
