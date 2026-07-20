# M1B1 P0 — Input and Weapon Semantics Evidence

Status: **TO VALIDATE on physical iPhone Safari**. This report records the
independent P0 fix only; it does not claim that P1 aspect-ratio work is complete.

## Baseline reproduction

**CONFIRMED** The v15 client could let the native HTML input and Godot
`LineEdit` disagree. Immediately before FORGE, an unversioned empty DOM value
overwrote a non-empty Godot value. The resulting request contained an empty
`description` while its numeric drawing summary remained present.

**CONFIRMED** The Worker converted that pre-provider error into a valid
`Practice Sketchblade`; the client then exposed CONFIRM and allowed combat even
though metadata said provider `none / none`, attempts `0`, confidence `0%`.

**CONFIRMED** `area_blast` was the only grenade-related field in the old
contract. It spawned immediately at the player and could not represent a thrown
delivery or flight trajectory.

Local baseline evidence is retained outside Git at
`output/playwright/m1b1-blockers/baseline/baseline.json` with the corresponding
failure screenshots. Those results are failure evidence and are not counted as
passing tests.

## Implemented P0 behavior

- A single acknowledged Description draft uses a monotonically increasing Web
  revision across `input`, `change`, `compositionend`, `blur`, explicit clear,
  and programmatic synchronization.
- FORGE is duplicate-locked while it blurs/commits marked iOS text and freezes
  `{description, description_revision, drawing_summary, request_id}`.
- An unversioned DOM mutation cannot erase the acknowledged draft.
- The exact in-memory request snapshot and request ID are visible during loading
  and on an error screen. Raw descriptions are not written to Worker logs or D1.
- A normal result requires `success=true`, `provider_invoked=true`, at least one
  provider attempt, positive confidence, no fallback reason, and a valid
  WeaponSpec/PowerBudget. The client repeats this gate at both CONFIRM and equip.
- A Red Team follow-up found and closed a second fail-open path: an absent
  `WEAPON_AI_PROVIDER` can no longer select the local deterministic adapter by
  default. Local/mock interpretation requires explicit test configuration.
- Normal client confirmation now requires the exact pinned identity
  `anthropic / claude-haiku-4-5-20251001`. A deterministic, spoofed, missing, or
  different-model response is rejected before confirmation and again before
  equip.
- Error responses contain no `weapon_spec`, never display or equip Practice
  Sketchblade, hide CONFIRM, and expose only EDIT INPUT / TRY AGAIN recovery.
- WeaponSpec v2 separates `weapon_form`, `delivery`, `trajectory`, `impact`, and
  `area_effect` from the five existing attack patterns.
- Grenade is deterministically repaired to
  `grenade / thrown / arc / delayed_or_contact / explosion / area_blast`; its
  visible projectile travels first and creates the blast only at contact or the
  end of its bounded flight.
- Bow, sword, boomerang, and spear have explicit canonical semantic mappings.
- Delivery, trajectory, impact, area effect, projectile flight, and blast radius
  all have explicit deterministic PowerBudget entries.

## Automated evidence

**CONFIRMED** `scripts/test.ps1` passed after the change:

- Godot import and typed-script parse: pass.
- Godot deterministic suite: 32 matrix cases, 520 assertions, 0 failures.
- Main-scene headless smoke: pass.
- Static Worker, WASM loader, interpreter, D1 idempotency/quota, Anthropic
  adapter, $5 budget guard, and Anthropic safety suites: pass.
- Interpreter suite includes 48 normal/creative/unsafe/transport cases plus
  exact grenade, bow, sword, boomerang, and spear semantics.

**CONFIRMED** Chromium mobile regression passed with 0 application console
errors. It captured the outgoing POST and proved:

- stale unversioned DOM `""` did not replace the acknowledged non-empty text;
- request body description, drawing summary, and request ID matched the visible
  frozen snapshot;
- an unfinished composition was committed before request construction;
- provider timeout produced `weapon_spec=null`, `runtime_valid=false`, no
  CONFIRM touch rectangle, and working EDIT INPUT / TRY AGAIN actions.

Evidence: `output/playwright/p0-fixed-chromium.json`.

**CONFIRMED** the same regression passed in Playwright WebKit with 0 application
console errors. Evidence: `output/playwright/p0-fixed-webkit.json`.

**CONFIRMED** the independent provider-identity hardening regression passed:

- Node interpreter + Anthropic adapter: 93 tests, 0 failures;
- Godot client/runtime: 32 matrix cases, 589 assertions, 0 failures;
- missing/empty provider configuration returns a non-equipable explicit error;
- `deterministic_local`, Sonnet/Opus, missing model, attempts 0, provider not
  invoked, and confidence 0 cannot pass the client confirmation gate.

## Remaining P0 delivery evidence

- **TO VALIDATE** Run one budget-guarded real Claude request for grenade and one
  for bow after both P0 and P1 are integrated, then record the redacted request
  snapshot, request ID, fixed provider/model, response semantics, latency, and
  cost.
- **TO VALIDATE** Re-run the deployed build on physical iPhone Safari. No merge
  is authorized before the product owner accepts both P0 and P1.
