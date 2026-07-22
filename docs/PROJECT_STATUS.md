# Project Forge current status

Last updated: **2026-07-23 (Australia/Sydney)**

This is the fast-moving runtime and delivery-status entry point. It does not
replace `GDD.md`, `ARCHITECTURE.md`, `DECISIONS.md`, or milestone acceptance
reports.

## Current production baseline

| Item | Status |
| --- | --- |
| Remote default branch | **CONFIRMED:** `main` |
| Current production source on `main` | **CONFIRMED:** `2c7b8f5021506bece6b60cb2c649ae7f3fbb961e` |
| Weapon Physics B1 merge | **CONFIRMED:** PR #7, merge `b37e524c206c5f4490ce612fb5e3d54838e8ebdd` |
| Runtime closeout documentation merge | **CONFIRMED:** PR #8, merge `2c7b8f5021506bece6b60cb2c649ae7f3fbb961e` |
| Current stable tag | **CONFIRMED:** `v0.3.0-weapon-physics-b1` |
| Production Site | **CONFIRMED:** Version 25 at <https://project-forge-weapon-lab.hongningliu0130.chatgpt.site> |
| Production archive hash | **CONFIRMED:** `sha256:13bec17c923b0476aacd1abef09718aebb91549205f0429e04487836de0b8922` |
| Equivalent smoke-tested build | **CONFIRMED:** Sites Version 24 has the same archive hash |
| Repository visibility | **CONFIRMED:** Private; Issues enabled |

Sites Version 25 records the current production source from `main`. Version 24 deployed the gameplay merge
`b37e524` and passed HTTP, Chromium, WebKit, mobile-input, four weapon-role,
and one explicitly authorized Anthropic smoke gate. The equal archive hash proves
that the Version 25 code bundle is equivalent; it does not rewrite the historical
Version 24 smoke record. Governance-only commits may advance the Git branch
without changing this runtime identity; deployment status must be stated
separately from repository integration status.

## Rollback chain

1. **CONFIRMED direct runtime rollback:** Sites Version 23.
2. **CONFIRMED direct Git rollback:** `v0.2.1-m1b1.2` at
   `9e0ff3b174c1c38d2dcb35f0717775e2a9d9aaef`.
3. **CONFIRMED historical M1B1 stable point:** `v0.2.0-m1b1` at
   `e363e7321705f5b13983c4ee8731bc5eb9a9c555`.
4. **CONFIRMED historical M1A stable point:** `v0.1.0-m1a` at
   `b09bd8fb6fa7d4466251f73e6d647823682d513e`.

Retained release archives, test evidence, branches, and worktrees are part of
rollback readiness. No cleanup is authorized by this governance task.

## Milestone state

| Milestone | State |
| --- | --- |
| M0 technical spike | **CONFIRMED complete** |
| M1A deterministic compiler and mobile acceptance | **CONFIRMED complete** |
| M1B1 real text interpreter and reopened P0 fixes | **CONFIRMED complete** |
| M1B1.1 player UI simplification | **CONFIRMED complete** |
| M1B1.2 absolute held-melee reach | **CONFIRMED complete** |
| Weapon Physics B0 authority contract | **CONFIRMED complete** |
| Weapon Physics B1 controlled melee physicality | **CONFIRMED complete and released** |
| M1B2 | **CONFIRMED not started** |
| Next gameplay milestone | **TBD / TO VALIDATE: product-owner decision required** |

Earlier B1.5, B2, and M1B2 descriptions are roadmap candidates only. They are not
authorization to begin development.

## Work currently allowed

- **CONFIRMED:** documentation reconciliation and engineering governance.
- **CONFIRMED:** provider-free local tests, builds, CI, and browser automation.
- **CONFIRMED:** read-only audits of Git, GitHub, Sites metadata, retained
  evidence, branches, and worktrees.
- **CONFIRMED:** scoped fixes to this workflow-hardening branch when they do not
  change gameplay, runtime contracts, or deployment behavior.

## Work currently prohibited

- Starting B1.5, B2, M1B2, or any other gameplay milestone.
- Changing gameplay, player UI, `WeaponSpec`, Schema, `PowerBudget`, weapon
  physics, combat balance, Provider, D1, or deployment business logic.
- Reading or exposing `ANTHROPIC_API_KEY`, or making a real provider call.
- Deploying, rolling back, moving/deleting tags, merging without explicit
  approval, or changing repository visibility.
- Deleting or cleaning branches, worktrees, screenshots, logs, archives, or
  user files without separate approval.

## GitHub control-plane audit

Read-only audit on 2026-07-23:

- **CONFIRMED:** repository is Private, default branch is `main`, and Issues are
  enabled.
- **CONFIRMED:** `main` protection requires the `validate` status check with
  strict up-to-date branches.
- **CONFIRMED:** the protected branch requires the pull-request path and blocks
  direct protected-branch updates that do not satisfy its rules; administrators
  are not exempt.
- **CONFIRMED:** administrators are included; force-push and branch deletion are
  disabled; all review conversations must be resolved.
- **CONFIRMED:** required approving review count is currently 0 and code-owner
  review is not enabled.
- **CONFIRMED:** there are no repository rulesets in addition to branch
  protection.
- **CONFIRMED:** the latest `main` CI for `2c7b8f5` succeeded in run
  [29927724188](https://github.com/olliebigbang/project-forge/actions/runs/29927724188).
- **CONFIRMED:** stable and rollback tags
  `v0.3.0-weapon-physics-b1`, `v0.2.1-m1b1.2`, `v0.2.0-m1b1`, and
  `v0.1.0-m1a` exist on the remote.
- **TO VALIDATE:** reviewer ownership is not confirmed; do not create
  `CODEOWNERS` by guessing a user or team.

## Retained branches and worktrees

The workflow-hardening task uses
`codex/chore/workflow-hardening` in
`output/workflow-hardening-worktree`, based on the audited `origin/main`
baseline `2c7b8f5`.

Remote historical branches retained at audit time:

- `codex/deploy/ui-preview`
- `codex/docs/weapon-physics-b1-closeout`
- `codex/feat/m1b1-real-text-interpreter`
- `codex/feat/weapon-physics-b1`
- `codex/fix/absolute-weapon-reach`
- `codex/fix/m1b1-input-aspect`
- `codex/ui/player-interface-simplification`

Retained worktrees include the old M1B1 closure root, Weapon Physics B1,
player-UI simplification, absolute reach, UI preview, detached M1B1.2 rollback,
detached B1 release verification, M1A art/QA/stable, and M1B1 mobile/safety QA
worktrees. Their exact paths remain discoverable through
`git worktree list --porcelain`.

- **CONFIRMED:** none were cleaned during workflow hardening.
- **TO VALIDATE:** every historical worktree and branch needs a separate
  product-owner cleanup decision.

## Retained artifact classification

| Class | Examples | Policy |
| --- | --- | --- |
| Formal acceptance evidence | tracked acceptance reports; physical-iPhone reports; accepted browser screenshots and JSON | **CONFIRMED retain** |
| Rollback material | Sites v23; stable tags; release archives such as `project-forge-b1-stable-*.tar.gz` and retained M1B1 packages | **CONFIRMED retain** |
| Regenerable builds | `build/web`, `dist`, CI bundle staging, local release verification directories | May be regenerated; do not delete in this task |
| Temporary logs | `output/*server.stdout.log`, `output/*server.stderr.log`, Godot test logs, temporary browser reports | Ignored going forward; existing files remain untouched |
| Unclear / user decision | old QA, art, preview, detached, and closure worktrees plus untracked historical captures | **TO VALIDATE before cleanup** |

## Known limitations and open decisions

- **TO VALIDATE:** the 72 px reach floor still loses sub-grid resolution.
- **TO VALIDATE:** mass is a bounded cross-axis proxy rather than material
  density, balance point, or moment of inertia.
- **TO VALIDATE:** contact regions, tip/root damage, sweet spots, interruption,
  shield/multi-target physical response, and matching feedback are absent.
- **TO VALIDATE:** weapon-role and near/ranged compensation are absent.
- **TBD:** authentication, production moderation policy, telemetry retention,
  and traffic-scale validation.
- **TBD:** the next gameplay milestone, its scope, acceptance gate, and owner.

The next action requiring product-owner confirmation is selection of the next
gameplay milestone. It must begin with a new Issue and isolated worktree from
then-current `origin/main`; this status page must be updated at that point.
