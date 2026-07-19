# M1B1 real-provider decision

Status: **TBD — one product-owner choice required**

Prepared: 2026-07-19

Scope: text plus bounded `drawing_summary`; no image understanding

Backend: **CONFIRMED — reuse the active Project Forge Sites Worker with logical
D1 binding `DB`.** The 2026-07-19 environment check returned revision 0 with no
runtime variables, so no provider, model, or credential is currently configured.

Vendor-neutral gate: **CONFIRMED — candidate `104fddb` passed independent Safety
and Mobile QA.** Real provider behavior, deployed D1, cost/latency/accuracy,
public preview, and physical iPhone acceptance remain **TO VALIDATE**.

## Recommendation

**Recommended: OpenAI `gpt-5.6-luna` through the Responses API with Structured
Outputs.** It is a stable, cost-sensitive model with native structured-output
support. Its current list price is USD $1.00 per million input tokens and $6.00
per million output tokens. This is a good first balance between multilingual
creative classification, strict JSON, and a small interactive-game budget.

The recommendation is provisional until the labelled 48-case matrix runs against
the real endpoint. If it misses the 90% pattern/element target, the project should
compare one stronger model using the exact same adapter contract rather than
weakening the acceptance gate.

## Current official options

The cost example uses a deliberately explicit planning assumption: **1,000 input
tokens + 200 output tokens per forge request**, standard synchronous pricing, no
cache discount, no retry, and no tools. It is not a bill or measured usage.

| Option | Structured output | Current list price per 1M input/output tokens | Example cost per call | Fit |
| --- | --- | ---: | ---: | --- |
| **A — OpenAI `gpt-5.6-luna` (recommended)** | Supported | $1.00 / $6.00 | **$0.00220** | Low-cost stable model; simple Responses API adapter; test semantic accuracy first |
| **B — Google `gemini-3.1-flash-lite`** | Supported | $0.25 / $1.50 | **$0.00055** | Cheapest option and explicitly designed for lightweight extraction/classification; creative ambiguity may need escalation |
| **C — Anthropic `claude-haiku-4-5`** | Supported | $1.00 / $5.00 | **$0.00200** | Fastest Claude tier and strict JSON support; similar cost to option A |

For the required 48 real cases, the same assumptions imply approximately $0.106,
$0.026, or $0.096 respectively, before retries. Actual cost must come from
provider usage fields and stays `UNKNOWN` until the run.

Official references checked on 2026-07-19:

- [OpenAI GPT-5.6 Luna model and pricing](https://developers.openai.com/api/docs/models/gpt-5.6-luna)
- [Google Gemini 3.1 Flash-Lite model and structured output](https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-lite)
- [Google Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing)
- [Anthropic model overview](https://platform.claude.com/docs/en/about-claude/models/overview)
- [Anthropic structured outputs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)
- [Anthropic API pricing](https://platform.claude.com/docs/en/about-claude/pricing)

## Latency expectation

- **ASSUMPTION:** a short non-streaming schema response should normally fit a
  1–4 second interactive planning range on all three small/fast models.
- **TO VALIDATE:** no vendor page provides a Project Forge end-to-end latency SLA.
  The actual median and nearest-rank P95 will be measured over the real labelled
  run. Acceptance remains median ≤5 seconds and P95 ≤10 seconds.
- The server timeout stays 8 seconds. It sends `AbortSignal` and does not retry a
  wrapper timeout because upstream billing may already have occurred. At most one
  retry is available only for an adapter-classified retry-safe transient failure.
  Retries and failures are reported separately rather than hidden in averages.

## Required server configuration

Common non-secret values:

```text
WEAPON_AI_PROVIDER=openai | google | anthropic
WEAPON_AI_MODEL=<selected model ID>
WEAPON_INTERPRETER_REQUIRE_DURABLE_GUARD=true
```

Exactly one provider credential, stored as a Sites secret environment value:

```text
OPENAI_API_KEY=<secret>       # option A
GEMINI_API_KEY=<secret>       # option B
ANTHROPIC_API_KEY=<secret>    # option C
```

The key must never enter Godot settings, HTML/JavaScript/WASM/PCK assets, Git,
query strings, screenshots, test fixtures, or logs. The user should set it through
the deployment service's secret control rather than paste it into chat or source.

## Deployment and cost controls

1. Add only the selected server adapter behind `resolveAdapter()`; keep Godot on
   same-origin `/api/compile-weapon`.
2. Configure provider/model, the durable-guard requirement, and the provider key
   in Sites server environment.
3. Deploy the checked-in Sites D1 `DB` migration. It atomically enforces 8
   requests/minute per session and 60 per network, owns cross-isolate request
   leases/replays, and fails closed before provider invocation if unavailable.
4. Before public paid traffic, add an account-level provider spend cap. D1 is the
   application quota/idempotency boundary; the provider cap is the independent
   financial backstop.
5. Run the labelled matrix, safety corpus, M1A suite, Web build, Chromium and
   WebKit; record real usage, cost, latency, failures, corrections, and accuracy.
6. Deploy a newly hashed public preview only after PR/CI pass. Keep M1A v9 and
   `v0.1.0-m1a` as rollback evidence.

## Decision requested

Choose **A, B, or C** (or name another provider/model), confirm that a server-side
API key can be configured, and approve an account spend cap before the
public preview. No real provider call occurs before that choice.
