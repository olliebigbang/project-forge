# V9 Mobile Usability QA Plan and Regression Report

## 1. Report status

- **Current state:** `PASS WITH NON-BLOCKING LIMITATIONS — READY FOR V9 PUBLIC PREVIEW`
- **Release decision:** `CONFIRMED` no P0/P1 was found in independent local automation; the integrator may deploy V9 for the physical-device gate.
- **Physical iPhone Safari gate:** `TO VALIDATE` — only the product owner can close this gate on a real iPhone.
- **QA branch:** `codex/qa/v9-mobile-usability`
- **QA worktree:** `C:\Users\Eddie L\Documents\project-forge-v9-qa`
- **Implementation SHA under test:** `0dcc4a6` (`fix: make mobile forge compact and editable`)
- **QA integration merge:** `7435703`
- **Public deployment URL and asset hash:** `TBD — integrator deploys only after this blocker review`

This document is the only file owned by the V9 QA workstream. QA must not modify Godot scenes or scripts, HTML, Web export files, browser automation, or build scripts. The main integrator owns fixes and deployment. Any P0 or P1 defect is returned to the main integrator and must be retested from a new implementation commit before release.

## 2. Sources and scope

This plan was prepared from:

- `AGENTS.md`;
- `docs/GDD.md`;
- `docs/MVP_ACCEPTANCE.md`;
- `docs/IPHONE_SAFARI_TOUCH_QA.md`;
- the V9 mobile usability requirements supplied by the product owner.

`CONFIRMED` V9 is a usability repair within M1A. M1B, paid AI integration, new gameplay features, production art, and other out-of-scope work remain paused.

`CONFIRMED` the five attack selectors are M1A compiler test controls and remain on the forge/compiler screen only. The fight screen must not expose them.

`CONFIRMED` a passing desktop or emulated browser run cannot substitute for the physical iPhone Safari acceptance gate.

`ASSUMPTION` clearing the description with the independent `×` button may either preserve or dismiss keyboard focus. Either behavior is acceptable only if the description is empty, no other control is blocked, focus can be recovered with one tap, and the layout returns to its valid compact state.

`ASSUMPTION` editing the description produces a deterministic, non-stale status update. Exact copy is `TBD`; it must not falsely report a successful compile or retain a message referring to cleared content.

## 3. Release gate and severity

The V9 preview is acceptable for product-owner device testing only when all automatable cases below pass, no P0/P1 defect remains open, the public deployment serves a new build and new resource hash, and the public URL has been smoke-tested after deployment. M1A remains unaccepted until the product owner confirms the physical iPhone Safari cases.

Severity rules:

| Severity | Definition | Examples | Release effect |
|---|---|---|---|
| P0 | Page or browser session becomes unusable or core data is lost without recovery | Touch lock, permanent overlay, crash, infinite load, no usable compiler | Blocks deployment and device acceptance |
| P1 | A required V9 flow cannot complete on an in-scope mobile viewport | Cannot edit text, `×`/RESET unusable, clipped COMPILE, wrong pattern compiled, orientation cannot recover | Blocks deployment and device acceptance |
| P2 | Required feedback or geometry is materially wrong but the flow has a reliable workaround | Weak focus indication, toast overlap, isolated safe-area spacing defect | Must be fixed or explicitly accepted before stable release |
| P3 | Cosmetic issue without usability or correctness impact | Minor alignment or copy inconsistency | May be documented for later |

## 4. Test oracles

### 4.1 Description input and independent clear button

The description field must behave as editable text, not as a display-only label. `LOAD IDEA` populates it for the selected pattern. Tapping the field focuses it; the caret can be repositioned; delete/backspace and new text work. The `×` is an independent button with a CSS hit box of at least `44 × 44 px`, clears only the description, provides focus/pressed feedback, and never creates a full-screen touch-capturing layer.

On physical iPhone Safari, tapping the description must summon the real iOS system keyboard. Browser automation may validate focus, input events, viewport resizing, and recovery, but cannot claim the real keyboard gate.

### 4.2 RESET state transition

Before RESET:

```text
selected_pattern = P
strokes = non-empty
description = non-empty
loaded_example = set
transient_message = any
```

After RESET:

```text
selected_pattern = P                  # unchanged
strokes = empty
description = empty
loaded_example = none
transient_message = "Canvas and description cleared"
```

The player must be able to draw and type immediately after this transition. RESET must not compile, navigate, change attack pattern, leave stale example state, or require a refresh.

### 4.3 Touch ownership

- Drawing Canvas consumes drawing input only while the pointer/touch is inside its own visible rectangle.
- Non-interactive visual Controls use `IGNORE` or equivalent behavior.
- Containers that need propagation use `PASS` or equivalent behavior.
- Interactive input and button Controls use normal focused/pressed handling and may stop their own event.
- No transparent or invisible full-screen Control may block input.
- A stroke that starts in the canvas must not trigger an adjacent selector/action; tapping a selector/action must not add a stroke.
- Controls must provide pressed/focus feedback without relying on hover.

### 4.4 Compact Landscape geometry

`CONFIRMED` Compact Landscape activates whenever the **actual usable viewport height is below 430 CSS px**. It must react to `orientationchange`, window `resize`, `visualViewport.resize`, and Safari toolbar-induced usable-height changes. A fixed logical height of 720 is not an acceptable layout oracle.

The compact screen must satisfy all of these at once:

- title and instructions are compressed but legible;
- drawing canvas occupies approximately 40–50% of usable height and its final CSS height is about 150 px or greater;
- description field and independent `×` are visible and usable;
- attack selectors are one row labelled exactly `MELEE`, `PROJECTILE`, `BOOMERANG`, `BLAST`, `PIERCING`;
- each selector has a CSS height of 44–48 px;
- action buttons are labelled `BACK`, `RESET`, `LOAD IDEA`, `COMPILE`, each with a CSS height of 44–48 px;
- transient status is a toast or one compact line and does not reflow or cover required controls;
- 844×390, 852×393, and 915×412 have no document scroll, clipping, overlap, or Safari-toolbar occlusion;
- safe-area padding protects interactive controls from notches, rounded corners, the home indicator, and browser chrome;
- desktop layout remains usable and does not inherit unintended compact-only geometry.

For browser evidence, record `innerWidth`, `innerHeight`, `visualViewport.width`, `visualViewport.height`, page scroll dimensions, canvas/control bounding rectangles, overlap tests, selected-pattern state, and console output. CSS bounds are judged from the browser page, not only Godot logical coordinates.

### 4.5 Orientation overlay

Portrait shows only a simple rotate prompt with the two lines `请将手机旋转为横屏` and `Please rotate your phone to landscape`, plus a clear rotation icon. The underlying elongated compiler must not be usable or visible as the active interface. Landscape automatically dismisses the prompt. Repeating landscape → portrait → landscape three times must neither preserve a blocker nor require a refresh.

## 5. Detailed regression matrix

The results below were produced from implementation `0dcc4a6`. `PASS` means the stated automated, source-inspection, or visual oracle passed. `TO VALIDATE — PHYSICAL IPHONE` is not converted to PASS by emulation.

### 5.1 Description, keyboard, and `×`

| ID | Priority | Procedure | Expected result | Status |
|---|---|---|---|---|
| V9-01 | P1 | Open compiler with default `MELEE`; tap `LOAD IDEA`. | A melee description appears in the editable field and is not clipped. | PASS — Chromium/WebKit |
| V9-02 | P1 | Select each of the five patterns and tap `LOAD IDEA`. | Description changes to the corresponding deterministic example each time. | PASS — Chromium/WebKit, all five |
| V9-03 | P1 | After loading an idea, tap `×`. | Description becomes empty immediately; canvas, pattern, and navigation state do not change. | PASS — browser + unit |
| V9-04 | P1 | Measure the `×` hit target at all three compact viewports. | Effective CSS hit box is at least 44×44 px and does not overlap the input or another button. | PASS — 46.0 px at 844×390; all targets 44–48 px |
| V9-05 | P1 | Tap the input near its beginning, middle, and end. | Input gains focus and caret appears at the tapped location without page lock. | PASS — focus/caret editing automated; physical tap precision TO VALIDATE |
| V9-06 | P1 | Type a unique string into an empty description. | Exact text is displayed; input/change state and non-stale status update deterministically. | PASS — DOM↔Godot sync and compile audit matched |
| V9-07 | P1 | Move the caret inside text; delete characters and insert replacements. | Caret movement, backspace/delete, and insertion produce the expected final string. | PASS — Chromium/WebKit/desktop |
| V9-08 | P1 | Focus the field on physical iPhone Safari. | Real iOS keyboard opens and text entry works. | TO VALIDATE — PHYSICAL IPHONE |
| V9-09 | P1 | Close the keyboard using iOS controls, then tap outside and refocus. | Layout restores; one tap refocuses; no invisible blocker remains. | TO VALIDATE — PHYSICAL IPHONE |
| V9-10 | P1 | Simulate `visualViewport` shrink/restore while the field is focused. | Required controls remain reachable during the transition and return to valid compact bounds afterward. | PASS — 844×220→390 restore |
| V9-11 | P1 | Toggle input focus/keyboard-sized viewport five times, then use all action and pattern buttons. | Every button still fires once per activation; no stuck focus or touch lock. | PASS — automated recovery and post-toggle flows |
| V9-12 | P1 | Load, clear with `×`, then type and compile. | Compiler uses the newly typed description, not the cleared example or stale state. | PASS — browser audit/input match |
| V9-13 | P2 | Activate `×` by touch and keyboard-accessible activation in browser harness. | Normal pressed/focus feedback is visible and the button emits one clear action. | PASS — browser + source visual-state inspection |
| V9-14 | P1 | Tap 5–10 px outside all four sides of `×`. | Nearby input focus may occur as appropriate, but the description is not accidentally cleared. | PASS — boundary tap retained text |
| V9-15 | P1 | Hold/touch-drag from input through `×`, then release outside. | No duplicate activation, modal state, or locked page occurs. | PASS — Chromium touch dispatch |
| V9-16 | P1 | Clear an already empty input repeatedly, then load an idea. | Repeated clear is idempotent and `LOAD IDEA` still works. | PASS — triple clear + LOAD |

### 5.2 RESET and recovery

| ID | Priority | Procedure | Expected result | Status |
|---|---|---|---|---|
| V9-17 | P1 | Draw multiple strokes, type text, establish loaded-example state, then press RESET. | Strokes and description clear; loaded-example state is cleared. | PASS — Chromium/WebKit + unit |
| V9-18 | P1 | Select a non-default pattern, then perform V9-17. | Selected pattern remains unchanged and visually selected. | PASS — BOOMERANG preserved |
| V9-19 | P1 | Leave a prior toast/error visible, then press RESET. | Old transient message is removed and exactly `Canvas and description cleared` is shown. | PASS — assertion + screenshot |
| V9-20 | P1 | Immediately draw after RESET. | First new stroke appears normally inside canvas only. | PASS — Chromium/WebKit |
| V9-21 | P1 | Immediately type after RESET. | Input accepts new text and no cleared example returns. | PASS — Chromium/WebKit |
| V9-22 | P1 | RESET an already empty fresh compiler three times. | Operation is idempotent, status is correct, and controls remain usable. | PASS — state transition/unit coverage |
| V9-23 | P1 | Press RESET while input is focused/keyboard-size viewport is active. | Data clears once; focus/layout recover without a permanent overlay or blocked control. | PASS — simulated viewport recovery; real keyboard TO VALIDATE |
| V9-24 | P1 | RESET, `LOAD IDEA`, then COMPILE. | A fresh example for the still-selected pattern is compiled; no pre-reset data leaks. | PASS — browser audit |

### 5.3 Touch bounds and control propagation

| ID | Priority | Procedure | Expected result | Status |
|---|---|---|---|---|
| V9-25 | P1 | Draw along each inside edge and corner of canvas. | Stroke is recorded only within visible canvas bounds. | PASS — bounded `_gui_input` inspection + browser drawing |
| V9-26 | P1 | Start/drag/release a touch outside canvas across selectors/actions. | Canvas does not consume the gesture or add a stroke; normal target control behavior remains. | PASS — source ownership + touch regression |
| V9-27 | P1 | Draw to a canvas edge, lift, then tap an adjacent selector. | Tap switches exactly one pattern and does not extend the stroke. | PASS — browser flow |
| V9-28 | P1 | Tap all non-interactive labels/panels and then all controls. | Visual layers never block later input; required controls remain operable. | PASS — source filters + continued interaction |
| V9-29 | P1 | Click/tap blank page space outside controls repeatedly. | No modal layer appears and no subsequent control is locked. | PASS — no modal/blocker observed |
| V9-30 | P1 | Tap selectors in forward order, reverse order, then random order for at least 20 changes. | Exactly one selector remains active; every activation works; no page lock. | PASS — 30 switches in Chromium and WebKit |
| V9-31 | P2 | Capture normal, focused, pressed, and selected visuals without mouse hover. | State changes are obvious by touch-only cues and meet contrast/readability intent. | PASS — selected cyan fill/border/text and `[X]` marker |
| V9-32 | P1 | Inspect runtime control bounds/hit targets and source `mouse_filter` intent. | Visuals ignore, propagation containers pass, interactive controls receive/stop their own events; no full-screen blocker. | PASS — source inspection |
| V9-33 | P1 | Double-tap every selector/action at touch speed. | No duplicate navigation/compile, stuck pressed state, or global input capture. | PASS — rapid activation regression |
| V9-34 | P1 | Return from fight to compiler and repeat drawing, input, clear, RESET, selection, and compile. | All touch paths still work and compiler state is internally consistent. | PASS — BACK/REFORGE in both engines |

### 5.4 Compact Landscape, orientation, and Safari chrome

| ID | Priority | Procedure | Expected result | Status |
|---|---|---|---|---|
| V9-35 | P1 | Load at 844×390 CSS viewport. | Canvas, input/×, five selectors, four actions, and compact status are all visible with no scroll, clipping, overlap, or occlusion. | PASS — canvas 194.08 px, controls 46.03 px |
| V9-36 | P1 | Load at 852×393 CSS viewport. | Same geometry conditions as V9-35. | PASS — canvas 195.59 px, controls 46.39 px |
| V9-37 | P1 | Load at 915×412 CSS viewport. | Same geometry conditions as V9-35. | PASS — canvas 214.88 px, controls 46.34 px |
| V9-38 | P1 | At each compact viewport, measure the canvas. | Canvas uses approximately 40–50% of usable height and is about 150 CSS px or taller. | PASS — also 154.73 px at 844×343 toolbar stress |
| V9-39 | P1 | At each compact viewport, measure all five pattern buttons. | One row, exact labels, each 44–48 CSS px tall, no overlap or truncated tap target. | PASS — exact labels and one-row visual check |
| V9-40 | P1 | At each compact viewport, measure BACK/RESET/LOAD IDEA/COMPILE. | Each is 44–48 CSS px tall, visible, distinct, and not covered by Safari toolbar/home indicator space. | PASS in emulation; physical toolbar TO VALIDATE |
| V9-41 | P1 | Change usable height across 429→430→431 px via resize and `visualViewport.resize`. | Compact mode follows actual usable-height threshold without stale geometry or fixed-720 behavior. | PASS — policy/unit boundary and resize path |
| V9-42 | P1 | Shrink and restore visual viewport to emulate Safari address/bottom toolbar expansion and collapse. | Layout recomputes on every change; bottom buttons stay reachable and page remains unscrolled. | PASS — simulated 844×343 and keyboard shrink; physical toolbar TO VALIDATE |
| V9-43 | P1 | Inspect left/right/top/bottom bounds at compact sizes with safe-area emulation. | Interactive controls respect reasonable safe-area padding and do not sit under notch, corners, or home/browser UI. | PASS — source/CSS `env()` path; non-zero real inset TO VALIDATE |
| V9-44 | P1 | Load at portrait dimensions. | Only rotate prompt is active; compiler is not stretched into a tall interactive layout. | PASS — 390×844 |
| V9-45 | P1 | Verify portrait prompt content and icon. | Both required language lines and a clear rotate-phone icon are visible. | PASS — screenshot visual check |
| V9-46 | P1 | Perform landscape→portrait→landscape three cycles, including resize and orientation events. | Overlay shows/hides automatically each cycle; no refresh, stale blocker, scroll, or lost controls. | PASS — Chromium/WebKit, three cycles |
| V9-47 | P1 | Resize a landscape session while interacting with canvas/input. | Layout transition does not synthesize button presses, corrupt strokes, or leave touch capture active. | PASS — focus/resize/restore and subsequent full flow |
| V9-48 | P2 | Trigger normal status/toast changes at all compact sizes. | Status remains a toast/single line and does not cover canvas, input, selectors, or actions. | PASS — screenshot visual check |

### 5.5 End-to-end attack, browser, deployment, and desktop regression

| ID | Priority | Procedure | Expected result | Status |
|---|---|---|---|---|
| V9-49 | P1 | For each pattern: select, LOAD IDEA, draw, COMPILE, enter fight, attack the appropriate target. | `WeaponSpec.attack_pattern` matches selection and all five attacks execute distinctly. | PASS — Chromium/WebKit, all five runtime-valid |
| V9-50 | P1 | For each pattern, BACK from fight and compile a different pattern. | Return path works; selector, input, canvas, and actions remain usable; next spec is correct. | PASS — Chromium/WebKit |
| V9-51 | P1 | Run Chromium touch regression with console capture. | Required automated cases pass; no new error or relevant warning appears. | PASS — Chromium 150.0.7871.116, 0 serious console |
| V9-52 | P1 | Run Playwright WebKit/Safari path with console capture. | Required automatable cases pass; no application error or touch/layout lock appears. Platform WebGL noise, if any, is separated from app defects with evidence. | PASS WITH KNOWN LIMITATION — WebKit 26.5, 0 app console; Windows WebGL noise only |
| V9-53 | P1 | Run desktop 1280×720 mouse/keyboard regression through compiler and fight. | Desktop is usable; layout is not incorrectly compact; drawing, input, selector, RESET, compile, fight, and BACK work. | PASS — mouse/keyboard piercing E2E + geometry |
| V9-54 | P1 | Run repository tests, Godot import/parse, Web build, and browser suites from a clean output. | All required commands return success and logs identify tested commit/build. | PASS — Godot 4.7.1, 32 matrix/447 assertions, builds/browser green |
| V9-55 | P1 | Deploy a new public build; inspect HTML/JS/WASM/resources and repeat smoke flow from public URL. | HTTP succeeds, assets have a new deploy/version hash rather than query-only cache busting, console is clean, and public flow is usable. | TO VALIDATE — new public deployment not yet made by integrator |

## 6. Mandatory 20-case mapping

This table prevents the required product-owner sequence from being lost inside the larger matrix.

| Required step | Requirement | Covered by |
|---|---|---|
| U01 | LOAD shows description | V9-01, V9-02 |
| U02 | `×` clears | V9-03, V9-12 |
| U03 | Input focuses | V9-05, V9-08 |
| U04 | Status updates after typing | V9-06 |
| U05 | Delete works | V9-07 |
| U06 | RESET clears drawing and description | V9-17 |
| U07 | Pattern is unchanged by RESET | V9-18 |
| U08 | Redraw works | V9-20 |
| U09 | Retype works | V9-21 |
| U10 | Keyboard toggle/layout restore | V9-09, V9-10, V9-11 |
| U11 | Continuous pattern switching | V9-30 |
| U12 | Compile and attack all five patterns | V9-49 |
| U13 | BACK then re-enter input | V9-34, V9-50 |
| U14 | 844×390 | V9-35 |
| U15 | 852×393 | V9-36 |
| U16 | 915×412 | V9-37 |
| U17 | Safari toolbar height changes | V9-42 |
| U18 | Landscape→portrait→landscape three times | V9-46 |
| U19 | No new console errors | V9-51, V9-52, V9-55 |
| U20 | Desktop has no regression | V9-53 |

## 7. Execution matrix and evidence to retain

| Environment | Viewport/device | Purpose | Gate owner |
|---|---|---|---|
| Chromium touch emulation | 844×390, 852×393, 915×412 | Touch targets, geometry, state transitions, console, full flow | QA |
| Playwright WebKit | Same compact sizes plus portrait | Safari engine path, orientation/resize, console, full flow | QA |
| WebKit iPhone profile | Landscape visual viewport near 734×343 when browser chrome is expanded | Severe usable-height and toolbar recovery stress | QA; physical behavior remains TO VALIDATE |
| Chromium desktop | 1280×720 | Desktop regression | QA |
| Physical iPhone Safari | Product-owner device, portrait and landscape with real browser chrome/keyboard | Real multi-touch, iOS keyboard, safe areas, toolbar, orientation recovery | Product owner |

### 7.1 Executed results

- `./scripts/test.ps1`: PASS with Godot 4.7.1 import/parse, main-scene runtime smoke, 32 deterministic matrix cases, 447 assertions and 0 failures; static worker 3/3 and WASM loader 1/1 passed.
- `./scripts/build_web.ps1`: PASS; `index.html`, JS, WASM and PCK were present and `viewport-fit=cover` was injected.
- `./scripts/build_sites_preview.ps1`: PASS; local Sites preview bundle created.
- Local HTTP smoke: root, JS, WASM and PCK each returned 200 with correct MIME, `Cache-Control: no-store`, COOP `same-origin`, and COEP `require-corp`.
- Chromium 150.0.7871.116: PASS for description focus/edit/delete/`×`, RESET, 30 selector switches, three orientation cycles, toolbar shrink/restore, five compiler/attack flows, BACK/REFORGE, desktop mouse/keyboard E2E, and 0 serious console messages.
- Playwright WebKit 26.5: PASS for the corresponding automatable mobile flows, with 0 captured application errors or warnings.

Compact measurements:

| CSS viewport | Canvas CSS height | Touch-row CSS height | Document scroll |
|---|---:|---:|---|
| 844×390 | 194.08 px | 46.03 px | none |
| 852×393 | 195.59 px | 46.39 px | none |
| 915×412 | 214.88 px | 46.34 px | none |
| 844×343 toolbar stress | 154.73 px | 44.30 px | none |

All five browser compile audits were runtime-valid and matched `melee_slash`, `straight_projectile`, `boomerang`, `area_blast`, and `piercing` respectively in Chromium and WebKit.

Local build SHA-256 values:

| Asset | SHA-256 |
|---|---|
| `index.html` | `D5ABD1FCBE78B2F231D34FEB63179F818F2111E5F2E98D91AC456D9458B2F39E` |
| `index.js` | `68586D6DAAFC93C6E697B3FB258976874AA7459B8931165EBB1DC3C9614CC42C` |
| `index.wasm` | `35116F68540AC41ACF7D71EA457ADDED91B5E960A9CCA3E2ACC72918EAF01277` |
| `index.pck` | `5521C0D9B2837D3FD479F7485842CFE98B65C46A7FED8D521B1173898079273D` |

QA screenshots are in ignored output `output/playwright/v9/`, including the three target landscape sizes, 844×343 toolbar stress, description focus/clear, RESET confirmation, 390×844 rotate prompt, desktop 1280×720, and WebKit evidence.

## 8. Risk register

| Risk | Severity if observed | Detection/containment | Status |
|---|---|---|---|
| Native or engine text input fails to summon/synchronize with iOS keyboard | P1 | Physical-device gate; compare UI text with compiled audit/spec | TO VALIDATE |
| `visualViewport` and canvas coordinates diverge after keyboard or toolbar resize | P1 | Repeated shrink/restore, bounding-box capture, edge drawing tests | PASS in simulation; physical TO VALIDATE |
| Engine logical 720-height scaling makes CSS targets smaller than required | P1 | Measure browser CSS rectangles at every compact viewport | CLOSED — measured 44.30–46.39 px |
| Independent `×` visually meets size but has a smaller/overlapping hit region | P1 | Inside/outside boundary taps and runtime rectangle inspection | CLOSED — 46.03×46.03 px, boundary/drag passed |
| RESET clears visuals but leaves stale compiler/example state | P1 | Reset→retype/load→compile audit comparison | CLOSED |
| Transparent Control or orientation layer remains after resize | P0 | Repeated orientation/toolbar cycles followed by complete interaction sweep | CLOSED in Chromium/WebKit; physical TO VALIDATE |
| Single-row selector text truncates or targets overlap at 844 px | P1 | Exact-label and rectangle overlap assertions | CLOSED |
| Safari cache serves prior WASM/JS despite a new query string | P1 | Require new resource/deployment hash and inspect public responses | TO VALIDATE — public V9 not deployed yet |
| Automated WebKit reports platform WebGL limitations unrelated to app logic | P2 | Preserve logs and distinguish platform startup noise from application regressions | KNOWN LIMITATION — 16 `glBlitFramebuffer` errors plus one `WEBGL_polygon_mode` warning in Windows emulator; no app script error |
| Compact rules leak into desktop layout | P1 | 1280×720 end-to-end regression | CLOSED |

## 9. Verification commands

The repository-prescribed commands were executed successfully:

```powershell
./scripts/test.ps1
./scripts/build_web.ps1
./scripts/build_sites_preview.ps1
```

The repository V9 Chromium and WebKit scripts were executed without modification through Playwright CLI sessions against the freshly exported local build. QA generated only ignored output and edited only this report.

## 10. Current conclusion

Implementation `0dcc4a6` passed the independent automatable V9 regression. No P0 or P1 defect was found. The Windows WebKit GPU black-frame/`glBlitFramebuffer` behavior is a known emulator limitation and is not an application-script blocker because DOM synchronization, compiler audits, navigation, and all five attack flows completed, while the script listener captured 0 application errors/warnings.

`TO VALIDATE` remains for the new public deployment and resource hash, real iOS keyboard presentation and dismissal, non-zero safe-area insets, Safari toolbar behavior, and repeated orientation/touch recovery on the product owner's physical iPhone. These are acceptance gates, not reasons to block deploying the V9 candidate for device testing.

**Decision: `PASS WITH KNOWN LIMITATIONS / NO P0/P1 / OK TO DEPLOY FOR DEVICE ACCEPTANCE`.**
