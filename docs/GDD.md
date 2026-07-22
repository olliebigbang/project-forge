# Project Forge — Game Design Document

Version: 0.1 (organized from the supplied GDD)  
Stable delivery milestone: **M1B1.2 absolute weapon reach — physical iPhone scope acceptance CONFIRMED; release closure in progress**
Next isolated milestone: **Weapon Physics B0 specification, followed by the controlled B1 physicality experiment; not M1B2**
Stable mobile acceptance: **CONFIRMED on physical iPhone Safari with v9**

## 1. Product identity

- **CONFIRMED** Working title: **Project Forge**.
- **CONFIRMED** This is a new standalone project unrelated to Cat Battle or any
  previous game.
- **CONFIRMED** Genre: AI-assisted creative weapon generation plus 2D side-view
  action stages.
- **CONFIRMED** Primary target platforms: iOS and Android.
- **CONFIRMED** Trial platform: Web browser.
- **CONFIRMED** Engine: Godot 4.
- **CONFIRMED** Presentation: landscape, 2D, hand-drawn cartoon direction.
- **CONFIRMED** Current phase is playability validation, not production-scale
  commercialization.

### One-sentence pitch

Players draw a weapon and supplement it with text (and, in a later version,
voice). AI translates that idea into a weapon with an executable attack pattern,
attributes, effects, and a weakness; the player then uses it against monsters and
stages.

### Player fantasy

> This is not a weapon the game handed me. It is the weapon I imagined, and it
> really fights according to my idea.

## 2. Design pillars

### 2.1 The player's creation remains recognizable

- **CONFIRMED** AI must not completely replace the player's drawn shape.
- **CONFIRMED** The game may clean lines, add material, and add effects, but the
  player must still recognize their work.
- **TO VALIDATE** Determine the acceptable amount of smoothing and decoration.

### 2.2 Creativity changes play

- **CONFIRMED** Weapons must differ mechanically, not only by image and name.
- **CONFIRMED** Relevant dimensions include attack form, range, damage, element,
  status effect, special ability, and usage cost.

### 2.3 Power has a cost

- **CONFIRMED** High damage trades against attack speed.
- **CONFIRMED** Full-screen coverage trades against single-target damage.
- **CONFIRMED** Automatic tracking trades against projectile speed.
- **CONFIRMED** Strong control trades against cooldown.
- **CONFIRMED** Giant weapons trade against movement speed.
- **TO VALIDATE** Exact budgets and curves are deferred to the M1 weapon compiler.

### 2.4 Monsters prompt new creations

- **CONFIRMED** Enemies present qualitatively different problems instead of only
  increasing health.
- **TO VALIDATE** Players should respond by inventing a different weapon rather
  than repeatedly rolling for a higher damage number.

## 3. Intended game loop

1. Enter a stage and read the monster's traits and a simple hint.
2. Draw a weapon and optionally add one text description.
3. **TBD (post-M1)** Voice can later be another input route.
4. AI analyses the idea.
5. The game shows the weapon name, attack form, strengths, and weakness.
6. The player confirms and enters combat.
7. Move, attack, use a special ability, and dodge.
8. On victory, obtain an upgrade or re-forging opportunity.
9. Enter the next stage.
10. On defeat, adjust the design and try again.

- **ASSUMPTION** A normal stage lasts 60–120 seconds.
- **ASSUMPTION** A boss lasts 2–3 minutes.
- **ASSUMPTION** A short run contains three normal stages and one boss, lasting
  roughly 8–12 minutes.
- **TO VALIDATE** All pacing assumptions require playtesting.

## 4. Combat

- **ASSUMPTION** The preferred format is single-screen, side-view action combat.
- **CONFIRMED (target experience)** Players can move left/right, perform a normal
  attack, use a weapon ability, dodge, and inspect health/cooldowns.
- **CONFIRMED** Mobile controls place movement on the left and attack, ability,
  and dodge on the right.
- **CONFIRMED** Landscape safe areas must be supported; interaction must not rely
  on a keyboard, hover, or right-click.
- **CONFIRMED** Web may also offer keyboard/mouse controls.
- **CONFIRMED** The first version excludes platform jumping, complex combos,
  multi-weapon switching, inventory, multiplayer, and precision aiming.
- **CONFIRMED (M0)** The technical spike implements left/right movement and normal
  attacks only; ability, dodge, health, and cooldown systems remain later work.

## 5. Weapon generation

### 5.1 Inputs

Final intent supports finger drawing, text, voice, and combinations. Delivery order:

1. **CONFIRMED (M0/M1):** drawing + text;
2. **CONFIRMED (M1):** text-only;
3. **TBD (M3 candidate):** voice-to-text;
4. **TBD:** joint drawing + voice understanding.

Voice is an input method, not a separate weapon system.

### 5.2 AI responsibilities and boundaries

- **CONFIRMED (M1B1)** AI interprets the concept and selects only supported
  semantic labels. The project-owned compiler, validator, and `PowerBudget`—not
  the model—deterministically assign or repair executable numeric values.
- **CONFIRMED** AI must not generate or execute game code, create infinite damage,
  alter saves, call engine functions directly, bypass budgets, or return an
  unsupported capability.
- **CONFIRMED (M0)** Use a deterministic local mock. No paid API or API key.
- **CONFIRMED (M1B1)** The production client calls only the same-origin project
  endpoint. The selected server adapter uses Anthropic's native Messages API,
  native Structured Outputs, and immutable model
  `claude-haiku-4-5-20251001`; it never uses an OpenAI-compatible route or model
  upgrade. The credential is a Sites Secret and never enters client assets.
- **CONFIRMED (M1B1)** Provider free-form display text, correction text, metadata,
  and nested cost fields are untrusted and never reflected directly. The server
  derives names, summaries, and repair messages from allow-listed semantic labels.

### 5.3 Canonical `WeaponSpec`

```json
{
  "name": "极寒回旋伞",
  "weapon_class": "ranged",
  "weapon_form": "boomerang",
  "delivery": "thrown",
  "trajectory": "returning",
  "impact": "contact",
  "area_effect": "none",
  "attack_pattern": "boomerang",
  "element": "ice",
  "damage": 32,
  "attack_speed": 0.7,
  "range": 420,
  "special_ability": "front_shield",
  "status_effect": "freeze",
  "drawback": "slow_recovery",
  "visual_material": "frozen_metal",
  "power_score": 100
}
```

- **CONFIRMED** Runtime data must pass schema validation and numeric clamping.
- **CONFIRMED** The checked-in schema is `schema/weapon_spec.schema.json`.
- **CONFIRMED (M1B1)** Weapon form and delivery semantics are independent from
  the executable attack/effect module. In particular, a grenade is thrown on an
  arc before `area_blast` creates the landing explosion; `area_blast` alone is
  not a delivery mechanism.
- **TO VALIDATE** `front_shield` in the product-intent example is not in the
  current executable M1A allow-list. M1B1 repairs/omits it instead of inventing a
  new module; adding a shield ability requires separate gameplay and budget work.

### 5.4 Supported modules

- **CONFIRMED (full MVP/M1):** melee slash, straight projectile, boomerang, area
  explosion, and piercing attack.
- **CONFIRMED (full MVP/M1):** normal, fire, ice, and electricity.
- **CONFIRMED (full MVP/M1):** burn, freeze, chain hit, knockback, and temporary
  shield.
- **CONFIRMED (M1A):** all five listed attack forms and all four elements are
  executable. Temporary front shielding remains **TO VALIDATE** as a future
  supported ability.
- **CONFIRMED** The first version promises stable combinations of supported
  modules, not perfect realization of arbitrary descriptions.

## 6. Weapon visuals

- **CONFIRMED** Preserve original strokes, remove the drawing background, apply
  light smoothing, infer grip and attack direction, add material/element effects,
  and use a preset animation for the attack type.
- **ASSUMPTION** Text/voice-only weapons can later combine blade, handle, gun body,
  and staff modules.
- **CONFIRMED** A polished asynchronous card image may not block combat.
- **CONFIRMED (M0)** The spike directly reuses normalized player strokes and adds
  only a simple color/glow treatment; grip inference and smoothing are later work.
- **CONFIRMED (M1B1 P0 visual-role fix)** Confirmation and held visuals use the
  actual stroke bounding box, 10% padding, and one uniform scale; canvas
  whitespace is ignored and original strokes are not rewritten. A projectile
  reuses player ink only when the validated form is itself thrown (grenade or
  boomerang). Bow, bullet, energy and piercing projectiles are deterministic
  program graphics, separate from the held weapon and impact effect.
- **CONFIRMED (M1B1.2)** A held melee drawing's frozen absolute
  horizontal span determines one bounded effective reach. The same reach drives
  held rendering from grip to visible tip, melee hit distance, HUD Range, and an
  inverse attack-speed tradeoff used by swing, hit timing, recovery, and
  cooldown. Drawing length does not increase damage.
- **CONFIRMED (M1B1.2 scope acceptance)** Physical iPhone testing confirmed that
  short, standard, and full-canvas long melee drawings remain visibly and
  mechanically different in combat. The current release candidate preserves the
  same bounded reach in the held visual, hit boundary, and HUD.
- **TO VALIDATE (Weapon Physics B1)** The prototype reach curve, tier thresholds,
  72-228 px bounds, and linear range-to-speed exchange are provisional. A future
  controlled short/long x light/heavy experiment will derive handling and the
  observable startup/active/recovery phases. Weapon mass remains independent
  from length, and length alone does not increase damage.
- **CONFIRMED (Weapon Physics B0 contract)** Numeric authority is frozen as
  `GeometryEvidence -> PhysicalProfile -> CombatDerived`; AI cannot author
  numeric physics and the public Schema does not expand for B1.
- **TO VALIDATE (Weapon Physics B1 prototype)** A bounded continuous reach ×
  light/balanced/heavy matrix now drives observable startup, active, hit and
  recovery timing plus existing Range/Speed PowerBudget components. Its curve
  still requires Chromium/WebKit and physical-device combat-feel evidence.
- **TO VALIDATE (Weapon Physics B2)** The current melee capsule applies one damage
  value from grip to visible tip. Grip/root low-effect zones, blade regions,
  outer sweet spots, tip damage, and their required visual/audio/hit-stop feedback
  are deferred as one contact-model feature; they are not part of M1B1.2.
- **TO VALIDATE** Grip and attack direction remain the current deterministic
  left-to-right prototype; semantic grip/orientation inference is still deferred.

## 7. Enemies and levels

| Enemy | Trait | Encouraged idea | Status |
| --- | --- | --- | --- |
| Basic slime | Slow, no special ability | Test basic attack | **CONFIRMED (full MVP)** |
| Shield monster | Frontal reduction | Boomerang, pierce, explosion | **CONFIRMED (full MVP)** |
| Flying monster | Keeps distance | Ranged, tracking, area | **CONFIRMED (full MVP)** |
| Fire boss | Fire attacks and phases | Freeze, defense, control | **CONFIRMED (full MVP)** |
| Training dummy | Stationary damage target | Verify generated attacks | **CONFIRMED (M0)** |

- **CONFIRMED** Each stage teaches one new problem, not only more health.
- **CONFIRMED** Failure should be understandable; hints should not directly give
  the answer; multiple solutions should remain valid.
- **CONFIRMED** M0 has no formal level, monster set, boss, or full victory/failure
  loop. Those remain M2 work per the explicit current-round scope.

## 8. AI and backend architecture

Target data flow:

`Godot client → secure backend → input moderation → AI interpretation → WeaponSpec validation → balance budget → Godot client`

- **CONFIRMED** No AI key in the client; all real AI requests go through a backend.
- **CONFIRMED** Validate input and output; require JSON Schema; clamp numeric
  bounds; provide an explicit non-equipable error on failure; log latency,
  errors, and estimated cost; cache
  equivalent input; never call AI during combat; do not retain raw voice by
  default.
- **CONFIRMED (M0)** `MockAIService` runs locally and implements the same data
  boundary without network access.
- **CONFIRMED (M1B1)** Godot Web calls `POST /api/compile-weapon` on its own
  origin. The Sites server worker owns request limits, safety checks, provider
  invocation, schema/allow-list/budget enforcement, non-equipable failure
  envelopes, and privacy-safe
  audit metadata. Secrets exist only as server environment variables.
- **CONFIRMED (M1B1)** Random client/request IDs, SHA-256 privacy namespaces,
  strict response-ID matching, and privacy-safe logs are programmatically
  enforced. Sites D1 owns atomic per-session/network quotas and cross-isolate
  idempotency.
- **CONFIRMED (M1B1)** Worker + D1 enforce the approved USD 5 lifetime provider
  budget by reserving worst-case spend before invocation and failing closed on
  exhaustion or guard uncertainty. Unknown billing is charged conservatively.
- **CONFIRMED (M1B1)** A separate Anthropic workspace spend limit at or below
  USD 5 was configured before controlled paid traffic. Provider moderation,
  production authentication policy, observability, cache policy, and retention
  periods remain **TBD**.

## 9. Safety and content control

- **CONFIRMED (full MVP)** Handle sexual/extreme violence, hate, real people,
  known characters/brands, dangerous real-world weapon descriptions, requests for
  unlimited damage, and prompt/code extraction attempts.
- **CONFIRMED** MVP excludes sharing, community, chat, user-generated content from
  other players, accounts, and unnecessary personal data.
- **CONFIRMED (full MVP)** Provide a “result is inappropriate” feedback route.
- **ASSUMPTION** MVP is not positioned as a children's application.
- **TO VALIDATE** M0 only proves deterministic bounds and fallback behavior; it is
  not a production moderation system.

## 10. Full MVP scope (preserved; not all M0)

### Required for the full MVP

- Runnable Godot project and deployable Web build usable from a phone.
- Landscape touch controls, one controllable character, drawing board and text.
- Input converted into `WeaponSpec`.
- At least five attack forms and four elements.
- Generated appearance preserves the drawing.
- One test enemy and one boss.
- A complete battle, victory, defeat, and restart.
- Fallback weapon on AI failure.
- Generation latency and failure-reason logging.

### Explicitly excluded

- Production accounts/cloud saves; multiplayer, leaderboard, community, sharing;
  purchases and ads; many formal levels/characters/full narrative; generation or
  execution of gameplay code; App Store or Google Play submission.

## 11. Full MVP acceptance (preserved)

### Engineering

Build without blocking errors; Web preview opens; mobile landscape is operable;
service failure does not crash; no API key is exposed.

### AI

Run at least 20 inputs spanning normal, abstract, overpowered, random drawings,
unsafe content, famous IP, and unintelligible descriptions. Valid output must fit
`WeaponSpec`, use only executable capabilities, obey the budget, safely transform
or reject unsafe input, fall back on failure, and log latency/errors.

### Playability

Players should understand what they drew, how AI interpreted it, why it attacks as
it does, its advantage/weakness, why combat succeeded or failed, and what to change.
The key test is whether a second weapon comes from a new idea instead of repeatedly
rolling for a higher damage value.

## 12. Milestones

- **M0 — technical spike (complete):** Godot, drawing board, Web export, touch,
  service boundary, `WeaponSpec`, visible weapon, training dummy, melee/projectile.
- **M1A — deterministic weapon compiler (complete):** combined drawing/text
  input, explicit power budget, runtime and JSON Schema validation/repair, five
  attack forms, four elements, target lab, 32 input cases, public Web deployment,
  and physical iPhone Safari acceptance.
- **M1B1 — real text-to-weapon interpreter (complete):** Anthropic
  Haiku 4.5 is configured server-side through the native Messages API and native
  Structured Outputs. The public blocker-fix candidate confirms the same-origin
  contract, explicit non-equipable failure flow, atomic request snapshots,
  confirmation/correction UI, deployed D1 USD 5 hard limit, and exact
  model. The real-provider matrix passed 42/42 cases with 100% labelled pattern
  and element accuracy, 100% Schema/allow-list/runtime validity, 1.318 s median
  provider latency, 4.846 s P95, and USD 0.033588 measured matrix cost. Chromium
  and version-matched WebKit public regression passed with zero application
  console errors. Two additional live blocker cases confirmed grenade
  thrown/arc/landing-explosion and bow direct-projectile semantics for USD
  0.003575 total. Physical iPhone Safari M1B1 acceptance is **CONFIRMED**.
  A later physical-iPhone pass reopened two P0 gates: keyboard focus/Canvas
  stability and held/projectile/impact visual separation. The replacement keeps
  a stable Canvas with compact text entry, keeps bows held while arrows fly, and
  gives grenades a centred drawn flight copy plus independent explosion. These
  are **CONFIRMED in Chromium/WebKit and on physical iPhone Safari**.
- **M1B1.1 — Player UI Simplification (accepted; release closure in progress):** retain the accepted Codex
  repository, Godot/Web/backend architecture, AI safety boundaries, mobile input
  behavior, five attack modules, four elements, and complete target lab while
  separating a quiet player-facing Forge/Combat presentation from the complete
  Developer/Test presentation. Player Combat places the player left, current
  target right, readable attack space in the middle, and compact HUD/actions at
  the edges. This presentation pass does not add drawing understanding, new AI,
  production art, accounts, voice, or gameplay systems. Its executable contract
  is `docs/M1B1_1_PLAYER_UI_ACCEPTANCE.md`.
- **M1B1.2 — Absolute Weapon Reach (accepted; release closure in progress):**
  freeze one client-owned geometry profile per FORGE request and use its bounded
  effective reach for held-melee grip-to-tip rendering, HUD Range, real hit
  boundary, inverse cycle timing, and facing lock. Physical iPhone scope
  acceptance is **CONFIRMED**. Mass/handling experiments and contact-position
  damage remain the separately staged Weapon Physics B1 and B2 work. Its
  executable contract is `docs/M1B1_2_ABSOLUTE_REACH_ACCEPTANCE.md`.
- **M1B2 — drawing semantic understanding (not started):** image/vision meaning
  is explicitly outside M1B1; only bounded `drawing_summary` metadata is sent.
- **M2 — vertical slice:** production combat character, three normal monsters, one
  boss, 3–4 stages, win/loss/retry, base audio, animation, feedback.
- **M3 — voice and mobile test:** voice-to-text, Android internal test, iOS
  TestFlight, device matrix, performance, background recovery.
- **M4 — proceed decision:** expand only if creation itself is fun, weapons differ
  meaningfully, players voluntarily create second/third weapons, AI latency/cost
  and failures are acceptable, and some testers want to return.

## 13. Current defaults requiring evaluation

| Question | Current default | Status |
| --- | --- | --- |
| 2D or 3D | 2D | **CONFIRMED** |
| View | Single-screen side view | **ASSUMPTION** |
| Combat | Move, attack, ability, dodge | **ASSUMPTION** |
| Creation timing | Before entering a stage | **ASSUMPTION** |
| Re-forge in combat | At most once per stage | **ASSUMPTION** |
| First input | Drawing + text | **CONFIRMED** |
| Voice timing | After weapon system validation | **TBD** |
| Art direction | Hand-drawn cartoon | **ASSUMPTION** |
| Child positioning | Not a child app for MVP | **ASSUMPTION** |
| Real-time text-to-image | Not required by MVP | **CONFIRMED** |
| Community | Not in MVP | **CONFIRMED** |

