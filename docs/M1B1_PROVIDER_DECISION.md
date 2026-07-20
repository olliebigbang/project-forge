# M1B1 real-provider decision

Status: **CONFIRMED — Anthropic Claude Haiku 4.5 selected and Sites configuration gate passed**

Decision date: 2026-07-20

Scope: text plus bounded numeric `drawing_summary`; no image understanding

## Selected provider contract

- **CONFIRMED** Provider: Anthropic.
- **CONFIRMED** Immutable model snapshot: `claude-haiku-4-5-20251001`.
- **CONFIRMED** Transport: Anthropic native `POST /v1/messages` only.
- **CONFIRMED** Structured response: native `output_config.format` JSON Schema.
- **CONFIRMED** No OpenAI-compatible endpoint, provider fallback, model alias,
  automatic upgrade, tools, prompt caching, extended thinking, or SDK retry.
- **CONFIRMED** The provider selects allow-listed semantic labels only. The
  project-owned server creates numeric values, then the full WeaponSpec JSON
  Schema, runtime allow-lists and `PowerBudget` validate the final result again.

The native response schema intentionally contains enums and required object
fields supported by Anthropic Structured Outputs. Unsupported numeric JSON
Schema constraints are not delegated to the provider; the existing full local
schema and runtime validator remain authoritative.

## Sites configuration

The Sites environment was rechecked after the product owner corrected the secret.
Revision 2 reports the following names without exposing the secret value:

```text
WEAPON_AI_PROVIDER=anthropic
WEAPON_AI_MODEL=claude-haiku-4-5-20251001
WEAPON_INTERPRETER_REQUIRE_DURABLE_GUARD=true
M1B1_PROVIDER_BUDGET_USD=5
ANTHROPIC_API_KEY=<Sites Secret>
```

- **CONFIRMED** `ANTHROPIC_API_KEY` is marked secret in Sites and is not sourced
  from Claude Code or the local shell.
- **CONFIRMED** The key is never read back, logged, copied into Git, injected into
  Godot, or shipped in HTML, JavaScript, WASM or PCK assets.
- **CONFIRMED** A dedicated Anthropic workspace provider-side spend limit at or
  below USD 5 was configured before controlled paid traffic. This remains an
  independent backstop to the D1 application ledger.

## Five-dollar hard limit

- **CONFIRMED** The product owner approved a maximum M1B1 provider spend of USD 5.
- **CONFIRMED** Worker + D1 use a lifetime ledger keyed by milestone, provider,
  immutable model and pricing revision.
- **CONFIRMED** Each request atomically reserves 201,280 micro-USD before calling
  Anthropic: the 200,000-token model input ceiling at USD $1/M plus the fixed
  256-token output ceiling at USD $5/M.
- **CONFIRMED** Verified usage settles to its measured amount. Once an Anthropic
  request is sent, every non-2xx, timeout, abort, malformed successful response
  or other unknown billing state commits the full reservation conservatively.
  Only a failure proven to occur before provider invocation may release it.
- **CONFIRMED** Missing D1, a partial guard, configuration mismatch, lock,
  duplicate charge identity, exhaustion, projected cap exceed, settlement error
  or reservation breach fails closed. No provider call occurs after that decision.
- **CONFIRMED** Refusal and `max_tokens` output are discarded but their verified
  usage is still charged to the D1 ledger.

## Retry and validation rules

- **CONFIRMED** The native adapter uses raw `fetch` and allows one attempt only.
  Anthropic 429, 5xx, network errors, aborts and wrapper timeouts do not
  automatically retry.
- **CONFIRMED** The response must have the exact configured model, one text block,
  `end_turn`, valid usage, at most 16 KiB and only the required semantic fields. Refusal,
  truncation, wrong model, wrong shape, unsupported enums and missing usage all
  produce a bounded non-equipable error. They cannot expose CONFIRM or combat.
- **CONFIRMED** Provider prose, names, corrections, metadata, IDs and nested costs
  never cross the trust boundary. Player-facing text is generated from validated
  labels; cost is `UNKNOWN` or one bounded USD object derived from usage.

## Evidence state

- **CONFIRMED** 17 Anthropic adapter, 14 provider-budget and 11 hostile safety
  tests pass alongside the existing interpreter, D1, Godot and Web suites.
- **CONFIRMED (public browser)** Final Chromium and version-matched WebKit mobile
  flows pass on the public blocker-fix candidate with zero application console
  errors.
- **CONFIRMED (offline)** The paid 42-case runner is hard-disabled unless an
  explicit authorization environment value is present; it calls only the same-
  origin Project Forge endpoint and never reads a provider key.
- **CONFIRMED** The public canary, deployed D1 reserve/settle audit, five core
  resource hashes, and 42-case real-provider matrix passed. The matrix achieved
  42/42 cases, 100% labelled pattern and element accuracy, 100% final validity,
  1.318 s median, 4.846 s P95, and USD 0.033588 measured cost.
- **CONFIRMED** The guarded blocker run added exactly one live grenade and one
  live bow request. Both used the fixed provider/model, passed every gate, settled
  in D1, and executed the required thrown-arc-explosion/direct-projectile combat
  semantics for USD 0.003575 total.
- **TO VALIDATE** Physical iPhone Safari acceptance of the public blocker-fix
  candidate.

Official implementation references checked on 2026-07-20:

- [Anthropic authentication](https://platform.claude.com/docs/en/manage-claude/authentication)
- [Anthropic Structured Outputs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)
- [Anthropic model IDs](https://platform.claude.com/docs/en/about-claude/models/model-ids-and-versions)
- [Claude Haiku pricing](https://www.anthropic.com/claude/haiku)
- [Anthropic API errors](https://platform.claude.com/docs/en/api/errors)
- [Anthropic workspaces and spend limits](https://platform.claude.com/docs/en/manage-claude/workspaces)
