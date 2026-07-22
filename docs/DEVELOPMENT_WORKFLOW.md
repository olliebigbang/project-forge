# Project Forge development workflow

Status: **CONFIRMED engineering workflow**

This workflow applies to gameplay, UI, AI, infrastructure, fixes, and release
governance. It preserves the current stable baseline until a scoped task passes
all applicable gates.

## Standard delivery path

```text
Issue
  -> confirm baseline and scope
  -> isolated branch + worktree
  -> implementation
  -> local tests
  -> browser verification
  -> Draft PR
  -> CI
  -> independent review
  -> product acceptance
  -> merge
  -> reproducible build from final main
  -> deploy + smoke
  -> stable tag + status documents
  -> retained rollback point
```

Skipping a stage requires an explicit recorded decision. A passing local test is
not evidence that a later browser, physical-device, provider, or deployment gate
passed.

## 1. Issue and scope

- One Issue owns one primary task or defect.
- Record the formal baseline: `origin/main` SHA, current stable tag, Sites
  version when relevant, and dependency PRs/issues/decisions.
- State allowed files and systems, prohibited scope, forbidden regressions,
  acceptance criteria, tests, evidence, risks, and rollback.
- Mark every uncertainty exactly `CONFIRMED`, `ASSUMPTION`, `TO VALIDATE`,
  or `TBD`.
- A fix must list the accepted behavior that must not regress.
- A new gameplay milestone requires explicit product-owner authorization.

## 2. Isolated branch and worktree

- Fetch current `origin/main` and verify it against `docs/PROJECT_STATUS.md`.
- Create one new branch and one isolated worktree for the task.
- Never develop directly on production `main`.
- Never start new work from an old feature, preview, QA, or release-closure
  branch.
- Do not edit the same files concurrently from multiple agents/worktrees.
- Only the main integrator selects commits for the delivery branch.

If the remote baseline differs from the recorded baseline, stop implementation,
record the difference, and resolve which state is authoritative.

## 3. Implementation

- Change only the scoped systems.
- Preserve Source of Truth and add tests with the behavior change.
- Do not introduce real provider calls, paid services, secrets, deployment, or
  destructive cleanup unless the Issue explicitly authorizes them.
- Provider output is data only and cannot execute gameplay code.
- UI tasks include responsive captures or recordings.
- Security, Schema, `PowerBudget`, D1, and cost boundaries are explicit review
  areas, even when the expected impact is `NONE`.

## 4. Local verification

The default deterministic gate is:

```powershell
./scripts/test.ps1
./scripts/build_web.ps1
./scripts/build_sites_preview.ps1
```

Record the command, source SHA, result, assertion/test count when available,
warnings, generated hash, and artifact location. Do not call a real provider as
part of ordinary local verification.

## 5. Browser and device evidence

- Browser behavior includes application console-error inspection.
- Chromium is the fast automation gate. WebKit is a release-candidate gate for
  Safari-sensitive work.
- Physical iPhone Safari acceptance cannot be replaced by a simulator when the
  task touches touch input, keyboard, safe areas, Safari toolbar behavior,
  orientation, Canvas ownership, or device-specific combat feel.
- UI work includes screenshots or a recording at the acceptance viewports.
- Provider failure cannot be represented as a successful local fixture result.
  A fixture proves client behavior only.
- A real provider check requires separate authorization, a verified durable
  budget guard, and an explicit attempt ceiling.

## 6. Draft PR and CI

- Open a Draft PR first and link the Issue.
- Include actual scope, deliberately unchanged systems, tests, evidence,
  limitations, risk, and rollback.
- CI must remain provider-free and must not read provider secrets.
- CI failures are investigated on the branch; do not weaken a gate to obtain a
  green check.
- Resolve all actionable review threads. Independent review focuses on scope,
  regression locks, security/cost boundaries, and reproducibility.

## 7. Acceptance, merge, and release

- Product acceptance is recorded against a precise PR HEAD or immutable build
  identity.
- Merge only after required CI, review, and product gates pass.
- Build release artifacts again from the final merged `main` SHA.
- Record the build SHA and artifact hash before deployment.
- Deployment must have a named rollback version and verified rollback method.
- Post-deploy smoke includes HTTP/resource checks, applicable Chromium/WebKit,
  and only explicitly approved real-provider or physical-device checks.
- Create or verify the stable tag, update `CHANGELOG.md` and
  `docs/PROJECT_STATUS.md`, then stop at the release boundary.

Use `docs/RELEASE_CHECKLIST.md` for the executable release/rollback gate.

## 8. Evidence and cleanup

- Keep formal acceptance evidence, rollback archives, stable tags, and the
  release provenance record.
- Keep generated builds and temporary logs outside Git unless they are
  deliberately curated evidence.
- Never delete branches, worktrees, screenshots, logs, archives, or user files
  without separate cleanup authorization.
- After authorization, classify every candidate as formal evidence, rollback
  material, regenerable build, temporary log, or unclear/user-confirm before
  removal.

## Stop conditions

Stop and escalate when:

- the remote baseline conflicts with Source of Truth;
- required scope would change a prohibited or unrelated system;
- a destructive action or new external authority is required;
- provider guard/budget identity is unavailable;
- acceptance requires a physical device or product decision that has not been
  supplied;
- the next gameplay milestone is still `TBD / TO VALIDATE`.
