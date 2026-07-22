# Weapon Physics B1 Controlled Prototype Acceptance

Status: **CONFIRMED automated and physical-iPhone round-two acceptance;
release closure in progress**

B1 is a local deterministic physicality experiment after accepted M1B1.2. It is
not M1B2, B1.5, or B2 and does not expand the public `WeaponSpec` Schema.

## Why round one was rejected

The product owner's physical iPhone Safari v23 experiment used four drawings of
the same `A sword` result (Damage 36 / Power 33):

| Drawn length | Range | HUD Speed |
| --- | ---: | ---: |
| 1 grid | 72 | 1.13 |
| 4 grids | 92 | 1.09 |
| 8 grids | 120 | 1.03 |
| 16 grids | 199 | 0.85 |

The 1-grid and 16-grid attacks felt far too similar. The first B1 implementation
also produced only a 1.874 extreme complete-cycle ratio. That ratio is explicitly
rejected as acceptance evidence. Three flattening causes are recorded:

1. The accepted 72 px minimum Range floor collapses every sub-anchor drawing to
   the same reach value.
2. The first B1 handling clamp and drawback speed caps kept HUD Speed and the
   full animation cycle in a narrow band.
3. `GeometryEvidence` measures the complete ink bounding box. It cannot yet
   distinguish blade length from guard or grip length, so an elaborate handle
   can dilute blade-only evidence. Blade/guard/grip segmentation remains B2.

## Round-two executable gates

- [x] Stable start is `v0.2.1-m1b1.2` commit
  `9e0ff3b174c1c38d2dcb35f0717775e2a9d9aaef`.
- [x] `GeometryEvidence -> PhysicalProfile -> CombatDerived` remains the local
  authority chain and raw strokes remain unchanged.
- [x] Internal `ultra_short` handling covers the 72-class floor without adding a
  public field.
- [x] The deterministic matrix is 1/4/8/16 grids x light/balanced/heavy: 12 cases.
- [x] A bounded piecewise-smoothstep reach curve replaces the narrow linear
  handling clamp. It is not inverse reach and retains a 0.25 s safety floor.
- [x] `attack_speed = 1 / full cycle` drives startup, visible tween angular
  velocity, hit time, active, recovery, cooldown, and touch acceptance.
- [x] One authoritative active-attack gate plus a one-slot Boolean buffer prevents
  re-entry, overlapping hit windows, and unbounded tap bursts.
- [x] Displayed grip-to-tip length, HUD Range, and real hit boundary agree within
  0.05 px per case; fit remains uniform with 8%-12% padding.
- [x] Damage remains 36 across the matrix. Length does not grant damage.
- [x] B2 remains honest: one uniform grip-to-tip capsule, no regions, tip sweet
  spot, or contact-dependent feedback.
- [x] No paid provider call, public deployment, or stable v23 mutation occurred.

## Round-two automated evidence (2026-07-22)

The deterministic suite passed 32 existing compiler cases and 877 assertions.
The values below are from the final Chromium report; WebKit reproduced the same
bounded timing.

| Case | Reach | Speed | Startup | Active | Hit | Recovery | Cycle | Power | Range+Speed delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1-grid light | 72 | 3.00 | .055 | .057 | .090 | .221 | .333 | 52 | +18.67 |
| 1-grid balanced | 72 | 2.39 | .075 | .075 | .122 | .268 | .418 | 46 | +12.57 |
| 1-grid heavy | 72 | 2.10 | .098 | .093 | .156 | .285 | .476 | 43 | +9.67 |
| 4-grid light | 92 | 1.82 | .095 | .095 | .154 | .359 | .549 | 40 | +6.27 |
| 4-grid balanced | 92 | 1.42 | .132 | .129 | .212 | .443 | .704 | 36 | +2.27 |
| 4-grid heavy | 92 | 1.25 | .170 | .159 | .269 | .471 | .800 | 35 | +.57 |
| 8-grid light | 120 | 1.23 | .149 | .146 | .240 | .518 | .813 | 35 | +1.04 |
| 8-grid balanced | 120 | .96 | .207 | .197 | .329 | .638 | 1.042 | 33 | -1.66 |
| 8-grid heavy | 120 | .84 | .266 | .243 | .417 | .681 | 1.190 | 31 | -2.86 |
| 16-grid light | 199 | .76 | .281 | .256 | .440 | .779 | 1.316 | 32 | -.91 |
| 16-grid balanced | 199 | .59 | .388 | .346 | .603 | .961 | 1.695 | 31 | -2.61 |
| 16-grid heavy | 199 | .52 | .488 | .422 | .750 | 1.013 | 1.923 | 30 | -3.31 |

The representative target windows all pass: .333 s, .549 s, 1.042 s, and
1.695/1.923 s. The extreme 16-grid-heavy / 1-grid-light ratio is **5.775**.
At a 170 px gap, all 1/4/8-grid cases miss and all 16-grid cases hit for the same
36 damage.

Three rapid browser touches on 1-grid/light produce exactly two accepted attacks
(current + one buffered), two non-overlapping hit windows, and exactly two 36
damage events. Hit-window gaps were .302 s in Chromium and .343 s in WebKit;
both stay above 90% of the .333 s authoritative cycle after frame sampling.
The recorded active-swing angular speed is about 16.84 rad/s versus 2.27 rad/s
for 16-grid/heavy, so visible motion differs by about 7.4x.
The direct runtime stress sends eight same-frame requests and also produces only
two hit windows.

High cadence is not free in the existing budget: 1-grid/light raises the Speed
component from 10 to 30 and the final Power from the source 33 to 52, while the
same 36 damage and existing knockback/control costs remain charged. Light mass
does not grant extra impact, stagger, or special ability. If another weapon's
existing abilities approach Power 100, the deterministic post-physics gate caps
speed before changing damage. B1 does not claim that this is final DPS balance;
role/resource compensation remains B1.5 and interruption/contact control is B2.

Chromium and WebKit each passed 12/12 physics cases and the existing four-case
bow/grenade/sword/boomerang, keyboard, toolbar, and orientation regression with
zero application console errors. Evidence is retained outside Git under
`output/playwright/weapon-physics-b1-round2/`, including JSON reports, individual
combat/impact/rapid-input screenshots, blocker reports, and
`chromium-1-4-8-16-grid-matrix.png`.

## WebKit mass/reach blocker diagnosis and closure

The PR review failure was not caused by mass entering the 4-grid reach formula.
WebKit coalesced the only far-tip pointer sample differently between otherwise
equivalent drawings. Pre-fix retained evidence was:

| Case | source_bounds `(x, y, w, h)` | normalized_length | effective_reach |
| --- | --- | ---: | ---: |
| 4-grid light | `(152.445496, 225.077286, 415.343567, 24.000000)` | .271466383591 | 91 |
| 4-grid balanced | `(152.445496, 197.384964, 420.881470, 79.384628)` | .275085927926 | 92 |
| 4-grid heavy | `(152.445496, 154.923431, 415.343567, 164.307709)` | .271466383591 | 91 |

The varying source width fully predicts the varying reach. The old physical
calculation also contained a separate latent coupling: an ink-aspect safety cap
could shorten extremely thick evidence even when longitudinal bounds matched.
It did not activate in the failing 4-grid samples, but violated the B0 invariant.

The fix gives every controlled browser outline three far-side points at the same
x extremum, removes the ink-aspect cap, and makes `normalized_length` the only
reach input. A non-Playwright test uses identical 500 px longitudinal bounds with
12/45/280 px cross-axis thickness and proves light/balanced/heavy all derive the
same reach. Browser reports now retain input-coordinate spread separately from
the physical residual; a same normalized length with different reach still
fails.

Two consecutive post-fix WebKit runs produced the same 4-grid evidence:

| Case | source_bounds `(x, y, w, h)` | normalized_length | effective_reach |
| --- | --- | ---: | ---: |
| 4-grid light | `(152.445496, 225.077286, 420.881470, 24.000000)` | .275085927926 | 92 |
| 4-grid balanced | `(152.445496, 197.384964, 420.881470, 79.384628)` | .275085927926 | 92 |
| 4-grid heavy | `(152.445496, 154.923431, 420.881470, 164.307709)` | .275085927926 | 92 |

For both runs, source-width spread, normalized-length spread, effective-reach
spread, and maximum physical residual were all zero. Fix evidence is retained at
`output/playwright/weapon-physics-b1-mass-reach-fix/`.

## Physical iPhone and isolated preview acceptance (2026-07-22)

The product owner accepted the round-two combat feel on a physical iPhone after
testing the isolated Sites preview. The accepted product-code HEAD is
`e15e32dd6fd16f76fc5a84f3622e2bef17e72191` (PR #7). Sites Version 2 uses the
deployment-only metadata commit `a81061f0d37754cce28f547ffe4d20b98ab2eb3a`;
the only intentional difference is binding `.openai/hosting.json` to the
isolated preview project rather than the stable Site.

- **CONFIRMED:** The visible and executable cadence difference between the
  tested 1/4/8/16-grid swords is acceptable on the physical device.
- **CONFIRMED:** The very short sword is limited primarily by the player's tap
  cadence while the long sword remains visibly and mechanically slower.
- **CONFIRMED:** No new mobile input, layout, keyboard, orientation, or combat
  blocker was reported during this acceptance pass.
- **CONFIRMED:** The isolated preview retained the Anthropic snapshot and D1
  guard while using a separate USD 0.50 lifetime application cap. The stable
  v23 Site was not mutated during device review.
- **CONFIRMED:** Sites deployment Version 2 included both D1 migrations and
  returned HTTP 200 through the authenticated Site boundary. Anonymous access
  remained behind the expected Sign in with ChatGPT gate.

## Remaining release gates and limitations

- **CONFIRMED:** Product-owner physical-iPhone combat-feel review passed on
  2026-07-22.
- **TO VALIDATE:** The 72 px floor still loses sub-grid reach resolution.
- **TO VALIDATE:** Whole-ink cross-axis load is only a mass proxy; material
  density, balance point, moment of inertia, and blade/handle separation are not
  modeled.
- **TO VALIDATE (B1.5):** Weapon-role and near/ranged compensation are absent.
- **TO VALIDATE (B2):** Contact regions, sweet spots, interruption, shields,
  multi-target behavior, and matching feedback remain unimplemented.
- **RELEASE GATE:** PR #7 final CI, merge, stable-main deployment, smoke test,
  rollback verification, and release tag remain closure work. The isolated
  preview is acceptance evidence, not the stable production release.

## Release-closure rerun (2026-07-22)

The integrator rebuilt and reran the accepted PR #7 state after recording the
device result:

- `./scripts/test.ps1`: PASS; Godot 4.7.1 import/parse, deterministic compiler,
  Worker/interpreter, D1 idempotency, provider-budget, and hostile safety gates.
- `./scripts/build_web.ps1`: PASS; fresh Godot Web export.
- `./scripts/build_sites_preview.ps1`: PASS; fresh Worker/WASM Sites bundle.
- Chromium: 12/12 physicality cases, console errors 0, extreme cycle ratio
  5.7748, exactly two accepted attacks/damage events from three rapid taps, and
  maximum physical reach residual 0 px.
- WebKit: the same 12/12, zero errors, 5.7748 ratio, two-event input bound, and
  0 px residual.

The first two browser-launch attempts did not load the application because the
bundled Playwright module path was incomplete. After resolving the actual pnpm
module path, both complete browser runs passed; those launch-environment errors
are not gameplay or test failures.
