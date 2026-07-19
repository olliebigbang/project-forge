# M1A Deterministic Weapon Compiler Handoff

## Outcome

**CONFIRMED:** M1A is a runnable Godot and Web prototype. Drawing plus one text
line compiles locally into a runtime-valid, schema-parity-checked `WeaponSpec`.
The HUD exposes the exact power calculation and tradeoff. Five distinct attack
modules can be tested against stationary, moving, shielded, and grouped targets.

## Public preview

[Project Forge public Web trial](https://project-forge-weapon-lab.hongningliu0130.chatgpt.site)

The same URL is updated in place for M1A. It is public and does not require a
local server, account, API key, or paid service.

## Local use

```powershell
./scripts/run_game.ps1
./scripts/test.ps1
./scripts/build_web.ps1
```

To serve the local export, run `./scripts/serve_web.ps1` and open
`http://localhost:8060`. The public link above is the phone delivery path.

## Compiler audit

Every generation prints and appends a JSON record containing the sanitized input,
drawing summary, raw profile, final `WeaponSpec`, budget before/after, correction
reasons, fallback reason, validation outcome, and elapsed time. Godot stores the
session log at `user://m1a_generation_log.jsonl`.

The checked-in acceptance definitions live in `tests/m1a_input_matrix.json`; the
final execution summary and representative records live under `artifacts/`.

## Downloadable Web bundle

Run `./scripts/package_web_release.ps1` to produce
`release/Project-Forge-M1A-Web.zip`. The archive includes the exported files,
`START_WEB.ps1`, a Node HTTP server, and offline instructions. This provides a
recoverable handoff even if the public host later becomes unavailable.

## Scope boundary

M1A deliberately does not include paid AI, production moderation/backend, formal
art, full levels, bosses, accounts, cloud saves, sharing, commerce, advertising,
multiplayer, voice, or mobile-store packaging.

## Recommendation

Proceed to the next milestone only after QA regression closes all blocking issues.
M1A proves compiler determinism, validation recovery, power accounting, attack
modularity, elements, and target-specific behavior; it does not prove final game
balance or production mobile performance.
