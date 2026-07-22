# Weapon Physics B0 Contract and B1 Controlled Prototype

Status: **CONFIRMED B0 authority contract and accepted B1 controlled curve;
production balance remains TO VALIDATE**

Weapon Physics B1 is complete and released as
`v0.3.0-weapon-physics-b1`. B1.5/B2 labels below preserve roadmap boundaries;
the next gameplay milestone is **TBD / TO VALIDATE** until the product owner
authorizes it.

This work begins at stable tag `v0.2.1-m1b1.2` and does not start M1B2. It
preserves the accepted interpreter, Worker/D1 safety boundary, public
`WeaponSpec`, five attack modules, four elements, player UI, mobile input, and
physical-iPhone reach invariants.

## B0 authority chain

| Layer | Owns | Must not own |
| --- | --- | --- |
| `GeometryEvidence` | Frozen raw-stroke deep copy, source bounds, canvas size, horizontal span, cross-axis span, aspect, path/point counts | Weapon semantics, damage, timing, budget decisions |
| `PhysicalProfile` | Bounded `effective_reach`, reach tier, independent light/balanced/heavy mass profile | AI-authored numbers, contact damage, role compensation |
| `CombatDerived` | Handling multiplier, final `attack_speed`, startup, active, hit moment, recovery, full cycle, physics budget delta | New `WeaponSpec` fields, sweet spots, per-region damage |

`DrawingGeometryProfile` remains a compatibility facade for accepted M1B1.2
call sites. Its serialized QA evidence exposes the three layers, but none of
those fields enter the provider request or public JSON Schema.

### Frozen invariants

- Raw strokes are deep-copied and never rewritten by profiling or fitting.
- Horizontal span and cross-axis load are independent evidence axes. Length
  never selects mass, and mass never grants reach.
- One `effective_reach` remains the source for grip-to-visible-tip length,
  melee capsule, HUD Range, and reach audit.
- Drawing length and mass do not change `damage` in B1.
- One derived `attack_speed` drives the swing tween, hit moment, recovery,
  cooldown, and attack-input acceptance. The phase durations sum to the cycle.
- Every physical correction records reach, mass, speed, the three phase times,
  PowerBudget delta, and the explicit `damage unchanged` reason.

## Fixed order

1. Existing server/client Schema repair and allow-list validation.
2. Existing semantic compatibility and strong-capability drawback enforcement.
3. Existing deterministic `PowerBudget.balance()` and 100-point cap.
4. Freeze `GeometryEvidence` from the same revisioned FORGE snapshot.
5. Derive `PhysicalProfile` locally; the model cannot supply numeric physics.
6. Derive reach, `attack_speed`, phases, and existing Range/Speed component
   costs. If this step crosses 100, speed is deterministically capped before any
   damage change; an impossible result remains non-equipable.
7. Recalculate the existing component breakdown and runtime-validity gate.

## B1 controlled mapping

All values below are **TO VALIDATE**, not production balance:

- Reach remains continuous and bounded at 72-228 px. The accepted 0.18-0.92
  horizontal-span anchors remain for comparison. The former ink-aspect safety
  cap was removed because it coupled cross-axis thickness into reach. An internal
  `ultra_short` tier identifies the 72-class floor without Schema work.
- Cross-axis canvas load maps to `light < 0.08`, `balanced < 0.20`, otherwise
  `heavy`. Controlled tests may inject the same internal class directly; no
  player-facing or provider field is added.
- Complete-cycle anchors at 72/92/120/199/228 px are joined by piecewise
  smoothstep interpolation. Light/balanced/heavy and existing drawbacks apply
  bounded multipliers; this is deliberately not inverse reach.
- `attack_speed = 1 / complete cycle`, capped to existing runtime bounds; the
  cycle retains a 0.25 s safety floor.
- Startup and active shares rise modestly with reach and mass. Recovery receives
  the remaining cycle. Contact is sampled once 62% through active motion.
- The 1-grid/light to 16-grid/heavy candidate cycle ratio is 4-6. The product
  owner accepted the round-two 5.775 ratio on physical iPhone on 2026-07-22;
  broader role and production balance remain outside B1.
- PowerBudget continues to price only public executable stats. Reach changes
  the existing `range / 45` component and handling changes the existing
  `attack_speed * 10` component; the audit records their combined delta.
- One active-attack gate and one Boolean buffer allow at most the current attack
  plus one queued attack; cooldown never reaches zero by design.

## B2 interface boundary

`CombatDerived` reports `uniform_grip_to_tip`, no regions, and sweet spots
disabled. This is an honest B1 limitation. Sword tip/body/root/guard/grip
regions, damage multipliers, interruption, shield and multi-target rules, VFX,
sound, hit stop, damage-number styling, and debug visualization remain B2.

## Evidence matrix

The deterministic and browser suites cover 1/4/8/16-grid x
light/balanced/heavy (12 cases) on Chromium and WebKit at an iPhone landscape
viewport. Each case checks stroke preservation, uniform fit, visible tip = HUD
Range = hit boundary, unchanged damage, phase timing, bounded cycle ratio,
budget audit, facing lock, one-slot rapid input buffering, exact hit count, and
zero application console errors.
