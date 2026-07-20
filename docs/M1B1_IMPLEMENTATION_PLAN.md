# M1B1 Real Text-to-Weapon AI Interpreter — implementation plan

Status: **CONFIRMED — Anthropic guarded integration implemented; live and device gates pending**

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
6. **CONFIRMED** Add request locking, cancellation, aborting timeout, at most one
   explicitly safe retry, validated fallback, and state preservation. Sites D1
   owns cross-isolate quotas and request leases/results; local maps are dev-only.
7. **CONFIRMED** Run at least 40 annotated cases plus M1A, mobile, WebKit, build,
   schema, budget, worker, and public-resource regression.
8. **CONFIRMED** Anthropic with immutable model
   `claude-haiku-4-5-20251001`, native Messages/Structured Outputs, Sites Secret,
   and the USD 5 Worker + D1 application cap were selected and implemented.
   Real latency and cost remain `UNKNOWN` until the guarded live matrix runs.
9. **TO VALIDATE** Create a PR and public preview only after real-provider tests
   pass. Do not merge or clean M1B1 worktrees before physical iPhone acceptance.

## Architecture boundary

```text
Godot forge UI
  -> WeaponInterpreter client contract
  -> same-origin POST /api/compile-weapon
  -> request limits + safety classification
  -> Sites D1 quota + idempotency lease/result
  -> D1 lifetime USD budget reservation
  -> Anthropic native Messages adapter (fixed Haiku 4.5 snapshot)
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
- Generate names, summaries and correction codes from allow-listed server data;
  never reflect provider free text. Cost is `UNKNOWN` or bounded USD amount only.
- Log request ID, input length, provider identifier, latency, fallback category,
  repair count and cost only; never log keys or unnecessary personal data.
- Keep generation private to the requesting session; M1B1 has no sharing.
- Provide a visible “result not suitable” feedback affordance without building a
  community or long-term raw-input store.

## Reliability policy

- One in-flight request per forge screen.
- Random 128-bit client/request IDs plus 128-bit SHA-256 namespaces feed a Sites
  D1 ledger. Atomic leases share one in-flight operation and replay the result
  across worker isolates; local deterministic runs use a process map.
- The client binds each HTTP callback to its initiating revision/request ID and
  rejects stale or mismatched responses before state mutation.
- D1 returns 429 after 8 session requests/minute or 60 network requests/minute
  across isolates. A real/custom provider with a missing, partial, or unavailable
  D1 guard fails closed before provider invocation and cannot downgrade to memory.
  Paid public traffic additionally requires a provider account spend cap.
- A second D1 ledger reserves 201,280 micro-USD before every Anthropic call and
  enforces the approved USD 5 lifetime application limit. Unknown billing is
  charged conservatively; any configuration or settlement uncertainty locks or
  fails the paid path closed.
- Configurable timeout sends `AbortSignal`. A wrapper timeout never retries;
  adapters may request at most one retry only for a transient failure they can
  prove safe to repeat.
- Cancel restores an editable forge without discarding text or strokes.
- Every terminal failure returns or constructs a schema-valid, allow-listed,
  budget-valid base weapon and explains that fallback in the review screen.
- Repeated identical concepts use stable deterministic combat values even when
  semantic wording varies.

## Explicit exclusions

No voice, drawing image recognition, production art, complete levels, accounts,
cloud saves, multiplayer, community, sharing, ads, purchases, store submission,
or generated/executed gameplay code. M1B2 is not part of this branch.
