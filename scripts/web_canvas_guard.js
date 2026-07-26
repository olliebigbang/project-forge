(() => {
  if (window.__forgeViewportController) return;

  const KEYBOARD_MIN_DROP = 96;
  const KEYBOARD_DROP_RATIO = 0.22;
  const RESTORE_RATIO = 0.78;
  const state = {
    stable: null,
    override: null,
    textEntryArmed: false,
    keyboardOpen: false,
    closing: false,
    frame: 0,
    revision: 0,
  };

  const safeNumber = (value, fallback = 0) =>
    Number.isFinite(Number(value)) ? Number(value) : fallback;

  const liveViewport = () => {
    const viewport = window.visualViewport;
    return {
      width: safeNumber(viewport?.width, window.innerWidth),
      height: safeNumber(viewport?.height, window.innerHeight),
      offsetLeft: safeNumber(viewport?.offsetLeft, 0),
      offsetTop: safeNumber(viewport?.offsetTop, 0),
      scale: safeNumber(viewport?.scale, 1),
      innerWidth: safeNumber(window.innerWidth, 0),
      innerHeight: safeNumber(window.innerHeight, 0),
    };
  };

  const viewport = () => ({ ...liveViewport(), ...(state.override || {}) });
  const isLandscape = (value) => value.width > value.height;
  const inputFocused = () =>
    document.activeElement?.id === "forge-description-input";

  const keyboardDrop = (value) => {
    if (!state.stable || !isLandscape(value)) return false;
    const threshold = Math.max(
      KEYBOARD_MIN_DROP,
      state.stable.height * KEYBOARD_DROP_RATIO,
    );
    return state.stable.height - value.height >= threshold;
  };

  const canvasElement = () =>
    document.getElementById("canvas") || document.querySelector("canvas");

  const applyDocumentShell = () => {
    const shared = {
      margin: "0",
      padding: "0",
      width: "100%",
      height: "100%",
      overflow: "hidden",
      overscrollBehavior: "none",
      background: "#000",
    };
    Object.assign(document.documentElement.style, shared);
    Object.assign(document.body.style, shared, {
      position: "fixed",
      inset: "0",
      touchAction: "none",
    });
  };

  const applyCanvas = (target) => {
    const canvas = canvasElement();
    if (!canvas || !target) return;
    const pixelRatio = Math.max(safeNumber(window.devicePixelRatio, 1), 1);
    const cssWidth = Math.max(Math.round(target.width), 1);
    const cssHeight = Math.max(Math.round(target.height), 1);
    const backingWidth = Math.max(Math.round(cssWidth * pixelRatio), 1);
    const backingHeight = Math.max(Math.round(cssHeight * pixelRatio), 1);
    Object.assign(canvas.style, {
      position: "fixed",
      display: "block",
      left: `${safeNumber(target.offsetLeft, 0)}px`,
      top: `${safeNumber(target.offsetTop, 0)}px`,
      width: `${cssWidth}px`,
      height: `${cssHeight}px`,
      maxWidth: "none",
      maxHeight: "none",
      visibility: "visible",
      opacity: "1",
      transform: "none",
    });
    if (canvas.width !== backingWidth) canvas.width = backingWidth;
    if (canvas.height !== backingHeight) canvas.height = backingHeight;
  };

  const refresh = () => {
    state.frame = 0;
    applyDocumentShell();
    const current = viewport();

    // A true orientation change wins over keyboard freezing. This allows Godot
    // to show its portrait gate and prevents a stale landscape canvas.
    if (!isLandscape(current)) {
      state.textEntryArmed = false;
      state.keyboardOpen = false;
      state.closing = false;
      state.stable = { ...current };
      document.body.dataset.forgeTextEntry = "off";
      applyCanvas(current);
      state.revision += 1;
      return;
    }

    const focused = inputFocused();
    state.keyboardOpen = Boolean((state.textEntryArmed || focused) && keyboardDrop(current));

    if (state.closing && state.stable) {
      const restored = current.height >= state.stable.height * RESTORE_RATIO;
      if (restored) state.closing = false;
    }

    // Recompute after the closing transition. Safari can restore the keyboard
    // and browser chrome in the same visualViewport frame without emitting a
    // later resize. Reusing the pre-transition value leaves the Canvas frozen
    // at the old height and exposes a permanent black strip below it.
    const entryActive = state.textEntryArmed || focused || state.closing;
    const keepStable = entryActive && state.stable && isLandscape(state.stable);
    if (!keepStable) state.stable = { ...current };
    const canvasViewport = keepStable ? state.stable : current;
    document.body.dataset.forgeTextEntry = entryActive ? "on" : "off";
    applyCanvas(canvasViewport);
    if (entryActive) window.scrollTo(0, 0);
    state.revision += 1;
  };

  const schedule = () => {
    cancelAnimationFrame(state.frame);
    state.frame = requestAnimationFrame(refresh);
  };

  const armTextEntry = () => {
    const current = viewport();
    if (isLandscape(current) && !keyboardDrop(current)) state.stable = { ...current };
    state.closing = false;
  };

  const beginTextEntry = () => {
    armTextEntry();
    state.textEntryArmed = true;
    schedule();
  };

  const endTextEntry = () => {
    state.textEntryArmed = false;
    state.keyboardOpen = false;
    state.closing = true;
    schedule();
    // Safari restores visualViewport over several animation frames.
    let checks = 0;
    const settle = () => {
      refresh();
      checks += 1;
      if (state.closing && checks < 90) requestAnimationFrame(settle);
    };
    requestAnimationFrame(settle);
  };

  const metrics = () => {
    const current = viewport();
    const canvas = canvasElement();
    const rect = canvas?.getBoundingClientRect();
    const entryActive = state.textEntryArmed || inputFocused() || state.closing;
    return {
      ...current,
      stableWidth: state.stable?.width || current.width,
      stableHeight: state.stable?.height || current.height,
      layoutWidth: entryActive ? state.stable?.width || current.width : current.width,
      layoutHeight: entryActive ? state.stable?.height || current.height : current.height,
      textEntryActive: Boolean(entryActive),
      keyboardOpen: Boolean(state.keyboardOpen),
      inputFocused: inputFocused(),
      closing: Boolean(state.closing),
      revision: state.revision,
      canvasRect: rect
        ? { x: rect.x, y: rect.y, width: rect.width, height: rect.height }
        : null,
      canvasBackingWidth: canvas?.width || 0,
      canvasBackingHeight: canvas?.height || 0,
      pageScrollX: window.scrollX,
      pageScrollY: window.scrollY,
    };
  };

  window.__forgeViewportController = {
    armTextEntry,
    beginTextEntry,
    endTextEntry,
    metrics,
    refresh,
    setQaViewportOverride: (value) => {
      const qaEnabled = new URLSearchParams(window.location.search).get("qa") === "m1b1";
      if (!qaEnabled) return false;
      state.override = value && typeof value === "object" ? { ...value } : null;
      schedule();
      return true;
    },
    clearQaViewportOverride: () => {
      state.override = null;
      schedule();
    },
  };

  window.addEventListener("orientationchange", schedule, { passive: true });
  window.addEventListener("resize", schedule, { passive: true });
  window.visualViewport?.addEventListener("resize", schedule, { passive: true });
  window.visualViewport?.addEventListener("scroll", schedule, { passive: true });
  applyDocumentShell();
  refresh();
})();
