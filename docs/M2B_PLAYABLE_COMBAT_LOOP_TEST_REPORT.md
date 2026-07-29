# M2B Minimum Playable Belt-Combat Loop Test Report

Status: **AUTOMATED REPAIR PASS / PHYSICAL IPHONE REVALIDATION REQUIRED**

Date: 2026-07-29
Branch: `codex/feat/m2b-playable-combat-loop`  
Base: `origin/main` at `3101eafa781a247da9b3fae87eae541ccb8d5812`  
Issue: [#20](https://github.com/olliebigbang/project-forge/issues/20)

## Scope

This report covers the isolated M2B one-room playable-loop probe defined by
`docs/M2B_PLAYABLE_COMBAT_LOOP_ACCEPTANCE.md`. It does not authorize M1B2,
production deployment, Schema/PowerBudget changes, paid Provider calls, or a
larger level/reward system.

## Implemented result

- **CONFIRMED:** The normal M2A route now enters one playable belt room with one
  bruiser and one direction-locking charger.
- **CONFIRMED:** DODGE has one authoritative active window, invulnerability
  window, movement vector, arena clamp, footprint passage, and cooldown.
- **CONFIRMED:** WARD consumes one charge, deals no damage, negates one strike,
  and forces the attacker into recovery.
- **CONFIRMED:** Victory requires both enemies to be defeated. Defeat requires
  zero player HP. Retry and Reforge clear transient combat state.
- **CONFIRMED:** Victory permits exactly one `WARD+` or `DODGE+` choice for the
  next attempt. The reward expires after that attempt and never rewrites the
  routed `WeaponSpec`.
- **CONFIRMED:** Developer/Test Mode retains the five weapon fixtures and the
  moving, shield, and grouped target routes.
- **CONFIRMED:** The reopened iOS DODGE control resolves on a complete
  press/release gesture. Cooldown/busy requests remain routable and report an
  explicit outcome instead of disabling the Button during the same touch.
- **CONFIRMED:** An explicit confirmation-page `FLIP DRAWING` action records
  authored direction without claiming M1B2 image understanding. The internal
  sign survives the route; combat applies one fitted-copy mirror and one target
  rotation while preserving source strokes.
- **CONFIRMED:** Non-melee held drawings use bounded small/standard/large visual
  profiles derived from raw bounds relative to the frozen Canvas. Fit remains
  uniform with 10% padding and does not alter projectile range or collision
  authority.

## Automated evidence

| Check | Result |
| --- | --- |
| Godot import and script parse | **PASS** |
| Deterministic compiler/runtime suite | **PASS** |
| M2B belt-combat suite | **PASS — 427 assertions, 0 failed** |
| 30/60/120 Hz DODGE displacement profile | **PASS — bounded within 12 px** |
| Main-scene headless smoke | **PASS** |
| Worker, Schema, D1, Anthropic adapter, budget, and security suites | **PASS** |
| Web export | **PASS** |
| Chromium live regression | **PASS — five patterns in both directions, explicit flip, bounded ranged sizing, 20 real-touch DODGE cycles, route identity, WARD, victory/reward, Unicode transport, 0 console errors** |
| WebKit live regression | **PASS — five patterns in both directions, explicit flip, bounded ranged sizing, 20 real-touch DODGE cycles, route identity, WARD, victory/reward, Unicode transport, 0 console errors** |
| Provider policy | **PASS — 0 Provider calls** |

## Reopened physical-iPhone blockers and repair evidence

The product-owner's first M2B device pass found three independent blockers:

1. DODGE could work once and then stop responding.
2. Asymmetric player ink could point away from the target after changing sides.
3. Large ranged drawings were normalized into the same small held box.

The repaired deterministic and browser suites verify:

- accepted, busy, cooldown, terminal and reset DODGE outcomes;
- 20 consecutive real touchscreen DODGE activations after cooldown in both
  Chromium and WebKit;
- five attack patterns on both target sides, with held, projectile and impact
  direction tied to the frozen attack vector;
- the physical-device crossing case: every live target is staged behind a stale
  movement-facing direction and ATTACK auto-faces the nearest one;
- explicit `ink_forward_sign` +1/-1, confirmation-page flip, and route
  persistence;
- strictly increasing but bounded small/standard/large non-melee held visuals;
- equal X/Y fit scale, preserved point count and source SHA-256 signature;
- 844x390, 852x393 and 915x412 controls, exact Chinese request transport, zero
  Provider calls and zero application console errors.

The Chromium and WebKit runs covered 844x390, 852x393, and 915x412 CSS
viewports. Joystick, Retry, Reforge, WARD, DODGE, and ATTACK remained visible,
non-overlapping, and at least 44 CSS pixels in their effective touch dimension.

## Retained local evidence

Browser reports and screenshots are retained under the ignored directory:

`output/playwright/m2b-input-visual-fix/`

Representative evidence:

- `chromium/chromium-m2b-playable-room-844x390.png`
- `chromium/chromium-m2b-ward-success.png`
- `chromium/chromium-m2b-victory-reward.png`
- `chromium/chromium-unicode-request-in-flight.png`
- corresponding WebKit screenshots and JSON report

These generated artifacts are intentionally not committed to Git.

## Known limitations and physical-device gate

- **TO VALIDATE:** Real iPhone Safari confirms DODGE remains usable after at
  least 10-20 cooldown cycles and while movement touch is held.
- **TO VALIDATE:** Real iPhone Safari confirms `FLIP DRAWING` makes an
  asymmetric gun point toward targets on both sides and that the choice survives
  confirmation, Retry, and Reforge as intended.
- **TO VALIDATE:** Real iPhone Safari confirms small and large ranged drawings
  remain visibly different while neither obscures the player or controls.
- **TO VALIDATE:** Real-device timing readability for the bruiser telegraph,
  charger locked lane, dodge window, and WARD window.
- **TO VALIDATE:** Portrait/landscape recovery and Safari toolbar changes in the
  new M2B room. Existing M2A/CJK regression paths passed automation, but physical
  M2B acceptance remains authoritative.
- **TO VALIDATE:** Whether `WARD+` and `DODGE+` produce a meaningful next-attempt
  choice rather than an obvious dominant option.

M2B must remain unmerged and must not replace production until an isolated
preview passes the product owner's physical-iPhone acceptance.
