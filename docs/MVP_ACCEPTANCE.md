# M0/M1A Acceptance Plan and Full-MVP Traceability

This file preserves the completed M0 gate and defines the current M1A gate.
`docs/GDD.md` retains the broader product definition; later requirements remain
visible without being silently pulled into the deterministic compiler milestone.
M1A remains open until the replacement deployment passes the user's physical
iPhone Safari acceptance; browser emulation is evidence, not a substitute.

## M1A exit criteria

| ID | Acceptance criterion | Status | Evidence target |
| --- | --- | --- | --- |
| M1A-01 | Public, phone-accessible Web URL; not localhost | **CONFIRMED** | Sites v8 public deployment returns HTTP 200 and exact replacement asset hashes |
| M1A-02 | Public flow covers draw, generate, move, attack, and re-forge | **TO VALIDATE (real iPhone)** | Chromium/WebKit automation passes; physical iPhone remains the final gate |
| M1A-03 | Five attack modules execute and look/behave differently | **CONFIRMED** | Five browser combat runs |
| M1A-04 | Normal, fire, ice, and electric compile and execute | **CONFIRMED** | Matrix plus combat effect checks |
| M1A-05 | Explicit power component calculator enforces 0–100 | **CONFIRMED** | HUD, unit tests, audit JSON |
| M1A-06 | Strong capability creates a corresponding tradeoff | **CONFIRMED** | Matrix invariant and extreme cases |
| M1A-07 | JSON Schema and runtime validation remain in parity | **CONFIRMED** | Automated parity assertions |
| M1A-08 | Missing, illegal, non-finite, extra, and out-of-range data auto-repair | **CONFIRMED** | Fault injection assertions |
| M1A-09 | At least 20 deterministic acceptance inputs | **CONFIRMED — 32** | `tests/m1a_input_matrix.json` |
| M1A-10 | Moving, shield, and grouped targets validate attack tradeoffs | **CONFIRMED** | Target lab and rule tests |
| M1A-11 | Spec, budget, repairs, and results are recorded | **CONFIRMED** | Runtime JSONL and artifacts |
| M1A-12 | Full tests, Web build, public browser console, and mobile layout pass | **TO VALIDATE (real iPhone)** | CI, public Chromium/WebKit automation, and replacement assets pass; physical Safari acceptance remains pending |

## Status vocabulary

- `CONFIRMED`: an explicit requirement or settled decision.
- `ASSUMPTION`: a working default that may change after evidence.
- `TO VALIDATE`: a hypothesis this prototype must test.
- `TBD`: intentionally undecided.

## M0 exit criteria

| ID | Acceptance criterion | Status | Evidence target |
| --- | --- | --- | --- |
| M0-01 | A new Godot 4 2D landscape project runs | **CONFIRMED** | Headless smoke run and editor command |
| M0-02 | Drawing accepts mouse and phone touch | **CONFIRMED** | Desktop and mobile-emulation interaction screenshots |
| M0-03 | Player draws a weapon and enters one text description | **CONFIRMED** | Creation screen |
| M0-04 | Local mock returns a schema-conforming `WeaponSpec`; no key/network required | **CONFIRMED** | Automated unit tests |
| M0-05 | Generated visible weapon preserves player strokes | **CONFIRMED** | Combat screenshot after generation |
| M0-06 | One test character and one training dummy are visible | **CONFIRMED** | Combat screenshot |
| M0-07 | Generated weapon damages the dummy | **CONFIRMED** | Runtime interaction and dummy health readout |
| M0-08 | Melee and straight-projectile forms are demonstrable | **CONFIRMED** | Two deterministic presets and tests |
| M0-09 | UI displays name, damage, attack form, special effect, and weakness | **CONFIRMED** | Weapon card screenshot |
| M0-10 | Player can re-open creation, redraw, and generate another weapon | **CONFIRMED** | Runtime interaction |
| M0-11 | A Web export is produced and served over HTTP | **CONFIRMED** | `build/web/index.html` and browser smoke check |
| M0-12 | Common phone landscape sizes retain usable layout and touch targets | **CONFIRMED (Web emulation)** | 844×390, 915×412, and 1280×720 captures; native devices remain M3 |
| M0-13 | Runnable tests, parse/static checks, smoke check, and Web build pass | **CONFIRMED** | `artifacts/TEST_RESULTS.md` |
| M0-14 | Key screenshots, results, and known limitations are recorded | **CONFIRMED** | `artifacts/screenshots/`, results, README |

## Test scenarios

### Drawing and generation

1. Draw at least two connected strokes with a mouse; clear; draw again.
2. Emulate touch and draw a stroke in a phone landscape viewport.
3. Generate the provided melee example and verify a melee `WeaponSpec`.
4. Re-forge, generate the projectile example, and verify a ranged `WeaponSpec`.
5. Generate with blank or unsupported text and confirm a bounded fallback result.

### Combat

1. Move with `A/D`, arrow keys, and the on-screen hold controls.
2. Place the dummy in melee reach and attack; health must decrease.
3. Generate a projectile and attack from outside melee reach; the projectile must
   travel visibly and decrease dummy health.
4. Confirm the dummy resets after its health reaches zero.

### Layout matrix

| Viewport | Representative use | Gate |
| --- | --- | --- |
| 1280×720 | Desktop baseline / 16:9 | No clipping; all controls visible |
| 844×390 | iPhone-style compact landscape | Drawing, text, generate and combat controls usable |
| 915×412 | Android-style wide landscape | Safe margins and minimum touch targets retained |

## Full-MVP items deliberately deferred

The following GDD requirements are not deleted; they are outside the explicit M0
scope and become later gates:

| Requirement | Planned gate | Status |
| --- | --- | --- |
| Five attack forms and four elements | M1 weapon compiler | **CONFIRMED** |
| Power-budget balancing and 20 input cases | M1 weapon compiler | **CONFIRMED** |
| Production moderation and secure real-AI backend | M1 or later | **TBD** |
| Test monster, boss, complete battle, win/loss/retry | M2 vertical slice | **CONFIRMED** |
| Special ability, dodge, health/cooldowns | M2 vertical slice | **ASSUMPTION** |
| Voice input and device builds | M3 | **CONFIRMED** |

## M1 recommendation gate

Proceed to M1 only if M0 proves: drawing is usable on touch, player strokes remain
recognizable, both attack families are legible, `WeaponSpec` is a stable boundary,
Web performance is acceptable, and no architecture blocker requires replacing the
prototype foundation.
