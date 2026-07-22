# Development workflow hardening report

Status: **CONFIRMED implementation and local verification complete; PR #9
remains the authoritative integration record in GitHub**

Date: 2026-07-23

Branch: `codex/chore/workflow-hardening`

Base: `origin/main`
`2c7b8f5021506bece6b60cb2c649ae7f3fbb961e`

This is a pure engineering-governance change. It does not change gameplay, UI,
`WeaponSpec`, Schema, `PowerBudget`, weapon physics, Provider, D1, combat
balance, or deployment business logic.

## Baseline verification

- **CONFIRMED:** remote `main` is `2c7b8f5`.
- **CONFIRMED:** PR #7 and PR #8 are merged.
- **CONFIRMED:** `v0.3.0-weapon-physics-b1` is the current stable tag.
- **CONFIRMED:** Sites Version 25 is current production and records current
  `main`.
- **CONFIRMED:** Versions 24 and 25 share archive hash
  `sha256:13bec17c923b0476aacd1abef09718aebb91549205f0429e04487836de0b8922`.
- **CONFIRMED:** Sites Version 23 and `v0.2.1-m1b1.2` are the direct rollback
  pair.
- **CONFIRMED:** `v0.2.0-m1b1` and `v0.1.0-m1a` remain historical stable tags.
- **CONFIRMED:** M1B2 has not started.
- **CONFIRMED:** no branch, worktree, evidence, archive, or tag was cleaned.

## Source-of-Truth drift corrected

- Replaced active-language claims that M1B1, M1B1.1, M1B1.2, or B1 release
  closure was still in progress.
- Replaced the old M1B1 v20 preview as the README's current public entry with the
  production Version 25 origin and direct rollback chain.
- Recorded Version 25/current `main` provenance without rewriting the historical
  Version 24 production smoke.
- Marked historical milestone reports as historical instead of changing their
  original test evidence.
- Changed B1.5/B2/M1B2 from implied next authorization to roadmap candidates;
  the next gameplay milestone is `TBD / TO VALIDATE`.
- Reconciled the physical-iPhone keyboard/Safari architecture note with the
  completed device acceptance while preserving the future-device gate.

## New governance controls

- `docs/PROJECT_STATUS.md`: current production, rollback, milestone, GitHub,
  branch/worktree, artifact, limitation, and authorization entry point.
- `docs/DEVELOPMENT_WORKFLOW.md`: Issue through retained rollback delivery
  workflow with stop conditions.
- `docs/RELEASE_CHECKLIST.md`: pre-merge, reproducible main build, deployment,
  smoke, tagging, status, and rollback checklist.
- Structured GitHub bug and feature forms.
- Pull-request template covering scope, regression locks, Source of Truth,
  actual test results, browser/device applicability, evidence, security/cost,
  limitations, rollback, and review.
- No `CODEOWNERS` was guessed. Reviewer ownership remains **TO VALIDATE**.

## CI hardening

Existing Godot, deterministic, Worker, WASM, interpreter, D1, Anthropic adapter,
provider-budget, security, Web/Sites build, packaging parity, size, and SHA-256
gates remain.

The added Chromium gate:

- installs pinned `playwright-core@1.61.1` without lifecycle scripts;
- serves only the local deterministic Web build;
- runs the checked-in browser regression in dedicated provider-free
  `ci-smoke` mode;
- intercepts compile requests and makes no provider call;
- covers 844x390, 852x393, 915x412, 844x343 toolbar stress, Description, Forge,
  confirmation, attack, reforge, rotation, and viewport recovery;
- fails on application-level console warnings/errors;
- uploads report, server logs, and screenshots only on CI failure.

WebKit, real Provider, and physical iPhone remain release-candidate human gates.

## Local verification

| Gate | Result |
| --- | --- |
| YAML parse: workflow + Issue forms | **PASS** |
| `git diff --check` | **PASS** |
| `./scripts/test.ps1` equivalent with one-process execution-policy bypass | **PASS** |
| Godot import/parse and main-scene smoke | **PASS** |
| Deterministic matrix | **PASS: 32 cases, 877 assertions, 0 failed** |
| Static Worker | **PASS: 4/4** |
| WASM loader | **PASS: 1/1** |
| Interpreter | **PASS: 77/77** |
| Durable D1 guard | **PASS: 9/9** |
| Anthropic adapter offline tests | **PASS: 17/17** |
| Provider budget offline tests | **PASS: 14/14** |
| Anthropic safety offline tests | **PASS: 11/11** |
| `./scripts/build_web.ps1` equivalent | **PASS** |
| `./scripts/build_sites_preview.ps1` equivalent | **PASS** |
| Chromium full simulated mobile regression | **PASS: 4 layouts, 4 fixture requests, 0 application console errors** |
| Chromium dedicated `ci-smoke` | **PASS: 4 layouts, 1 immediate fixture call, no provider claim, 0 application console errors** |
| Real provider | **NOT RUN — prohibited for this task** |
| WebKit | **NOT RUN — unchanged runtime; retained release-candidate gate** |
| Physical iPhone | **NOT RUN — unchanged runtime; retained release-candidate gate** |
| Deployment | **NOT RUN — prohibited for this task** |

Windows initially blocked direct `.ps1` execution and the isolated worktree did
not contain ignored local tools. Verification used a process-scoped
`-ExecutionPolicy Bypass` and an ignored junction to the existing Godot 4.7.1
tool directory. Neither changes system policy nor enters Git.

## GitHub control-plane result

- Repository is Private; Issues are enabled.
- `main` protection requires strict `validate` CI, includes administrators,
  disables force-push/deletion, and requires review-conversation resolution.
- Required approving review count is 0; code-owner review is disabled.
- No additional repository ruleset exists.
- Latest `main` CI for `2c7b8f5` passed.

## Remaining TO VALIDATE / TBD

- **TO VALIDATE:** reviewer and code-owner ownership.
- **TO VALIDATE:** separate product-owner cleanup decision for retained
  historical branches, worktrees, logs, captures, and archives.
- **TBD / TO VALIDATE:** next gameplay milestone and its acceptance boundary.
- **TBD:** production authentication, moderation policy, telemetry retention,
  and traffic-scale validation.

## Risk and rollback

Primary risk is CI browser-runner availability or future Playwright/Chrome
compatibility. The dependency is pinned, Chrome presence is checked, the test is
provider-free, and failure evidence is uploaded.

Before merge, rollback is abandoning or reverting this branch. After merge,
rollback is a normal revert of the workflow-hardening commit; no Sites version,
stable tag, runtime artifact, provider budget, or database is changed by this
task.
