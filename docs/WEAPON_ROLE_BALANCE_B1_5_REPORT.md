# Weapon Physics B1.5 Candidate Report

Date: 2026-07-23 (Australia/Sydney)

Issue: [#10](https://github.com/olliebigbang/project-forge/issues/10)

Branch: `codex/feat/weapon-role-balance-b1-5`
Baseline: `82d0a399462f63d2a18f671306c36b0e3451b6fa`

## Current decision

- **CONFIRMED (pre-freeze automated candidate):** deterministic unit,
  Worker/security, Godot parse and Web/Sites build gates pass. Focused Chromium
  runs also pass the strengthened mobile, manual-correction, Developer/Test and
  `direct_blast` behavior oracles.
- **TO VALIDATE:** the strengthened full Chromium/WebKit matrix must be rerun
  from the committed branch candidate before Draft PR evidence is final.
- **TO VALIDATE:** a separate public preview and physical-iPhone combat-feel
  pass are still required before merge or milestone completion.
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
| `./scripts/test.ps1` | **PASS** — 32 matrix cases, 1105 Godot assertions, 0 failures; Worker, D1, Interpreter and security suites passed |
| `./scripts/build_web.ps1` | **PASS** — Godot 4.7.1 Web export |
| `./scripts/build_sites_preview.ps1` | **PASS** — same-origin Sites bundle assembled |
| `git diff --check` | **PASS** |

### Browser evidence

The earlier full Chromium/WebKit exploration passed the provider-free 844x390
seven-role matrix. The strengthened candidate additionally adds:

- a real `direct_blast` compatibility combat case with no projectile lifecycle;
- fixed-input local/provider/manual/Developer role-parity assertions;
- observable moving-target motion, mandatory shield hits and explicit miss
  lifecycle evidence;
- actual normal/fire/ice/electric combat-effect assertions;
- Description focus, keyboard-sized Visual Viewport, 844x343 Safari toolbar
  stress and three portrait/landscape cycles with zero combat-counter drift.

Focused Chromium reruns for short melee, standard melee, straight ranged and
`direct_blast` pass. A full eight-case Chromium/WebKit rerun remains required
after the branch candidate is committed.

The exploratory full runs recorded:

- 7 product roles x stationary, moving, shield and group = 28 isolated combat
  scenarios per engine;
- zero new application console errors;
- short/standard/long melee retained increasing reach and cycle;
- Bow retained its held drawing and fired a procedural arrow;
- Grenade recorded a multi-sample arc, ground impact, independent explosion and
  three-target group damage;
- Boomerang completed outbound/return hits without an overlapping second launch;
- Piercing used the 7 px path, bypassed shield reduction and hit no more than
  three grouped bodies.

Pre-freeze local ignored evidence:

- `output/playwright/weapon-role-balance-b1-5-final-audited/chromium/report.json`
- `output/playwright/weapon-role-balance-b1-5-final-audited/webkit/report.json`
- Per-role group screenshots plus Bow, Grenade, Boomerang and Piercing active-
  attack screenshots in the same engine directories.

The exploratory audited reports serialize Boomerang `attack_count=1`,
`projectile_spawn_count=1`, `projectile_finish_count=1`, and
`peak_active_projectiles=1` in both engines after rapid taps.

An earlier Grenade test placed a target only about 50 px from the actual
projectile origin, inside the combined collision radii, and therefore observed a
valid frame-zero contact explosion with only two duplicate path samples. The QA
fixture was corrected to a 220 px grip gap so the acceptance test measures the
intended visible arc while the blast still covers the group. The runtime was not
changed to manufacture evidence.

## Remaining gates and limitations

- **TO VALIDATE:** independent code/reality review of the committed final diff.
- **TO VALIDATE:** Draft PR and CI from a committed, pushed HEAD.
- **TO VALIDATE:** isolated Sites preview with a new runtime/release identity.
- **TO VALIDATE:** physical iPhone Safari role feel, touch input and mobile
  regression. Browser emulation is not a substitute.
- **TO VALIDATE:** production role thresholds, moving-target tuning and the
  extreme short-melee DPS are intentionally not declared balanced.
- **TBD / out of scope:** B2 tip/root/sweet spots, interruption, material physics
  and M1B2 drawing semantics.

The candidate is not approved to merge, deploy as stable, tag, clean or begin
B2/M1B2.
