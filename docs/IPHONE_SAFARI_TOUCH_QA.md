# iPhone Safari Touch and Layout QA / Red-Team Report

Document state: **Baseline reproduced; fix regression pending**  
Prepared on: 2026-07-19  
QA branch: `codex/qa/iphone-safari-touch-layout`  
Baseline runtime revision: `214aa14` (public v7; QA worktree base `f65a7a3`)

## 1. Scope and independence

- **CONFIRMED** M1B, paid AI integration, production art, and every unrelated new
  feature remain paused until this gate is closed.
- **CONFIRMED** QA may edit only this report. It does not modify Godot scenes,
  runtime scripts, build scripts, or the integration branch.
- **CONFIRMED** The five attack-pattern controls are M1A compiler test tools. They
  belong only on the drawing/forging screen, are mutually exclusive, and default
  to `melee_slash`.
- **CONFIRMED** A physical iPhone Safari failure is authoritative. Browser
  emulation is supporting evidence and cannot close the physical-device gate.
- **CONFIRMED** Portrait must show a reversible rotate-to-landscape overlay rather
  than a stretched compiler. Landscape must keep drawing, description, all five
  pattern buttons, and all three forge actions visible.
- **TO VALIDATE** The final fix revision, final public deployment, asset hashes,
  browser versions, and all result fields below remain pending until the
  integration owner provides them.

## 2. Baseline blocker reproduction

Public baseline:
[Project Forge M1A v7](https://project-forge-weapon-lab.hongningliu0130.chatgpt.site/?qa=v7-final-214aa14)

### 2.1 Physical iPhone evidence supplied by the user

The supplied iPhone Safari photo shows all of the release-blocking symptoms:

1. The portrait viewport renders the entire compiler instead of a rotation
   prompt. The drawing panel expands vertically and compresses the controls into
   the bottom edge.
2. The `OptionButton` opens a five-row native Godot `PopupMenu`. Its rows are far
   below the required 48–56 CSS-pixel touch height.
3. The popup overlaps the forge action row and behaves modally. The user cannot
   select a row, dismiss it, or use BACK, CLEAR, LOAD IDEA, COMPILE WEAPON, or the
   drawing surface.
4. Safari's bottom toolbar sits immediately below the squeezed action row, so the
   old layout has no robust bottom safe margin.

Disposition: **P0 BLOCKER — M1A is not complete on real iPhone Safari.** The
previous report's physical-phone deferral is superseded by this direct evidence.

### 2.2 Independent browser reproduction

| Check | Baseline result |
| --- | --- |
| Public entry document | **PASS** — HTTPS HTTP 200, `text/html`, `Cache-Control: public, max-age=0, must-revalidate` |
| Chromium path | **FAIL / P0** — HeadlessChrome 150, 390×844, real CDP touch opened `PopupMenu`; touching CLEAR outside did not dismiss it or activate CLEAR |
| Chromium console | **PASS at baseline** — 0 errors, 0 warnings |
| WebKit path | **FAIL / P0** — Playwright WebKit 26.5, iPhone 15 profile, CSS 393×659 / DPR 3; touchscreen tap opened the same menu and tap on CLEAR left it open |
| WebKit console | **FAIL / P1 candidate** — 16 repeated `glBlitFramebuffer` `INVALID_OPERATION` messages and two warnings; must be triaged on the final build |
| Portrait presentation | **FAIL / P0** — no rotation overlay; canvas filled the portrait viewport and the compiler remained stretched |

The Chromium and WebKit failures match the user's physical screenshot. The fact
that all public resources load and the Godot frame keeps rendering isolates the
primary blocker to UI/input behavior rather than site availability.

## 3. Release gate

The fix cannot pass QA unless all of the following are true:

1. The old `OptionButton`/`PopupMenu` path is absent from the compiler screen.
2. Five permanently visible, non-modal, mutually exclusive touch buttons work in
   both directions and survive repeated switching and re-forging.
3. Every selected button drives both LOAD IDEA and the final
   `WeaponSpec.attack_pattern`.
4. Drawing consumes input only inside its own rectangle. Visual controls and
   containers do not create invisible full-screen interception.
5. Portrait shows a bilingual rotate overlay, then automatically returns to the
   live game after landscape rotation without reload.
6. All required controls remain visible at 844×390, 852×393, and 915×412 with
   safe bottom/side margins and no scrolling, clipping, or overlap.
7. Godot import/parse, deterministic tests, runtime smoke, Web export, Chromium
   touch, WebKit touch, network, console, and final public-asset hash checks pass.
8. The user completes the physical iPhone Safari acceptance. Automation alone
   cannot change the final state from **TO VALIDATE** to **CONFIRMED**.

## 4. Touch and orientation regression matrix

The matrix contains 44 independently reportable checks. `PENDING` means it must
be executed on the supplied fix SHA and then again on the final public URL.

| ID | Area | Procedure | Required oracle | Baseline / current result |
| --- | --- | --- | --- | --- |
| IOS-01 | Default | Enter compiler from a clean load | MELEE SLASH is the only selected mode | **PENDING** |
| IOS-02 | Exclusivity | Tap each mode and inspect all five states | Exactly one mode selected at every step | **PENDING** |
| IOS-03 | Mode | Touch MELEE SLASH | Stable `pressed`; strong fill, border, text contrast, and check mark | **FAIL** — old dropdown |
| IOS-04 | Mode | Touch STRAIGHT PROJECTILE | Stable selection; no popup/modal | **FAIL** — old dropdown |
| IOS-05 | Mode | Touch BOOMERANG | Stable selection; no popup/modal | **FAIL** — old dropdown |
| IOS-06 | Mode | Touch AREA BLAST | Stable selection; no popup/modal | **FAIL** — old dropdown |
| IOS-07 | Mode | Touch PIERCING | Stable selection; no popup/modal | **FAIL** — old dropdown |
| IOS-08 | Sequence | Tap modes 1→2→3→4→5 | Five selections succeed with one active state each | **PENDING** |
| IOS-09 | Sequence | Tap modes 5→4→3→2→1 | Reverse sequence succeeds with one active state each | **PENDING** |
| IOS-10 | Stress | Alternate all modes for at least 20 releases | 20/20 accepted; no lock, duplicate, or lost release | **PENDING** |
| IOS-11 | Outside tap | Tap blank space after switching | Page remains interactive; no modal state exists | **FAIL / P0** — baseline popup remains open |
| IOS-12 | Target size | Measure each effective hit rectangle | Height 48–56 CSS px or greater; gaps avoid adjacent activation | **PENDING** |
| IOS-13 | Hover independence | Select using touch with no pointer hover | Selected state is fully legible without hover | **PENDING** |
| IOS-14 | LOAD IDEA | For each selected mode, press LOAD IDEA | Description matches that mode's deterministic example | **PENDING** |
| IOS-15 | Compile | For each mode, LOAD IDEA then COMPILE WEAPON | Result has the selected `WeaponSpec.attack_pattern` | **PENDING** |
| IOS-16 | Combat | Compile and attack once for each of five modes | All enter combat and execute their distinct attack behavior | **PENDING** |
| IOS-17 | Return | From combat press REFORGE/BACK, then change mode | Compiler returns live; switching and compiling still work | **PENDING** |
| IOS-18 | Scope | Inspect combat screen after every compile | Pattern-selection buttons never appear in combat | **PENDING** |
| IOS-19 | Canvas input | Draw one finger stroke wholly inside canvas | Stroke follows touch and is retained | **PENDING** |
| IOS-20 | Canvas boundary | Begin/end just inside each canvas edge | Only in-rectangle points are consumed; no page lock | **PENDING** |
| IOS-21 | Canvas isolation | Tap pattern/action controls outside canvas | Drawing handler does not consume or duplicate the tap | **PENDING** |
| IOS-22 | Drawing adjacency | Draw near the bottom canvas edge | No neighboring pattern button activates | **PENDING** |
| IOS-23 | CLEAR | Draw, press CLEAR, repeat three times | Canvas clears every time; all other controls remain live | **PENDING** |
| IOS-24 | LOAD IDEA | Press LOAD IDEA repeatedly with each mode | Always responds once per release; correct text remains visible | **PENDING** |
| IOS-25 | COMPILE | Press once after a valid idea/drawing | Exactly one compile; enters combat; no duplicate event | **PENDING** |
| IOS-26 | BACK | Press BACK before compile and after returning from combat | Always responds; no invisible overlay intercepts it | **PENDING** |
| IOS-27 | Text keyboard | Tap description, type, dismiss iOS keyboard | Keyboard opens/closes and text remains editable | **TO VALIDATE — physical iPhone** |
| IOS-28 | Keyboard recovery | Close keyboard and re-check all forge controls | Layout restores with no overlap or permanent resize | **TO VALIDATE — physical iPhone** |
| IOS-29 | Portrait | Load at width < height | Bilingual rotate overlay and rotation icon appear | **FAIL / P0** — stretched compiler shown |
| IOS-30 | Portrait concealment | While portrait overlay is shown | Compiler and controls are not visible/interactable behind it | **FAIL / P0** |
| IOS-31 | Rotate recovery | Rotate portrait→landscape without reload | Overlay automatically closes and compiler is live | **PENDING** |
| IOS-32 | Rotate repeat | landscape→portrait→landscape, three cycles | Overlay toggles every cycle; no lock, stale touch, or duplicate input | **PENDING** |
| IOS-33 | Layout | Use 844×390 landscape viewport | Drawing, text, 5 modes, 3 actions all visible; no scroll/crop/overlap | **PENDING** |
| IOS-34 | Layout | Use 852×393 landscape viewport | Same complete visibility and touch-target requirements | **PENDING** |
| IOS-35 | Layout | Use 915×412 landscape viewport | Same complete visibility and touch-target requirements | **PENDING** |
| IOS-36 | Safe area | Emulate left/right notch and rounded-corner insets | Interactive content stays inside safe margins | **PENDING** |
| IOS-37 | Safari chrome | Exercise expanded/collapsed top and bottom toolbars | Bottom actions remain reachable and padded; no page scroll | **TO VALIDATE — physical iPhone** |
| IOS-38 | Chromium | Run full touch flow in a fresh Chromium context | 1→5→1 switching, draw, load, compile, attack, reforge pass | **PENDING** |
| IOS-39 | WebKit | Run the same flow in Playwright WebKit iPhone profile | Functional parity; no popup lock or input interception | **PENDING** |
| IOS-40 | Console | Cold load through rotation, five compiles, attacks, reforge | 0 uncaught errors; warnings documented and triaged | **FAIL / P1 candidate** on baseline WebKit |
| IOS-41 | Network | Inspect HTML, JS, PCK, WASM parts, worker, icon | Every required response 2xx; no mixed content or missing asset | **PENDING final deployment** |
| IOS-42 | Versioning | Compare final local/public PCK and versioned boot assets | New filenames or content hashes; exact public/local hash match | **PENDING final deployment** |
| IOS-43 | Cache | Cold load, normal reload, and cache-warm reopen | All three load the same fix revision; no stale JS/PCK/WASM mix | **PENDING final deployment** |
| IOS-44 | Physical gate | User repeats the reported flow on real iPhone Safari | Can select, switch, dismiss/leave, rotate, and continue without lock | **TO VALIDATE — user-owned final gate** |

## 5. Five-mode functional oracle

| Button | LOAD IDEA must identify | Compiled value | Minimum combat proof |
| --- | --- | --- | --- |
| MELEE SLASH | close/heavy slash example | `melee_slash` | Visible close arc; close target can be hit |
| STRAIGHT PROJECTILE | straight ranged example | `straight_projectile` | Visible finite straight shot |
| BOOMERANG | returning weapon example | `boomerang` | Visible outbound and return phases |
| AREA BLAST | radial/explosive example | `area_blast` | Visible bounded area and group hit |
| PIERCING | line/piercing example | `piercing` | Continues through a bounded aligned set |

Changing the button changes both the loaded text and the compiler hint. It must
not merely recolor UI while allowing keywords from the prior idea to select a
different pattern. Re-forging must not retain the previous button's pattern when
a new button is selected.

## 6. Input interception inspection oracle

The integration diff and runtime node tree will be reviewed for these invariants:

- Drawing Canvas accepts drawing input only when the touch position is inside its
  own visible rectangle and must not own a full-screen `_unhandled_input` path.
- Purely visual Controls use `MOUSE_FILTER_IGNORE`; pass-through layout Controls
  use `MOUSE_FILTER_PASS`; only actionable widgets stop the relevant event.
- There is no transparent full-screen Control or popup remaining after rotation,
  BACK, compile, or re-forge.
- Five selection buttons emit their normal `pressed` signal on release and share
  one `ButtonGroup` or equivalent exclusive state owner.
- The portrait overlay is the only deliberate full-viewport interceptor. Its
  visibility follows current orientation and can never remain visible in
  landscape or require reload.

## 7. Severity and handoff rules

| Severity | This gate's examples | Disposition |
| --- | --- | --- |
| **P0 Blocker** | Any real/emulated touch lock; pattern cannot be selected; portrait compiler shown instead of overlay; core control clipped/unreachable | Stop deployment/M1B; return to integration owner |
| **P1 Major** | Wrong LOAD IDEA/spec mapping; nonexclusive states; drawing intercepts outside; rotation recovery fails; repeatable WebKit errors not proven harmless | Fix and rerun affected cases plus full smoke |
| **P2 Moderate** | Bounded safe-margin or visual-state defect with an accessible workaround | Record, fix before declaring this mobile gate closed |
| **P3 Minor** | Cosmetic wording/alignment outside hit targets and safe areas | Record; may remain with explicit approval |

The QA branch and worktree must remain intact. This report will be updated after
the main agent supplies the integration fix SHA, and again after the final public
deployment. Even if every automated row passes, final disposition remains
**WAITING FOR PHYSICAL IPHONE SAFARI ACCEPTANCE** until the user confirms IOS-44.

## 8. Current disposition

**FAIL — P0 BLOCKER REPRODUCED.**

Do not mark M1A complete, merge a stable release, clean this branch/worktree, or
start M1B until the five-button, touch-isolation, portrait-overlay, landscape
safe-area, Chromium, WebKit, and final public deployment regressions pass and the
user accepts the build on a physical iPhone Safari device.
