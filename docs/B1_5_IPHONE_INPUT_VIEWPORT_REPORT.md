# B1.5 iPhone Input and Viewport Blocker Report

Status: **CONFIRMED automated candidate / TO VALIDATE on physical iPhone Safari**

## Device evidence

The product owner rejected the B1.5 exposure candidate after a physical iPhone
Safari run on 2026-07-26.

- **CONFIRMED:** after Description/keyboard activity, the Forge Canvas could
  remain about 104 CSS pixels shorter than the restored Visual Viewport, leaving
  a large black strip until a later viewport event.
- **CONFIRMED:** `冰冻手榴弹` remained intact in the native HTML input, while
  Godot's Latin-only UI fallback rendered the same text as missing-glyph boxes.
- **CONFIRMED:** that request produced a generic `NORMAL / AREA BLAST`, not an
  ice grenade with thrown/arc delivery.
- **CONFIRMED:** ATTACK appeared enabled but became ineffective after one or two
  non-lethal enemy strikes. One screenshot also shows LEFT held while ATTACK was
  attempted with a second finger.
- **TO VALIDATE:** the exact physical Safari input cancellation point. Runtime
  evidence proves non-lethal damage does not close the gameplay attack gate;
  existing pre-fix browser strategy tests bypassed the visible ATTACK button and
  therefore could not validate the device path.

## Separate root causes and corrections

### Canvas restore race

`web_canvas_guard.js` calculated `entryActive` before clearing its `closing`
state. If Safari restored keyboard and toolbar geometry in one frame and emitted
no later resize, that frame still applied the stale Canvas height and the settle
loop stopped.

The controller now recomputes `entryActive` after the closing transition, so the
same frame adopts the live Visual Viewport and reaches its bottom edge.

### ATTACK touch path

The visible ATTACK control previously depended on a release-only `pressed`
signal. A second active touch or Safari pointer cancellation could lose the
release even though the button stayed visually enabled. ATTACK now commits one
intent on `button_down`; the existing `ForgePlayer` gate remains authoritative
for cooldown, buffering, boomerang detachment, combat state, and terminal state.
No hit or cooldown state is forcibly reset on damage.

QA state now distinguishes:

- visible UI attack intents;
- accepted player attacks;
- buffered or rejected attack outcomes;
- button disabled state.

Melee reach/contact math is unchanged in this correction. A temporary
target-surface-radius experiment caused the existing Chromium spacing gate to
regress and was removed. Contact regions and sweet spots remain the separate B2
scope.

### Chinese semantic and display boundary

The native HTML Description remains the Web renderer for arbitrary IME text.
Raw player text is no longer exposed through Godot labels while the native layer
is hidden; request audit copy reports `DESCRIPTION SAVED` with request ID and
geometry counts.

The Anthropic prompt and deterministic explicit-cue repair now cover canonical
Chinese forms and elements. In particular, `冰冻手榴弹` deterministically repairs
a conflicting provider classification to:

- `weapon_form=grenade`;
- `delivery=thrown`;
- `trajectory=arc`;
- `impact=delayed_or_contact`;
- `area_effect=explosion`;
- `attack_pattern=area_blast`;
- `element=ice`.

The provider is still called. This bounded repair does not replace Claude with a
general keyword interpreter and does not allow provider-authored numeric stats.

## Automated evidence

- Godot/import/runtime/Worker/security suite:
  `32` matrix cases, `1187` assertions, `0` failures.
- Interpreter suite: `78` tests, including a deliberately conflicting provider
  result for `冰冻手榴弹`.
- Focused Chromium 844x390:
  - ATTACK after HP 80: UI intent and executable attack both increment;
  - ATTACK while movement remains held after HP 60: both increment;
  - same-frame keyboard/toolbar restore: `844x390`, black strip `0px`;
  - Chinese DOM and Godot state values both remain `冰冻手榴弹`;
  - application console errors: `0`.
- Focused Playwright WebKit 844x390: identical results.
- Full rebuilt Chromium C0/B1.5 matrix:
  - touch ATTACK after HP `80` and `60`: pass;
  - Pressure TTK order: pass;
  - Spacing total damage short/standard/long: `80/20/20`;
  - combined no-triple-winner gate: pass;
  - application console errors: `0`.
- Full rebuilt WebKit C0/B1.5 matrix:
  - touch ATTACK after HP `80` and `60`: pass;
  - Pressure TTK order: pass;
  - Spacing total damage short/standard/long: `40/0/0`;
  - combined no-triple-winner gate: pass;
  - application console errors: `0`.
- A temporary target-surface hit-radius experiment was rejected after Chromium
  regressed to `20/0/20` Spacing damage and failed the required long-reach
  exposure gate. The final candidate does not contain that change.
- Web export: pass.

Generated browser reports remain under the ignored
`output/playwright/iphone-blocker-local/` evidence directory.

## Explicitly deferred

- **TO VALIDATE / later balance:** grenade damage, cadence, useful throw range,
  charge-to-throw, and player-drawn grenade size affecting combat presentation.
- **TO VALIDATE / physical device:** real iPhone multi-touch ATTACK, Canvas
  restore after actual Safari toolbar transitions, and a guarded real Claude
  `冰冻手榴弹` request on the next isolated preview.

This candidate cannot be merged or declared accepted until the product owner
passes the physical iPhone checklist.
