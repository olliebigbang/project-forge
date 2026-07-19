# v9 Mobile Usability verification

Status: **TO VALIDATE — physical iPhone Safari gate remains open**

Implementation source: `0dcc4a6`

Web package SHA-256: `0BDD31A387B3373C90C88D8F4DB19F8F9369BA0B143900324810F7F9BF4191F9`

Public v9 URL: <https://project-forge-weapon-lab.hongningliu0130.chatgpt.site/?release=v9-f309f28>

Sites version: `9`; deployed source: `f309f28da1ff1e62e9a11b10fb66a55f737c5d5a`

## Root cause and corrective boundary

- v8 sized phone controls in Godot logical pixels. The Web canvas then scaled
  those values into controls much taller than the requested 48–56 CSS pixels,
  leaving an unusably small drawing area.
- The Godot Web `LineEdit` did not provide a dependable real-iOS focus/keyboard
  path, and its built-in clear affordance was not a separate touch target.
- v9 derives Compact Landscape from `window.visualViewport`, renders 44–48 CSS
  px controls, keeps the drawing area at least 150 CSS px and 40% of usable
  height, and reacts to orientation/window/visual-viewport changes.
- v9 Web uses one bounded native HTML input plus an explicit 44×44 CSS px `×`,
  synchronized both ways with Godot. It is hidden in combat and portrait.
- `RESET` now clears strokes, text, loaded-example state, and temporary status,
  preserves the chosen attack mode, and shows a short confirmation.

## Automated results

| Check | Result |
| --- | --- |
| Godot import/script parse | **PASS** |
| Deterministic compiler/unit suite | **PASS — 32 matrix cases, 447 assertions** |
| Main-scene headless smoke | **PASS** |
| Static hosting worker tests | **PASS — 3/3** |
| WASM chunk loader tests | **PASS — 1/1** |
| Godot Web export and Sites bundle | **PASS** |
| Safe-area viewport metadata | **PASS — `viewport-fit=cover`** |
| Chromium touch regression | **PASS** |
| WebKit touch regression | **PASS** |
| Public index and PCK HTTP status | **PASS — HTTP 200** |
| Public PCK identity | **PASS — exact local/public SHA-256 match** |
| Public Chromium full regression | **PASS — no console warning/error** |
| Public WebKit full functional regression | **PASS — no application warning/error** |

Chromium and WebKit both passed Description load/focus/edit/delete/clear,
RESET/redraw/re-entry, 30 sequential selector changes, three portrait/landscape
cycles, Safari-toolbar-height simulation, and all five compile/attack/reforge
flows. Chromium reported no console errors or warnings.

The Windows Playwright WebKit renderer logs its known Godot/WebGL
`glBlitFramebuffer` validation messages before the test listener starts. The
functional regression completed with no GDScript/JavaScript error and no new
console message. This desktop renderer artifact is not treated as proof of real
iPhone rendering or keyboard behavior.

The public build was fetched without relying on an old resource body: its
95,800-byte `index.pck` hashes to
`0BDD31A387B3373C90C88D8F4DB19F8F9369BA0B143900324810F7F9BF4191F9`,
different from v8's `806B6E27...`. Public Chromium and WebKit then repeated the
complete v9 browser suites against Sites version 9.

## Compact layout measurements

| Viewport | Drawing height | Touch-row height | Scroll/crop |
| --- | ---: | ---: | --- |
| 844×390 | 194.08 px | 46.03 px | none |
| 852×393 | 195.59 px | 46.39 px | none |
| 915×412 | 214.88 px | 46.34 px | none |
| 844×343 toolbar simulation | 154.73 px | 44.30 px | none |

Desktop 1280×720 also passed without scroll/crop and retained the regular 3+2
selector layout.

## Five attack paths

| Pattern | LOAD IDEA | compiled pattern | runtime validation | ATTACK/REFORGE |
| --- | --- | --- | --- | --- |
| `melee_slash` | pass | pass | pass | pass |
| `straight_projectile` | pass | pass | pass | pass |
| `boomerang` | pass | pass | pass | pass |
| `area_blast` | pass | pass | pass | pass |
| `piercing` | pass | pass | pass | pass |

## Screenshots

- `artifacts/v9_mobile_usability/forge-844x390.png`
- `artifacts/v9_mobile_usability/description-focused.png`
- `artifacts/v9_mobile_usability/description-cleared.png`
- `artifacts/v9_mobile_usability/reset-blank-state.png`
- `artifacts/v9_mobile_usability/portrait-rotate-prompt.png`

## Remaining gate

- **TO VALIDATE** A real iPhone Safari must prove that tapping Description opens
  the system keyboard, cursor/edit/delete work, keyboard dismissal restores the
  compact layout, and Safari toolbar expansion/collapse does not cover controls.
- **TO VALIDATE** Repeat landscape → portrait → landscape three times on the
  public v9 URL without refresh or input lock.
- M1B and other new-feature development remain paused until the user accepts
  these physical-device checks.
