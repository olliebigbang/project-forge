# Project Forge

Project Forge is an independent Godot 4 Web-first experiment that turns a
player's drawing and free-form weapon description into a validated,
power-budgeted `WeaponSpec`, preserves the original strokes as the weapon
visual, and executes the result through five distinct combat modules.

This repository does not reuse code, settings, art, names, balance data, or
direction from Cat Battle or any previous game.

## Current stable release

- **CONFIRMED:** the current production runtime was built from `main` at
  `2c7b8f5021506bece6b60cb2c649ae7f3fbb961e`.
- **CONFIRMED:** the stable tag is `v0.3.0-weapon-physics-b1`.
- **CONFIRMED:** M1B1, M1B1.1, M1B1.2, and Weapon Physics B1 are complete.
- **CONFIRMED:** the production Site is Version 25 at
  <https://project-forge-weapon-lab.hongningliu0130.chatgpt.site>.
- **CONFIRMED:** Sites Version 25 and the smoke-tested Version 24 have the same
  archive hash:
  `sha256:13bec17c923b0476aacd1abef09718aebb91549205f0429e04487836de0b8922`.
- **CONFIRMED:** the direct rollback pair is Sites Version 23 plus Git tag
  `v0.2.1-m1b1.2`. Historical stable tags `v0.2.0-m1b1` and
  `v0.1.0-m1a` remain retained.
- **CONFIRMED:** M1B2 has not started.
- **TBD / TO VALIDATE:** no next gameplay milestone may start until the product
  owner confirms its scope.

See [Project status](docs/PROJECT_STATUS.md) for the current runtime, branch,
worktree, rollback, and governance state. Query parameters on the mutable Sites
origin are diagnostic labels; they do not pin an older deployment.

Source: [GitHub repository](https://github.com/olliebigbang/project-forge)

## Stable system boundaries

- Normal players draw and enter one free-form description without preselecting
  an attack pattern.
- Godot calls only same-origin `POST /api/compile-weapon`; it never contacts an
  AI vendor or holds a provider key.
- Production interpretation uses Anthropic native Messages API and native
  Structured Outputs with immutable model
  `claude-haiku-4-5-20251001`.
- Worker + D1 enforce idempotency, quota, and a lifetime USD 5 application cap
  before provider invocation. Guard uncertainty fails closed.
- Provider output remains untrusted semantic data. Project-owned Schema,
  allow-list, repair, and `PowerBudget` gates own executable results.
- Provider failure cannot create an equipable fallback. Drawing and Description
  survive cancellation, timeout, retry, and explicit error recovery.
- Five attack patterns, four elements, and stationary, moving, shielded, and
  grouped targets remain executable.
- Weapon form, delivery, trajectory, impact, and area effect stay independent.
  Bows keep player ink held while firing procedural arrows; grenades reuse ink
  only as a centred thrown copy and play a separate explosion.
- Held-melee geometry preserves bounded absolute reach. One frozen reach value
  owns visible grip-to-tip length, HUD Range, and hit boundary; one derived
  cycle owns animation timing, hit time, recovery, cooldown, and input gating.
- Web mobile input retains the stable Canvas, native HTML Description overlay,
  `visualViewport`, safe areas, portrait gate, keyboard recovery, and
  physical-iPhone acceptance.

M1B1 sends only bounded numeric `drawing_summary` metadata. Drawing-image
understanding is not implemented and remains outside the current milestone.

## Run locally

Requirements: Godot 4.7.1. Scripts use
`.tools/Godot_v4.7.1-stable_win64_console.exe` when present, then fall back to
`godot4` or `godot` on `PATH`.

```powershell
./scripts/run_game.ps1
```

For the same-origin Web client and deterministic local backend:

```powershell
./scripts/build_web.ps1
./scripts/serve_web.ps1
```

Open <http://localhost:8060> on the development computer. `localhost` is not a
phone delivery address; use the production Sites address above for the current
publicly reachable build.

Controls:

- Forge: draw, enter a description, then select `FORGE`.
- Review: `CONFIRM`, `MODIFY INTERPRETATION`, `TRY AGAIN`, or
  `NOT SUITABLE`.
- Move: `A` / `D`, arrow keys, or on-screen `LEFT` / `RIGHT`.
- Attack: `Space` or on-screen `ATTACK`.
- Return to creation: `REFORGE`.

## Test and package

```powershell
./scripts/test.ps1
./scripts/build_web.ps1
./scripts/build_sites_preview.ps1
```

CI runs the provider-free Godot, Worker, WASM, interpreter, D1, Anthropic
adapter, budget, security, canonical Sites bundle, hash, and Chromium smoke
gates. Complete WebKit, physical iPhone, and any explicitly approved real
provider check remain release-candidate human gates.

## Documentation

- Current runtime and delivery state: `docs/PROJECT_STATUS.md`
- Development workflow: `docs/DEVELOPMENT_WORKFLOW.md`
- Release and rollback checklist: `docs/RELEASE_CHECKLIST.md`
- Workflow-hardening audit and test evidence:
  `docs/WORKFLOW_HARDENING_REPORT.md`
- Product scope: `docs/GDD.md`
- Technical boundaries: `docs/ARCHITECTURE.md`
- Decisions and open questions: `docs/DECISIONS.md`
- Milestone traceability: `docs/MVP_ACCEPTANCE.md`
- M1B1 acceptance and handoff: `docs/M1B1_ACCEPTANCE.md`,
  `docs/M1B1_HANDOFF.md`
- M1B1.1 and M1B1.2 historical acceptance:
  `docs/M1B1_1_PLAYER_UI_ACCEPTANCE.md`,
  `docs/M1B1_2_ABSOLUTE_REACH_ACCEPTANCE.md`
- Weapon Physics B0/B1 contract and acceptance:
  `docs/WEAPON_PHYSICS_B0_B1.md`,
  `docs/WEAPON_PHYSICS_B1_ACCEPTANCE.md`
- Version history: `CHANGELOG.md`
- Repository guidance: `AGENTS.md`
