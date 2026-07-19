# iPhone Safari Touch/Layout Fix Results

Run date: 2026-07-19 (Australia/Sydney)  
Frozen local fix: `8cdea56b248d88db76a4e529ad94ffa4a7fadb97`  
Branch: `codex/fix/iphone-safari-touch-layout`  
Milestone status: **TO VALIDATE — physical iPhone Safari and replacement public deployment remain open**

## Root cause

The forge used a Godot `OptionButton`. Its `PopupMenu` opened as a modal popup on
physical iPhone Safari but did not complete item selection or outside dismissal,
so the popup retained the page-wide touch grab. The forge also had a full-screen
`ColorRect` using `MOUSE_FILTER_STOP`, and the project used an expanding logical
viewport without a portrait-specific UI. In portrait this stretched the 1280×720
compiler into a very tall canvas and pushed the popup over the bottom controls.

## Implemented fix

- Removed the `OptionButton`/`PopupMenu` path completely.
- Added five persistent 3+2 `ButtonGroup`-equivalent controls with release-based
  `pressed` handling, one selected item, `[X]` marker, distinct selected colors,
  border, and text color.
- Set each mode target to 102 logical pixels: about 55 CSS pixels at 844×390 and
  48 CSS pixels in the WebKit iPhone 15 landscape visual viewport (734×343 after
  simulated Safari chrome).
- Made `LOAD IDEA` and compile use the current M1A override and record
  `forced_attack_pattern` in the compiler audit.
- Limited `DrawingCanvas` consumption to its own rectangle and removed the
  main scene's global unhandled-input processing.
- Changed visual overlays/labels to `IGNORE`, routing containers to `PASS`, and
  actual controls to bounded `STOP` with release-triggered actions.
- Added a reversible bilingual portrait overlay with a vector rotation icon and
  a small OFL Noto Sans SC subset so the Chinese message renders in Web exports.
- Kept the selector in the forge only. Combat still exposes movement, attack,
  and REFORGE; M1B player-facing generation will infer the attack pattern.

## Automated results

| Check | Result |
| --- | --- |
| Godot import/GDScript parse | **PASS** |
| Deterministic matrix | **PASS — 32/32** |
| Godot assertions | **PASS — 414/414** |
| Main scene headless smoke | **PASS** |
| Static hosting worker | **PASS — 3/3** |
| WASM chunk loader | **PASS — 1/1** |
| Web export | **PASS** |
| Chromium true-touch drawing and 30 selector switches | **PASS** |
| Chromium five LOAD IDEA → compile → attack → REFORGE cycles | **PASS** |
| Chromium 844×390, 852×393, 915×412 and three rotation cycles | **PASS; no scroll** |
| Chromium console | **PASS — 0 errors, 0 warnings** |
| Fresh WebKit iPhone 15 landscape, 734×343, 30 selector switches | **PASS** |
| Fresh WebKit five LOAD IDEA → compile → attack → REFORGE cycles | **PASS** |
| Physical iPhone Safari | **TO VALIDATE — user acceptance gate** |

Every Chromium and fresh-context WebKit compile produced a runtime-valid audit
whose `forced_attack_pattern` and `weapon_spec.attack_pattern` matched the selected
mode. The five loaded descriptions also matched their deterministic examples.

WebKit's Playwright port emits one `WEBGL_polygon_mode` warning and 16 repeated
`glBlitFramebuffer` validation errors. The same messages existed in the old-build
baseline. A fresh iPhone landscape context remains visible and completes the full
touch flow. Forcing portrait/landscape sizes inside one Playwright WebKit mobile
context can make screenshot readback black even though Godot continues processing
the touch/compile chain; this is recorded as a simulator limitation, not treated as
physical Safari acceptance.

## Build identity

- `index.pck`: 81,404 bytes
- `index.pck` SHA-256: `806B6E27A86E9B97F53A67D5C2A60ACB9A56A07B1D077A02E46F869815CCD9BB`
- `index.wasm`: 39,513,091 bytes
- `index.wasm` SHA-256: `35116F68540AC41ACF7D71EA457ADDED91B5E960A9CCA3E2ACC72918EAF01277`

These hashes differ from the currently published v7 resources. A replacement
deployment must publish these new bytes; changing only a query string is not an
acceptable cache workaround.

## Screenshots

### Chromium 844×390 forge

![Chromium 844×390 forge](chromium-844x390.png)

### Portrait rotate prompt

![Portrait rotate prompt](chromium-portrait-rotate.png)

Fresh WebKit portrait also shows an opaque background; the stretched forge is not
visible beneath the prompt.

![WebKit portrait rotate prompt](webkit-final-portrait-rotate.png)

### WebKit iPhone 15 landscape with simulated Safari chrome (734×343)

![WebKit compact landscape](webkit-final-734x343.png)

### WebKit selector after five compile/attack/REFORGE cycles

![WebKit selector after regression](webkit-fresh-selector-after-regression.png)

### Chromium attack evidence

![Melee slash](chromium-melee_slash-attack.png)
![Straight projectile](chromium-straight_projectile-attack.png)
![Boomerang](chromium-boomerang-attack.png)
![Area blast](chromium-area_blast-attack.png)
![Piercing](chromium-piercing-attack.png)

## Delivery gate

No normal Git remote is configured (`git remote -v` is empty). Therefore a real
PR cannot be opened and hosted CI cannot run. The user's required order is PR → CI
→ replacement public deployment, so deployment is intentionally paused at this
gate. Minimum unblock: configure a GitHub/GitLab remote for this repository, grant
push/PR permission for `codex/fix/iphone-safari-touch-layout`, and provide or allow
a CI workflow that runs `scripts/test.ps1` plus the Web export.

The old public v7 URL is not the acceptance build and should not be retested as if
it contained this fix.

The downloadable fallback is
`release/Project-Forge-M1A-iPhone-Touch-Fix-Web.zip`. It contains the exact Web
export, a local Node HTTP server, launch instructions, and a build identity file.
Archive SHA-256: `045AC90A37641110E61D9D425CA89E8876B38965AC4E50DF3D4FF7A309E51E76`.

## Physical iPhone acceptance checklist

1. Open the new deployment in Safari in portrait; confirm only the bilingual
   rotate prompt is shown.
2. Rotate to landscape without refreshing; confirm the prompt disappears and all
   forge controls are visible above Safari chrome.
3. Tap the five modes forward and backward, then switch repeatedly; confirm one
   `[X]` selection and no modal or lock.
4. Draw, clear, draw again, edit the description with the iOS keyboard, close the
   keyboard, and confirm the layout returns.
5. For each mode, use LOAD IDEA, compile, attack, REFORGE, and continue selecting.
6. Use BACK after returning to the forge, then REFORGE again.
7. Rotate portrait → landscape → portrait → landscape at least three times without
   refreshing and confirm touch remains responsive.
