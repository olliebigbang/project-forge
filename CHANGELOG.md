# Changelog

## v0.3.0-weapon-physics-b1 — 2026-07-22

### Added

- A deterministic `GeometryEvidence -> PhysicalProfile -> CombatDerived`
  authority chain for controlled held-melee physicality.
- A 1/4/8/16-grid by light/balanced/heavy validation matrix, including an
  internal ultra-short tier, one authoritative attack cycle, and one buffered
  input slot.

### Fixed

- Kept visible grip-to-tip length, HUD Range, and executable hit reach on the
  same frozen bounded value.
- Made visible swing cadence and actual input acceptance reflect the same
  startup/active/hit/recovery/cooldown cycle.
- Removed cross-axis thickness from reach derivation while preserving mass as a
  separate bounded handling proxy.

### Verified

- Physical-iPhone combat-feel acceptance on the isolated B1 preview.
- PR #7 CI and merge commit `b37e524`.
- Stable Sites Version 24 from that exact commit, HTTP 200, Chromium/WebKit
  production regressions, and one successful guarded Anthropic smoke request.
- Stable tag `v0.3.0-weapon-physics-b1`; rollback remains Sites v23 plus
  `v0.2.1-m1b1.2`.

### Deferred

- B1.5 weapon-role and near/ranged compensation.
- B2 contact regions, sweet spots, interruption, shield/multi-target behavior,
  and matching feedback.
- M1B2 visual interpretation and all production-scale features.

## v0.2.0-m1b1 — 2026-07-20

### Added

- Same-origin real text-to-weapon interpretation through Anthropic native
  Messages API and Structured Outputs, pinned to
  `claude-haiku-4-5-20251001`.
- WeaponSpec v2 form, delivery, trajectory, impact, and area-effect semantics.
- Deterministic held/projectile/impact visual bundles for Bow, Grenade, Sword,
  Boomerang, and other projectile kinds.
- D1 request idempotency, quota, and USD 5 lifetime provider-budget enforcement.
- Request snapshots, explicit non-equipable interpretation errors, confirmation,
  MODIFY, retry, feedback, and cancellation/stale-response handling.

### Fixed

- Preserved Description and drawing state across keyboard, forge, route, retry,
  and cancellation boundaries.
- Prevented failed or non-invoked provider responses from equipping Practice
  Sketchblade or entering combat.
- Preserved player-stroke aspect ratio from actual bounds with uniform scaling.
- Kept bows held while procedural arrows fly; added centred grenade arc,
  independent explosion, and cooldown restore; preserved melee and boomerang
  visual rules.
- Prevented iOS Safari keyboard focus from resizing or moving the Godot Canvas
  off screen; added a safe-area compact text-entry mode.
- Bounded chunked Worker request bodies to 8192 bytes before D1 or provider work.
- Made CI build and verify the actual injected, chunked Sites deployment bundle.

### Verified

- Real iPhone Safari acceptance by the product owner.
- Godot 629 assertions, complete Worker/Interpreter/D1/Anthropic/security tests,
  reproducible Web/Sites build, Chromium, and Playwright WebKit regressions.
- Controlled real Claude matrix and grenade/bow evidence under the USD 5 hard cap.

### Deferred

- M1B2 drawing semantic understanding, voice, production art/levels, accounts,
  sharing, monetization, and multiplayer.
