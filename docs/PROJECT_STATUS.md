# Project Forge current status

Last updated: **2026-07-31 (Australia/Sydney)**

This is the fast-moving runtime and delivery-status entry point. It does not
replace `GDD.md`, `ARCHITECTURE.md`, `DECISIONS.md`, or milestone acceptance
reports.

## Current production baseline

| Item | Status |
| --- | --- |
| Remote default branch | **CONFIRMED:** `main` |
| Current accepted M2 gameplay merge on `main` | **CONFIRMED:** PR #21 merge `3da018917193d269429354ae0d93cac70cf2cf8c` |
| Weapon Physics B1 merge | **CONFIRMED:** PR #7, merge `b37e524c206c5f4490ce612fb5e3d54838e8ebdd` |
| Runtime closeout documentation merge | **CONFIRMED:** PR #8, merge `2c7b8f5021506bece6b60cb2c649ae7f3fbb961e` |
| Weapon Physics/Exposure B1.5 merge | **CONFIRMED:** PR #12, merge `d88ee9710e1d253e421e6b64f05167579d649fc2` |
| M2 belt-combat accepted-prototype merge | **CONFIRMED:** PR #15, merge `ee2583c3664d4013d165d7276f8222238cd49152` |
| M2A live-WeaponSpec belt integration merge | **CONFIRMED:** PR #18, merge `7fa6f7ee2684b44af2c51796d763c80910fff5fd` |
| M2B playable-loop merge | **CONFIRMED:** PR #21, merge `3da018917193d269429354ae0d93cac70cf2cf8c` |
| Current Git milestone tag | **CONFIRMED:** `v0.6.0-m2b-playable-loop` |
| Current deployed stable tag | **CONFIRMED:** `v0.6.0-m2b-playable-loop` |
| Production Site | **CONFIRMED:** Sites Version 32, embedded marker `3da018917193`, at <https://project-forge-weapon-lab.hongningliu0130.chatgpt.site/?release=m2b-v32-3da0189> |
| Retained v32 local archive hash | **CONFIRMED:** `sha256:1e0001bfaeb32f8e115ff0c21245a4f80f94a199e073fe4134ea9292a6ae15fb` |
| Accepted-device build | **CONFIRMED:** Sites Version 31 runtime `0577e936b0dd`; final PR #21 branch candidate `c95f2c7` adds test/report evidence only |
| Repository visibility | **CONFIRMED:** Public; Issues enabled |

Sites Version 31 embeds runtime marker `0577e936b0dd` and passed the authoritative
physical-iPhone Safari gate on 2026-07-31. Final PR #21 candidate `c95f2c7`
differed only by browser test/report evidence. PR #21 then merged as `3da0189`.
Sites Version 32 was rebuilt from that exact merged `main`, embeds marker
`3da018917193`, and passed formal Playwright mobile plus the complete public
provider-free M2B regression. Version 31 is the direct accepted-device rollback;
Version 30 remains the prior B1.5 stable rollback.

PR #15 advanced `main` to `ee2583c` and tag `v0.5.0-m2-belt-spike` records that
accepted Git milestone. The side-view Combat Lab remains an executable regression
and rollback baseline.

PR #18 advanced `main` to `7fa6f7e` and made belt combat the normal
post-confirmation destination while retaining the side-view Combat Lab as an
explicit Developer/QA route. PR #21 completed the minimum playable belt-room
loop and released it from exact merged `main` as Sites Version 32.

## Rollback chain

1. **CONFIRMED current stable release:** Sites Version 32 plus
   `v0.6.0-m2b-playable-loop`, exact merge `3da018917193d269429354ae0d93cac70cf2cf8c`.
2. **CONFIRMED direct accepted-device rollback:** Sites Version 31 with embedded
   marker `0577e936b0dd`.
3. **CONFIRMED prior stable Sites rollback:** Sites Version 30 at B1.5 merge
   `d88ee9710e1d253e421e6b64f05167579d649fc2`.
4. **CONFIRMED accepted-device B1.5 rollback:** Sites Version 29 from
   `1365f0d420a77cb03efc3d83850ebecbae7c90dd`.
5. **CONFIRMED accepted M2 Git milestone:**
   `v0.5.0-m2-belt-spike` at PR #15 merge `ee2583c`.
6. **CONFIRMED accepted M2A repository integration:** PR #18 merge
   `7fa6f7ee2684b44af2c51796d763c80910fff5fd`.
7. **CONFIRMED direct deployed Git release point:**
   `v0.4.0-weapon-exposure-b1.5` at `d88ee9710e1d253e421e6b64f05167579d649fc2`.
8. **CONFIRMED prior B1 stable point:** Sites Version 25 plus
   `v0.3.0-weapon-physics-b1`.
9. **CONFIRMED historical M1B1 stable point:** `v0.2.0-m1b1` at
   `e363e7321705f5b13983c4ee8731bc5eb9a9c555`.
10. **CONFIRMED historical M1A stable point:** `v0.1.0-m1a` at
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
| M2 belt-combat comparison spike | **CONFIRMED complete and merged by PR #15 / `ee2583c`; physical-iPhone runtime `39b077e` accepted; belt combat approved as the future primary direction; stable Combat Lab remains the current default regression baseline** |
| M2A live-WeaponSpec belt integration | **CONFIRMED repository integration, device acceptance, and deployed inclusion:** PR #18 merged as `7fa6f7e`; its corrected route is included in accepted Sites Version 31; B2/M1B2 and cadence remain unstarted |
| M2B minimum playable belt-combat loop | **CONFIRMED complete and released:** Issue #20; physical-iPhone Sites Version 31 accepted; PR #21 merged as `3da0189`; exact-main Sites Version 32 and tag `v0.6.0-m2b-playable-loop`; public smoke passed |

B2 and M1B2 descriptions remain roadmap candidates only. They are not
authorization to begin development.

## Work currently allowed

- **CONFIRMED:** read-only M2C/playability planning and definition of a separate
  executable gate. Implementation still requires explicit authorization.
- **CONFIRMED:** documentation closeout and read-only verification of the merged
  M2 belt-combat comparison spike. PR #15 merged as `ee2583c`,
  `v0.5.0-m2-belt-spike` records the accepted Git milestone, and production
  deployment remains unchanged.
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

- Deleting the stable side-view Combat Lab, Sites Versions 31/32, stable tags,
  worktrees, screenshots, logs, or rollback archives without explicit cleanup
  approval.
- Starting M2C, B2, M1B2, cadence/automatic firearms, charged grenades, or other
  gameplay work before its own explicitly approved executable gate.
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
  `v0.6.0-m2b-playable-loop`, `v0.5.0-m2-belt-spike`,
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
- `codex/feat/m2b-playable-combat-loop`
- `codex/feat/weapon-physics-b1`
- `codex/fix/absolute-weapon-reach`
- `codex/fix/m1b1-input-aspect`
- `codex/ui/player-interface-simplification`
- `codex/docs/m2b-release-closeout`

Retained worktrees include the old M1B1 closure root, Weapon Physics B1,
player-UI simplification, absolute reach, UI preview, detached M1B1.2 rollback,
detached B1 release verification, M1A art/QA/stable, and M1B1 mobile/safety QA
worktrees. Their exact paths remain discoverable through
`git worktree list --porcelain`.

The M2B gameplay worktree and the retained exact-main release-verification
worktree remain present with public regression evidence and the Version 32
archive. They are not cleanup candidates without a separate owner decision.

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
