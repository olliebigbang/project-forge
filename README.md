# Project Forge — M1B1 Text-to-Weapon Interpreter

Project Forge is an independent Godot 4 experiment that turns a player's drawing
and free-form weapon description into a validated, power-budgeted `WeaponSpec`,
preserves the original strokes as the weapon visual, and executes the result with
five distinct combat modules.

The accepted M1A release remains the stable rollback baseline. The current M1B1
branch adds a provider-neutral, same-origin text interpretation boundary; it does
not yet claim real-AI accuracy, latency, or cost because the provider/model and
server credential are still **TBD**.

This repository does not reuse code, settings, art, names, or direction from Cat
Battle or any previous game.

## Stable public trial

[Open the accepted M1A v9 Web build](https://project-forge-weapon-lab.hongningliu0130.chatgpt.site/?release=v9-f309f28)

That deployment is the physical-iPhone-accepted M1A rollback version. It contains
no paid AI call or API key. A separate M1B1 public preview will be deployed only
after the real provider is selected, tested, and reviewed through CI.

Source: [GitHub repository](https://github.com/olliebigbang/project-forge)

## M1B1 provider-neutral implementation

- Normal players draw and enter one free-form description without preselecting an
  attack pattern.
- Godot calls only same-origin `POST /api/compile-weapon`; it never contacts an AI
  vendor or holds a provider key.
- The backend limits and safety-checks input, normalizes structured semantic
  output, applies schema and allow-list repair, calculates deterministic power,
  and returns privacy-minimized audit metadata.
- Executable stats remain deterministic and capped at Power Score 100. AI output
  is untrusted data and cannot generate or execute gameplay code.
- The five M1A pattern buttons are hidden in the normal flow and appear only in
  Developer/Test Mode or `MODIFY INTERPRETATION`; corrections are revalidated.
- Loading, duplicate-request locking, cancellation, one explicitly safe retry,
  stale-response rejection, aborting timeout, and explicit non-equipable error
  recovery preserve text and strokes. Wrapper timeouts are not automatically
  retried, and a failed/non-invoked provider cannot enter confirmation or combat.
- Random client/request IDs, D1 cross-isolate idempotency/quota, strict response-ID
  matching, SHA-256 namespaces, and provider-metadata stripping close duplicate
  charge, stale-response, collision, and response/log disclosure paths.
- M1B1 sends bounded `drawing_summary` metadata only. Image understanding is
  explicitly deferred to M1B2.
- Five attack patterns, four elements, and stationary, moving, shielded, and
  grouped targets continue to use the accepted M1A runtime.
- WeaponSpec v2 separates form, delivery, trajectory, impact, and area effect;
  grenades visibly travel on an arc before the landing blast.
- Review, held, attack, and projectile visuals share actual stroke bounds, 10%
  padding, and one uniform scale without rewriting the player's ink.

Production Sites uses Anthropic's native Messages/Structured Outputs API with
the fixed `claude-haiku-4-5-20251001` snapshot and a Worker + D1 lifetime USD 5
hard cap. Local/offline regression uses the deterministic adapter and never
requires a provider secret.

## Run locally

Requirements: Godot 4.7.1. Scripts use
`.tools/Godot_v4.7.1-stable_win64_console.exe` when present, then fall back to
`godot4` or `godot` on `PATH`.

```powershell
./scripts/run_game.ps1
```

For the same-origin Web client and deterministic backend:

```powershell
./scripts/build_web.ps1
./scripts/serve_web.ps1
```

Open [http://localhost:8060](http://localhost:8060) on the development computer.
`localhost` is not a phone delivery address; use the stable public link above for
the accepted M1A phone build.

Controls:

- Forge: draw, type a description, then select `FORGE WEAPON`.
- Review: `CONFIRM`, `MODIFY INTERPRETATION`, `TRY AGAIN`, or report `NOT SUITABLE`.
- Move: `A` / `D`, arrow keys, or on-screen `LEFT` / `RIGHT`.
- Attack: `Space` or on-screen `ATTACK`.
- Return to creation: `REFORGE`.

## Test and package

```powershell
./scripts/test.ps1
./scripts/build_web.ps1
./scripts/build_sites_preview.ps1
```

The full provider-neutral gate also runs the checked-in Chromium and WebKit mobile
regressions documented in `artifacts/M1B1_TEST_RESULTS.md`.

## Documentation

- Product scope: `docs/GDD.md`
- Milestone traceability: `docs/MVP_ACCEPTANCE.md`
- M1B1 executable acceptance: `docs/M1B1_ACCEPTANCE.md`
- M1B1 implementation plan: `docs/M1B1_IMPLEMENTATION_PLAN.md`
- Real-provider options and required decision: `docs/M1B1_PROVIDER_DECISION.md`
- Technical boundaries: `docs/ARCHITECTURE.md`
- Decisions and open questions: `docs/DECISIONS.md`
- Independent M1B1 safety review: `docs/M1B1_RED_TEAM_REPORT.md`
- Mobile/browser regression: `artifacts/M1B1_TEST_RESULTS.md`
- Stable M1A delivery: `docs/M1A_DELIVERY_SUMMARY.md`
- Repository guidance: `AGENTS.md`
