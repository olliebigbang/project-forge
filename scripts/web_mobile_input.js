(() => {
  if (window.__forgeInstallMobileInput) return;

  window.__forgeInstallMobileInput = () => {
    if (window.__forgeMobileInput) return;

    const INPUT_ID = "forge-description-input";
    const ROOT_ID = "forge-description-native";
    const CLEAR_ID = "forge-description-clear";
    const DONE_ID = "forge-description-done";
    let revision = 0;
    let composing = false;
    let lastLayout = null;
    let viewportFrame = 0;

    const root = document.createElement("div");
    root.id = ROOT_ID;
    root.setAttribute("data-forge-native-input", "true");
    Object.assign(root.style, {
      position: "fixed",
      display: "none",
      alignItems: "stretch",
      gap: "6px",
      zIndex: "1000",
      pointerEvents: "auto",
      boxSizing: "border-box",
    });

    const input = document.createElement("input");
    input.id = INPUT_ID;
    input.type = "text";
    input.maxLength = 512;
    input.placeholder = "Describe your weapon";
    input.autocomplete = "off";
    input.autocapitalize = "sentences";
    input.spellcheck = true;
    input.setAttribute("enterkeyhint", "done");
    input.setAttribute("aria-label", "Weapon description");
    Object.assign(input.style, {
      minWidth: "0",
      flex: "1 1 auto",
      height: "100%",
      padding: "0 12px",
      border: "2px solid #5578a4",
      borderRadius: "7px",
      outline: "none",
      background: "#101721",
      color: "#edf4ff",
      caretColor: "#65d9ff",
      font: "600 16px system-ui, -apple-system, sans-serif",
      boxSizing: "border-box",
      touchAction: "manipulation",
      WebkitUserSelect: "text",
      userSelect: "text",
    });

    const makeButton = (id, text, label, width, border, background) => {
      const button = document.createElement("button");
      button.id = id;
      button.type = "button";
      button.textContent = text;
      button.setAttribute("aria-label", label);
      Object.assign(button.style, {
        flex: `0 0 ${width}px`,
        height: "100%",
        minWidth: `${width}px`,
        padding: "0 8px",
        border: `2px solid ${border}`,
        borderRadius: "7px",
        background,
        color: "#edf4ff",
        font: "700 16px system-ui, -apple-system, sans-serif",
        boxSizing: "border-box",
        touchAction: "manipulation",
        cursor: "pointer",
      });
      return button;
    };

    const clear = makeButton(
      CLEAR_ID,
      String.fromCharCode(215),
      "Clear description",
      44,
      "#65d9ff",
      "#1a3150",
    );
    clear.style.fontSize = "25px";
    const done = makeButton(
      DONE_ID,
      "DONE",
      "Finish editing description",
      64,
      "#78eea6",
      "#17382f",
    );
    done.style.display = "none";

    root.append(input, clear, done);
    document.body.appendChild(root);

    let safeProbe = document.getElementById("forge-safe-area-probe");
    if (!safeProbe) {
      safeProbe = document.createElement("div");
      safeProbe.id = "forge-safe-area-probe";
      Object.assign(safeProbe.style, {
        position: "fixed",
        visibility: "hidden",
        pointerEvents: "none",
        paddingTop: "env(safe-area-inset-top)",
        paddingRight: "env(safe-area-inset-right)",
        paddingBottom: "env(safe-area-inset-bottom)",
        paddingLeft: "env(safe-area-inset-left)",
      });
      document.body.appendChild(safeProbe);
    }

    const emitDescription = (kind, bump = false) => {
      if (bump) revision += 1;
      input.dataset.forgeRevision = String(revision);
      window.__forgeGodotDescriptionCallback?.(
        kind,
        input.value,
        revision,
        composing,
      );
    };

    const metrics = () => {
      const viewport = window.visualViewport;
      const guarded = window.__forgeViewportController?.metrics?.() || {};
      const safe = getComputedStyle(safeProbe);
      return {
        width: guarded.width ?? viewport?.width ?? window.innerWidth,
        height: guarded.height ?? viewport?.height ?? window.innerHeight,
        offsetLeft: guarded.offsetLeft ?? viewport?.offsetLeft ?? 0,
        offsetTop: guarded.offsetTop ?? viewport?.offsetTop ?? 0,
        scale: guarded.scale ?? viewport?.scale ?? 1,
        innerWidth: guarded.innerWidth ?? window.innerWidth,
        innerHeight: guarded.innerHeight ?? window.innerHeight,
        layoutWidth: guarded.layoutWidth ?? viewport?.width ?? window.innerWidth,
        layoutHeight: guarded.layoutHeight ?? viewport?.height ?? window.innerHeight,
        stableWidth: guarded.stableWidth ?? viewport?.width ?? window.innerWidth,
        stableHeight: guarded.stableHeight ?? viewport?.height ?? window.innerHeight,
        textEntryActive: Boolean(guarded.textEntryActive),
        keyboardOpen: Boolean(guarded.keyboardOpen),
        safeTop: parseFloat(safe.paddingTop) || 0,
        safeRight: parseFloat(safe.paddingRight) || 0,
        safeBottom: parseFloat(safe.paddingBottom) || 0,
        safeLeft: parseFloat(safe.paddingLeft) || 0,
        inputFocused: document.activeElement === input,
        canvasRect: guarded.canvasRect || null,
        canvasBackingWidth: guarded.canvasBackingWidth || 0,
        canvasBackingHeight: guarded.canvasBackingHeight || 0,
        pageScrollX: guarded.pageScrollX || 0,
        pageScrollY: guarded.pageScrollY || 0,
      };
    };

    const updateLayout = (layout) => {
      lastLayout = layout;
      const canvas = document.getElementById("canvas") || document.querySelector("canvas");
      if (!canvas || !layout?.visible) {
        root.style.display = "none";
        return;
      }

      const viewportMetrics = metrics();
      if (viewportMetrics.textEntryActive && viewportMetrics.width > viewportMetrics.height) {
        const outer = 6;
        const left = viewportMetrics.offsetLeft + viewportMetrics.safeLeft + outer;
        const top = viewportMetrics.offsetTop + viewportMetrics.safeTop + outer;
        const width = Math.max(
          viewportMetrics.width - viewportMetrics.safeLeft - viewportMetrics.safeRight - outer * 2,
          280,
        );
        Object.assign(root.style, {
          position: "fixed",
          left: `${left}px`,
          top: `${top}px`,
          width: `${width}px`,
          height: "52px",
          padding: "4px",
          display: "flex",
          alignItems: "center",
          gap: "6px",
          borderRadius: "9px",
          background: "rgba(9, 20, 36, 0.96)",
          boxShadow: "0 2px 14px rgba(0, 0, 0, 0.55)",
        });
        input.style.height = "44px";
        clear.style.width = "44px";
        clear.style.height = "44px";
        done.style.display = "block";
        done.style.height = "44px";
        return;
      }

      const canvasRect = canvas.getBoundingClientRect();
      const scaleX = canvasRect.width / Math.max(layout.logicalWidth, 1);
      const scaleY = canvasRect.height / Math.max(layout.logicalHeight, 1);
      Object.assign(root.style, {
        position: "fixed",
        left: `${canvasRect.left + layout.x * scaleX}px`,
        top: `${canvasRect.top + layout.y * scaleY}px`,
        width: `${layout.width * scaleX}px`,
        height: `${layout.height * scaleY}px`,
        padding: "0",
        display: "flex",
        alignItems: "stretch",
        gap: "6px",
        borderRadius: "0",
        background: "transparent",
        boxShadow: "none",
      });
      input.style.height = "100%";
      clear.style.width = `${Math.max(44, layout.height * scaleY)}px`;
      clear.style.height = "100%";
      done.style.display = "none";
    };

    const notifyViewport = () => {
      cancelAnimationFrame(viewportFrame);
      viewportFrame = requestAnimationFrame(() => {
        if (lastLayout) updateLayout(lastLayout);
        window.__forgeGodotViewportCallback?.("viewport");
      });
    };

    input.addEventListener(
      "pointerdown",
      () => window.__forgeViewportController?.beginTextEntry(),
      { passive: true },
    );
    input.addEventListener("focus", () => {
      window.__forgeViewportController?.beginTextEntry();
      input.style.borderColor = "#65d9ff";
      emitDescription("focus");
      notifyViewport();
    });
    input.addEventListener("blur", () => {
      input.style.borderColor = "#5578a4";
      if (composing) {
        composing = false;
        emitDescription("compositionend", true);
      }
      emitDescription("blur");
      window.__forgeViewportController?.endTextEntry();
      notifyViewport();
    });
    input.addEventListener("input", () => emitDescription("input", true));
    input.addEventListener("change", () => emitDescription("change", true));
    input.addEventListener("compositionstart", () => {
      composing = true;
      emitDescription("compositionstart");
    });
    input.addEventListener("compositionend", () => {
      composing = false;
      emitDescription("compositionend", true);
    });

    clear.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      input.value = "";
      emitDescription("clear", true);
      window.__forgeViewportController?.beginTextEntry();
      input.focus({ preventScroll: true });
    });
    done.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      input.blur();
    });

    const addPressFeedback = (button, normal, pressed) => {
      const press = () => {
        button.style.background = pressed.background;
        button.style.color = pressed.color;
      };
      const release = () => {
        button.style.background = normal.background;
        button.style.color = normal.color;
      };
      button.addEventListener("pointerdown", press, { passive: true });
      button.addEventListener("pointerup", release, { passive: true });
      button.addEventListener("pointercancel", release, { passive: true });
      button.addEventListener("blur", release, { passive: true });
    };
    addPressFeedback(
      clear,
      { background: "#1a3150", color: "#edf4ff" },
      { background: "#65d9ff", color: "#091424" },
    );
    addPressFeedback(
      done,
      { background: "#17382f", color: "#edf4ff" },
      { background: "#78eea6", color: "#091424" },
    );

    const elementRect = (element) => {
      const value = element?.getBoundingClientRect();
      return value
        ? { x: value.x, y: value.y, width: value.width, height: value.height }
        : null;
    };

    window.__forgeMobileInput = {
      metrics,
      updateLayout,
      setValue: (value) => {
        const next = String(value ?? "");
        if (input.value !== next) {
          input.value = next;
          emitDescription("programmatic", true);
        }
      },
      value: () => input.value,
      snapshot: () => ({
        value: input.value,
        revision,
        composing,
        connected: input.isConnected,
        focused: document.activeElement === input,
      }),
      focus: () => {
        window.__forgeViewportController?.beginTextEntry();
        input.focus({ preventScroll: true });
      },
      blur: () => input.blur(),
      clear: () => {
        input.value = "";
        emitDescription("clear", true);
      },
      commitForRequest: () => {
        input.blur();
        requestAnimationFrame(() => {
          if (composing) {
            composing = false;
            emitDescription("compositionend", true);
          }
          emitDescription("commit");
        });
      },
      qaSetViewportOverride: (value) => {
        const accepted = window.__forgeViewportController?.setQaViewportOverride(value) || false;
        notifyViewport();
        return accepted;
      },
      qaClearViewportOverride: () => {
        window.__forgeViewportController?.clearQaViewportOverride();
        notifyViewport();
      },
      qaSnapshot: () => ({
        metrics: metrics(),
        inputRect: elementRect(input),
        clearRect: elementRect(clear),
        doneRect: elementRect(done),
        rootRect: elementRect(root),
        inputFontSize: parseFloat(getComputedStyle(input).fontSize) || 0,
        inputValue: input.value,
        rootVisible: root.style.display !== "none",
        doneVisible: done.style.display !== "none",
      }),
    };

    const qaEnabled = new URLSearchParams(window.location.search).get("qa") === "m1b1";
    if (qaEnabled) {
      let latestState = {};
      let latestControls = {};
      const cssRect = (rect, logicalWidth, logicalHeight) => {
        if (!rect) return null;
        const canvas = document.getElementById("canvas") || document.querySelector("canvas");
        if (!canvas) return null;
        const box = canvas.getBoundingClientRect();
        const scaleX = box.width / Math.max(logicalWidth, 1);
        const scaleY = box.height / Math.max(logicalHeight, 1);
        return {
          x: box.left + rect.x * scaleX,
          y: box.top + rect.y * scaleY,
          width: rect.width * scaleX,
          height: rect.height * scaleY,
        };
      };
      window.__forgeM1B1Test = {
        state: () => structuredClone(latestState),
        controls: () => structuredClone(latestControls),
        setScenario: (name, options = {}) =>
          window.__forgeGodotQaCallback?.(
            "scenario",
            JSON.stringify({ name: String(name), options }),
          ),
        setDeveloperMode: (enabled) =>
          window.__forgeGodotQaCallback?.(
            "developer_mode",
            JSON.stringify({ enabled: Boolean(enabled) }),
          ),
        mobileInput: () => window.__forgeMobileInput.qaSnapshot(),
        setVisualViewport: (value) => window.__forgeMobileInput.qaSetViewportOverride(value),
        clearVisualViewport: () => window.__forgeMobileInput.qaClearViewportOverride(),
        _update: (payload) => {
          latestState = payload.state || {};
          latestControls = {};
          for (const [name, value] of Object.entries(payload.controls || {})) {
            latestControls[name] = Array.isArray(value)
              ? value.map((rect) => cssRect(rect, payload.logicalWidth, payload.logicalHeight))
              : cssRect(value, payload.logicalWidth, payload.logicalHeight);
          }
        },
      };
    }

    window.addEventListener("orientationchange", notifyViewport, { passive: true });
    window.addEventListener("resize", notifyViewport, { passive: true });
    window.visualViewport?.addEventListener("resize", notifyViewport, { passive: true });
    window.visualViewport?.addEventListener("scroll", notifyViewport, { passive: true });
    notifyViewport();
  };
})();
