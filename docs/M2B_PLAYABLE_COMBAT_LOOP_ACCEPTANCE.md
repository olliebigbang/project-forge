# M2B Minimum Playable Belt-Combat Loop Acceptance

Status: **AUTOMATED PASS / PHYSICAL IPHONE TO VALIDATE**

GitHub Issue: [#20](https://github.com/olliebigbang/project-forge/issues/20)

## Product question

Does the accepted Forge-to-belt route produce a readable, repeatable combat
decision loop when the player must manage positioning, enemy telegraphs, one
defensive technique, dodge timing, victory, defeat, reward, and Reforge?

## Included

1. One bounded normal-player belt room using the exact M2A-routed weapon.
2. Two deterministic enemies with visibly different behavior:
   - a slow bruiser with a broad, high-damage committed strike;
   - a charger that locks a direction, dashes through a narrow lane, and has a
     punishable recovery.
3. A touch-first dodge with an explicit cooldown, bounded movement,
   invulnerability only during the active window, and passage through living
   enemy footprints while active.
4. One one-charge defensive weapon-technique prototype named `WARD`. It creates
   a short visible guard window; a correctly timed enemy strike deals zero
   damage and forces that enemy into recovery. It does not alter `WeaponSpec`,
   damage, PowerBudget, Provider output, or attack timing.
5. Victory and defeat states, Retry, Reforge, and a post-victory choice between:
   - `WARD+`: one extra WARD charge for the next room attempt;
   - `DODGE+`: a bounded shorter dodge cooldown for the next room attempt.
6. Developer/Test Mode retains all M2A fixture weapons, moving/shield/group
   encounters, exact route diagnostics, and the side-view Combat Lab.

## Explicit exclusions

- No M1B2 visual/drawing interpretation.
- No public `WeaponSpec`, JSON Schema, runtime repair, or PowerBudget change.
- No Provider, model, D1, quota, secret, cost, retry, or request-lifecycle
  change.
- No burst/automatic cadence, charged grenade, jump, crouch, combo tree,
  inventory, level sequence, boss, production art, voice, account, sharing,
  monetization, or multiplayer.
- No production deployment before an isolated preview and physical-iPhone
  acceptance.

## Deterministic invariants

- WARD and DODGE never generate damage or extra weapon hits.
- WARD consumes exactly one charge when activated, whether it succeeds or
  misses. One enemy strike may trigger it once.
- DODGE cannot be activated while another dodge is active, after death, or
  during a terminal state. Its cooldown uses one authoritative timer.
- A charger freezes its dash direction at the end of telegraph and cannot
  retarget during the dash.
- Victory/defeat/Reforge/Retry/scene exit clear guard windows, dodge state,
  enemy dash state, projectiles, attack timers, touch input, and detached
  visuals.
- Reward selection changes only the next room attempt's player ability
  parameters. It never rewrites the routed weapon or its audit.
- 30/60/120 Hz and one bounded long frame produce the same terminal outcome,
  reward count, WARD charge use, and dodge acceptance count.

## Acceptance matrix

| ID | Criterion |
| --- | --- |
| M2B-01 | Normal Forge confirmation enters the one-room M2B belt loop with the exact M2A weapon and strokes |
| M2B-02 | The room contains one bruiser and one charger with distinct color, silhouette, telegraph, strike path, damage, and recovery |
| M2B-03 | Bruiser strike is broad, slow, and readable; moving out of its committed range avoids damage |
| M2B-04 | Charger locks a visible lane, does not retarget after telegraph, dashes through it, and enters punishable recovery |
| M2B-05 | DODGE works with simultaneous touch movement, crosses living footprints while active, and never exits arena bounds |
| M2B-06 | DODGE grants damage immunity only during its active window and exposes a visible cooldown |
| M2B-07 | WARD consumes one charge, visibly guards, negates one correctly timed enemy strike, and forces that enemy into recovery |
| M2B-08 | WARD and DODGE do not alter WeaponSpec, PowerBudget, weapon damage, attack count, or Provider behavior |
| M2B-09 | All five attack patterns and four elements remain executable against both enemy archetypes |
| M2B-10 | Victory appears only after both enemies are defeated; defeat appears only at zero player HP |
| M2B-11 | Victory offers WARD+ and DODGE+; exactly one choice applies to the next retry and is visible in QA state |
| M2B-12 | Retry preserves the exact weapon, rebuilds living enemies, clears transients, and applies only the selected reward |
| M2B-13 | Reforge restores original drawing and Description without carrying room rewards into a new weapon |
| M2B-14 | Developer/Test Mode retains moving, shield, grouped, all weapon fixtures, and side-view regression routes |
| M2B-15 | 844x390, 852x393, and 915x412 expose joystick, ATTACK, WARD, DODGE, Retry, and Reforge without clipping or overlap |
| M2B-16 | Portrait gate, iOS keyboard return, Safari toolbar resize, simultaneous movement/action touches, and orientation recovery do not lock input |
| M2B-17 | Godot, Worker/security, Web/Sites builds, Chromium, and WebKit pass with zero provider calls and no new application console errors |
| M2B-18 | An isolated public preview passes physical-iPhone feel and readability acceptance before merge or production deployment |

## Completion gate

M2B remains **TO VALIDATE** until deterministic, browser, isolated-preview, and
physical-iPhone evidence pass. Keep M2A production/runtime status, tags,
branches, worktrees, screenshots, and rollback packages unchanged until then.

## Current evidence

- **CONFIRMED:** Godot import, deterministic/runtime tests, the 381-assertion
  belt suite, Worker/D1/Anthropic/security tests, and Web export pass.
- **CONFIRMED:** Chromium and WebKit pass the provider-free live regression with
  all five patterns, exact route identity, DODGE, WARD, victory/reward, Unicode
  request transport, the three compact landscape sizes, and zero application
  console errors.
- **TO VALIDATE:** isolated public preview and physical-iPhone acceptance.

Full evidence and known limitations are recorded in
`docs/M2B_PLAYABLE_COMBAT_LOOP_TEST_REPORT.md`.
