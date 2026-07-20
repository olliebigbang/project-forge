# M1B1 weapon visual roles P0 evidence

Status: **CONFIRMED in deterministic Godot, Chromium and Playwright WebKit;
TO VALIDATE on a physical iPhone Safari**. This is a separate root cause from the
iOS keyboard issue.

## Separate root cause

The former projectile path unconditionally instantiated the player's complete
`WeaponVisual` for every projectile and then drew a procedural projectile on top.
It therefore made the whole bow fly, rotated all straight projectiles, and used
the held visual's off-centre target rectangle as the grenade pivot. The runtime
had no explicit distinction between held weapon, flying object and impact effect.

## Deterministic visual bundle

`WeaponVisualBundle.from_spec()` now derives an internal, executable visual role
from validated `weapon_form`, `delivery`, `trajectory`, `impact`, `area_effect`
and `attack_pattern`:

| Weapon semantics | Held visual | Projectile visual | Rotation/lifecycle | Impact visual |
| --- | --- | --- | --- | --- |
| bow | player strokes, always held | procedural arrow | faces velocity; never tumbles | none |
| grenade | player strokes | temporary player-stroke copy | bbox-centred tumble; held hidden until cooldown | separate explosion |
| sword/melee | player strokes | none | held slash and exact rest reset | slash effect |
| boomerang | player strokes | same drawn weapon instance | bbox-centred outbound/return spin; held hidden until return | none |
| spear/piercing | player strokes | procedural spear | faces velocity | contact |
| other normal projectile | player strokes | procedural bullet | faces velocity | contact |
| other elemental projectile | player strokes | procedural energy body | faces velocity | contact |

Only a semantically thrown object such as grenade or boomerang can reuse the
player's drawing as its projectile. A projectile attack type alone never grants
permission to throw the held drawing.

All drawn visuals use actual stroke bounds, 10% padding and one uniform scale.
Grenade and boomerang copies are centred on the fitted geometry origin; source
strokes remain deep-copied and unchanged.

## Automated evidence

| Assertion | Chromium | WebKit |
| --- | ---: | ---: |
| Bow accepted attacks | 10/10 | 10/10 |
| Touch attempts required per accepted bow attack | 1 max | 1 max |
| Maximum simultaneous arrows | 1 | 1 |
| Arrow heading error | 0 rad | 0 rad |
| Held-bow position drift | 0 px | 0 px |
| Grenade physics samples | 8 | 8 |
| Grenade rendered aspect error | 0.0000215% | 0.00000695% |
| Grenade self-centred pivot | <=1px | <=1px |
| Grenade landing explosion and cooldown restore | PASS | PASS |
| Sword projectile count delta | 0 | 0 |
| Same boomerang instance returned | PASS | PASS |
| New application console errors | 0 | 0 |

The grenade samples move monotonically forward, rise above the start/end chord,
then descend before the independent `impact_spawn` event. Event order is
`projectile_spawn -> impact_spawn -> projectile_finish`, and the held grenade
returns only after cooldown reaches zero.

Machine reports:

- [Chromium report](evidence/m1b1-p0-v19/chromium-report.json)
- [WebKit report](evidence/m1b1-p0-v19/webkit-report.json)

Visual evidence:

- [WebKit bow held while one arrow flies](evidence/m1b1-p0-v19/webkit-bow-held-arrow-flight.png)
- [WebKit centred grenade in arc flight](evidence/m1b1-p0-v19/webkit-grenade-arc-flight.png)
- [WebKit independent landing explosion](evidence/m1b1-p0-v19/webkit-grenade-landing-explosion.png)
- [Chromium bow held while one arrow flies](evidence/m1b1-p0-v19/chromium-bow-held-arrow-flight.png)
- [Chromium centred grenade in arc flight](evidence/m1b1-p0-v19/chromium-grenade-arc-flight.png)
- [Chromium independent landing explosion](evidence/m1b1-p0-v19/chromium-grenade-landing-explosion.png)

## Modified files

- `scripts/weapon_visual_bundle.gd`
- `scripts/projectile_visual.gd`
- `scripts/projectile.gd`
- `scripts/player.gd`
- `scripts/weapon_visual.gd`
- `scripts/main.gd`
- `tests/run_tests.gd`
- `tests/browser/run_m1b1_blocker_regression.mjs`

## Remaining physical gate

The same public build must still be observed on a physical iPhone: bow held plus
arrow flight for repeated attacks, grenade departure/arc/centred rotation/blast/
restore, melee with no projectile, and boomerang return. No merge is permitted
before that product-owner result.
