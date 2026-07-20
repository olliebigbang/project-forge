# M1B1 blocker-fix delivery

Status: **TO VALIDATE on physical iPhone Safari**. The fixes are isolated on
`codex/fix/m1b1-input-aspect`, draft PR
[#4](https://github.com/olliebigbang/project-forge/pull/4), and are not merged.
M1B2 remains paused.

## Separate diagnoses

### P0: input/provider/weapon semantics

**CONFIRMED** Description existed in two unsynchronized states. Immediately
before FORGE, a stale unversioned HTML value could overwrite the acknowledged
Godot value. The Worker then converted `EMPTY DESCRIPTION` into an executable
Practice Sketchblade, and the client treated any valid-looking `weapon_spec` as
success even when provider metadata was `none / none`, attempts were zero, and
confidence was zero.

**CONFIRMED** The old contract represented only an `attack_pattern`. It could
label a grenade as `area_blast`, but could not represent thrown delivery, an arc
trajectory, contact/delay, or a landing explosion. The immediate blast at the
player was therefore contract behavior, not a Claude recognition error.

P0 implementation commit: `28323ed` plus provider-identity hardening in
`2dfc6fa`.

### P1: drawing proportion

**CONFIRMED** The visual path first normalized X and Y by different canvas
dimensions, then independently filled a fixed weapon rectangle. Canvas whitespace
participated in the transform, and piercing added another non-uniform scale.
This was independent of AI interpretation.

P1 implementation commit: `3723abd`.

## Delivered behavior

- FORGE atomically freezes acknowledged Description revision, numeric drawing
  summary, raw-stroke deep copy, and random request ID; the visible request
  snapshot is the exact outgoing state.
- Provider failure, empty input, zero confidence, no invocation, wrong provider,
  wrong model, invalid response, or fallback cannot expose CONFIRM or enter
  combat. Practice Sketchblade is not emitted as a disguised success.
- Success requires the exact identity
  `anthropic / claude-haiku-4-5-20251001` at response, confirmation, and equip
  boundaries.
- WeaponSpec v2 separates `weapon_form`, `delivery`, `trajectory`, `impact`, and
  `area_effect` from `attack_pattern`.
- Grenade is `thrown / arc`; it visibly travels before an explosion is created
  at contact or bounded-flight completion. `area_blast` describes the landing
  effect only.
- Bow is `projectile / direct / contact / straight_projectile`; its drawn bow
  remains held while a separate procedural arrow travels.
- Actual stroke bounds ignore canvas whitespace. Every player-ink review, held,
  melee-animation, grenade-copy and boomerang-copy visual uses 10% padding and
  one uniform `min(width scale, height scale)` scalar without rewriting source
  points. Arrow, bullet, energy and spear projectiles are separate deterministic
  program shapes.

## Real Claude evidence

The guarded public run executed exactly once and allowed exactly two POSTs. No
duplicate request was observed or allowed. Both D1 charges settled.

| Case | Request ID | Provider result | Combat result | Latency | Cost |
| --- | --- | --- | --- | ---: | ---: |
| grenade | `m1b1-14c6f2d1bd9a25edac09aa52a7c34b45` | `grenade / thrown / arc / delayed_or_contact / explosion / area_blast` | visible projectile, then landing blast 230.05 px from origin | 3,383 ms | USD 0.001797 |
| bow | `m1b1-275938d440292dec4be7a96a0b6963f7` | `bow / projectile / direct / contact / none / straight_projectile` | visible straight projectile | 1,390 ms | USD 0.001778 |

Total measured cost: **USD 0.003575** against the Worker + D1 lifetime hard cap
of USD 5. Complete request snapshot, bounded response, repairs, budget, runtime
state, and transform evidence are in the
[machine report](evidence/m1b1-blockers/real-provider-grenade-bow.json). The
[Worker correlation](evidence/m1b1-blockers/real-provider-worker-log-summary.json)
records `provider_budget.state=settled` for both request IDs without raw input or
provider output.

## Aspect-ratio evidence

| Shape | Source ratio | Rendered ratio | Relative error | Padding |
| --- | ---: | ---: | ---: | ---: |
| real wide bow | 6.195281 | 6.195280 | 0.000000137 | 10% |
| real round grenade | 0.999901 | 0.999901 | 0.000000215 | 10% |

Both are below the required 2% error. Confirmation, held, melee-animation, and
semantic drawn-projectile global-transform X/Y scale deltas were zero or at
floating-point epsilon. Procedural projectiles use their own deterministic
geometry and never copy the held drawing.

Before/after evidence:

- [wide bow before](evidence/m1b1-blockers/before-wide-bow-combat.png) / [after confirmation](evidence/m1b1-blockers/after-wide-bow-confirmation.png) / [after combat](evidence/m1b1-blockers/after-wide-bow-combat.png)
- [round grenade before](evidence/m1b1-blockers/before-round-grenade-combat.png) / [after confirmation](evidence/m1b1-blockers/after-round-grenade-confirmation.png) / [after combat](evidence/m1b1-blockers/after-round-grenade-combat.png)
- [real grenade arc](evidence/m1b1-blockers/real-grenade-arc-flight.png) / [real landing explosion](evidence/m1b1-blockers/real-grenade-landing-explosion.png)
- [real bow confirmation](evidence/m1b1-blockers/real-bow-confirmation.png) / [real projectile](evidence/m1b1-blockers/real-bow-projectile.png)

## Automated and deployed verification

**CONFIRMED** Full local verification passed:

- Godot import/typed parse and scene smoke;
- 32 Godot matrix cases, 615 assertions, zero failures;
- Worker 4/4, WASM loader 1/1, interpreter 76/76, D1 request guard 9/9,
  Anthropic adapter 17/17, D1 budget guard 14/14, and hostile safety 11/11;
- Web export and Sites package build;
- Chromium and Playwright WebKit P0/P1 browser regression with zero application
  console errors;
- mobile input/composition/cancel/retry/keyboard/rotation regression in both
  browser engines with zero application console errors.

**CONFIRMED** The deployed public build passed the same P0/P1 fixture regression
in Chromium and version-matched Playwright WebKit. The real-provider run also
reported zero application console errors. Draft PR #4 CI was green before this
evidence-only delivery update and is rechecked on the final pushed commit.

**CONFIRMED** A separate public zero-paid safety request was rejected before
provider invocation with `success=false`, `provider_invoked=false`, attempts 0,
`weapon_spec=null`, `runtime_valid=false`, matching input/request snapshot,
hidden CONFIRM, visible EDIT INPUT / TRY AGAIN, HTTP 200 `no-store`, and zero
application console errors.

Public integrity probe:

| Resource | Public SHA-256 | Result |
| --- | --- | --- |
| `index.js` | `68586d6daafc93c6e697b3fb258976874aa7459b8931165ebb1dc3c9614cc42c` | exact local match |
| `index.pck` | `f3e9a664d6d5bb980412b5a0fb70853589c0b288b2044f68b8859037976024cf` | stable local candidate; exact public match required after final deploy |
| reconstructed `index.wasm` | `35116f68540ac41acf7d71ea457added91b5e960a9cca3e2acc72918eaf01277` | both public chunks, exact local match |

The HTML and core assets return HTTP 200 with
`Cache-Control: public, max-age=0, must-revalidate`. The Sites service exposes
one stable public origin rather than a separate immutable version URL; the build
label is diagnostic only. Correctness is established by the actual redeployment
and byte-for-byte resource hashes, not by changing a query string.

`docs/.gdignore` keeps retained QA screenshots/reports outside Godot's resource
scanner. The final PCK hash above was identical across two consecutive exports,
so adding delivery evidence can no longer perturb the game package.

## Public preview and remaining gate

Preview:
<https://project-forge-weapon-lab.hongningliu0130.chatgpt.site/?qa=m1b1&build=blocker-fix>

**TO VALIDATE** Playwright WebKit on Windows is a Safari-engine path, not a
physical iPhone Safari acceptance result. The branch must not merge and M1B2
must not start until the product owner confirms the public build.

Shortest physical-iPhone check:

1. Open the preview in Safari, rotate to landscape, draw a round grenade, enter
   `grenade`, and tap FORGE.
2. Verify the visible request snapshot is non-empty and the result shows
   Anthropic/Haiku, grenade/thrown/arc/explosion; CONFIRM and verify visible
   flight followed by a remote blast.
3. REFORGE, draw a wide bow, enter `bow`, and verify the review, held weapon, and
   straight projectile retain the wide aspect.
4. Close/reopen the iOS keyboard once and rotate portrait -> landscape once;
   verify Description and drawing remain, then forge again.
5. Try a blank Description and verify an explicit error with edit/retry actions,
   no CONFIRM, and no Practice Sketchblade combat path.

## Reopened physical-iPhone P0 candidate

The prior candidate did not pass physical-iPhone acceptance. Two later findings
are separately diagnosed and evidenced here:

- [iOS keyboard/Canvas P0](M1B1_IOS_KEYBOARD_P0_EVIDENCE.md): export policy `2`,
  temporary keyboard height and Safari focus scrolling competed for Canvas
  ownership. The replacement freezes a stable Canvas and presents a safe-area
  compact text-entry dock with Description, clear and Done.
- [weapon visual roles P0](M1B1_WEAPON_VISUAL_ROLES_P0_EVIDENCE.md): the former
  projectile path reused the complete held `WeaponVisual`. The replacement uses
  a deterministic held/projectile/impact bundle, including held bow plus arrow
  and centred thrown grenade plus separate explosion.

Current automated candidate results: Godot 615 assertions; Worker 4/4; WASM 1/1;
interpreter 76/76; request D1 9/9; Anthropic adapter 17/17; budget D1 14/14;
hostile safety 11/11; Web export PASS; Chromium and WebKit P0 regression PASS
with zero application console errors. Physical iPhone Safari remains
**TO VALIDATE**, so Draft PR #4 stays unmerged and M1B2 stays paused.
