# Core Combat C0 — Lethal Micro-Playtest Report

Date: 2026-07-25

Status: **CONFIRMED test harness technically complete; CONFIRMED gameplay
balance gate failed; physical-device acceptance and merge are not authorized**

## Scope and provenance

- Branch: `codex/feat/core-combat-c0`
- Base: corrected Weapon Physics B1.5 candidate
  `ec6161357c2b10843d7c08f6c32bb1b1b5ae9d68`
- Runtime: Godot 4.7.1, Web-first, provider-free C0 fixtures
- Contract: `docs/CORE_COMBAT_C0_ACCEPTANCE.md`

C0 did not change the public `WeaponSpec` Schema, `PowerBudget`, Provider,
Worker, D1, or lifetime provider-budget behavior. Browser tests blocked and
counted both `/api/compile-weapon` and provider routes.

## Technical result

The isolated prototype now contains:

- a pre-provider input-integrity gate for empty, one-point, zero-length, and
  accidental micro-stroke ink;
- player health, damage, death, and reset;
- one deterministic enemy with approach, telegraph, strike, recovery, damage,
  defeat, and reset phases;
- Victory, Defeat, Retry, and Reforge;
- collision separation that prevents free player/enemy pass-through;
- committed drawing and Description restoration on Reforge;
- provider-free fixtures and round metrics for first hit, TTK, damage taken,
  whiffs, movement, attacks, damage events, and terminal state.

**CONFIRMED:** the C0 test harness is technically usable. It is not a production
combat loop or a declaration that the current weapon curve is balanced.

## Automated verification

| Gate | Result |
| --- | --- |
| Godot import and script parse | **PASS** |
| Deterministic Godot suite | **PASS — 32 matrix cases, 1,147 assertions, 0 failed** |
| Main-scene runtime smoke | **PASS** |
| Worker/WASM/Interpreter/D1/budget/security suites | **PASS** |
| Web export | **PASS** |
| Sites preview bundle build | **PASS** |
| Chromium 844×390 functional cases | **PASS** |
| WebKit 844×390 functional cases | **PASS** |
| Application console errors | **PASS — 0** |
| Compile/provider calls from C0 browser tests | **PASS — 0** |
| Short/standard/long balance gate | **FAIL** |

The browser matrix passed nine drawing-gate cases, input preservation, idle
Defeat, enemy telegraph/strike/recovery, Retry, Reforge restoration, metric
capture, keyboard Canvas stability, portrait gate, and landscape recovery. It
also verified all of the following before evaluating the deliberately separate
balance gate:

- Victory and Defeat freeze held keyboard movement, touch movement, and attack
  input without changing positions, health, counters, or event logs.
- Victory and Defeat leave zero active projectiles or area effects.
- Retry and Reforge are activated through real Playwright touchscreen taps;
  their final rendered touch height is approximately `47.67 CSS px`.
- Sustained collision pressure from the left and right cannot cross or overlap
  the enemy. Both expanded logical arena edges are enforced at approximately
  `x=70` and `x=1488`.
- Browser cases recorded zero application console errors and zero compile or
  provider calls.

## Controlled comparison

All three fixtures used normal element, 36 damage, the same enemy, the same
starting state, and the same attack/movement driver.

| Browser | Reach fixture | First hit | TTK | Damage taken |
| --- | --- | ---: | ---: | ---: |
| Chromium | short | 2.644 s | 4.017 s | 20 |
| Chromium | standard | 2.750 s | 5.974 s | 40 |
| Chromium | long | 2.773 s | 8.288 s | 60 |
| WebKit | short | 2.371 s | 3.702 s | 20 |
| WebKit | standard | 2.555 s | 5.747 s | 40 |
| WebKit | long | 2.565 s | 8.067 s | 80 |

Browser scheduling causes small timing variation between runs, but both engines
produce the same ordering.

## Gate decision

- **CONFIRMED FAIL:** short melee simultaneously wins time to first hit, TTK,
  and damage taken.
- **CONFIRMED FAIL:** long reach creates no damage-exposure advantage in this
  deterministic lethal scenario.
- **CONFIRMED:** this validates the earlier audit finding that the current
  length/cadence exchange makes short melee dominant when damage is fixed and
  attacking does not create a compensating exposure or commitment cost.

This is a successful diagnostic result for the C0 test harness and a failed
gameplay result for the current B1/B1.5 balance. C0 must not be represented as a
passed milestone, merged to `main`, or used to authorize B2/M1B2.

## Next gate

Return to a narrowly scoped B1/B1.5 cadence/exposure correction using this same
C0 harness. The correction must:

1. preserve the accepted visible reach and real hit-distance authority;
2. keep length and mass as separate dimensions;
3. avoid adding B2 contact regions or M1B2 visual understanding;
4. introduce a readable, executed cost that prevents short melee from winning
   all three controlled metrics;
5. demonstrate an observable long-reach exposure advantage;
6. rerun the full Godot, Chromium, WebKit, mobile-layout, and provider-safety
   gates before any physical-iPhone preview.

Exact balance constants remain **TO VALIDATE**. No tuning is approved by this
report.

## Retained evidence

Local generated evidence is retained under
`output/playwright/core-combat-c0-final/` and is intentionally excluded from
Git. The final Chromium and WebKit reports include the terminal-freeze, rendered
touch-target, bidirectional sustained-collision, arena-boundary, mobile
regression, and controlled-comparison evidence before the expected gameplay
failure. The isolated branch/worktree, build outputs, and evidence must remain
until the product owner separately approves cleanup.
