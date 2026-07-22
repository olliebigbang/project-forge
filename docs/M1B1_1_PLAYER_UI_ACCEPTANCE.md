# M1B1.1 Player UI Simplification

Status: **CONFIRMED complete and released**

Historical record — superseded by the v0.3.0 Weapon Physics B1 closure.

This is an isolated presentation milestone after stable M1B1. It keeps the
current Project Forge repository and runtime. It is not M1B2 and does not add
image understanding, a provider, production art, voice, accounts, sharing, or a
new combat mechanic.

## Product outcome

The normal-player path should read as a playable drawing-and-combat game rather
than a validation dashboard. The implementation remains original. Comparative
references inform only the general principles of fewer visible panels, stronger
whitespace, a clear central attack lane, and HUD/actions at the edges.

## Regression-locked foundation

The following are **CONFIRMED** and must not regress:

- Godot 4.7.1, landscape Web-first rendering, and the same-origin backend.
- D1 idempotency, quota and cost protection; random caller/request IDs;
  revision and late-response rejection; strict Schema and PowerBudget checks.
- Provider failure never creates an equipable weapon. Drawing and Description
  survive failure, cancellation, timeout, retry, and explicit error recovery.
- Stable Web Canvas, `visualViewport` handling, safe-area insets, portrait gate,
  native HTML Description overlay, keyboard Done/clear, and post-keyboard restore.
- Five attack modules, four elements, and stationary, moving, shield, and grouped
  target validation remain executable.
- Attack-mode test buttons appear only in Developer/Test Mode or explicit
  `MODIFY INTERPRETATION`.

## Player Forge acceptance

1. The drawing surface is the dominant visual area.
2. Title and instructions are reduced to the minimum needed to act.
3. Description, text clear, drawing/reset action, and Forge/Confirm remain inside
   the usable landscape safe area.
4. Every touch action is approximately 44 CSS px or larger and remains readable.
5. The accepted native input overlay and state-persistence path remain unchanged
   in behavior.
6. Decorative panel nesting, repeated borders, engineering terms, and permanent
   status copy are removed or reduced.
7. One primary Forge/Confirm action is visually dominant; destructive or
   secondary actions remain clearly subordinate.

## Player Combat acceptance

1. The player begins on the left and the current combat target reads on the
   right, with an unobstructed attack lane through the centre.
2. The upper-left contains at most one compact weapon HUD with name, core stats,
   element, weakness, and simplified Power. It does not expose the full budget
   formula.
3. Reforge is at the upper-right, Left/Right at the lower-left, and Attack at the
   lower-right. Controls do not cover characters, targets, health bars, or the
   expected projectile path.
4. Normal Player Mode does not show `M1B1 VALIDATION COMBAT LAB`, `READY`,
   `TEST DUMMY`, `GROUP 1/2/3`, complete budget components, or debug damage logs.
5. Damage feedback is temporary, local, and bounded; repeated hits do not create
   a permanent text stack.
6. Player, current target, HUD, health bars, labels, and controls have no overlap,
   crop, or safe-area collision.

## Developer/Test acceptance

1. Five attacks, four elements, and all four target categories remain available.
2. Complete PowerBudget and repair evidence remains inspectable only here.
3. Diagnostic density does not obscure combat. Use separated regions, pages, or
   collapsible panels when required instead of stacking every label at centre.
4. Switching presentation modes cannot change a `WeaponSpec`, combat behavior,
   provider call, budget result, or request identity.

## Responsive and browser gate

Verify at minimum:

| Visual viewport | Required result |
| --- | --- |
| 844 x 390 | Player Forge and Combat complete, readable, and uncropped |
| 852 x 393 | Player Forge and Combat complete, readable, and uncropped |
| 915 x 412 | Player Forge and Combat complete, readable, and uncropped |
| Portrait | Reversible rotation gate; game UI does not stretch underneath |
| Keyboard open/close | Description remains visible; stable Canvas restores immediately |
| Safari toolbar change | Layout recomputes without black screen, crop, or overlap |

Capture evidence for Player Forge, Player Combat, and Developer/Test Mode.
Player Combat evidence must contain no internal validation copy or target matrix.
Temporary screenshots, logs, exports, and build bundles stay outside Git.

## Required functional regression

- Each of the five attacks executes in Developer/Test Mode.
- Normal, fire, ice, and electric execute without visual-role regressions.
- Stationary, moving, shield, and grouped targets retain their validation value.
- Description focus/edit/delete/Done, Reset, Forge, Confirm, Attack, Reforge, and
  orientation cycles pass in Chromium and WebKit.
- Bow remains held while its arrow flies; grenade arcs/explodes/restores; sword
  emits no projectile; boomerang leaves and returns.
- Dagger/short sword, standard sword, and full-canvas long sword retain strictly
  increasing held length and melee distance. Their complete cycles are strictly
  short < standard < long; visible tip, melee capsule, HUD Range, swing hit time,
  recovery, and cooldown come from the same frozen reach/speed profile.
- A melee attack freezes its starting facing through hit and recovery. Immediate
  reverse movement cannot flip the visible swing away from the recorded hit
  direction; the new facing applies only after recovery.
- Drawing geometry and reach do not drift across 844×390, 852×393, 915×412 or
  orientation cycles. Every fitted copy keeps one uniform X/Y scale, at most 2%
  aspect error, 8%-12% padding, and unchanged raw strokes.
- Browser console has no new application error.

Run:

```powershell
./scripts/test.ps1
./scripts/build_web.ps1
./scripts/build_sites_preview.ps1
```

## Delivery boundary

- The completed development branch was
  `codex/ui/player-interface-simplification` from stable
  `main` / `v0.2.0-m1b1`.
- Product-owner acceptance and release integration completed. The current stable
  line is `v0.3.0-weapon-physics-b1`; this document preserves the M1B1.1 gate as
  historical evidence.
- Existing accepted branches, tags, worktrees, evidence, and rollback files
  remain retained until cleanup is separately approved.
