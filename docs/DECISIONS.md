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
| V-001 | **CONFIRMED (Web emulation)** Touch drawing remains controllable at 844×390 and the layout remains usable at 915×412 | Native Android/iOS devices remain an M3 validation |
| V-002 | **TO VALIDATE** Player strokes remain recognizable when attached to the character | M0 screenshots and user test |
| V-003 | **TO VALIDATE** Melee and projectile behavior feel mechanically distinct | M0 hands-on test |
| V-004 | **TO VALIDATE** Players change ideas rather than re-roll for higher damage | M1/M2 playtest; deterministic M0 values avoid false reward |
| V-005 | **TO VALIDATE** Five full-MVP attack forms and four elements fit one stable compiler/budget | M1 input matrix |
| V-006 | **TO VALIDATE** Native safe areas, touch latency, and performance | M3 Android/iOS device matrix |
| V-007 | **TO VALIDATE** Moderation, malformed output, timeout, caching, latency, and cost behavior | Backend prototype before paid integration |

## TBD

| ID | Decision not yet made |
| --- | --- |
| T-001 | **TBD** AI/model provider and whether any paid integration is justified |
| T-002 | **TBD** Backend stack, hosting, authentication, cache, and telemetry |
| T-003 | **TBD** Voice implementation and exact milestone after weapon validation |
| T-004 | **TBD** Production art pipeline, smoothing threshold, grip inference, and card rendering |
| T-005 | **TBD** Final numeric budget and balance curves |
| T-006 | **TBD** Data retention, privacy policy, and moderation vendor |

## Deferred without deletion

The following remain confirmed product requirements but are outside M0: five
attack forms, four elements, 20 AI input cases, a test monster plus boss, complete
win/loss/restart loop, formal levels, voice/device builds, production moderation,
and a secure backend. See `docs/GDD.md` and `docs/MVP_ACCEPTANCE.md` for milestone
traceability.
