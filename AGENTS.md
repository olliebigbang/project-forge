# Project Forge repository guide

## Project identity

This is a new, standalone game. Never import or reuse code, names, lore, art,
assets, balance data, or development direction from Cat Battle or another project.

## Source of truth

- `docs/PROJECT_STATUS.md` is the current runtime and delivery-status entry point.
- `docs/GDD.md` preserves the product vision and milestone scope.
- `docs/MVP_ACCEPTANCE.md` defines the current gate.
- `docs/ARCHITECTURE.md` defines the data and runtime boundaries.
- `docs/DECISIONS.md` records settled and unsettled decisions.
- Milestone acceptance documents preserve their historical evidence and do not
  get rewritten as current status pages.
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
- **CONFIRMED** M1B1 real text interpretation and its reopened P0 fixes passed
  physical iPhone Safari acceptance on 2026-07-20 and are released.
- Weapon Physics B1 release closure is complete. Do not start M1B2 from the
  B1 release or closeout branches, and do not move/delete any stable tag.
- **CONFIRMED** Current stable runtime delivery was built from `main` at `2c7b8f5`, tag
  `v0.3.0-weapon-physics-b1`, and Sites Version 25. Sites Version 23 plus
  `v0.2.1-m1b1.2` are the direct rollback pair.
- The M1A forge uses five persistent attack-pattern test buttons. Never restore
  an `OptionButton`, `PopupMenu`, or full-screen modal selector for this flow.

Do not add paid AI, secrets, production levels or art, voice, accounts, cloud
saves, sharing, monetization, multiplayer, or store submission in M1A.

## Current scope: stable Weapon Physics B1 baseline

- M1B1.1 player-interface simplification and M1B1.2 absolute held-melee reach are
  stable on `main`; Weapon Physics B1 is PR #7 from
  `codex/feat/weapon-physics-b1`. It is not M1B2.
- Preserve every M1B1 AI, Worker, D1, schema, PowerBudget, request/revision,
  failure-recovery, and physical-iPhone input invariant below.
- For held melee, frozen `effective_reach` remains the single source for visible
  grip-to-tip length, hit boundary, and HUD Range. One derived complete cycle
  owns startup, active, hit time, recovery, cooldown, visible swing speed, and
  input acceptance. Do not restore fixed held size, hidden reach padding, or
  independent animation/cooldown clocks.
- Drawing length does not determine damage. B1 mass is a separate bounded
  cross-axis proxy and cannot change reach or grant impact. Uniform grip-to-tip
  damage remains an explicit B2 follow-up; do not add contact regions, sweet
  spots, interruption, or new Schema fields during B1 closure.
- The executable gate is `docs/WEAPON_PHYSICS_B1_ACCEPTANCE.md`. Physical-iPhone
  cadence acceptance, PR #7, CI, merge, stable deployment, production smoke,
  stable tag, and rollback verification completed on 2026-07-22.

## Current development scope: Weapon Physics B1.5

- **CONFIRMED:** the product owner authorized the isolated Weapon Physics B1.5
  role-balance milestone on 2026-07-23. Its executable contract is
  `docs/WEAPON_ROLE_BALANCE_B1_5_ACCEPTANCE.md`; GitHub Issue #10 and branch
  `codex/feat/weapon-role-balance-b1-5` own the implementation.
- B1.5 validates deterministic roles for short/standard/long melee, straight
  ranged, thrown blast, boomerang and piercing. Every role needs an executed
  advantage and cost; equal raw DPS is not the target.
- Existing M1B1 AI remains stable and may select only allow-listed semantics.
  Local deterministic code owns numeric physics. Do not expand the public Schema
  until the controlled physicality experiments establish required fields.
- Do not start B2 or M1B2, and do not add contact-region or visual-understanding
  semantics, during B1.5.

## Preserved M1B1 boundaries

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
- Preserve drawing/text across cancellation, timeout, retry and explicit error
  recovery. Provider failure must never create an equipable fallback weapon.
- Keep `weapon_form`, `delivery`, `trajectory`, `impact`, and `area_effect`
  independent from `attack_pattern`; `area_blast` never substitutes for a
  grenade's thrown/arc delivery.
- Fit player-ink visuals from actual raw-stroke bounds with 8%-12% padding and
  one uniform scale. Never destructively rewrite source strokes. Only a semantic
  thrown object may reuse ink as a projectile; bows, guns, energy and piercing
  attacks use deterministic projectile visuals selected by `WeaponVisualBundle`.
- Web keyboard entry owns a stable landscape Canvas. Never resize the game world
  from the temporary keyboard-reduced Visual Viewport; keep Description, clear
  and Done inside the visible safe area and restore normal layout after blur.
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

- Follow `docs/DEVELOPMENT_WORKFLOW.md`; every major task starts from a scoped
  issue and an isolated worktree based on current `origin/main`.
- Stable runtime source: `main` at `2c7b8f5` when this guide was last reconciled;
  governance-only commits may advance the branch without a Sites deployment.
- Current stable tag: `v0.3.0-weapon-physics-b1`.
- Direct rollback tag: `v0.2.1-m1b1.2`; historical stable tags
  `v0.2.0-m1b1` and `v0.1.0-m1a` remain retained.
- Completed B1 branch: `codex/feat/weapon-physics-b1` (merged PR #7; retained
  until cleanup is separately approved).
- Active B1.5 branch: `codex/feat/weapon-role-balance-b1-5` (Issue #10; isolated
  worktree; not approved to merge or deploy as stable).
- Stable B1 tag: `v0.3.0-weapon-physics-b1`; retained rollback tag:
  `v0.2.1-m1b1.2`.
- Compact Landscape uses CSS `visualViewport` dimensions; do not size mobile
  touch controls from the 1280×720 logical viewport alone.
- Web Description input is a bounded native HTML overlay synchronized with
  Godot. Keep it off combat and portrait-gate screens, and preserve native
  `LineEdit` behavior for non-Web builds.
- QA and art work remain isolated in their assigned worktrees/branches.
- Only the main integrator selects changes into the delivery branch.
- Never merge, delete branches/worktrees, or clean user work without confirmation.
- Push/open a PR only when a normal Git remote is configured.
- Release and rollback work follows `docs/RELEASE_CHECKLIST.md` and must update
  `docs/PROJECT_STATUS.md` after the final deployed state is known.
