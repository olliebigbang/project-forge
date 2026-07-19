# Project Forge — M1A Deterministic Weapon Compiler

An independent Godot 4 experiment that turns a player's drawing and one-line
description into a validated, power-budgeted `WeaponSpec`, renders the original
strokes as a weapon, and runs it against a behavior-focused target lab.

This repository does not reuse code, settings, art, names, or direction from Cat
Battle or any previous game.

## Public trial

[Open the iPhone touch-fix Web preview](https://project-forge-weapon-lab.hongningliu0130.chatgpt.site/?release=v8-b403d9e)

The preview is a landscape Web build. It contains no paid AI call, API key,
account, store, advertising, multiplayer, or production art.

Source and review: [GitHub repository](https://github.com/olliebigbang/project-forge)
and [Draft PR #1](https://github.com/olliebigbang/project-forge/pull/1). The PR
remains unmerged until the physical iPhone Safari acceptance is complete.

## M1A contents

- Mouse and phone-touch drawing plus a one-line description.
- Deterministic local compiler for `melee_slash`, `straight_projectile`,
  `boomerang`, `area_blast`, and `piercing`.
- `normal`, `fire`, `ice`, and `electric` palettes and combat effects.
- JSON Schema plus runtime allow-list, type, finite-number, and bounds validation.
- Automatic repair records and an explicit component-by-component power budget.
- Automatic tradeoffs for strong abilities and over-budget stat reduction.
- Stationary, moving, shielded, and grouped test targets.
- Runtime JSONL generation audit and a 32-case executable acceptance matrix.

## Run locally

Requirements: Godot 4.7.1. The scripts use `.tools/Godot_v4.7.1-stable_win64_console.exe`
when present, then fall back to `godot4` or `godot` on `PATH`.

```powershell
./scripts/run_game.ps1
```

Controls:

- Draw: left mouse or one-finger drag.
- Describe: type a sentence, or choose one of the five deterministic examples.
- Move: `A` / `D`, arrow keys, or the on-screen `LEFT` / `RIGHT` buttons.
- Attack: `Space` or the on-screen `ATTACK` button.
- Replace the active weapon: `REFORGE`.

## Test and build

```powershell
./scripts/test.ps1
./scripts/build_web.ps1
./scripts/serve_web.ps1
```

The local server uses [http://localhost:8060](http://localhost:8060). This local
address is for development only; use the public trial link on a phone.

## Documentation

- Product scope: `docs/GDD.md`
- Current acceptance: `docs/MVP_ACCEPTANCE.md`
- Technical boundaries: `docs/ARCHITECTURE.md`
- Decisions and open questions: `docs/DECISIONS.md`
- QA / red-team report: `docs/M1_RED_TEAM_REPORT.md`
- Original visual direction: `docs/ART_DIRECTION.md`
- M1A handoff: `docs/M1A_HANDOFF.md`
- Repository guidance: `AGENTS.md`
