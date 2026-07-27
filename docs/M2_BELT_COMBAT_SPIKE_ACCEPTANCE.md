# M2 Belt Combat Spike Acceptance

Status: **CONFIRMED technical, physical-device, and product-direction acceptance**

Authorized by the product owner on 2026-07-27 after the Weapon Exposure B1.5
release closeout. This began as an isolated comparison prototype.
Physical-device evidence passed, and the product owner selected belt combat as
the future primary direction on 2026-07-27. The accepted side-view Combat Lab
remains executable as the current default regression and rollback baseline until
a later integration gate changes that routing.

## Product question

Does a single-screen belt battlefield with horizontal and depth movement make
Project Forge's five weapon roles more readable, more tactically distinct, and
more enjoyable on a landscape phone than the current fixed-height side view?

## Fixed baseline

- **CONFIRMED:** start from stable `main` after
  `v0.4.0-weapon-exposure-b1.5`.
- **CONFIRMED:** keep the current side-view Combat Lab executable as the
  regression and comparison baseline.
- **CONFIRMED:** preserve the validated `WeaponSpec`, PowerBudget, interpreter,
  Provider/D1, input-integrity, geometry, physical-profile, combat-derived,
  player-ink, keyboard, safe-area, and mobile Canvas contracts.
- **CONFIRMED:** no real Provider call is required by this spike. Deterministic
  fixtures exercise the five existing attack modules.

## Included

1. One bounded, single-screen belt room with X/Y player movement.
2. One left-side eight-direction touch control and one right-side ATTACK control.
   Keyboard input may support the same axes for development.
3. Y sorting, bounded actor movement, auto-facing, and light deterministic target
   assist. No second aiming stick is introduced.
4. Three isolated encounter fixtures: moving target, frontal shield target, and
   a small grouped target encounter.
5. Five two-dimensional attack adaptations:
   - melee: a forward capsule or fan with visible depth width;
   - straight projectile: a direct two-dimensional lane that stops at the first
     valid body;
   - piercing: a narrow committed lane, shield bypass, bounded bodies, and the
     existing deterministic damage decay;
   - boomerang: an outbound and return path in the battlefield plane, locked
     until return;
   - thrown blast: visible arc/landing intent followed by a ground ellipse and
     independent explosion.
6. The accepted lethal micro-loop: player health, readable enemy telegraph,
   victory, defeat, Retry, and Reforge.
7. Provider-free QA evidence for time to first contact, TTK, damage taken,
   whiffs, player travel, attacks, target-assist choice, and terminal state.

## Regression invariants

- One bounded effective reach still drives held-melee rendering, real contact
  distance, and HUD Range.
- One derived cycle still drives startup, active, hit, recovery, cooldown, and
  input acceptance.
- Length does not silently grant damage. Mass and damage remain separate.
- Raw strokes remain frozen. Held, projectile, and impact visuals remain
  separate; only a semantic thrown object may reuse player ink as a projectile.
- Existing role costs remain executed: Bow is first-body and shield-blocked;
  Piercing keeps committed startup and 100%/70%/45% body decay; Boomerang remains
  locked until return; thrown blast pays travel/detonation/cooldown.
- Every scene exit, Retry, Reforge, defeat, and fixture switch cleans up active
  projectiles, timers, queued attacks, touch state, and detached held visuals.
- Simulation outcome must be stable at 30, 60, and 120 physics updates per
  second and after one bounded long frame.

## Explicit exclusions

- No replacement or deletion of the fixed-height Combat Lab.
- No M1B2 drawing/image interpretation and no Provider, Worker, D1, Schema, or
  PowerBudget changes.
- No Weapon Physics B2 root/body/tip contact regions.
- No cadence/burst/automatic firearm field or machine-gun implementation.
- No charged grenade throw.
- No jump, crouch, platforming, dodge, independent skill input, resource meter,
  combo system, second weapon, inventory, upgrade, route, boss, production
  level, production art, voice, account, sharing, monetization, or multiplayer.

## Acceptance matrix

| ID | Criterion |
| --- | --- |
| M2B-01 | Existing side-view Combat Lab remains the default and passes its prior regression suite |
| M2B-02 | Belt scene opens only through an explicit prototype entry and cannot accidentally replace production combat |
| M2B-03 | Player moves in X/Y, respects room bounds, and sorts by battlefield depth |
| M2B-04 | Landscape touch movement and ATTACK can be held simultaneously without losing either input |
| M2B-05 | Auto-facing chooses a deterministic eligible target in front of the player and never snaps to an invalid/dead target |
| M2B-06 | Melee depth width is visible and matches its executable contact area |
| M2B-07 | Straight projectile, Piercing, Boomerang, and thrown blast follow visibly different two-dimensional paths |
| M2B-08 | Straight projectile stops at the first body and remains shield-blocked |
| M2B-09 | Piercing keeps committed startup, shield bypass, three-body limit, and 100%/70%/45% damage |
| M2B-10 | Boomerang cannot overlap activations and returns before the next accepted attack |
| M2B-11 | Thrown blast shows travel/landing/explosion phases and damages only inside its ground ellipse |
| M2B-12 | Moving, shield, and grouped encounters can be selected and reset independently |
| M2B-13 | Player can be defeated; enemy encounter can be won; terminal states block further damage and attacks |
| M2B-14 | Retry restores the same fixture and weapon; Reforge exits without losing stable Forge input |
| M2B-15 | 30/60/120 Hz and bounded long-frame simulations produce equivalent hit counts, terminal state, and cleanup |
| M2B-16 | 844x390, 852x393, and 915x412 show the complete room and touch controls without clipping or overlap |
| M2B-17 | Portrait gate, keyboard restoration, Safari toolbar changes, and the stable Canvas do not regress |
| M2B-18 | Godot tests, Web build, Sites preview build, Chromium, and version-matched WebKit pass with no new application console errors |
| M2B-19 | **CONFIRMED:** the product owner completed the real-iPhone Safari checklist on 2026-07-27, reported all items passed, and selected belt combat as the future primary direction |
| M2B-20 | A living enemy blocks direct body overlap but its foot-sized collision does not prevent a diagonal depth escape; every defeated enemy immediately becomes non-blocking and Retry restores living collision |
| M2B-21 | Straight and piercing projectiles lock one bounded two-dimensional target point at attack start, launch from the actual muzzle toward that point, and cannot retarget or become near-vertical during startup |

## Product decision gate

The belt scene advances only if physical-device evidence shows that:

1. all five attack roles are easier to distinguish spatially;
2. X/Y movement adds deliberate positioning rather than touch confusion;
3. no one weapon solves moving, shield, and grouped encounters by default;
4. the player can explain the chosen weapon's advantage and executed cost; and
5. keyboard, viewport, touch, and Forge-to-combat continuity retain their
   accepted behavior.

If the evidence is neutral or worse, retain the fixed-height side view. A
working prototype alone is not acceptance of the belt-combat direction.

**CONFIRMED PASS:** the automated, browser, and physical-iPhone evidence passed,
and the product owner approved belt combat as the future primary combat
direction on 2026-07-27. The current PR retains explicit prototype routing and
the old Combat Lab; making belt combat the public default requires a later
integration acceptance gate.

## Physical-device result

**CONFIRMED:** commit
`39b077ed4d41dd4a3af3bdae3927556a52e6a03a` passed the product owner's complete
real-iPhone Safari checklist on 2026-07-27. This closes the prototype's
physical-device blocker, including corrected two-dimensional Piercing aim,
diagonal escape around living enemies, immediate non-blocking defeated enemies,
Retry collision restoration, simultaneous touch movement/attack, lifecycle
cleanup, orientation recovery, and Safari toolbar recovery.

**CONFIRMED:** after reviewing the accepted prototype, the product owner chose
belt combat as Project Forge's future primary combat direction. This is a
product-direction decision, not authorization to deploy it as the public default
or to remove the side-view regression baseline.

## Integration closure

**CONFIRMED:** PR #15 final HEAD `5655619` passed two required `validate`
checks, received an independent Reality Checker `GO`, and merged to `main` as
`ee2583c3664d4013d165d7276f8222238cd49152`. Tag
`v0.5.0-m2-belt-spike` records that accepted Git milestone.

**CONFIRMED:** no production deployment was performed. The production Site
remains Version 30 on the B1.5 runtime; the belt scene remains an explicit route
and the old side-view Combat Lab remains the public default.
