# Project Forge Decision Log

This log records current decisions without turning untested defaults into facts.

## Confirmed

| ID | Decision | Rationale / source |
| --- | --- | --- |
| D-001 | **CONFIRMED** Project Forge is independent; no reuse from Cat Battle or other projects | Explicit project instruction |
| D-002 | **CONFIRMED** Use Godot 4 and a 2D landscape presentation | GDD and current-round instruction |
| D-003 | **CONFIRMED** M0 uses drawing + one text line with mouse and touch | Current-round acceptance |
| D-004 | **CONFIRMED** M0 uses a local mock AI service and no API key | Current-round constraint |
| D-005 | **CONFIRMED** AI output is structured data only and cannot generate/execute gameplay code | GDD safety boundary |
| D-006 | **CONFIRMED** The generated visual preserves player stroke geometry | Core design pillar |
| D-007 | **CONFIRMED** M0 implements melee slash and straight projectile attacks | Current-round minimum |
| D-008 | **CONFIRMED** Web export and representative landscape browser checks are M0 gates | Current-round acceptance |
| D-009 | **CONFIRMED** Use Godot 4.7.1 for the reproducible M0 evidence | Current official Windows release used for this spike |
| D-010 | **CONFIRMED** Full-MVP requirements stay documented but are not implemented during M0 | Explicit “only M0” scope overrides broader milestone list for this round |
| D-011 | **CONFIRMED** M1A supports five fixed attack modules and four fixed elements | Current-round acceptance |
| D-012 | **CONFIRMED** The M1A compiler stays deterministic and offline | Current-round constraint |
| D-013 | **CONFIRMED** Power is an explicit component sum capped at 100; strong capability cannot retain `none` as its drawback | Current-round acceptance |
| D-014 | **CONFIRMED** JSON Schema and runtime repair are independently checked and kept in field/enum parity | Current-round acceptance |
| D-015 | **CONFIRMED** Public Web hosting reconstructs an exact two-part WASM payload because the provider rejects the raw 39.5 MB file | Deployment evidence |
| D-016 | **CONFIRMED** M1A exposes five always-visible, mutually exclusive attack-pattern buttons only as deterministic compiler test tools; `LOAD IDEA` and compile use the selected pattern | Real iPhone Safari showed the former `OptionButton`/`PopupMenu` could capture all page touch |
| D-017 | **CONFIRMED** In M1B player-facing generation, attack pattern is inferred from drawing/text/voice; the five manual buttons are hidden unless developer test mode is enabled or the player explicitly chooses “modify recognition result” | Prevent M1A test UI from becoming the final player flow |
| D-018 | **CONFIRMED** The Web game targets landscape but does not rely on browser orientation lock; portrait shows a reversible bilingual rotate prompt and automatically resumes after landscape rotation | Mobile Safari cannot reliably honor Web orientation lock |
| D-019 | **CONFIRMED** Forge viewports below 430 CSS px in landscape use a Compact Landscape policy driven by `visualViewport`; controls render at 44–48 CSS px, the five attack modes use one row, and the drawing area remains at least 150 CSS px and 40% of usable height | Physical iPhone v8 acceptance found that Godot logical sizes became oversized after browser scaling |
| D-020 | **CONFIRMED** Web uses a bounded native HTML Description input and explicit 44×44 CSS px clear button, synchronized both ways with Godot; native Godot builds retain `LineEdit` | A real DOM input is the reliable iOS Safari keyboard/focus boundary, while keeping gameplay state inside Godot |
| D-021 | **CONFIRMED** Description `×` clears text only. `RESET` clears drawing, Description, loaded-example state, and temporary feedback while preserving the selected attack mode | Removes the ambiguous v8 `CLEAR` behavior |
| D-022 | **CONFIRMED** The product owner accepted M1A mobile on the public v9 build after a physical iPhone Safari pass covering rotation, Compact Landscape, drawing, native keyboard editing, `×`, RESET, all five compile/attack/reforge paths, BACK, and Safari toolbar changes | Physical-device acceptance reported by the product owner |
| D-023 | **CONFIRMED** `v0.1.0-m1a` is the stable M1A release line; M1B must begin, if authorized, on a separate future branch and cannot modify the stable release during this closure | Release and branch-isolation instruction |
| D-024 | **CONFIRMED** M1B1 starts from accepted `main` on `codex/feat/m1b1-real-text-interpreter`; `main`, the M1A deployment, and `v0.1.0-m1a` remain the rollback baseline until a separate M1B1 acceptance | M1B1 branch-isolation instruction |
| D-025 | **CONFIRMED** Godot may call only same-origin `POST /api/compile-weapon`; the Sites server worker owns provider access and credentials exist only in server secret environment variables | Prevents browser/client secret disclosure and keeps the provider replaceable |
| D-026 | **CONFIRMED** Normal-player forging hides the five manual attack buttons. They appear only in Developer/Test Mode or after `MODIFY INTERPRETATION`; every correction is recompiled, schema-checked, allow-listed, and re-budgeted | Keeps M1A test controls out of the player flow without losing a safe correction path |
| D-027 | **CONFIRMED** A real model may select and explain allow-listed semantic labels, but executable numeric stats are assigned and repaired deterministically by project-owned profiles and `PowerBudget` | Creative interpretation cannot bypass deterministic balance |
| D-028 | **CONFIRMED** M1B1 sends bounded `drawing_summary` metadata only and makes no visual-understanding claim; drawing/image semantics belong to M1B2 | Explicit phase boundary |
| D-029 | **CONFIRMED** M1B1 permits one active idempotent request, at most one transient retry, user cancellation with late-response invalidation, and a schema/allow-list/power-valid fallback while preserving strokes and text | Reliability and state-preservation requirements |
| D-030 | **CONFIRMED** M1B1 client session IDs and request IDs are random 128-bit values; server idempotency is caller-namespaced and concurrent identical requests share one in-flight operation | Prevents honest-client key collision, duplicate provider charges, and replay races |
| D-031 | **CONFIRMED** Provider free-form names, summaries, correction text, metadata, and nested cost fields never cross the trust boundary. The server generates display text and repair codes from allow-listed labels; cost is `UNKNOWN` or bounded USD amount only | Red-team reproduced response/log disclosure through an untrusted adapter |
| D-032 | **CONFIRMED** Sites production binds D1 as `DB` for atomic 8 requests/minute per session, 60 per network, and caller-namespaced request leases/results across worker isolates. A real/custom provider with a missing, partial, or unavailable guard fails closed before provider invocation; the process-local map is explicit deterministic-test fallback only. **TO VALIDATE:** first Sites migration/deployment and provider account spend cap | Anonymous paid endpoints need a durable cost boundary rather than isolate-local maps |
| D-033 | **CONFIRMED** Network, session, and normalized-payload namespaces use truncated 128-bit SHA-256 fingerprints; raw IP, session ID, description, and drawing data are not stored in the request guard | Reduce collision and privacy risk while retaining short-lived quota/idempotency keys |
| D-034 | **CONFIRMED** Every adapter receives an `AbortSignal`. An enforced wrapper timeout aborts the transport but is not retried because billing state is ambiguous; one retry is permitted only for an adapter-classified retry-safe transient failure | Prevent timed-out calls from overlapping or producing an automatic double charge |
| D-035 | **CONFIRMED** M1B1 uses Anthropic's native Messages API and native Structured Outputs with the immutable model `claude-haiku-4-5-20251001`; no OpenAI-compatible route, alias, automatic model upgrade, tool use or provider fallback is allowed | Product-owner selection C on 2026-07-20; WeaponSpec requires a strict structured boundary |
| D-036 | **CONFIRMED** M1B1 provider spend has a USD 5 lifetime application hard cap enforced by Worker + D1. Each request reserves 201,280 micro-USD before invocation; verified usage settles, every sent non-2xx or ambiguous billing state commits the full reservation, only a proven pre-invocation failure releases it, and any guard uncertainty fails closed | Product-owner approved limit plus independent Safety/Red Team recommendation |
| D-037 | **CONFIRMED** `ANTHROPIC_API_KEY` exists only as a Sites Secret. The configured secret name and non-secret runtime values were verified without retrieving its value | Prevents accidental inheritance from local Claude tooling or client exposure |
| D-038 | **CONFIRMED** The Anthropic adapter makes one attempt only. Refusal and `max_tokens` responses are discarded but charged from verified usage; wrong model, content shape, enum or usage produces a validated fallback | Native API can bill valid 200 responses that are unusable as structured gameplay data |

## Assumptions

| ID | Assumption | Validation |
| --- | --- | --- |
| A-001 | **ASSUMPTION** Single-screen side-view combat is the best first format | M2 playtest |
| A-002 | **ASSUMPTION** A 1280×720 logical viewport with responsive expansion is adequate for Web landscape | M0 browser matrix, M3 devices |
| A-003 | **ASSUMPTION** Keyword-driven deterministic profiles are sufficient to validate the `WeaponSpec` boundary | M0 results; replace/extend in M1 |
| A-004 | **ASSUMPTION** Direct stroke normalization plus a simple element palette is enough for recognizability | M0 observation and tester feedback |
| A-005 | **ASSUMPTION** Weapon creation occurs before a stage, with at most one in-stage re-forge | Later loop playtest |
| A-006 | **ASSUMPTION** MVP is not positioned as a child application | Product/legal review |

## To validate

| ID | Question / hypothesis | Planned evidence |
| --- | --- | --- |
| V-002 | **TO VALIDATE** Player strokes remain recognizable when attached to the character | M0 screenshots and user test |
| V-003 | **TO VALIDATE** Melee and projectile behavior feel mechanically distinct | M0 hands-on test |
| V-004 | **TO VALIDATE** Players change ideas rather than re-roll for higher damage | M1/M2 playtest; deterministic M0 values avoid false reward |
| V-005 | **CONFIRMED (M1A prototype)** Five attack forms and four elements fit one stable compiler/budget | 32-case matrix and five browser combat runs; balance feel remains M2 |
| V-006 | **TO VALIDATE** Native safe areas, touch latency, and performance | M3 Android/iOS device matrix |
| V-007 | **CONFIRMED (provider-neutral faults)** Malformed output, missing fields, timeout, offline, 429, 5xx, cancellation, stale response, and safe fallback behavior pass local Chromium/WebKit regression. **TO VALIDATE:** real-provider moderation, accuracy, median/P95 latency, and cost | Real 40+ case run after provider/model/key selection |
| V-008 | **TO VALIDATE** `front_shield` is present in the product-intent example but not in the current executable ability allow-list; M1B1 must omit/repair it rather than silently invent gameplay | Separate module, combat behavior, and budget design before support |

## TBD

| ID | Decision not yet made |
| --- | --- |
| T-001 | **TO VALIDATE** Dedicated Anthropic workspace provider-side spend limit before paid public traffic; the USD 5 Worker + D1 application cap is **CONFIRMED** |
| T-002 | **TBD** Production authentication, provider-side moderation/rate controls, cache policy, observability destination, and telemetry retention. The provider/model/secret boundary, same-origin Worker and D1 guards are **CONFIRMED** |
| T-003 | **TBD** Voice implementation and exact milestone after weapon validation |
| T-004 | **TBD** Production art pipeline, smoothing threshold, grip inference, and card rendering |
| T-005 | **TBD** Final production balance curves; M1A numeric costs are confirmed only as deterministic prototype values |
| T-006 | **TBD** Data retention, privacy policy, and moderation vendor |

## Deferred without deletion

The five attack forms, four elements, target lab, and deterministic compiler are
complete in M1A. M1B1 now contains the Anthropic text interpreter, secure
same-origin boundary, and USD 5 D1 hard cap; live evidence remains gated by the
provider-account backstop and controlled deployment.
Formal levels, complete win/loss/restart, voice, image understanding, production
moderation policy, accounts, community, monetization, and native-store delivery
remain deferred without deletion. See `docs/GDD.md` and
`docs/MVP_ACCEPTANCE.md` for milestone traceability.
