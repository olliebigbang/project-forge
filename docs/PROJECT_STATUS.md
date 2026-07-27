# Project Forge current status

Last updated: **2026-07-27 (Australia/Sydney)**

This is the fast-moving runtime and delivery-status entry point. It does not
replace `GDD.md`, `ARCHITECTURE.md`, `DECISIONS.md`, or milestone acceptance
reports.

## Current production baseline

| Item | Status |
| --- | --- |
| Remote default branch | **CONFIRMED:** `main` |
| Current production source on `main` | **CONFIRMED:** `d88ee9710e1d253e421e6b64f05167579d649fc2` |
| Weapon Physics B1 merge | **CONFIRMED:** PR #7, merge `b37e524c206c5f4490ce612fb5e3d54838e8ebdd` |
| Runtime closeout documentation merge | **CONFIRMED:** PR #8, merge `2c7b8f5021506bece6b60cb2c649ae7f3fbb961e` |
| Weapon Physics/Exposure B1.5 merge | **CONFIRMED:** PR #12, merge `d88ee9710e1d253e421e6b64f05167579d649fc2` |
| Current stable tag | **CONFIRMED:** `v0.4.0-weapon-exposure-b1.5` |
| Production Site | **CONFIRMED:** Version 30 at <https://project-forge-weapon-lab.hongningliu0130.chatgpt.site> |
| Production archive content hash | **CONFIRMED:** `sha256:dd7e8684c5efba9c42f9a67c7b0321348388c8bcbd496150404a96cb48e7a3fe` |
| Accepted-device build | **CONFIRMED:** Sites Version 29 from PR #12 HEAD `1365f0d` |
| Repository visibility | **CONFIRMED:** Public; Issues enabled |

Sites Version 30 records and deploys the B1.5 merge from `main` at `d88ee97`.
Version 29 deployed runtime commit `1365f0d` and passed the authoritative physical
iPhone Safari gate. The commits differ because `698008a` added acceptance
documentation and `d88ee97` is the merge commit; no gameplay runtime change
exists between the accepted v29 runtime and the v30 release source.
Governance-only commits may advance the Git branch without changing this runtime
identity; deployment status must be stated separately from repository
integration status.

## Rollback chain

1. **CONFIRMED direct accepted-runtime rollback:** Sites Version 29 from
   `1365f0d420a77cb03efc3d83850ebecbae7c90dd`.
2. **CONFIRMED direct Git release point:**
   `v0.4.0-weapon-exposure-b1.5` at `d88ee9710e1d253e421e6b64f05167579d649fc2`.
3. **CONFIRMED prior B1 stable point:** Sites Version 25 plus
   `v0.3.0-weapon-physics-b1`.
4. **CONFIRMED historical M1B1 stable point:** `v0.2.0-m1b1` at
   `e363e7321705f5b13983c4ee8731bc5eb9a9c555`.
5. **CONFIRMED historical M1A stable point:** `v0.1.0-m1a` at
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
| Weapon Physics B1.5 role balance | **CONFIRMED complete and released by PR #12 / `d88ee97`** |
| Core Combat C0 lethal micro-playtest | **CONFIRMED diagnostic implementation complete; technical gates pass; gameplay balance gate fails in Chromium and WebKit** |
| Weapon Exposure B1.5 | **CONFIRMED complete; physical iPhone v29 accepted, Sites v30 stable, tag `v0.4.0-weapon-exposure-b1.5`** |
| M1B2 | **CONFIRMED not started** |
| Next gameplay validation | **TBD; B2/M1B2 remain blocked and belt combat/cadence are only future probes** |

B2 and M1B2 descriptions remain roadmap candidates only. They are not
authorization to begin development.

## Work currently allowed

- **CONFIRMED:** documentation reconciliation and engineering governance.
- **CONFIRMED:** provider-free local tests, builds, CI, and browser automation.
- **CONFIRMED:** B1.5 documentation reconciliation, read-only release audits,
  and retention of its QA evidence.
- **CONFIRMED:** scoped Core Combat C0 implementation is functional on its
  isolated branch: 1,147 Godot assertions pass, Web/Sites builds pass, and the
  provider-free Chromium/WebKit functional matrix has zero application console
  errors and zero compile/provider calls.
- **CONFIRMED:** the frozen C0 diagnostic fails under its original
  attack-before-movement aggressive driver. The B1.5 correction replaces that
  driver with same-frame Pressure plus role-agnostic Spacing and uses a bounded
  reach-to-cycle curve. Rebuilt Chromium/WebKit now pass the exposure and
  non-dominance gates; physical-iPhone feel is **CONFIRMED** on Sites Version
  29. See
  `docs/CORE_COMBAT_C0_REPORT.md` and
  `docs/WEAPON_EXPOSURE_B1_5_REPORT.md`.
- **CONFIRMED:** scoped correction of the physical-iPhone ATTACK touch path,
  same-frame Canvas restore race, and explicit Chinese form/element repair.
  The corrected candidate passed its isolated public preview and physical-device
  gate on 2026-07-27.
- **CONFIRMED:** read-only audits of Git, GitHub, Sites metadata, retained
  evidence, branches, and worktrees.
- **CONFIRMED:** scoped fixes to this workflow-hardening branch when they do not
  change gameplay, runtime contracts, or deployment behavior.

## Work currently prohibited

- Starting B2, M1B2, or gameplay work outside the authorized C0 contract.
- Changing player UI, public `WeaponSpec` Schema, `PowerBudget` pricing,
  Provider, D1, or deployment business logic. Gameplay and weapon-physics changes
  are limited to the approved B1.5 acceptance contract.
- Reading or exposing `ANTHROPIC_API_KEY`, or making a real provider call.
- Deploying, rolling back, moving/deleting tags, merging without explicit
  approval, or changing repository visibility.
- Deleting or cleaning branches, worktrees, screenshots, logs, archives, or
  user files without separate approval.

## GitHub control-plane audit

Release audit on 2026-07-27:

- **CONFIRMED:** repository is Public, default branch is `main`, and Issues are
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
- **CONFIRMED:** both required `validate` checks for PR #12 HEAD `698008a`
  succeeded before merge `d88ee97`.
- **CONFIRMED:** stable and rollback tags
  `v0.4.0-weapon-exposure-b1.5`, `v0.3.0-weapon-physics-b1`,
  `v0.2.1-m1b1.2`, `v0.2.0-m1b1`, and `v0.1.0-m1a` exist on the remote.
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
- **TO VALIDATE (browser-harness stability):** the full C0 fairness runner is
  deterministic in the exact-commit local/CI gates but crossed one damage
  quantum and one fixture-staging tolerance in two public production runs.
  Mobile input smoke and physical iPhone acceptance pass; do not treat remote
  wall-clock jitter as new gameplay evidence until the harness is hardened.
- **CONFIRMED (released B1.5):** deterministic execution, 1187 Godot
  assertions, Web/Sites builds, CI, Chromium/functional WebKit evidence, and
  physical-iPhone acceptance are retained. Bow remains
  mobile/first-target/shield-blocked; Piercing uses a longer startup-only
  movement commitment and 29/20/13 three-body damage decay.
- **CONFIRMED:** PR #12, stable Sites Version 30, tag
  `v0.4.0-weapon-exposure-b1.5`, and the Version 29 rollback are closed.
- **TBD:** authentication, production moderation policy, telemetry retention,
  and traffic-scale validation.
- **CONFIRMED:** B1.5 is released; B2 and M1B2 remain **TBD**.

The next gameplay milestone is **TBD**. Cleanup, B2 and M1B2 each require a
later explicit decision. Sites v26 and PR #11 remain superseded evidence.
