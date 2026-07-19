# M0 Technical Spike Handoff

## Outcome

**CONFIRMED:** M0 is runnable locally and as a Godot Web export. A player can draw
with a mouse or touch, choose a one-line idea, receive a validated mock
`WeaponSpec`, see their strokes attached to the test character, and damage a
training dummy with either a melee slash or a straight projectile. Re-forging
clears the canvas and replaces the active weapon.

## Start the project

From PowerShell in the repository root:

```powershell
./scripts/run_game.ps1
```

To open the Godot editor:

```powershell
./scripts/run_editor.ps1
```

The scripts prefer the ignored workspace-local Godot 4.7.1 executable under
`.tools/`, then fall back to `godot4` or `godot` on PATH.

## Start the Web trial

```powershell
./scripts/build_web.ps1
./scripts/serve_web.ps1
```

Open [http://localhost:8060](http://localhost:8060). There is no configured remote
or hosting target, so M0 produces a local Web trial rather than a public URL.

To open the build from another device on the same network, run the server, allow
the chosen port through the local firewall if required, and browse to
`http://<development-computer-LAN-IP>:8060`. This is a development server, not a
production deployment.

## Controls

- Draw: left mouse drag or one-finger drag.
- Choose `MELEE IDEA` or `PROJECTILE IDEA`, or type a sentence.
- Generate: `GENERATE WEAPON`.
- Move: `A`/`D`, arrows, or hold the on-screen movement buttons.
- Attack: `Space` or `ATTACK`.
- Create another weapon: `REFORGE`.

## Delivered systems

- Responsive 2D landscape scene and touch-sized controls.
- Mouse and true browser touch event drawing.
- Deterministic local mock with latency/fallback metadata.
- JSON Schema plus runtime allow-list validation and numeric clamping.
- Stroke-normalized weapon visual using the player's geometry.
- Test pilot, training dummy, health readout, hit feedback, and dummy reset.
- Melee and projectile attack dispatch with fixed, non-rerolling profiles.
- Re-forging flow and complete weapon stat readout.
- Headless tests, import/parse check, runtime smoke, Web build, local HTTP server,
  and Playwright browser evidence.

## Evidence

Detailed results and limitations are recorded in `artifacts/TEST_RESULTS.md`.
Representative screenshots are under `output/playwright/`:

- `10-mobile-touch-drawing.png` — real Chromium touch events on the drawing board.
- `14-mobile-844x390-hit-final.png` — compact landscape touch-generated hit.
- `15-mobile-915x412-combat.png` — wide Android-style landscape layout.
- `18-desktop-melee-hit-final.png` — desktop melee hit and full stat readout.
- `20-desktop-projectile-flight-final.png` — visible generated projectile in flight.
- `21-desktop-projectile-hit-final.png` — projectile hit and freeze feedback.
- `19-desktop-reforge-final.png` — cleared re-forge state.

## M1 recommendation

**Recommended, with scope discipline.** M0 validates the engine, touch/Web path,
structured data boundary, stroke preservation, and two mechanically distinct
attack families. M1 should now focus on the weapon compiler: all five planned
attack patterns, four elements, an explicit power-budget calculator, malformed and
timeout responses, and the 20-input matrix. Do not connect a paid AI provider until
those deterministic compiler and fallback tests pass.

