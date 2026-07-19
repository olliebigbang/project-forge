# Project Forge M1A final delivery

Status: **CONFIRMED — accepted on physical iPhone Safari**

Stable release: `v0.1.0-m1a`

Public build:
<https://project-forge-weapon-lab.hongningliu0130.chatgpt.site/?release=v9-f309f28>

Accepted runtime PCK SHA-256:
`0BDD31A387B3373C90C88D8F4DB19F8F9369BA0B143900324810F7F9BF4191F9`

## Delivered M1A scope

- Deterministic drawing + text weapon compiler with no paid AI or API key.
- `WeaponSpec` JSON Schema and runtime validation/repair.
- Explicit deterministic power budget capped at 100 with logged tradeoffs.
- `melee_slash`, `straight_projectile`, `boomerang`, `area_blast`, and
  `piercing`, each with distinct visible and combat behavior.
- Normal, fire, ice, and electric elements.
- Stationary, moving, shield, and grouped target lab.
- 32-case normal/extreme/illegal/adversarial acceptance matrix.
- Compact iPhone landscape layout, reversible portrait gate, bounded drawing
  touch, native Web Description input, explicit `×`, and RESET semantics.
- Public Godot Web deployment and downloadable offline Web bundle.

## Verification retained

- Godot 4.7.1 import/parse and main-scene smoke: **PASS**.
- Deterministic suite: **32 matrix cases, 447 assertions, 0 failures**.
- Static worker: **3/3 PASS**; WASM loader: **1/1 PASS**.
- Chromium and WebKit full mobile regression: **PASS**.
- Public HTTP/resource identity and new PCK hash: **PASS**.
- GitHub Actions validation: **PASS**.
- Product-owner physical iPhone Safari acceptance: **PASS**.

The physical run covered rotation prompt/recovery, repeated mode switching,
drawing dimensions, LOAD IDEA, Description editing, real iOS keyboard, `×`,
RESET, all five compile/attack/reforge paths, BACK/re-entry, repeated orientation
changes, and Safari toolbar expansion/collapse.

## Evidence and rollback

- `docs/V9_MOBILE_USABILITY_QA.md`
- `artifacts/V9_MOBILE_USABILITY_RESULTS.md`
- `artifacts/M1A_TEST_RESULTS.md`
- `artifacts/v9_mobile_usability/`
- `schema/weapon_spec.schema.json`
- Stable annotated Git tag `v0.1.0-m1a`
- Sites version 9 and accepted PCK hash above

The stable build, release tag, reports, and screenshots must not be deleted.

## Next-stage recommendation

**ASSUMPTION:** M1B real-AI interpretation is the logical next prototype only if
the team wants to evaluate inference quality, latency, moderation, cost, and
fallback behavior. It should begin from `v0.1.0-m1a` on a new branch with a new
acceptance plan. No M1B implementation is included in this release closure.
