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
| V-007 | **TO VALIDATE** Moderation, malformed output, timeout, caching, latency, and cost behavior | Backend prototype before paid integration |

## TBD

| ID | Decision not yet made |
| --- | --- |
| T-001 | **TBD** AI/model provider and whether any paid integration is justified |
| T-002 | **TBD** Backend stack, hosting, authentication, cache, and telemetry |
| T-003 | **TBD** Voice implementation and exact milestone after weapon validation |
| T-004 | **TBD** Production art pipeline, smoothing threshold, grip inference, and card rendering |
| T-005 | **TBD** Final production balance curves; M1A numeric costs are confirmed only as deterministic prototype values |
| T-006 | **TBD** Data retention, privacy policy, and moderation vendor |

## Deferred without deletion

The following remain confirmed product requirements but are outside M0: five
attack forms, four elements, 20 AI input cases, a test monster plus boss, complete
win/loss/restart loop, formal levels, voice/device builds, production moderation,
and a secure backend. See `docs/GDD.md` and `docs/MVP_ACCEPTANCE.md` for milestone
traceability.
