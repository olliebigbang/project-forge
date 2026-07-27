# M2 Belt Combat Spike Delivery Report

Status: **CONFIRMED technical prototype, physical-iPhone, and product-direction acceptance complete**

Date: 2026-07-27

## Outcome

The isolated belt-combat comparison scene is executable without replacing the
accepted side-view Combat Lab. It adds horizontal and depth movement, a single
continuous eight-direction touch control, deterministic target assistance,
three encounter fixtures, five distinct two-dimensional attack executions, and
the existing lethal Retry/Reforge loop.

The product owner completed the physical-iPhone prototype checklist on
2026-07-27, reported every item passed, and then approved belt combat as Project
Forge's future primary combat direction. The current implementation remains
behind an explicit prototype entry and preserves the stable side-view Combat Lab
as the default regression and rollback baseline.

## Scope and boundaries

- The default Web route still opens the stable Forge flow.
- The prototype opens only through `?mode=belt`, `?qa=m2belt`, or the native
  `--belt-spike` development argument.
- The scene uses deterministic local fixture `WeaponSpec` data. Browser
  automation blocks and counts compile/provider routes; observed Provider calls
  were zero.
- Existing Schema, PowerBudget, Worker, D1, Anthropic, drawing-input, keyboard,
  stable Canvas, and side-view combat contracts were not replaced.
- B2 contact regions, M1B2 image interpretation, cadence, charged grenade
  throws, jump, dodge, skills, progression, production art, and production
  balance are excluded.

## Implemented comparison surface

- One bounded belt room with X/Y movement and Y sorting.
- One left-side eight-direction joystick plus right-side ATTACK, including
  simultaneous multi-touch movement and attack.
- Deterministic auto-facing that rejects dead or invalid targets.
- Moving, frontal-shield, and grouped fixtures with independent reset.
- Player HP, readable enemy telegraph/strike/recover states, victory, defeat,
  Retry, and Reforge.
- Five attack roles:
  - melee uses forward reach plus visible depth width;
  - straight projectile stops at the first body and remains shield-blocked;
  - piercing bypasses the shield, locks horizontal movement during startup, and
    applies the existing 100%/70%/45% three-body decay;
  - boomerang flies out and returns before another activation is accepted;
  - thrown blast follows an arc, lands, and displays a horizontal ground ellipse
    whose executable radii match the QA state.

## Automated verification

### Godot and backend

- `./scripts/test.ps1`: **PASS**, exit 0.
- Dedicated belt-combat suite: **170 assertions, 0 failed**.
- The deterministic long-frame case compares one `0.12s` projectile step with
  twelve `0.01s` steps and confirms identical hit count, damage, terminal state,
  and zero remaining transients.
- Existing deterministic compiler, runtime repair, WeaponSpec/Schema,
  PowerBudget, M1B1 interpreter, safety, Worker, D1, Anthropic adapter, durable
  budget, and main-scene smoke checks: **PASS**.
- `./scripts/build_web.ps1`: **PASS**, exit 0.
- `./scripts/build_sites_preview.ps1`: **PASS**, exit 0.
- The only emitted engine diagnostic was the known non-gameplay Windows root
  certificate-store warning; no GDScript parse or runtime failure was present.

### Chromium

- **PASS**, exit 0.
- 844x390, 852x393, 915x412, portrait gate, and 844x343 reduced-height toolbar
  layouts passed.
- Real concurrent touch events kept diagonal movement active while ATTACK was
  pressed and released.
- Five weapon roles and all three fixtures passed.
- 30/60/120 Hz browser profiles produced equivalent hit counts and cleanup.
- Application console errors: **0**.
- Provider calls: **0**.
- Forge -> belt prototype -> Forge preserved the exact Description and stroke
  count.

### WebKit

- **PASS**, exit 0.
- The same viewport, touch, weapon, fixture, lifecycle, shield, target-assist,
  and simulation matrix passed.
- Application console errors: **0**.
- Provider calls: **0**.
- Forge -> belt prototype -> Forge preserved the exact Description and stroke
  count.

### Stable-route regression

- Existing lethal side-view Core Combat C0 suite: **PASS** in Chromium and
  WebKit.
- Existing iPhone input blocker suite: **PASS** in Chromium and WebKit,
  including Chinese Description synchronization, concurrent move/attack touch,
  and keyboard/Visual Viewport restoration.
- Restored stable Canvas: `844x390`, black strip `0px`, console errors `0`.
- The default URL continued to open Forge; only the explicit belt query entered
  the prototype.

**TO VALIDATE:** Playwright's headless WebKit can return a black WebGL screenshot
after an in-place viewport resize even while the Godot QA state, orientation
gate, and console remain healthy. The test therefore verifies the live state
transition first, then captures a fresh WebKit render at the resulting viewport
size. This is recorded explicitly in the JSON report and is not treated as
physical Safari evidence. Real iPhone rotation and Safari toolbar behavior
remain part of the device gate.

## Visual evidence

Generated evidence is retained outside Git under:

`output/playwright/m2-belt-combat-spike-final6/`

Key files:

- Chromium complete room:
  `chromium/chromium/chromium-844x390.png`
- Chromium reduced-height toolbar:
  `chromium/chromium/chromium-toolbar-844x343.png`
- Chromium thrown-blast ellipse:
  `chromium/chromium/chromium-weapon-grenade-impact.png`
- WebKit complete room:
  `webkit/webkit/webkit-844x390.png`
- WebKit reduced-height toolbar:
  `webkit/webkit/webkit-toolbar-844x343.png`
- WebKit thrown-blast ellipse:
  `webkit/webkit/webkit-weapon-grenade-impact.png`
- Machine-readable reports:
  `chromium/chromium/chromium-report.json` and
  `webkit/webkit/webkit-report.json`

## Review findings and resolutions

An independent visual review initially returned **NEEDS WORK**:

1. WebKit live-resize screenshots were black even though state assertions
   passed. Evidence collection now separates live state verification from a
   fresh-render screenshot and retains physical Safari as the authority.
2. At 844x343 the player's feet crossed the arena boundary. Player and enemy
   movement now clamp their complete rendered extents.
3. The initial grenade screenshot showed the restored held grenade rather than
   a readable landing area. The blast now uses explicit ellipse points, a
   0.56 depth ratio, and a visible hold/fade window; Chromium and WebKit evidence
   show the horizontal ground ellipse.
4. Selected fixture/weapon buttons used a dim disabled text color. Selected
   controls now retain the normal readable text color alongside their highlight.
5. Physical-iPhone review found that a Piercing attack could commit toward one
   target and then calculate impact from a different target after startup. The
   locked target point now travels with the attack request, while the final
   launch vector is rebuilt from the actual muzzle. Straight and Piercing tests
   switch targets during startup and verify the emitted projectile still follows
   the original bounded target point.
6. Full-height player and enemy capsules treated torso overlap as a hard wall in
   the battlefield plane. Living actors now collide through small foot
   footprints: direct overlap remains blocked, but diagonal depth escape is
   possible. QA defeat, direct damage, and burn death all disable enemy collision
   immediately; Retry restores it.

**CONFIRMED:** items 5 and 6 pass deterministic Godot plus Chromium/WebKit
automation and the product owner's physical-iPhone run. The accepted candidate
is commit `39b077ed4d41dd4a3af3bdae3927556a52e6a03a` at:

<https://project-forge-b1-preview.hongningliu0130.chatgpt.site/?qa=m2belt&release=m2-belt-39b077e>

## Physical iPhone comparison checklist

**CONFIRMED PASS (2026-07-27):** the product owner ran this checklist on a real
iPhone Safari and reported all items passed, including the corrected Piercing
direction, diagonal escape around a living enemy, defeated-enemy passage,
touch/attack continuity, Retry/Reforge cleanup, orientation, and Safari toolbar
recovery.

1. Open the independent preview in landscape and confirm the default link still
   opens Forge while the belt query opens only the prototype.
2. Hold the joystick diagonally and tap ATTACK repeatedly with another finger;
   neither input should drop.
3. Move above and below enemies and confirm actor overlap order changes by depth.
4. Test SLASH, SHOT, BOOMERANG, BLAST, and PIERCE against MOVING, SHIELD, and
   GROUP; note whether their spatial roles are easier to understand than in the
   stable side-view scene.
5. With GROUP + PIERCE, move vertically while attacking repeatedly. Every spear
   must travel toward the locked forward target; none may turn near-vertical or
   leave the arena through its top or bottom edge.
6. Walk directly into a living enemy and confirm it still blocks overlap. Then
   move diagonally around the same enemy and confirm the player can escape in
   depth instead of being hard-locked by a torso-sized collider.
7. Defeat an enemy and walk through its former position. Select Retry and confirm
   the restored living enemy blocks direct overlap again.
8. Confirm BLAST has visible travel and a horizontal landing ellipse.
9. Lose once, Retry, then Reforge; no attack, touch, projectile, or detached
   weapon state should remain.
10. Before entering the prototype, load a Forge fixture or make a drawing and
   Description; after Reforge, confirm both are still present.
11. Rotate portrait/landscape and expand/collapse Safari toolbars; the scene must
   recover without black screen, clipping, or lost touch.

## Known limitations

- Programmatic placeholder visuals and developer controls are intentionally
  retained for comparison; this is not a production combat UI or art pass.
- Auto-facing is deliberately light and deterministic; final aim-assist feel is
  **TO VALIDATE**.
- Weapon values reuse the accepted deterministic role fixtures and are not final
  production balance.
- The scene preserves Forge input across its isolated route, but it does not yet
  consume a newly compiled live weapon through the normal player flow; the
  tested `equip_weapon()` boundary accepts an already repaired/runtime-valid
  `WeaponSpec`.
- Physical iPhone prototype usability and the future primary belt-combat
  direction are **CONFIRMED**. Public-default routing and live compiled-weapon
  integration remain later scoped gates.

## Merge and rollback record

- PR #15 final HEAD: `5655619e437581f068221502d4edb3dd0554d937`.
- Required CI: two `validate` checks **PASS**.
- Independent release review: Reality Checker **GO**, no P0/P1 merge blocker.
- `main` merge: `ee2583c3664d4013d165d7276f8222238cd49152`.
- Accepted Git tag: `v0.5.0-m2-belt-spike`.
- Production deployment: **not performed**; Sites Version 30 remains unchanged.
- Runtime rollback: the accepted `39b077e` preview package and evidence remain
  retained; `v0.4.0-weapon-exposure-b1.5` remains the deployed stable Git
  rollback point.
