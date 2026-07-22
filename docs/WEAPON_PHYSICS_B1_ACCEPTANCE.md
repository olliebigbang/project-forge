# Weapon Physics B1 Controlled Prototype Acceptance

Status: **CONFIRMED automated prototype gate; TO VALIDATE physical-device
combat-feel review**

B1 is a local deterministic physicality experiment after accepted M1B1.2. It is
not M1B2, B1.5, or B2 and does not expand the public `WeaponSpec` Schema.

## Executable gates

- [x] Stable start is `v0.2.1-m1b1.2` commit
  `9e0ff3b174c1c38d2dcb35f0717775e2a9d9aaef`.
- [x] `GeometryEvidence -> PhysicalProfile -> CombatDerived` is visible in QA
  evidence while raw strokes remain unchanged.
- [x] The 3×3 reach × mass unit matrix is deterministic and every case stays
  runtime-valid and at or below PowerBudget 100.
- [x] Same-reach light/balanced/heavy cases retain the same effective reach but
  have strictly increasing hit delay and complete cycle.
- [x] Same-mass short/standard/long cases retain increasing visible and hit reach
  and have strictly increasing hit delay and complete cycle.
- [x] Short/light versus 210+ px long/heavy is clearly different, with a complete
  cycle ratio from 1.35 inclusive to 3.0 exclusive.
- [x] Displayed grip-to-tip length, HUD Range, and real hit boundary agree within
  0.05 px; fit remains uniform with 8%–12% padding.
- [x] Damage is identical across the controlled physical matrix. No free
  range-plus-damage grant exists.
- [x] Correction audit includes reach, mass, startup/active/recovery, Range/Speed
  budget delta, and reason.
- [x] B2 contact model remains `uniform_grip_to_tip` with no regions or sweet
  spots enabled.
- [x] M1B1 input, Worker/D1/security, UI, keyboard, five-module/four-element, and
  browser visual-role regressions pass without paid AI calls.

Run:

```powershell
./scripts/test.ps1
./scripts/build_web.ps1
./scripts/build_sites_preview.ps1
```

Then run `tests/browser/run_weapon_reach_regression.mjs` against the local build
with Chromium and WebKit. Retain JSON reports and screenshots outside Git.

## Automated evidence (2026-07-22)

The checked-in deterministic suite passed 788 assertions after the final matrix
invariant was added. The values below are the frozen `CombatDerived` values from
the Chromium report; WebKit produced the same deterministic values.

| Case | Reach | Speed | Startup | Active | Hit | Recovery | Cycle | Power | Range+speed delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| short-light | 72 | 1.20 | 0.182 s | 0.151 s | 0.276 s | 0.709 s | 1.042 s | 34 | +0.67 |
| short-heavy | 72 | 0.93 | 0.329 s | 0.242 s | 0.479 s | 0.773 s | 1.344 s | 31 | -2.03 |
| standard-balanced | 123 | 0.99 | 0.282 s | 0.217 s | 0.417 s | 0.764 s | 1.263 s | 33 | -0.30 |
| long-light | 228 | 0.85 | 0.360 s | 0.265 s | 0.524 s | 0.846 s | 1.471 s | 34 | +0.63 |
| long-heavy | 228 | 0.64 | 0.615 s | 0.420 s | 0.875 s | 0.918 s | 1.953 s | 32 | -1.47 |

The extreme cycle ratio is 1.874. At the controlled 170 px target gap, both
short cases and standard-balanced missed while both long cases hit for the same
36 damage. Chromium and WebKit each passed 5/5 B1 cases with zero application
console errors. Both browsers also passed the existing keyboard/orientation and
bow/grenade/sword/boomerang blocker suite (4/4 weapon cases, zero errors).

Evidence is retained outside Git under
`output/playwright/weapon-physics-b1/`, including both JSON reports, individual
combat/impact captures, blocker reports, and the Chromium five-card comparison.

## Known limitations

- **TO VALIDATE:** Reach, cross-axis mass thresholds, phase shares, and handling
  multiplier caps require physical-device feel comparison.
- **TO VALIDATE:** Cross-axis stroke load is only a controlled geometry proxy;
  material density, balance point and moment of inertia are not modeled.
- **TO VALIDATE (B1.5):** Weapon role and near/ranged compensation are absent.
- **TO VALIDATE (B2):** The current capsule applies uniform damage from grip to
  tip and provides no contact-region feedback.
