# M1B1 P1 — Stroke Aspect-Ratio Evidence

> Historical geometry evidence only. The old projectile screenshots and pass
> conclusion are superseded by `M1B1_WEAPON_VISUAL_ROLES_P0_EVIDENCE.md` because
> they did not detect the complete held bow being copied as a projectile. The
> actual-bounds/uniform-scale measurements remain valid for player-ink visuals.

Status: **CONFIRMED on physical iPhone Safari**. This report covers the P1
display-transform blocker independently from the P0 interpreter/input blocker.

## Independent diagnosis

**CONFIRMED** The original drawing data was normalized once with separate canvas
width/height divisors and then filled into a fixed weapon rectangle with another
independent X/Y mapping. Canvas blank space therefore affected the result, and a
wide drawing was compressed horizontally. Piercing projectiles added a second
non-uniform parent scale (`0.68 x 0.32`).

**CONFIRMED** This was a rendering transform defect. It did not originate in
Claude, request construction, schema validation, or semantic repair.

The Claude Code repository was inspected read-only at commit
[`9edb896`](https://github.com/olliebigbang/project-forge-claude/tree/9edb896048c52e6371c53431a31efcab21d334e7).
Its ink-crop and keep-aspect principles informed the review; no source code was
copied. Project Forge keeps vector strokes and applies the stricter percentage
padding rule required by this milestone.

## Implemented transform

`StrokeFit` now performs one non-destructive mapping shared by confirmation,
held weapons, attack animation, straight projectiles, boomerangs, piercing
projectiles, and thrown grenades:

```text
bounds = bounding box of actual stroke points (canvas blank space ignored)
inner = target rectangle inset by 10% on each side
scale = min(inner.width / bounds.width, inner.height / bounds.height)
mapped = source_point * scale + centered_offset
```

- The raw canvas strokes are deep-copied at request freeze and never rewritten.
- X and Y always use the same scalar; parent size changes also remain uniform.
- Padding is clamped to 8%–12%, with 10% used by all current paths.
- The piercing-only `0.68 x 0.32` scale was removed.
- A real stroke preview was added to the confirmation screen and uses the same
  `WeaponVisual` path as combat.
- Empty, origin-only, pure horizontal, and pure vertical inputs remain safely
  renderable.

## Automated geometry evidence

**CONFIRMED** Godot completed 32 matrix cases and 589 assertions with zero
failures. The focused geometry matrix covers wide bow, long spear, long blade,
round grenade, and square shield across four target rectangles. Every case:

- preserved the original point arrays byte-for-byte;
- ignored canvas offset/blank space;
- kept limiting-axis padding within 8%–12%;
- kept rendered/source aspect-ratio error at or below 2%; and
- kept actual straight, boomerang, piercing, and grenade projectile transforms
  uniform.

**CONFIRMED** Chromium and Playwright WebKit completed the end-to-end browser
regression at 844x390 with zero application console errors. Both browsers drew
the weapon through the canvas, compiled it, inspected the confirmation preview,
entered combat, and executed the attack.

| Browser | Shape | Source ratio | Rendered ratio | Relative error | Padding | Review/held scale delta |
|---|---:|---:|---:|---:|---:|---:|
| Chromium | wide bow | 6.195281 | 6.195280 | 0.000000137 | 10% | 0 / 0 |
| Chromium | round grenade | 0.999901 | 0.999901 | 0.000000215 | 10% | 0 / 0 |
| WebKit | wide bow | 33.114379 | 33.114382 | 0.000000070 | 10% | 0 / 0 |
| WebKit | round grenade | 0.999901 | 0.999901 | 0.000000069 | 10% | 0 / 0 |

The unusually thin WebKit bow source is caused by Windows WebKit coalescing
mouse-drag samples; the test remains valid because it compares the captured
source bounding box with its rendered result. The fixed 4.5:1 synthetic wide-bow
case is also covered by the Godot geometry matrix.

**CONFIRMED** The deployed real-Claude run independently exercised the same
shared transform after a genuine provider response and through combat:

| Shape | Source ratio | Rendered ratio | Relative error | Padding | Review / held / attack / projectile scale delta |
| --- | ---: | ---: | ---: | ---: | ---: |
| wide bow | 6.195281 | 6.195280 | 0.000000137 | 10% | 0 / 0 / 0.000000060 / 0 |
| round grenade | 0.999901 | 0.999901 | 0.000000215 | 10% | 0 / 0 / 0.000000060 / 0 |

Both relative errors are far below the 2% limit. The grenade additionally kept
the same uniform drawing transform while held and during visible arc flight,
then created its area effect 230.05 logical pixels from the throw origin.

## Retained visual and machine-readable evidence

Failure baseline (not passing evidence):

- [wide bow before](evidence/m1b1-blockers/before-wide-bow-combat.png)
- [round grenade before](evidence/m1b1-blockers/before-round-grenade-combat.png)
- [baseline failure record](evidence/m1b1-blockers/baseline-failure.json)

Fixed build:

- [wide bow confirmation](evidence/m1b1-blockers/after-wide-bow-confirmation.png)
- [wide bow held in combat](evidence/m1b1-blockers/after-wide-bow-combat.png)
- [round grenade confirmation](evidence/m1b1-blockers/after-round-grenade-confirmation.png)
- [round grenade held in combat](evidence/m1b1-blockers/after-round-grenade-combat.png)
- [grenade visible arc flight](evidence/m1b1-blockers/grenade-arc-flight.png)
- [grenade landing explosion frame](evidence/m1b1-blockers/grenade-landing-explosion.png)
- [Chromium machine report](evidence/m1b1-blockers/chromium-report.json)
- [WebKit machine report](evidence/m1b1-blockers/webkit-report.json)
- [real Claude grenade/bow machine report](evidence/m1b1-blockers/real-provider-grenade-bow.json)
- [real wide-bow confirmation](evidence/m1b1-blockers/real-bow-confirmation.png)
- [real wide-bow projectile](evidence/m1b1-blockers/real-bow-projectile.png)
- [real round-grenade confirmation](evidence/m1b1-blockers/real-grenade-confirmation.png)
- [real round-grenade arc flight](evidence/m1b1-blockers/real-grenade-arc-flight.png)

The browser fixture deliberately identifies itself as simulated. It is valid
for client rendering/input/attack behavior only and is not claimed as real
Claude evidence. Real provider evidence is tracked separately under P0.
