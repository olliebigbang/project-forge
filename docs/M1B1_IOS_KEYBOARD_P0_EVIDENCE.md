# M1B1 iOS keyboard P0 evidence

Status: **CONFIRMED in Chromium and Playwright WebKit; TO VALIDATE on a physical
iPhone Safari**. This candidate remains on `codex/fix/m1b1-input-aspect` in
Draft PR #4 and must not merge before the product owner accepts the public build.

## Separate root cause

The black screen was not a normal keyboard-height reduction. Three independent
viewport owners were fighting each other:

1. Godot export canvas policy `2` resized the WebGL canvas from the temporary
   keyboard-reduced `window.innerHeight`.
2. The old bridge also recalculated the 1280x720 game layout from the reduced
   `visualViewport.height`, while ignoring `visualViewport.offsetTop`.
3. Safari focus auto-scroll and repeated `visualViewport.resize/scroll` callbacks
   moved the focused input and canvas again. The resulting feedback loop could
   place the whole canvas above the visible viewport and expose the black body.

This cause is independent of AI interpretation and weapon rendering.

## Implemented boundary

- Web export now uses JavaScript-managed canvas policy `0`.
- `web_canvas_guard.js` owns one stable landscape canvas size. It reads
  `innerWidth`, `innerHeight`, `visualViewport.width/height`, offsets and scale.
- A focused Description plus a material Visual Viewport height drop enters a
  dedicated `text_entry` mode. During that mode, the canvas CSS size and backing
  store remain frozen; the game world is not rescaled to keyboard height.
- The page shell is fixed with overflow and overscroll disabled, and focus uses
  `preventScroll` where supported so Safari cannot scroll the canvas away.
- A compact native input dock is placed inside the current Visual Viewport and
  all four safe-area insets. It keeps Description visible and provides explicit
  44px `x` and 64x44px `DONE` controls.
- The input uses a 16px system font to avoid iOS focus zoom.
- On blur, the bridge waits for Visual Viewport recovery before releasing the
  stable canvas. Toolbar and orientation events then resume normal layout.
- Portrait rotation safely exits text entry and retains Description state.

## Automated evidence

The QA-only viewport hook separates the 844x390 Layout Viewport from a 844x190
Visual Viewport with `offsetTop=92`, which ordinary `page.setViewportSize()`
cannot model.

| Assertion | Chromium | WebKit |
| --- | ---: | ---: |
| Canvas CSS rect before/open/after | 844x390 | 844x390 |
| Canvas backing store before/open/after | 2532x1170 | 2532x1170 |
| Synthetic keyboard Visual Viewport | 844x190 at y=92 | 844x190 at y=92 |
| Input / clear / Done inside Visual Viewport | PASS | PASS |
| Input font | 16px | 16px |
| Edit and delete text | PASS | PASS |
| Done restores normal layout without refresh | PASS | PASS |
| 844x343 Safari-toolbar stress | PASS | PASS |
| Landscape/portrait/landscape cycles | 3 | 3 |
| Description preserved | PASS | PASS |
| New application console errors | 0 | 0 |

Machine reports:

- [Chromium report](evidence/m1b1-p0-v19/chromium-report.json)
- [WebKit report](evidence/m1b1-p0-v19/webkit-report.json)

Visual evidence (synthetic keyboard geometry, not a claim that Windows displayed
the physical iOS keyboard):

- [WebKit text-entry mode open](evidence/m1b1-p0-v19/webkit-keyboard-open.png)
- [WebKit layout restored after Done](evidence/m1b1-p0-v19/webkit-keyboard-closed.png)
- [Chromium text-entry mode open](evidence/m1b1-p0-v19/chromium-keyboard-open.png)
- [Chromium layout restored after Done](evidence/m1b1-p0-v19/chromium-keyboard-closed.png)

## Modified files

- `export_presets.cfg`
- `scripts/build_web.ps1`
- `scripts/web_canvas_guard.js`
- `scripts/web_mobile_input.js`
- `scripts/web_mobile_bridge.gd`
- `scripts/main.gd`
- `tests/browser/run_m1b1_blocker_regression.mjs`

## Remaining physical gate

Playwright WebKit validates Safari-engine layout and events, but cannot display
or prove the real iOS system keyboard. A physical iPhone must still verify focus,
typing/deletion, Done, toolbar expansion/collapse and three orientation cycles.
Until that pass, this P0 remains **TO VALIDATE on physical iPhone Safari** and the
branch remains unmerged.
