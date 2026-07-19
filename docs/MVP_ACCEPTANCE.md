# M0/M1A Acceptance Record and M1B1 Gate

This file preserves the completed M0 and M1A gates and points to the active M1B1
acceptance contract in `docs/M1B1_ACCEPTANCE.md`.
`docs/GDD.md` retains the broader product definition; later requirements remain
visible without being silently pulled into the deterministic compiler milestone.
**CONFIRMED:** the product owner completed the v9 physical iPhone Safari
acceptance and formally accepted M1A. Browser automation, public-asset checks,
CI, and the physical-device result together close this gate.

## M1A exit criteria

| ID | Acceptance criterion | Status | Evidence target |
| --- | --- | --- | --- |
| M1A-01 | Public, phone-accessible Web URL; not localhost | **CONFIRMED (v9)** | Sites version 9 returns HTTP 200; public `index.pck` exactly matches the new local SHA-256 `0BDD31A3…` and differs from v8 |
| M1A-02 | Public flow covers draw, edit description, reset, generate, move, attack, and re-forge | **CONFIRMED (real iPhone v9)** | Product-owner physical Safari acceptance passed every creation, combat, keyboard, navigation, and re-forge item |
| M1A-03 | Five attack modules execute and look/behave differently | **CONFIRMED** | Five browser combat runs |
| M1A-04 | Normal, fire, ice, and electric compile and execute | **CONFIRMED** | Matrix plus combat effect checks |
| M1A-05 | Explicit power component calculator enforces 0–100 | **CONFIRMED** | HUD, unit tests, audit JSON |
| M1A-06 | Strong capability creates a corresponding tradeoff | **CONFIRMED** | Matrix invariant and extreme cases |
| M1A-07 | JSON Schema and runtime validation remain in parity | **CONFIRMED** | Automated parity assertions |
| M1A-08 | Missing, illegal, non-finite, extra, and out-of-range data auto-repair | **CONFIRMED** | Fault injection assertions |
| M1A-09 | At least 20 deterministic acceptance inputs | **CONFIRMED — 32** | `tests/m1a_input_matrix.json` |
| M1A-10 | Moving, shield, and grouped targets validate attack tradeoffs | **CONFIRMED** | Target lab and rule tests |
| M1A-11 | Spec, budget, repairs, and results are recorded | **CONFIRMED** | Runtime JSONL and artifacts |
| M1A-12 | Full tests, Web build, public browser console, Compact Landscape, and mobile input pass | **CONFIRMED (real iPhone v9)** | 844×390, 852×393, 915×412, toolbar-height, orientation-cycle, Chromium, WebKit, CI, and physical Safari all passed |

## v9 physical-device gate

- **CONFIRMED** v8 passed portrait rotation gating, automatic landscape resume,
  five-button forward/reverse/rapid switching, all five `LOAD IDEA → COMPILE →
  ATTACK → REFORGE` flows, and BACK/re-entry on a real iPhone Safari.
- **CONFIRMED** v8 failed usable landscape proportions, Description editing,
  explicit text clearing, RESET clarity, and iOS keyboard invocation.
- **CONFIRMED** v9 closed every failed item and survived repeated landscape →
  portrait → landscape transitions plus Safari toolbar expansion/collapse on the
  same physical device.
- **CONFIRMED** The product owner formally accepted the v9 M1A mobile gate.
- **CONFIRMED** M1B1 began only after release closure, from accepted `main`, on
  the isolated `codex/feat/m1b1-real-text-interpreter` branch. The stable M1A tag
  and deployment remain unchanged.

## M1B1 current gate

The detailed, executable criteria are in `docs/M1B1_ACCEPTANCE.md`. Current
status is intentionally split between the completed provider-neutral layer and
the real-provider evidence that cannot exist before the product decision.

| Area | Status | Evidence / remaining gate |
| --- | --- | --- |
| Same-origin `WeaponInterpreter` client/server contract | **CONFIRMED** | Godot calls only `/api/compile-weapon`; static worker and local server route it |
| Schema, allow-list, semantic compatibility, and PowerBudget enforcement | **CONFIRMED (provider-neutral)** | Godot 458 assertions; Node interpreter 68 tests; 48-case main matrix; 60-case red-team corpus |
| Loading, duplicate lock, safe retry, aborting timeout, cancel, stale rejection, D1 idempotency, and validated fallback | **CONFIRMED (simulated/local D1)** | Node D1 guard probes plus Chromium and WebKit end-to-end regression; Sites D1 still to validate |
| Normal-player selector hidden; Developer/MODIFY correction remains validated | **CONFIRMED (browser automation)** | Five patterns compiled, corrected, confirmed, and attacked in Chromium and WebKit |
| 844×390, 852×393, 915×412, keyboard-height recovery, and three rotation cycles | **CONFIRMED (emulated)** | No scrolling/cropping; real iPhone M1B1 still required |
| AI provider, model, deployment key, and provider moderation | **TBD** | One product-owner decision required; key must be server-side only |
| Real-provider 40+ case accuracy, latency, P95, cost, and fallback evidence | **TO VALIDATE** | Run only after provider configuration; cost stays `UNKNOWN` until measured |
| Public M1B1 preview, CI/PR, and physical iPhone Safari acceptance | **TO VALIDATE** | Must use a new asset version; do not merge or clean the branch beforehand |

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
