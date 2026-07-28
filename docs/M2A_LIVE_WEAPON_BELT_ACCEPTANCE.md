# M2A Live Weapon Belt Integration Acceptance

Status: **CONFIRMED for repository integration / TO VALIDATE for the final
fixed Sites deployment**

Authorized by the product owner after the M2 belt-combat comparison spike passed
automated, browser, and physical-iPhone Safari acceptance and belt combat was
selected as Project Forge's future primary combat direction.

## Product question

Can the accepted Forge and real text-interpreter flow hand its exact validated
weapon and original drawing into the accepted belt battlefield without changing
the weapon contract, losing input, exposing test fixtures, or regressing the
side-view rollback baseline?

## Fixed baseline

- **CONFIRMED:** branch from `main` after the accepted M2 prototype merge and
  governance closeout.
- **CONFIRMED:** the normal player still starts at Forge, draws a weapon, enters
  Description text, receives a guarded interpretation, and explicitly confirms
  it before combat.
- **CONFIRMED:** only a repaired, runtime-valid, PowerBudget-valid `WeaponSpec`
  may enter combat.
- **CONFIRMED:** original strokes and the frozen `DrawingGeometryProfile` cross
  the scene boundary by deep copy and are never destructively rewritten.
- **CONFIRMED:** belt combat is the player combat destination after confirmation.
  The accepted side-view Combat Lab remains executable through an explicit
  Developer/QA route for regression and rollback.
- **CONFIRMED:** this milestone uses no paid Provider call in automated tests.

## Included

1. A one-shot Forge-to-belt route payload containing the confirmed
   `WeaponSpec`, original strokes, frozen geometry profile, and bounded
   Description draft.
2. Fail-closed validation at both sides of the route. Missing, stale, malformed,
   invalid, or over-budget data cannot equip a fixture or fallback weapon.
3. Normal-player belt presentation using the confirmed weapon, with fixture and
   encounter selectors hidden.
4. Developer/Test Mode retaining deterministic fixture and encounter controls.
5. Reforge returning to Forge with the player's drawing and Description restored.
6. The existing five attack modules, four elements, lethal loop, touch controls,
   orientation gate, safe areas, and mobile Canvas behavior.
7. An explicit side-view QA route that does not become the normal player path.

## Regression invariants

- Provider, Worker, D1, model, timeout, idempotency, quota, cost, response
  revision, Schema, runtime repair, and PowerBudget behavior do not change.
- Provider failure never creates an equipable weapon or enters combat.
- The exact confirmed attack pattern, element, physical profile, derived timing,
  power score, corrections, and player strokes reach belt combat.
- Held, projectile, and impact visuals remain separate. Only a semantic thrown
  object may reuse player ink as its projectile.
- Reforge, Retry, victory, defeat, scene exit, and stale-route failure clear
  transient attacks, input state, timers, and detached visuals.
- A consumed route payload cannot be replayed by refresh or a later scene reload.
- Normal-player presentation never exposes fixture weapon buttons, encounter
  matrix controls, internal audit labels, or a test-only fallback.
- The accepted side-view regression route remains runnable and unchanged in
  behavior.

## Explicit exclusions

- No M1B2 drawing/image interpretation.
- No public `WeaponSpec` Schema or PowerBudget change.
- No Provider, Worker, D1, secret, quota, or deployment-business-logic change.
- No Weapon Physics B2 contact regions.
- No cadence, burst, automatic firearm, charged grenade, jump, crouch, dodge,
  skill, inventory, upgrade, level, boss, production art, voice, account,
  sharing, monetization, or multiplayer work.
- No deletion of the side-view Combat Lab.
- No production deployment before an isolated preview and physical-iPhone gate.

## Acceptance matrix

| ID | Criterion |
| --- | --- |
| M2A-01 | A normal confirmed Forge result enters belt combat, not the side-view Combat Lab |
| M2A-02 | Belt combat equips the exact confirmed runtime-valid `WeaponSpec`; attack pattern, element, stats, power, corrections, physical profile, and derived timing match |
| M2A-03 | Original strokes and geometry reach belt combat by deep copy and the held weapon remains recognizable and correctly scaled |
| M2A-04 | Missing, malformed, stale, invalid, or over-budget payload fails closed and never equips a fixture, fallback, or prior weapon |
| M2A-05 | The one-shot payload is consumed exactly once and cannot leak into Retry, refresh, later Forge requests, or a newer revision |
| M2A-06 | Provider error, cancellation, timeout, or non-confirmable result cannot enter either combat scene |
| M2A-07 | Normal player sees no fixture weapon buttons, encounter matrix controls, or internal prototype labels |
| M2A-08 | Developer/Test Mode retains deterministic fixture selection, moving/shield/group encounters, and complete diagnostic state |
| M2A-09 | `melee_slash`, `straight_projectile`, `boomerang`, `area_blast`, and `piercing` each execute from a live routed weapon |
| M2A-10 | `normal`, `fire`, `ice`, and `electric` each preserve their validated element and executable effect |
| M2A-11 | Bow keeps player ink held and fires a deterministic arrow; grenade throws an ink copy, lands, explodes, and restores held ink; sword stays held; boomerang leaves and returns |
| M2A-12 | Reforge exits belt combat and restores the same Description and original drawing without equipping a fallback |
| M2A-13 | Retry keeps the same confirmed weapon and cleanly resets the encounter |
| M2A-14 | Victory, defeat, Reforge, and scene exit remove projectiles, timers, queued attacks, touch state, and detached held visuals |
| M2A-15 | The side-view Combat Lab remains available only through an explicit Developer/QA route and passes its existing regression suite |
| M2A-16 | 30/60/120 Hz and one bounded long frame preserve attack counts, terminal state, payload identity, and cleanup |
| M2A-17 | 844x390, 852x393, and 915x412 retain the complete Forge and belt controls with no clipping or overlap |
| M2A-18 | Portrait gate, Description keyboard, orientation recovery, Safari toolbar changes, and simultaneous movement/ATTACK do not regress |
| M2A-19 | Godot tests, Worker/security tests, Web build, Sites preview build, Chromium, and version-matched WebKit pass with no new application console errors |
| M2A-20 | An isolated public preview uses new assets/version identity and passes the product owner's physical-iPhone checklist before merge or production deployment |

## Delivery gate

M2A is not complete merely because the route opens the belt scene. Completion
requires:

1. deterministic evidence for exact payload identity and fail-closed lifecycle;
2. all five attacks and all four elements through the live integration path;
3. side-view regression evidence;
4. Chromium and version-matched WebKit evidence at the three landscape sizes;
5. an isolated public preview with distinct release identity; and
6. explicit physical-iPhone Safari acceptance by the product owner.

The product owner accepted the M2A integration on 2026-07-28 after physical
iPhone testing of the isolated preview and automated Chromium/WebKit evidence
for the final facing/CJK corrections. PR #18 was then merged as `7fa6f7e`.

The final corrected Sites archive was built but was not uploaded because the
authenticated Sites editor was unavailable while the product owner was away
from a computer. This is not represented as a live-verified deployment.
Production therefore remains on the prior stable B1.5 Sites Version 30.

Keep the branch, worktree, prior stable deployment, accepted M2 tag, screenshots,
logs, corrected archive, and rollback evidence. Do not clean retained evidence
or begin M1B2 without a separate milestone decision.

## Current evidence

- **CONFIRMED (local automated):** `scripts/test.ps1` passed on 2026-07-27,
  including 32 deterministic matrix cases / 1,187 assertions, 243 M2 belt/M2A
  assertions, main-scene smoke, Worker, WASM, Interpreter, D1, Anthropic,
  provider-budget, and security regression tests.
- **CONFIRMED (build):** fresh `scripts/build_web.ps1` and
  `scripts/build_sites_preview.ps1` exports passed from the current worktree.
- **CONFIRMED (browser automation):** the provider-free live-route suite passed
  Chromium and WebKit at 844x390, 852x393, and 915x412. It exercised all five
  live attack patterns, all four elements, exact route identity, Retry, Reforge,
  invalid-route fail-closed recovery, one-shot refresh consumption, and the
  explicit side-view regression route. Both runs reported zero provider calls
  and zero application console errors.
- **CONFIRMED (physical iPhone):** the product owner exercised the isolated M2A
  preview on iPhone Safari, accepted the belt integration, and identified two
  final minor defects: left-facing attack visuals and CJK request-progress
  glyphs.
- **CONFIRMED (final corrections):** PR #18 HEAD `617b465` uses one canonical
  attack direction for held ink, slash effects, projectiles, and impact visuals.
  The Web Description overlay preserves exact Unicode through the frozen request
  snapshot while Godot shows a bounded English progress label instead of
  rendering unsupported CJK fallback glyphs.
- **CONFIRMED (final automated gate):** the corrected candidate passed the full
  Godot/Worker/WASM/Interpreter/D1/Anthropic/budget/security suite, Web and Sites
  builds, Chromium and WebKit runs for all five attacks in both directions, and
  exact `冰冻手榴弹` snapshot/request-body checks. Both required GitHub `validate`
  checks passed.
- **CONFIRMED (repository integration):** the product owner accepted the final
  corrections without requiring a second device deployment, and PR #18 merged
  as `7fa6f7ee2684b44af2c51796d763c80910fff5fd` on 2026-07-28.
- **TO VALIDATE (deployment only):** the corrected archive
  `sites-m2a-preview-f5e0896.tar.gz` has not been uploaded to Sites. The existing
  public production deployment remains B1.5 Sites Version 30 and must not be
  described as running M2A.
