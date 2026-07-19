# M1B1 Real Text-to-Weapon AI Interpreter — implementation plan

Status: **CONFIRMED — authorized, implementation in progress**

Stable baseline: `v0.1.0-m1a` / `b09bd8f`

Integration branch: `codex/feat/m1b1-real-text-interpreter`

## Objective

M1B1 replaces the normal-player M1A pattern preselection with one free-form text
request. A vendor-independent backend interprets the text into allow-listed
semantic choices, then the project-owned validator and `PowerBudget` repair and
price the final `WeaponSpec`. AI output remains data and can never introduce or
execute gameplay code.

Drawing data is limited to numeric `drawing_summary` context. **CONFIRMED:** M1B1
does not claim visual understanding; image semantics remain M1B2.

## Delivery sequence

1. **CONFIRMED** Preserve `main` and `v0.1.0-m1a`; develop only on the M1B1
   integration branch and isolated QA worktrees.
2. **CONFIRMED** Add a provider-neutral `WeaponInterpreter` request/response
   contract and deterministic local adapter.
3. **CONFIRMED** Add same-origin `POST /api/compile-weapon` to the Sites Worker.
   The route validates size/types, applies input safety rules, calls an adapter,
   repairs output, enforces allow-lists and `PowerBudget`, and emits only a safe
   response plus privacy-minimized metadata.
4. **CONFIRMED** Keep provider secrets only in Sites secret environment values.
   No key may enter Godot, generated Web files, Git, query strings, or logs.
5. **CONFIRMED** Change the normal forge flow to draw → describe → interpret →
   review → confirm. Hide the five M1A buttons unless Developer/Test Mode or
   MODIFY INTERPRETATION is active.
6. **CONFIRMED** Add request locking, cancellation, timeout, at most one safe
   retry, validated fallback, and state preservation.
7. **CONFIRMED** Run at least 40 annotated cases plus M1A, mobile, WebKit, build,
   schema, budget, worker, and public-resource regression.
8. **TO VALIDATE** After the provider-independent implementation passes, obtain
   one product-owner decision covering provider, model, credential, and final
   production environment variables. Real latency and cost remain `UNKNOWN`
   until that adapter runs.
9. **TO VALIDATE** Create a PR and public preview only after real-provider tests
   pass. Do not merge or clean M1B1 worktrees before physical iPhone acceptance.

## Architecture boundary

```text
Godot forge UI
  -> WeaponInterpreter client contract
  -> same-origin POST /api/compile-weapon
  -> request limits + safety classification
  -> provider adapter (deterministic local until provider is selected)
  -> structured semantic intent only
  -> server WeaponSpec repair + allow-list + PowerBudget
  -> client WeaponSpec repair + PowerBudget parity check
  -> review screen
  -> existing five attack modules after CONFIRM
```

The AI adapter should prefer semantic choices (`attack_pattern`, `element`,
`status_effect`, `special_ability`, `drawback`, name, and summary). Numeric combat
values are project-owned deterministic profiles and balancing results. TRY AGAIN
must not act as a higher-stat reroll.

## Provider-neutral contract

Request:

- `description`
- `drawing_summary`
- `locale`
- `request_id`
- `supported_attack_patterns`
- `supported_elements`
- `supported_abilities`
- `maximum_power_score`

Response:

- `weapon_spec`
- `interpretation_summary`
- `confidence`
- `corrections`
- `fallback_reason`
- `provider_metadata`
- `latency_ms`
- `estimated_cost`

`estimated_cost` is `UNKNOWN` unless the selected provider returns sufficient
usage data and a verified pricing rule is configured. No guessed value is valid.

## Safety and privacy controls

- Reject non-POST methods and oversized/non-JSON bodies.
- Normalize and cap descriptions without logging their raw contents.
- Treat player text as untrusted data, never as system/tool instructions.
- Programmatically reject code-generation, prompt-extraction, budget-bypass and
  unsupported-module attempts.
- Apply explicit allow-lists and schema/budget validation after every adapter.
- Strip unexpected provider fields and metadata.
- Log request ID, input length, provider identifier, latency, fallback category,
  repair count and cost only; never log keys or unnecessary personal data.
- Keep generation private to the requesting session; M1B1 has no sharing.
- Provide a visible “result not suitable” feedback affordance without building a
  community or long-term raw-input store.

## Reliability policy

- One in-flight request per forge screen.
- Configurable timeout; at most one retry for transient network, timeout, 429 or
  5xx failures.
- Cancel restores an editable forge without discarding text or strokes.
- Every terminal failure returns or constructs a schema-valid, allow-listed,
  budget-valid base weapon and explains that fallback in the review screen.
- Repeated identical concepts use stable deterministic combat values even when
  semantic wording varies.

## Explicit exclusions

No voice, drawing image recognition, production art, complete levels, accounts,
cloud saves, multiplayer, community, sharing, ads, purchases, store submission,
or generated/executed gameplay code. M1B2 is not part of this branch.
