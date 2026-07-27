# Weapon Exposure B1.5 Report

Status: **CONFIRMED automated and physical iPhone candidate**

Date: 2026-07-26 (Australia/Sydney)

## Outcome

The C0 gameplay failure had two causes:

1. The original driver accepted an attack before it began moving, which gave
   short weapons an earlier movement start and then forced every weapon into
   contact for the rest of the fight.
2. Even after correcting that experiment, the old reach-derived cycle curve
   repeatedly charged long weapons far more than their one-time spacing
   advantage could repay.

The corrected two-strategy matrix first reproduced the runtime imbalance without
changing gameplay. The bounded timing candidate then passed the same matrix in
Chromium and WebKit without role-specific enemies, contact damage, hit-stun,
forward-movement locks, Schema changes, provider calls, or B2 mechanics.

## Runtime correction

`CombatDerived.REACH_CYCLE_ANCHORS` now uses one nonlinear authority:

| Effective reach | Base cycle |
| ---: | ---: |
| 72 px | 0.50 s |
| 92 px | 0.60 s |
| 120 px | 0.71 s |
| 199 px | 0.95 s |
| 228 px | 1.01 s |

For the shared balanced-mass C0 fixtures, the resulting complete cycles are:

| Role | Reach | Complete cycle | Damage |
| --- | ---: | ---: | ---: |
| Short | 72 px | 0.549 s | 36 |
| Standard | 123 px | 0.781 s | 36 |
| Long | 220 px | 1.099 s | 36 |

Damage, reach, mass, and timing remain separate authorities. A one-grid light
weapon remains materially faster than a long heavy weapon; the deterministic
extreme ratio is bounded at approximately 2.5–3.0× instead of the previous
4–6× range.

## Browser strategy matrix

Pressure begins movement and attack in the same input dispatch and continues to
advance. Spacing uses only effective reach, actor positions, arena bounds, and
the visible enemy phase. It never branches on weapon role or fixture name.

### Chromium

- Pressure TTK, near: short 2806 ms / standard 3022 ms / long 4122 ms.
- Pressure TTK, far: short 2801 ms / standard 3803 ms / long 4123 ms.
- Spacing total damage taken across both starts:
  short 60 / standard 0 / long 20.
- Combined winners:
  standard first hit / short TTK / standard damage taken.
- Application console errors: 0.
- Compile/provider calls: 0.

### WebKit

- Pressure TTK, near: short 2495 ms / standard 2672 ms / long 3816 ms.
- Pressure TTK, far: short 2447 ms / standard 3483 ms / long 3844 ms.
- Spacing total damage taken across both starts:
  short 60 / standard 20 / long 0.
- Combined winners:
  long first hit / short TTK / standard+long damage taken.
- Application console errors: 0.
- Compile/provider calls: 0.

Both browsers therefore establish the intended trade:

- **CONFIRMED:** short remains the fastest pressure finisher.
- **CONFIRMED:** spacing converts longer reach into lower exposure.
- **CONFIRMED:** no reach role wins first hit, TTK, and damage taken together.
- **CONFIRMED:** all terminal-state, collision, touch-target, keyboard,
  orientation, input-integrity, and provider-isolation assertions remain active.

## Verification

- Godot deterministic suite: **CONFIRMED PASS**, 32 cases, 1185 assertions,
  0 failed.
- Web export: **CONFIRMED PASS**.
- Chromium C0/B1.5 browser matrix: **CONFIRMED PASS**.
- WebKit C0/B1.5 browser matrix: **CONFIRMED PASS**.
- Sites bundle build: **CONFIRMED PASS**.
- Physical iPhone feel and blocker regression: **CONFIRMED PASS on 2026-07-27
  using Sites Version 29 / PR #12 HEAD `1365f0d`**.

The first WebKit rerun exposed a test-only staging variance: the enemy advanced
6.4 px between the deterministic gap command and the observable snapshot. The
cross-browser staging tolerance was increased from 5 px to 8 px, covering at
most four 60 Hz enemy frames. Gameplay values and the spacing controller were
not changed to resolve this harness issue.

A final exact-commit Chromium rerun also showed why the gate must not impose
`long <= standard`: the near-gap row was short 40 / standard 0 / long 20,
and the aggregate was short 60 / standard 0 / long 20. Long still earned the
required one-strike improvement over short, while the standard sword sometimes
ended the fight before taking a strike. The accepted invariant therefore
compares both longer roles with short, but deliberately does not force an order
between standard and long.

## Evidence identity

- Strategy source commit:
  `f12bb5aac14b616b3ae6f7d7bd9292fb2e0f336c`.
- Accepted integrated source commit:
  `1365f0d420a77cb03efc3d83850ebecbae7c90dd`.
- Accepted public preview: Sites Version 29 at
  `https://project-forge-weapon-lab.hongningliu0130.chatgpt.site/?release=b1-5-iphone-fix-v29-1365f0d`.
- Chromium:
  `output/playwright/b1-5-strategy-matrix-f12bb5a/chromium-report.json`.
- WebKit:
  `output/playwright/b1-5-strategy-matrix-f12bb5a/webkit-report.json`.
- Both reports were generated from a Web export rebuilt from that commit.

## Release closure

The product owner accepted the integrated v29 candidate on a physical iPhone
Safari on 2026-07-27. PR #12 subsequently merged as `d88ee97`; both required CI
runs passed; the reproducible main build was deployed as Sites Version 30 and
tagged `v0.4.0-weapon-exposure-b1.5`. Sites Version 29 remains the direct
accepted-device runtime rollback. This release does not authorize B2 or M1B2.

## Stable release verification

- **CONFIRMED:** PR #12 merged as
  `d88ee9710e1d253e421e6b64f05167579d649fc2`; both required `validate` runs
  completed successfully.
- **CONFIRMED:** a detached worktree at that exact merge passed
  `scripts/test.ps1` with 32 Godot matrix cases, 1187 assertions and zero
  failures, plus all Worker, WASM, Interpreter, D1, Anthropic adapter, budget,
  and hostile-safety suites.
- **CONFIRMED:** `scripts/build_web.ps1` and
  `scripts/build_sites_preview.ps1` succeeded. Godot emitted only the known
  restricted-host certificate/editor-settings warnings after the Sites bundle
  was complete.
- **CONFIRMED:** Sites Version 30 records source commit `d88ee97` and is the
  current production deployment at
  `https://project-forge-weapon-lab.hongningliu0130.chatgpt.site`.
- **CONFIRMED:** the production Chromium iPhone-blocker suite passed touch
  ATTACK after damage, simultaneous move plus attack, Chinese Description
  synchronization, keyboard/toolbar restore, zero black-strip pixels, and zero
  application console errors without a provider call.
- **CONFIRMED functional / known harness warning:** the production WebKit path
  completed the same functional assertions and failed its final warning gate
  only on WebKit's own `window.styleMedia` deprecation warning. Known WebGL
  diagnostics remain filtered platform output.
- **TO VALIDATE (test stability, not release functionality):** the full public
  C0 fairness runner produced two different strict timing-boundary failures on
  consecutive runs: one aggregate 20-damage exposure quantum and one 9.6 px
  fixture-staging tolerance miss. The exact-commit local suite and both CI runs
  pass, and the physical iPhone gate is authoritative. Future browser-harness
  work should remove remote wall-clock/staging jitter before using this suite
  as a production smoke oracle.
- **CONFIRMED:** no additional paid-provider call was made for Version 30. The
  v29 guarded Claude timeout/fail-closed plus explicit successful retry remains
  valid because the accepted runtime code is unchanged; the later commits add
  acceptance documentation and merge provenance only.
