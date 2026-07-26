# Weapon Exposure B1.5 — Strategy Matrix Acceptance

Status: **CONFIRMED after corrected automation and physical iPhone acceptance**

## Purpose

- **CONFIRMED:** C0 proved that the lethal harness works, but its original
  controlled driver always advances into contact and therefore cannot, by
  itself, measure the defensive value of long reach.
- **CONFIRMED:** the frozen C0 diagnostic commit is `cbd7399`.
- **CONFIRMED:** the task first corrects the experiment, then permits only a
  bounded correction inside the existing B1 timing authority if the fair matrix
  still fails.
- **CONFIRMED:** short, standard, and long melee form a non-dominant set in the
  rebuilt Chromium and WebKit matrix.

## Strategy contract

### Pressure

- Movement and attack begin in the same input dispatch.
- The controller continues advancing and accepting attacks until a terminal
  result or the existing bounded timeout.
- **CONFIRMED:** short melee has the fastest pressure TTK. This is its intended
  cadence advantage and is not automatically a balance failure.

### Spacing

- The controller may read only public/runtime facts shared by every melee
  weapon: `effective_reach`, actor positions, arena bounds, attack readiness,
  and the enemy's visible phase.
- It must not branch on `role_id`, fixture name, or short/standard/long labels.
- One formula defines the engagement band:

  `hold_gap = grip_offset + effective_reach - margin`

- Constants are **CONFIRMED for this automated gate**:
  `grip_offset=18px`, `margin=10px`, and `hysteresis=6px`.
- Outside the band the player advances or retreats; inside it the player holds
  position and attacks.
- The same controller is tested from two bounded initial gaps: 220px and 360px.
  Infinite kiting or leaving the arena cannot pass.
- Mirrored staging remains **TO VALIDATE** because the existing C0 fixture API
  does not expose a reliable mirror command.

## Gameplay gate

The strategy matrix passes only if both Chromium and WebKit establish:

1. Pressure TTK preserves `short < standard < long`.
2. Across both starting gaps in Spacing, long takes at least one full enemy
   strike (`20` damage) less than short. Raw per-gap values remain recorded.
3. Across both starting gaps in Spacing, neither standard nor long takes more
   total damage than short. Long and standard are not ordered against each
   other: standard can trade less reach for a faster kill, while long trades
   cadence for spacing, and damage is quantized in 20-point strikes.
4. Across Pressure and Spacing together, no one reach role wins first-hit time,
   TTK, and damage taken.
5. Technical C0 gates, provider-call count, console safety, terminal freeze,
   touch targets, collision, keyboard, and orientation remain unchanged.

Passing this matrix means the candidate has a demonstrable tactical trade under
two rational policies. It does not authorize B2 or M1B2.

## Runtime correction

The fair baseline matrix still showed short dominance, so the first authorized
runtime candidate revised `CombatDerived.REACH_CYCLE_ANCHORS` while preserving
`short < standard < long`, fixed damage, existing reach, and independent mass.

- Base anchors: `72:0.50s`, `92:0.60s`, `120:0.71s`, `199:0.95s`,
  `228:1.01s`.
- Balanced C0 complete cycles:
  short `0.549s`, standard `0.781s`, long `1.099s`.
- The reserved second candidate—limiting only forward movement during the
  existing held-melee pre-hit phase—was not needed and remains unauthorized.

No role-specific enemy, hidden short-weapon cooldown, reach-scaled knockback,
contact region, hit-stun, interruption, or sweet spot is authorized here.

## Automated result

- **CONFIRMED:** Chromium and WebKit pass Pressure TTK, Spacing exposure, and
  combined non-dominance gates after rebuilding the Web export.
- **CONFIRMED:** exact-commit Spacing total damage is Chromium `60/0/20`
  and WebKit `60/20/0` for short/standard/long.
- **CONFIRMED:** no forward-movement restriction or second runtime correction
  was required.
- **CONFIRMED:** the product owner accepted Sites Version 29 on a physical
  iPhone Safari on 2026-07-27. The accepted source is PR #12 HEAD `1365f0d`.

See `docs/WEAPON_EXPOSURE_B1_5_REPORT.md`.
The reopened mobile blocker diagnosis and correction evidence is in
`docs/B1_5_IPHONE_INPUT_VIEWPORT_REPORT.md`.
The strategy evidence was generated from
`f12bb5aac14b616b3ae6f7d7bd9292fb2e0f336c` under
`output/playwright/b1-5-strategy-matrix-f12bb5a/`.
The accepted mobile blocker correction and public preview are bound to
`1365f0d420a77cb03efc3d83850ebecbae7c90dd` and Sites Version 29.
