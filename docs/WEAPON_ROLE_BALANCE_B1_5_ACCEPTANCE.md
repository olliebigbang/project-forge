# Weapon Physics B1.5 Role Balance Acceptance

## Status and authorization

- **CONFIRMED:** the product owner authorized Weapon Physics B1.5 on 2026-07-23.
- **CONFIRMED:** the original implementation was isolated under GitHub Issue
  #10 on `codex/feat/weapon-role-balance-b1-5`, based on `82d0a39`. The accepted
  complete integration is PR #12 from `codex/fix/b1-5-iphone-input-viewport`.
- **CONFIRMED:** each supported weapon role expresses a readable advantage and
  an executed deterministic cost in the automated matrix and accepted physical
  iPhone preview. Equal raw DPS is not the target.
- **CONFIRMED (2026-07-24 product correction):** in the current fixed-height
  side-view combat, a 7 px versus 11 px projectile radius does not create a
  reliably perceptible aiming cost. Piercing must therefore pay through an
  executed charge/movement commitment and deterministic per-body damage decay;
  narrow collision remains diagnostic geometry, not its primary balance claim.
- **CONFIRMED:** B1.5 is not Weapon Physics B2 and does not start M1B2.

## Product question

Does the existing deterministic weapon system make short, standard and long
melee weapons, straight ranged weapons, thrown blasts, boomerangs and piercing
weapons play as distinct roles, while keeping their strengths bounded by real
timing, reach, travel, targeting or recovery costs?

## Regression locks

- Provider output remains untrusted semantic data. Local deterministic code owns
  every numeric role and combat value.
- The public `WeaponSpec` JSON Schema does not expand in B1.5.
- `GeometryEvidence -> PhysicalProfile -> CombatDerived` remains the melee
  authority chain. Raw strokes remain frozen.
- One `effective_reach` continues to own held-melee rendering, HUD Range and the
  real hit boundary. One complete cycle owns startup, active, hit, recovery,
  cooldown and input acceptance.
- Every repaired spec must remain runtime-valid, schema-compatible, auditable and
  at or below the existing 100-point `PowerBudget` cap.
- Five attack patterns, four elements and stationary, moving, shield and grouped
  targets remain executable.
- Accepted iPhone Safari Canvas, Description overlay, safe-area, portrait gate,
  keyboard and recovery behavior cannot regress.
- B1.5 automated role tests are provider-free and must not consume AI budget.

## Role hypotheses

| Role | Intended advantage | Required deterministic cost |
| --- | --- | --- |
| Short melee | Very fast cycle and responsive repeat attacks | Short real reach and greater exposure |
| Standard melee | General-purpose reach and cadence | No extreme specialist advantage |
| Long melee / polearm | Space control and long real hit reach | Slow commit and recovery |
| Straight ranged | Safe reach and a clear projectile path | Travel time, miss risk and bounded single-target value |
| Thrown blast / grenade | Group damage at a chosen landing area | Arc/detonation delay, cooldown and lower single-target efficiency |
| Boomerang | Outbound and return opportunities | Longer completion, path dependence and self-stagger/recovery |
| Piercing | Multi-body line and shield bypass | Longer committed charge, horizontal movement lock during startup, 100%/70%/45% per-body damage decay, and bounded penetration count |

The existing M1A/Developer `area_blast` profile with held/direct delivery remains
a legal compatibility path. It must be audited explicitly as `direct_blast`, not
misrepresented as a thrown grenade and not counted as a new product role. Its
real advantage is a player-centred multi-body radius; its real cost is proximity
plus the complete cooldown. The seven rows above remain the B1.5 product cases.

All values and thresholds are **CONFIRMED for the B1.5 prototype scope** after
automated evidence and the accepted physical-iPhone preview. Production balance
remains **TO VALIDATE**.

## Acceptance gates

| ID | Criterion | Required evidence |
| --- | --- | --- |
| B1.5-01 | A deterministic, serializable internal role profile identifies all seven product role families and the explicit existing `direct_blast` compatibility path without adding public Schema fields | Godot unit matrix and audit output |
| B1.5-02 | Identical validated semantic input and drawing geometry produce identical role output through local, provider, manual-repair and Developer/Test paths | Deterministic parity tests |
| B1.5-03 | Every role records at least one advantage and one cost that is actually executed, not merely displayed | Role audit plus combat observations |
| B1.5-04 | Short, standard and long melee preserve the accepted B1 reach/cadence/facing-lock/input-buffer contract | Existing B1 matrix plus B1.5 regression |
| B1.5-05 | Non-melee startup, commit, active and recovery values govern actual projectile spawn or blast timing and input acceptance | Timing assertions and browser observations |
| B1.5-06 | A bow remains held and launches only a deterministic projectile visual | Godot and browser regression |
| B1.5-07 | A grenade follows its arc, detonates independently and restores its held visual after cooldown | Godot and browser regression |
| B1.5-08 | A boomerang has bounded outbound/return opportunities and cannot create unbounded overlap | Godot and browser regression |
| B1.5-09 | Piercing has a longer committed startup than straight ranged, locks horizontal movement only during that startup, applies deterministic 100%/70%/45% damage across the first three valid bodies, respects shield rules, and never exceeds the bounded body-hit count | Scenario matrix and serialized per-hit/movement observations |
| B1.5-10 | Stationary, moving, shield and grouped target scenarios can be isolated and reset in QA mode | Provider-free QA command evidence |
| B1.5-11 | Role numbers are finite, bounded, runtime-valid, `PowerBudget <= 100`, and retain derivation/correction reasons | Unit tests and audit records |
| B1.5-12 | The accepted 1/4/8/16-grid x light/balanced/heavy melee matrix remains unchanged | Full regression suite |
| B1.5-13 | All five attack patterns and all four elements still compile and execute | Godot matrix |
| B1.5-14 | Chromium and WebKit pass at 844x390, including keyboard/orientation/toolbars, with zero new application console errors | Browser artifacts and screenshots |
| B1.5-15 | `scripts/test.ps1`, `scripts/build_web.ps1` and `scripts/build_sites_preview.ps1` pass from the final branch HEAD | Command logs and hashes |
| B1.5-16 | A separate public preview passes product-owner physical-iPhone acceptance before merge | Preview identity and owner decision |

## Explicit exclusions

- No B2 contact regions, tip/root/sweet-spot damage, material simulation,
  interruption or production combat feedback.
- No M1B2 visual/drawing semantic interpretation.
- No Provider, model, secret, D1, quota, authentication or deployment-business
  changes.
- No jump, crouch, dodge, production art, levels, voice, accounts, sharing,
  monetization or multiplayer.
- Stable merge, deployment and tagging are authorized only through the accepted
  PR #12 release-closeout workflow. Branch/worktree cleanup and evidence
  deletion remain separately controlled.

## Stop conditions

Stop and return to product review if implementation requires a public Schema
change, weakens the accepted B1 timing/reach authority, weakens `PowerBudget`,
changes Provider/D1 behavior, or depends on B2 contact-region semantics.
