# Project Forge — M0 Technical Spike

An independent Godot 4 experiment for turning a player's drawing and one-line
description into a bounded `WeaponSpec`, rendering the original strokes as a
weapon, and testing it against a training dummy.

This repository does not reuse code, design, art, names, or direction from Cat
Battle or any previous game.

## What M0 contains

- Mouse and phone-touch drawing board.
- One-line description and deterministic local mock AI service.
- Schema-backed, clamped `WeaponSpec` boundary with generation metadata.
- Stroke-preserving visible weapon.
- Test pilot, training dummy, movement, melee slash, and straight projectile.
- Weapon name, damage, attack form, special effect, weakness, and re-forging.
- Godot headless checks, Web export, local HTTP server, and browser evidence.

No paid AI, production backend, formal level, boss, voice, accounts, cloud save,
community/sharing, ads, purchases, multiplayer, or store submission is included.

## Run locally

Requirements: Godot 4.7.1 (the workspace-local executable under `.tools/` is used
automatically when present).

```powershell
./scripts/run_game.ps1
```

Controls:

- Draw: left mouse or finger drag.
- Move: `A` / `D`, arrow keys, or hold the on-screen `LEFT` / `RIGHT` buttons.
- Attack: `Space` or the on-screen `ATTACK` button.
- Generate both attack forms with the `MELEE IDEA` and `PROJECTILE IDEA` text
  helpers, then press `GENERATE WEAPON` after drawing.
- Press `REFORGE` to clear the canvas and create another weapon.

## Test and build

```powershell
./scripts/test.ps1
./scripts/build_web.ps1
./scripts/serve_web.ps1
```

Then open [http://localhost:8060](http://localhost:8060). Web builds must be served
over HTTP; opening `index.html` directly is not supported by browser WASM rules.

## Documentation

- Product and milestone scope: `docs/GDD.md`
- Current acceptance and full-MVP traceability: `docs/MVP_ACCEPTANCE.md`
- Runtime and future backend architecture: `docs/ARCHITECTURE.md`
- Confirmed decisions, assumptions, validation items, and TBDs: `docs/DECISIONS.md`
- Repository agent guidance: `AGENTS.md`

