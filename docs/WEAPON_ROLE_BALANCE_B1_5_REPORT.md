# Weapon Physics B1.5 Candidate Report

Date: 2026-07-23 (Australia/Sydney)

Issue: [#10](https://github.com/olliebigbang/project-forge/issues/10)

Branch: `codex/feat/weapon-role-balance-b1-5`

Baseline: `82d0a399462f63d2a18f671306c36b0e3451b6fa`

Verified runtime commit: `e88ed69`

## Current decision

- **CONFIRMED (automated candidate):** runtime commit `e88ed69` passes the full
  deterministic unit, Worker/security, Godot parse, Web/Sites build, Chromium
  and WebKit gates.
- **CONFIRMED:** both browser engines pass the strengthened mobile,
  manual-correction, Developer/Test and `direct_blast` behavior oracles.
- **CONFIRMED:** Draft PR #11 is open, both GitHub `validate` runs pass, Reality
  Checker returned `APPROVE PREVIEW`, and Sites v26 is deployed from the exact
  verified source/build identity.
- **TO VALIDATE:** physical-iPhone combat-feel acceptance is still required
  before merge or milestone closure.
- **CONFIRMED:** no real provider call was made for B1.5 testing. Browser tests
  intercepted the same-origin request with a declared simulated validated
  semantic response, then exercised the normal client validation path.

## Implemented result

- Added internal `WeaponRoleProfile` derivation after validated semantics and
  the existing geometry/physical chain.
- Preserved the accepted B1 melee reach, cadence, facing lock and one-slot
  buffer.
- Made non-melee startup govern real projectile/blast commit instead of spawning
  immediately on button press.
- Applied a real 7 px Piercing collision radius.
- Bounded Boomerang to one hit per target per phase and two hits per target over
  outbound plus return; a detached Boomerang blocks another launch.
- Kept Grenade runtime arc samples separate from its nominal travel estimate.
- Added isolated stationary, moving, shield and three-body group QA scenarios
  with reset state and attributed damage events.
- Kept held/direct `area_blast` as the explicit `direct_blast` compatibility
  path. It cannot claim thrown/arc Grenade behavior.

No public Schema, `PowerBudget` price, Provider, model, secret, D1, player UI,
B2 contact model or M1B2 drawing-understanding change is included.

## Deterministic candidate values

These are **TO VALIDATE** prototype values, not production balance targets.

| Role | Damage | Cycle | Effective reach | Nominal single-target DPS | Executed cost / boundary |
| --- | ---: | ---: | ---: | ---: | --- |
| Short melee | 36 | 0.333 s | 72 px | 108.11 | Must enter the shortest real reach |
| Standard melee | 36 | 1.042 s | 120 px | 34.55 | Proximity and one closest target |
| Long melee | 36 | 1.923 s | about 199 px | 18.72 | Long startup and recovery |
| Straight ranged | 26 | 0.769 s | 675 px | 33.81 | Travel/miss risk; first body ends shot |
| Thrown blast | 34 | 2.071 s | 220 px | 16.42 | Startup, arc, blast delay and cooldown |
| Boomerang | 30 | 1.368 s | 620 px | 21.93 outbound | Return path and detached/self-stagger gate |
| Piercing | 29 | 0.952 s | 700 px | 30.46 | 7 px path and three-body maximum |

Equal DPS is deliberately not the target. Length still does not change melee
damage; B2 contact regions remain deferred.

## Automated evidence

### Repository commands

| Command | Result |
| --- | --- |
| `./scripts/test.ps1` | **PASS** - 32 matrix cases, 1105 Godot assertions, 0 failures; Worker, D1, Interpreter and security suites passed |
| `./scripts/build_web.ps1` | **PASS** - Godot 4.7.1 Web export |
| `./scripts/build_sites_preview.ps1` | **PASS** - same-origin Sites bundle assembled |
| `git diff --check` | **PASS** |

### Browser evidence

The committed runtime candidate passed the provider-free 844x390 matrix in
both Chromium and WebKit. Each engine ran:

- seven product roles plus the `direct_blast` compatibility path;
- stationary, moving, shield and grouped targets for every role, for 32
  isolated combat scenarios;
- the actual manual-correction UI path for Standard Melee and actual
  Developer/Test UI path for Straight Ranged;
- observable moving-target motion, mandatory shield hits and explicit miss
  lifecycle evidence;
- actual normal/fire/ice/electric combat-effect assertions;
- Description focus, keyboard-sized Visual Viewport, 844x343 Safari toolbar
  stress and three portrait/landscape cycles with zero combat-counter drift.

Both engines recorded zero application console errors. Bow retained its held
drawing while firing a procedural arrow; Grenade recorded a multi-sample arc,
ground impact, independent explosion and grouped damage; Boomerang completed
outbound/return hits without an overlapping second launch; Piercing used the
7 px path, bypassed shield reduction and hit no more than three grouped bodies.

Local ignored evidence retained outside Git:

- `output/playwright/weapon-role-balance-b1-5-head-e88ed69/chromium/report.json`
- `output/playwright/weapon-role-balance-b1-5-head-e88ed69/webkit/report.json`
- per-role group screenshots and Bow, Grenade, Boomerang, Piercing and
  `direct_blast` active-attack screenshots in the same engine directories;
- keyboard-open and keyboard-closed screenshots for both engines.

The final reports serialize Boomerang `attack_count=1`,
`projectile_spawn_count=1`, `projectile_finish_count=1`, and
`peak_active_projectiles=1` in both engines after rapid taps.

Evidence hashes:

- Web and Sites `index.pck`:
  `13B09CBE93E5586A4054C41E30C3C263C44C6AFAA3A61752193C8841AE145ACB`
- Web and Sites `index.js`:
  `68586D6DAAFC93C6E697B3FB258976874AA7459B8931165EBB1DC3C9614CC42C`
- Chromium report:
  `D3B5C8054FE983A8EB920048EFF2A337A50466E1510F4C3A44808EF16AD83C2D`
- WebKit report:
  `4A0ADDA70C1CF73D6BA4E1E3F27E82773D8D1133EF04D6F3F4CB45A1F68273AC`

### Public preview evidence

- Draft PR: [#11](https://github.com/olliebigbang/project-forge/pull/11)
- Sites version: 26, source commit `6398052`
- Acceptance URL:
  `https://project-forge-weapon-lab.hongningliu0130.chatgpt.site/?release=b1-5-v26-6398052`
- HTTP: **200**, `Cache-Control: public, max-age=0, must-revalidate`
- Public `index.pck` and `index.js` hashes match the local validated artifacts
  listed above.
- Public Chromium report: 8 roles x 4 targets, mobile regression, zero console
  errors; SHA-256
  `CF25FF310E06FCA0A694DC65B170D20EEDA4C2FDAF96AD680008F6619FE9CA61`.
- Public WebKit report: 8 roles x 4 targets, mobile regression, zero console
  errors; SHA-256
  `6A28C68BA1249021F0B8EC8CCD9C72D021B99522B86BC0A8F83CD1F9C5D185BE`.
- Deployment archive retained at SHA-256
  `3BEB7B46F7437BD6F091AB54FC2C0773B31E30DEA65FF796D0F79377A024588F`.
- **CONFIRMED:** public smoke remains provider-free; it does not spend the
  Anthropic budget or replace the existing M1B1 real-provider acceptance.

An earlier Grenade test placed a target about 50 px from the actual projectile
origin, inside the combined collision radii, and therefore observed a valid
frame-zero contact explosion with only two duplicate path samples. The QA
fixture was corrected to a 220 px grip gap so the acceptance test measures the
intended visible arc while the blast still covers the group. Runtime behavior
was not changed to manufacture evidence.

## Remaining gates and limitations

- **CONFIRMED:** independent Reality Checker review found no P0/P1 and approved
  the candidate for preview.
- **CONFIRMED:** both Draft PR `validate` checks pass.
- **CONFIRMED:** Sites v26 and its release-marked URL pass HTTP, hash, Chromium
  and WebKit smoke checks.
- **TO VALIDATE:** physical iPhone Safari role feel, touch input and mobile
  regression. Browser emulation is not a substitute.
- **TO VALIDATE:** production role thresholds, moving-target tuning and the
  extreme short-melee DPS are intentionally not declared balanced.
- **TBD / out of scope:** B2 tip/root/sweet spots, interruption, material physics
  and M1B2 drawing semantics.

The candidate is not approved to merge, deploy as stable, tag, clean or begin
B2/M1B2.
