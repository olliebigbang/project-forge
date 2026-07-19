# Project Forge repository guide

## Project identity

This repository is a new, standalone game project. Do not import or reuse code,
names, lore, art, assets, balance data, or development direction from Cat Battle
or any other previous project.

## Source of truth

- `docs/GDD.md` preserves the product vision and full milestone scope.
- `docs/MVP_ACCEPTANCE.md` defines the current milestone gate.
- `docs/ARCHITECTURE.md` defines technical boundaries and data flow.
- `docs/DECISIONS.md` records confirmed decisions, assumptions, validation items,
  and unresolved decisions.
- When a requirement is uncertain, mark it exactly `CONFIRMED`, `ASSUMPTION`,
  `TO VALIDATE`, or `TBD`; do not silently resolve product questions.

## Current scope

The current target is M0, a technical spike. Keep changes intentionally small:

- Godot 4, 2D landscape, Web-playable.
- Mouse and touch drawing plus one text description.
- A local deterministic mock service returning a validated `WeaponSpec`.
- A visible weapon made from the player's strokes.
- One player and one training dummy.
- Melee and projectile attacks, weapon readout, and re-forging.

Do not add paid AI APIs, secrets, production levels or art, voice, accounts, cloud
saves, community features, monetization, multiplayer, or store submission during
M0.

## Engineering rules

- Use typed GDScript where practical and keep reusable logic out of scene scripts.
- AI output is data only. Never generate or execute gameplay code.
- Validate and clamp every `WeaponSpec` before gameplay consumes it.
- Do not place API keys in the Godot client. A future real service must sit behind
  a secure backend.
- Preserve player strokes in the generated weapon visual.
- Touch interactions must not depend on hover, right-click, or a keyboard.
- Keep generated engine state (`.godot/`), downloaded tools (`.tools/`), and Web
  exports (`build/web/`) out of version control.
- Add tests for deterministic data transforms and boundary rules.

## Commands

From PowerShell at the repository root:

```powershell
./scripts/test.ps1
./scripts/build_web.ps1
./scripts/serve_web.ps1
```

For an editor run, open `project.godot` with Godot 4.7.1 or run:

```powershell
./scripts/run_editor.ps1
```

## Git workflow

- Work on a dedicated `feat/*` branch; M0 uses `feat/m0-technical-spike`.
- Make focused commits after tests and builds pass.
- Never merge, delete branches, or clean the worktree without user confirmation.
- Push and open a PR only when a remote is configured.

