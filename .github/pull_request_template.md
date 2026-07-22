## Linked Issue

Closes #

## Change and reason

Describe the defect/goal, root cause or product reason, and why this change is
the smallest correct scope.

## Formal baseline

- Base `origin/main` SHA:
- Stable tag:
- Relevant Sites version / URL:
- Dependencies (Issues, PRs, decisions, tags):

## Actual modification scope

- Changed:
- Intentionally unchanged:
- Forbidden regressions verified:

## Source of Truth

- [ ] `docs/PROJECT_STATUS.md` is accurate for any current-state change.
- [ ] `docs/GDD.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, and
      acceptance documents were updated when their authority changed.
- [ ] Historical evidence was preserved rather than rewritten.
- [ ] Uncertainty uses CONFIRMED / ASSUMPTION / TO VALIDATE / TBD.

## Tests and actual results

| Command / gate | Result | Evidence |
| --- | --- | --- |
| `./scripts/test.ps1` | | |
| `./scripts/build_web.ps1` | | |
| `./scripts/build_sites_preview.ps1` | | |
| Chromium | | |
| WebKit | | |
| Physical iPhone | | |

Do not write PASS for a gate that was not run. Use `NOT APPLICABLE`,
`NOT RUN`, `TO VALIDATE`, or `TBD` with a reason.

## Evidence

- Screenshots / recording:
- JSON / audit report:
- Logs:
- Source SHA / artifact hash:
- Browser console result:

## Security, Schema, PowerBudget, and cost impact

- Schema:
- PowerBudget:
- Worker / D1 / provider:
- Secrets:
- Provider attempts and cost:
- Security review:

State `NONE` only after checking the boundary. CI fixtures must not be described
as real-provider success.

## Known limitations

- CONFIRMED:
- TO VALIDATE:
- TBD:

## Rollback

- Direct Sites rollback:
- Direct Git tag/revert:
- Retained artifact:
- Verification method:

## Reviewer checklist

- [ ] Scope matches the linked Issue.
- [ ] No prohibited system or unrelated milestone changed.
- [ ] Tests report real results and failures honestly.
- [ ] Chromium/WebKit applicability is correct.
- [ ] Physical iPhone evidence is present when device behavior changed.
- [ ] No secret or real provider call entered CI.
- [ ] Schema/PowerBudget/security/cost impact is explicit.
- [ ] Source of Truth and rollback records are synchronized.
- [ ] All review conversations are resolved.

**TO VALIDATE — reviewer ownership not confirmed.** Do not infer a GitHub user,
team, or `CODEOWNERS` entry without product-owner confirmation.
