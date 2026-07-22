# Weapon Physics B1 Controlled Prototype Acceptance

Status: **CONFIRMED automated round-two gate; TO VALIDATE physical-device
combat-feel review**

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

The deterministic suite passed 32 existing compiler cases and 863 assertions.
The values below are from the final Chromium report; WebKit reproduced the same
bounded timing (its synthetic stroke coordinates can quantize Range by 1 px).

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

## Remaining gates and limitations

- **TO VALIDATE:** Product owner must judge round-two cadence on a physical
  iPhone; automated evidence cannot close combat feel.
- **TO VALIDATE:** The 72 px floor still loses sub-grid reach resolution.
- **TO VALIDATE:** Whole-ink cross-axis load is only a mass proxy; material
  density, balance point, moment of inertia, and blade/handle separation are not
  modeled.
- **TO VALIDATE (B1.5):** Weapon-role and near/ranged compensation are absent.
- **TO VALIDATE (B2):** Contact regions, sweet spots, interruption, shields,
  multi-target behavior, and matching feedback remain unimplemented.
- **DEPLOYMENT GATE:** No independent test Site/URL was available in this task.
  Keep stable v23 untouched; the integrator decides whether to provision a safe
  isolated preview for the physical-device review.
