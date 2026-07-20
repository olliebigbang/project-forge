# Changelog

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
