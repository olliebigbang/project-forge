# Project Forge repository guide

## Project identity

This is a new, standalone game. Never import or reuse code, names, lore, art,
assets, balance data, or development direction from Cat Battle or another project.

## Source of truth

- `docs/GDD.md` preserves the product vision and milestone scope.
- `docs/MVP_ACCEPTANCE.md` defines the current gate.
- `docs/ARCHITECTURE.md` defines the data and runtime boundaries.
- `docs/DECISIONS.md` records settled and unsettled decisions.
- Uncertainty must be marked exactly `CONFIRMED`, `ASSUMPTION`, `TO VALIDATE`, or
  `TBD`; do not silently resolve product questions.

## Stable baseline and current development scope

- Godot 4.7.1, 2D landscape, Web-first.
- Drawing and one text line feed a deterministic local `WeaponCompiler`.
- Five attack modules and four elements must remain executable.
- Every `WeaponSpec` passes JSON Schema parity checks and runtime repair.
- Power cost must be explicit, deterministic, capped at 100, and logged.
- Strong capabilities must have a visible drawback or deterministic stat cost.
- Test against stationary, moving, shield, and grouped targets.
- Physical iPhone Safari acceptance for v9 is complete and recorded.
- **CONFIRMED** M1B1 real text interpretation is authorized only on
  `codex/feat/m1b1-real-text-interpreter`, based on `v0.1.0-m1a`.
- Never develop M1B1 on `main` or move/delete the stable tag.
- The M1A forge uses five persistent attack-pattern test buttons. Never restore
  an `OptionButton`, `PopupMenu`, or full-screen modal selector for this flow.

Do not add paid AI, secrets, production levels or art, voice, accounts, cloud
saves, sharing, monetization, multiplayer, or store submission in M1A.

## Current scope: M1B1

- Normal players enter free text; five attack-pattern buttons are hidden until
  Developer/Test Mode or MODIFY INTERPRETATION.
- Godot calls only the same-origin project backend. Never call a provider from
  Godot or expose a provider key to Web/client code.
- Provider output is untrusted semantic data. Server and client both enforce the
  existing schema allow-lists and `PowerBudget` before combat.
- Never reflect provider free-form names, summaries, corrections, metadata or
  nested cost objects. Generate player-facing text from validated labels and keep
  cost to `UNKNOWN` or the strict bounded currency structure.
- Preserve random caller/request IDs, SHA-256 namespaces, D1 cross-isolate
  idempotency/quota, and strict response-ID/revision checks; a late response
  cannot commit to a newer request.
- A wrapper timeout must abort and must not automatically retry. Retry at most
  once only when the provider adapter explicitly proves the failure retry-safe.
- Before paid public traffic, require a provider account spend cap. Sites D1 is
  the application quota/idempotency boundary. Any non-local provider with a
  missing, partial, or unavailable D1 guard must fail closed before invocation.
- **CONFIRMED** M1B1 uses Anthropic's native Messages API with native Structured
  Outputs and the immutable model snapshot `claude-haiku-4-5-20251001`. Never use
  an OpenAI-compatible Anthropic endpoint or auto-upgrade to another Claude tier.
- **CONFIRMED** `M1B1_PROVIDER_BUDGET_USD=5` is a lifetime application hard cap.
  Worker + D1 reserve worst-case spend before invocation, settle verified usage,
  conservatively charge ambiguous outcomes, and fail closed on guard uncertainty.
- `ANTHROPIC_API_KEY` is a Sites Secret only. Never read, print, copy, persist, or
  inject it into tests, Godot, browser assets, Git, screenshots, or logs.
- Drawing input is numeric `drawing_summary` only; visual semantics are M1B2.
- Preserve drawing/text across cancellation, timeout, retry and fallback.
- No M1B2, voice, production art, accounts, sharing, monetization or multiplayer.

## Engineering rules

- Use typed GDScript where practical; warnings are treated as parse failures.
- AI output is data only. Never generate or execute gameplay code.
- Keep JSON Schema and `WeaponSpec` runtime allow-lists/bounds in parity.
- Preserve player strokes in the generated weapon visual.
- Touch interactions cannot depend on hover, right-click, or keyboard.
- Add deterministic matrix cases for compiler or budget changes.
- Retain repair reasons and budget breakdowns in the generation audit.
- Keep `.godot/`, `.tools/`, `build/web/`, `dist/`, and release archives out of Git.

## Verification commands

```powershell
./scripts/test.ps1
./scripts/build_web.ps1
./scripts/build_sites_preview.ps1
```

## Git and agent workflow

- Stable branch after release closure: `main`.
- Stable release tag: `v0.1.0-m1a`.
- Current integration branch: `codex/feat/m1b1-real-text-interpreter`.
- Compact Landscape uses CSS `visualViewport` dimensions; do not size mobile
  touch controls from the 1280×720 logical viewport alone.
- Web Description input is a bounded native HTML overlay synchronized with
  Godot. Keep it off combat and portrait-gate screens, and preserve native
  `LineEdit` behavior for non-Web builds.
- QA and art work remain isolated in their assigned worktrees/branches.
- Only the main integrator selects changes into the delivery branch.
- Never merge, delete branches/worktrees, or clean user work without confirmation.
- Push/open a PR only when a normal Git remote is configured.
