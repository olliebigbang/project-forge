# Project Forge release and rollback checklist

Status: **CONFIRMED release process; execute only when a release is authorized**

This checklist records process only. Creating it does not authorize deployment,
provider calls, tag changes, rollback, merge, or cleanup.

## Pre-merge

- [ ] Linked Issue has confirmed baseline, allowed scope, prohibited scope,
      forbidden regressions, acceptance criteria, risk, and rollback.
- [ ] PR is based on current `origin/main` and all intended files are committed
      and pushed.
- [ ] Required CI is green.
- [ ] Independent review is complete and actionable threads are resolved.
- [ ] Product-owner acceptance is recorded against the final PR HEAD or immutable
      candidate build.
- [ ] WebKit and physical-device gates are complete when applicable.
- [ ] Any real-provider check was separately authorized and its durable budget
      guard, attempt ceiling, model identity, and result were recorded.

## Merge and reproducible build

- [ ] Merge commit SHA is recorded.
- [ ] A clean worktree is created from the final remote `main` SHA.
- [ ] `./scripts/test.ps1` passes.
- [ ] `./scripts/build_web.ps1` passes.
- [ ] `./scripts/build_sites_preview.ps1` passes.
- [ ] Release artifacts are built only from the recorded final `main` SHA.
- [ ] Artifact contents and SHA-256 hashes are recorded and verified.
- [ ] No secret, local toolchain, temporary log, or untracked development file is
      included in the release bundle.

## Deployment and smoke

- [ ] Target Site/project and previous production version are recorded.
- [ ] A direct rollback version is identified before deployment.
- [ ] Production deployment source SHA and Sites version are recorded.
- [ ] Public URL returns the expected HTTP status.
- [ ] Critical JS, PCK, WASM parts, Worker modules, and resource hashes match the
      built artifact.
- [ ] Provider-free Chromium smoke passes with no application-level console
      error.
- [ ] WebKit smoke passes when Safari-sensitive behavior changed.
- [ ] A single real-provider smoke runs only when explicitly required and
      authorized.
- [ ] Physical iPhone acceptance runs when touch, keyboard, safe area, toolbar,
      orientation, Canvas, or combat feel changed.

## Stable state and rollback

- [ ] Stable tag exists at the intended tested source commit.
- [ ] `CHANGELOG.md` records the release and known limitations.
- [ ] `docs/PROJECT_STATUS.md` records current main, tag, Sites version, URL,
      artifact hash, rollback chain, and milestone state.
- [ ] Direct Sites rollback version is retained.
- [ ] Direct Git rollback tag is retained.
- [ ] Historical stable tags and formal evidence remain retained.
- [ ] Rollback method is verified without deleting current tags, branches,
      worktrees, or evidence.
- [ ] Release stop condition is explicit; no next milestone starts implicitly.

## Weapon Physics B1 completed example

| Item | Recorded value |
| --- | --- |
| Current production | **CONFIRMED:** Sites Version 25 |
| Production source | **CONFIRMED:** `2c7b8f5021506bece6b60cb2c649ae7f3fbb961e` |
| Equivalent smoke-tested version | **CONFIRMED:** Sites Version 24 |
| Version 24/25 archive hash | **CONFIRMED:** `sha256:13bec17c923b0476aacd1abef09718aebb91549205f0429e04487836de0b8922` |
| Direct Sites rollback | **CONFIRMED:** Version 23 |
| Stable tag | **CONFIRMED:** `v0.3.0-weapon-physics-b1` |
| Direct Git rollback | **CONFIRMED:** `v0.2.1-m1b1.2` |
| Historical stable points | **CONFIRMED:** `v0.2.0-m1b1`, `v0.1.0-m1a` |

The B1 example is a historical completed release record. This workflow-hardening
task does not execute deployment or rollback.
