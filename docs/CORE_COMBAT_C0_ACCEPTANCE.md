# Core Combat C0 — Lethal Micro-Playtest Acceptance

Status: **CONFIRMED diagnostic implementation complete on 2026-07-25;
technical checks pass; gameplay balance gate failed**

Result: `docs/CORE_COMBAT_C0_REPORT.md`

## Purpose

- **CONFIRMED:** C0 validates the first fail-able loop:
  `Forge -> Confirm -> Combat -> Victory/Defeat -> Retry/Reforge`.
- **CONFIRMED:** C0 starts from corrected Weapon Physics B1.5 candidate
  `ec6161357c2b10843d7c08f6c32bb1b1b5ae9d68` without declaring that candidate
  production-balanced or merged.
- **CONFIRMED:** C0 exists because the safe target lab cannot validate exposure,
  recovery risk, ranged safety, space control, defeat, or the desire to reforge.
- **TO VALIDATE:** natural short, standard, and long held-melee drawings each
  create a useful but non-dominant combat choice under one deterministic threat.

## Scope boundaries

### Included

- A deterministic Forge input-integrity gate.
- Player health, damage, death, and readable health feedback.
- One deterministic enemy that approaches, telegraphs, attacks, recovers, can
  damage the player, and can be defeated.
- Victory, defeat, Retry, and Reforge states.
- A bounded player/enemy separation rule; neither actor may pass through the
  other without consequence.
- Provider-free QA observations for first-hit time, TTK, damage taken, whiffs,
  movement distance, attack count, and terminal state.
- Controlled natural-drawing comparisons for short, standard, and long melee.

### Excluded

- Weapon Physics B2 contact regions, root/tip sweet spots, material physics, or
  interruption systems.
- M1B2 image/vision understanding.
- New paid-provider calls, Provider/Worker/D1 changes, public `WeaponSpec`
  fields, Schema changes, or `PowerBudget` pricing changes.
- Jump, crouch, dodge, independent special-skill input, stamina/mana, combos,
  production levels, production art, accounts, sharing, monetization, or
  multiplayer.

## Input-integrity gate

- **CONFIRMED:** a single point, zero-length path, or accidental micro-tap is
  not a weapon and must not enter provider compilation or become equipable.
- **CONFIRMED:** rejection preserves the drawing and Description, presents a
  concise actionable message, and permits immediate editing.
- **CONFIRMED:** a deliberately drawn natural short weapon remains valid; the
  gate must not erase the accepted `ultra_short` role.
- **TO VALIDATE:** exact minimum point count, accumulated path length, and
  non-zero-bounds thresholds are deterministic implementation constants selected
  from tap/short-line/rotated/curved fixtures rather than hidden product claims.
- **TO VALIDATE:** isolated outlier points are recorded as a geometry-risk
  observation in C0; robust outlier rejection is not silently invented unless a
  failing acceptance fixture requires it.

## Lethal-loop contract

- **CONFIRMED:** an idle player must be defeatable by the single enemy.
- **CONFIRMED:** the enemy attack has visible telegraph, active hit, and recovery
  phases driven by one deterministic timing authority.
- **CONFIRMED:** one enemy attack can damage the player at most once.
- **CONFIRMED:** enemy defeat produces Victory and stops further enemy damage.
- **CONFIRMED:** player defeat produces Defeat and blocks further player attacks.
- **CONFIRMED:** Retry restarts the same controlled combat with the current
  weapon; Reforge returns to preserved Forge input.
- **CONFIRMED:** normal-player C0 presentation contains only readable health,
  threat, result, and action feedback. Metrics and event traces remain in QA.
- **ASSUMPTION:** a controlled C0 fight should normally resolve within
  30–60 seconds; exact production pacing is not decided.

## Controlled comparison

- **CONFIRMED:** short, standard, and long fixtures use the same normal element,
  base damage, enemy, starting state, and deterministic input sequence.
- **CONFIRMED:** drawing length continues to control reach/cadence through the
  accepted B1 authority chain; C0 does not grant length-based damage.
- **TO VALIDATE:** long reach reduces exposure or damage taken enough to justify
  its slower cycle.
- **TO VALIDATE:** short cadence creates useful close-range pressure without
  simultaneously dominating first-hit time, TTK, and damage taken.

## Failure gate

C0 fails and must return to the relevant earlier system if any is true:

1. A tap or zero-length stroke compiles or equips a weapon.
2. An idle player cannot lose.
3. Victory or Defeat leaves combat actions active or produces duplicate terminal
   transitions.
4. Retry or Reforge loses the current drawing/Description unexpectedly.
5. Player and enemy can freely cross through each other.
6. Under the controlled comparison, short melee wins first-hit time, TTK, and
   damage taken simultaneously.
7. Long reach produces no observable exposure advantage.
8. Keyboard, portrait gate, Safari toolbar recovery, existing weapon roles,
   Schema, `PowerBudget`, D1, or provider-safety behavior regresses.

## Acceptance matrix

| ID | Criterion |
| --- | --- |
| C0-01 | Tap, one-point, zero-length, and micro-stroke input are rejected before compilation |
| C0-02 | Natural short, standard, long, rotated, and curved drawings remain forgeable |
| C0-03 | Rejection preserves strokes and Description and shows actionable feedback |
| C0-04 | Player HP is visible, bounded, auditable, and cannot fall below zero |
| C0-05 | Enemy approach, telegraph, strike, and recovery are visually distinct |
| C0-06 | One enemy attack applies at most one damage event |
| C0-07 | An idle player reaches Defeat within a bounded deterministic time |
| C0-08 | The enemy can be defeated and Victory is emitted exactly once |
| C0-09 | Defeat blocks player attacks and enemy damage; Victory blocks enemy attacks |
| C0-10 | Retry restores the same weapon and clean combat state |
| C0-11 | Reforge restores the pre-combat drawing and Description |
| C0-12 | Player/enemy separation prevents free pass-through at both arena edges |
| C0-13 | QA records first-hit time, TTK, damage taken, whiffs, movement distance, and attacks |
| C0-14 | Controlled short/standard/long fixtures share damage, element, enemy, and input sequence |
| C0-15 | The dominance failure gate is evaluated and serialized |
| C0-16 | Five attack patterns and four elements retain their B1.5 executable behavior |
| C0-17 | `scripts/test.ps1`, `scripts/build_web.ps1`, and `scripts/build_sites_preview.ps1` pass |
| C0-18 | Chromium and WebKit pass at 844x390 with zero new application console errors |
| C0-19 | Keyboard, orientation, safe-area, and Safari toolbar simulations do not regress |
| C0-20 | A separate preview passes physical-iPhone review before merge |

## Delivery gate

- **CONFIRMED:** automated tests use deterministic or simulated inputs only and
  make no Anthropic request.
- **CONFIRMED:** implementation remains isolated on
  `codex/feat/core-combat-c0`.
- **CONFIRMED:** no merge, stable deployment, tag, branch deletion, worktree
  cleanup, B2, or M1B2 begins before explicit product-owner acceptance.
