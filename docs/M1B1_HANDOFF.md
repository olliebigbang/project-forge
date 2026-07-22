# M1B1 final handoff

Date: 2026-07-20 (Australia/Sydney)

Status: **CONFIRMED and released; all M1B1 runtime/security boundaries remain
locked through the later Weapon Physics B1 stable release**

M1B2 has not started. This handoff records the accepted M1B1 product behavior
and the exact release-closure boundary.

## Physical iPhone acceptance

The product owner accepted the public Sites v19 build on a real iPhone Safari
session and reported no new blocker. The following all passed:

- first-touch Description focus and iOS keyboard appearance;
- no black Canvas while the keyboard was open;
- input, deletion, Done, and keyboard dismissal;
- Bow remains held and emits arrows;
- Grenade follows an arc, explodes, and restores after cooldown;
- Sword emits no projectile;
- Boomerang leaves and returns;
- the tested re-forge/navigation path.

This is the authoritative device result. Browser emulation remains supporting
evidence, not a substitute for it.

## Accepted build identity

- Public origin:
  `https://project-forge-weapon-lab.hongningliu0130.chatgpt.site/`
- Accepted diagnostic URL:
  `https://project-forge-weapon-lab.hongningliu0130.chatgpt.site/?qa=m1b1&release=p0-v20-6d5ba3a`
- Sites version: 19
- Sites source runtime: `6d5ba3a7c10c2eb46154209744c9af55e072cb32`
- PR #4 head when the public evidence was finalized:
  `019a6e82af554c22c2022b22e71bfb2245e4bd11`

The two Git identifiers differ because `019a6e8` is the direct child of
`6d5ba3a` and contains only README/docs plus committed screenshots and reports
created after deployment. There is no scene, runtime, Worker, schema, export, or
build-script delta between them. Repeated builds from `019a6e8` matched each
other, and their executable PCK/WASM matched Sites v19 byte-for-byte.

The final closure commit adds an 8192-byte bounded Worker request reader,
canonical release CI verification, and release records. It does not modify the
accepted mobile UI or combat behavior. The final merged SHA and stable Sites
version are reported after deployment.

## Verification evidence

- `scripts/test.ps1`: PASS for Godot import/parse, 629 deterministic assertions,
  main-scene smoke, Worker, WASM loader, Interpreter, D1 request guard,
  Anthropic adapter, D1 provider-budget guard, and hostile safety suites.
- Node security total after final review fix: 133/133 PASS; Interpreter 77/77.
- Canonical Web and Sites package: two reproducible builds, required iOS scripts
  injected, WASM chunks reconstruct byte-for-byte, reviewed Worker modules copied
  byte-for-byte.
- Chromium and Playwright WebKit P0 regression: four weapon cases PASS; Bow
  10/10 with zero held drift, Grenade arc/blast/restore, Sword projectile delta
  zero, Boomerang same-instance return, three orientation cycles, console errors
  zero.
- Canonical Anthropic mobile regression in Chromium and WebKit: 844×390,
  852×393, 915×412, and 844×343 toolbar stress PASS; cancellation, explicit
  non-equipable errors, rotation, background/resume simulation, confirmation,
  MODIFY, and combat PASS; application console errors zero.
- Real Claude evidence remains the controlled 42-case matrix plus the retained
  grenade/bow requests. Provider/model were exactly
  `anthropic / claude-haiku-4-5-20251001` and D1 charges settled under the USD 5
  lifetime cap.

## Final independent review

The independent review found two release blockers and no additional blocker in
iOS input, Canvas ownership, visual roles, combat lifecycles, StrokeFit, schema,
PowerBudget, Anthropic identity, or D1 billing boundaries.

The two blockers were fixed without scope expansion:

1. no-`Content-Length` request streams now stop at byte 8193 and return 413
   before JSON parsing, D1, rate limiting, or provider invocation;
2. CI now runs the canonical `build_sites_preview.ps1` pipeline, verifies every
   iOS injection and Worker/WASM packaging boundary, generates SHA-256 evidence,
   and uploads the deployable `dist` rather than a raw Godot export.

## Rollback chain

- Immediate pre-merge rollback: saved Sites version 19, source `6d5ba3a`.
- Retained package: `output/project-forge-m1b1-6d5ba3a-sites.tgz`, SHA-256
  `17fa60fc94c4839473081750ec623f4497c68f879f06c507166e53f1af590672`.
- Conservative baseline: Git tag `v0.1.0-m1a`, commit
  `b09bd8fb6fa7d4466251f73e6d647823682d513e`, plus the retained M1A Sites
  archive.

Rollback means redeploying the saved Sites version or retained package; it does
not delete the current stable tag, evidence, branches, or worktrees.

## Residual risks

- M1B1 interprets text and bounded numeric drawing metadata; drawing-image
  semantics remain M1B2 scope.
- Authentication, production moderation policy, telemetry retention, and
  traffic-scale validation remain TBD for later milestones.
- Playwright WebKit renderer diagnostics are engine noise; final application
  console errors were zero.
- The provider budget is intentionally lifetime-capped at USD 5 and fails closed;
  exhaustion is a visible non-equipable error, not an automatic model fallback.

## Weapon Physics B1 release addendum (2026-07-22)

M1B1 itself remained unchanged while the local deterministic held-melee
physicality experiment closed. PR #7 merged as
`b37e524c206c5f4490ce612fb5e3d54838e8ebdd`; stable Sites Version 24 deployed
that exact commit and passed HTTP, Chromium, WebKit, keyboard, four weapon-role,
and one-call real Anthropic smoke checks. Stable tag
`v0.3.0-weapon-physics-b1` and rollback pair Sites v23 / `v0.2.1-m1b1.2` are
retained. No M1B2 work started.
