# M1B1.2 Absolute Weapon Reach Acceptance

Status: **CONFIRMED complete and released after physical iPhone acceptance on
2026-07-22**

Historical record — superseded by the v0.3.0 Weapon Physics B1 closure.

M1B1.2 is an isolated correction after the accepted M1B1 interpreter and
M1B1.1 player-interface simplification. It is not M1B2 and does not add visual
AI interpretation, a new provider, new Schema fields, production art, or a new
weapon-contact system.

## Accepted source and public candidate

- Pull request: `#6`, `codex/fix/absolute-weapon-reach`.
- Source commit tested publicly: `5567eeb25fb6b85cda55554a9eddb772a791c9ef`.
- Public candidate: Sites v22 with release marker `v22-reach-5567eeb`.
- Dependency: PR `#6` is stacked on PR `#5` at
  `5ce5bdaba4f8df9c8b09659cde3297e08218dfd7`.

## Confirmed outcome

- A FORGE request freezes raw stroke bounds and canvas size without rewriting
  the original strokes.
- Short, standard, and full-canvas long held-melee drawings have strictly
  increasing bounded effective reach.
- One `effective_reach` drives grip-anchored held length, visible tip, melee hit
  boundary, and HUD Range.
- The former hidden `range + 96` hit allowance is removed.
- The same inverse speed drives swing hit timing, recovery, cooldown, and the HUD
  summary. Damage is not increased by drawing length.
- A melee attack locks its starting facing through hit and recovery, preventing
  reverse movement from visually flipping away from the recorded hit direction.
- The product owner confirmed on a physical iPhone Safari that the full-canvas
  long sword is materially longer in combat and that the M1B1.2 reach correction
  basically passes. On 2026-07-22 the owner approved closure with the deeper
  contact and handling work separated into the roadmap below.

## Required regression gate

- Deterministic geometry, Schema/runtime parity, PowerBudget, interpreter,
  Worker/D1/security, and all existing unit tests pass.
- Web import/parse and export complete with Godot 4.7.1.
- Sites preview bundle builds from the same source revision.
- Chromium and WebKit confirm short/standard/long visible reach, hit boundaries,
  timing order, facing lock, mobile viewport stability, and no new console error.
- M1B1 input preservation, keyboard recovery, bow/grenade/sword/boomerang visual
  roles, five attacks, four elements, and Developer/Test capabilities do not
  regress.

Run:

```powershell
./scripts/test.ps1
./scripts/build_web.ps1
./scripts/build_sites_preview.ps1
```

## Explicit known limitations

- **CONFIRMED superseded by Weapon Physics B1:** The M1B1.2 linear speed
  exchange was replaced by the accepted B1 controlled curve with separately
  observable startup, active, hit, recovery, cooldown, and bounded mass proxy.
  Material density, balance point, and moment of inertia remain **TO VALIDATE**.
- **TO VALIDATE (Weapon Physics B2):** The current grip-to-tip melee capsule
  applies one damage value. A handle/root should not automatically damage like a
  blade tip, but contact regions and sweet spots require collision plus matching
  VFX, sound, hit stop, damage-number, and debug feedback and are intentionally
  deferred together.
- **TO VALIDATE:** Grip/orientation inference remains deterministic
  left-to-right. The current geometry logic does not claim visual understanding.
- **CONFIRMED:** These limitations do not restore the former fixed-size weapon or
  hidden reach mismatch and therefore do not block this narrowly defined release.

## Final pre-merge verification

Executed on 2026-07-22 from the PR `#6` worktree after the acceptance and roadmap
documentation update:

- Godot 4.7.1 import/parse, deterministic suite, and main-scene smoke: **PASS**;
  32 matrix cases and 677 assertions passed, 0 failed.
- Sites static worker: **4/4 PASS**; WASM chunk loader: **1/1 PASS**.
- Interpreter: **77/77 PASS**; durable D1 guard: **9/9 PASS**; Anthropic adapter:
  **17/17 PASS**; provider budget: **14/14 PASS**; Anthropic security regression:
  **11/11 PASS**.
- Godot Web export and exact Sites preview bundle: **PASS**.
- Chromium and WebKit absolute-reach regression: **3/3 cases per browser PASS**;
  short/standard miss at the controlled 170 px gap, long hits, reach and speed
  remain monotonic, reverse movement cannot flip the active swing, and console
  errors are 0.
- Chromium and WebKit M1B1 blocker regression: **4/4 weapon cases per browser
  PASS**; bow, grenade, sword, boomerang, keyboard, toolbar, and three orientation
  cycles pass with description preserved and console errors 0.
- Local browser reports and screenshots are retained under
  `output/playwright/m1b1-2-final/` and intentionally remain outside Git.

## Release and rollback boundary

PR `#5` and PR `#6` were integrated in dependency order and the complete gate
was rerun. Weapon Physics B1 later closed on `main` and the stable line is now
`v0.3.0-weapon-physics-b1`. Retain `v0.2.0-m1b1`, v22 evidence, release archives,
branches, and worktrees until the product owner separately authorizes cleanup.
