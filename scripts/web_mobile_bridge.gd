class_name WebMobileBridge
extends RefCounted

signal description_event(kind: String, value: String, revision: int, composing: bool)
signal viewport_changed
signal qa_command(command: String, payload: Dictionary)

var _description_callback: Variant
var _viewport_callback: Variant
var _qa_callback: Variant
var _initialized := false


func initialize() -> void:
	if not OS.has_feature("web") or _initialized:
		return
	_description_callback = JavaScriptBridge.create_callback(_on_description_event)
	_viewport_callback = JavaScriptBridge.create_callback(_on_viewport_event)
	_qa_callback = JavaScriptBridge.create_callback(_on_qa_event)
	var browser_window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	browser_window.__forgeGodotDescriptionCallback = _description_callback
	browser_window.__forgeGodotViewportCallback = _viewport_callback
	browser_window.__forgeGodotQaCallback = _qa_callback
	JavaScriptBridge.eval(_install_script(), true)
	_initialized = true


func is_available() -> bool:
	return OS.has_feature("web") and _initialized


func metrics() -> Dictionary:
	if not is_available():
		return {}
	var encoded: Variant = JavaScriptBridge.eval(
		"window.__forgeMobileInput ? JSON.stringify(window.__forgeMobileInput.metrics()) : '{}'",
		true,
	)
	var parsed: Variant = JSON.parse_string(str(encoded))
	return parsed if parsed is Dictionary else {}


func set_value(value: String) -> void:
	if not is_available():
		return
	JavaScriptBridge.eval(
		"window.__forgeMobileInput && window.__forgeMobileInput.setValue(%s);" % JSON.stringify(value),
		true,
	)


func value() -> String:
	if not is_available():
		return ""
	return str(JavaScriptBridge.eval(
		"window.__forgeMobileInput ? window.__forgeMobileInput.value() : ''",
		true,
	))


func description_snapshot() -> Dictionary:
	if not is_available():
		return {"value": "", "revision": -1, "composing": false, "connected": false}
	var encoded: Variant = JavaScriptBridge.eval(
		"window.__forgeMobileInput ? JSON.stringify(window.__forgeMobileInput.snapshot()) : '{}'",
		true,
	)
	var parsed: Variant = JSON.parse_string(str(encoded))
	return parsed if parsed is Dictionary else {"value": "", "revision": -1, "composing": false, "connected": false}


func commit_for_request() -> void:
	if is_available():
		JavaScriptBridge.eval("window.__forgeMobileInput && window.__forgeMobileInput.commitForRequest();", true)


func focus() -> void:
	if is_available():
		JavaScriptBridge.eval("window.__forgeMobileInput && window.__forgeMobileInput.focus();", true)


func blur() -> void:
	if is_available():
		JavaScriptBridge.eval("window.__forgeMobileInput && window.__forgeMobileInput.blur();", true)


func update_layout(input_rect: Rect2, logical_size: Vector2, visible: bool) -> void:
	if not is_available():
		return
	var payload := {
		"x": input_rect.position.x,
		"y": input_rect.position.y,
		"width": input_rect.size.x,
		"height": input_rect.size.y,
		"logicalWidth": logical_size.x,
		"logicalHeight": logical_size.y,
		"visible": visible,
	}
	JavaScriptBridge.eval(
		"window.__forgeMobileInput && window.__forgeMobileInput.updateLayout(%s);" % JSON.stringify(payload),
		true,
	)


func update_qa_state(state: Dictionary, controls: Dictionary, logical_size: Vector2) -> void:
	if not is_available():
		return
	var payload := {
		"state": state,
		"controls": controls,
		"logicalWidth": logical_size.x,
		"logicalHeight": logical_size.y,
	}
	JavaScriptBridge.eval(
		"window.__forgeM1B1Test && window.__forgeM1B1Test._update(%s);" % JSON.stringify(payload),
		true,
	)


func _on_description_event(arguments: Array) -> void:
	if arguments.is_empty():
		return
	var kind := str(arguments[0])
	var input_value := str(arguments[1]) if arguments.size() > 1 else ""
	var revision := int(arguments[2]) if arguments.size() > 2 else -1
	var composing := bool(arguments[3]) if arguments.size() > 3 else false
	description_event.emit(kind, input_value, revision, composing)


func _on_viewport_event(_arguments: Array) -> void:
	viewport_changed.emit()


func _on_qa_event(arguments: Array) -> void:
	if arguments.is_empty():
		return
	var command := str(arguments[0])
	var payload: Dictionary = {}
	if arguments.size() > 1:
		var parsed: Variant = JSON.parse_string(str(arguments[1]))
		if parsed is Dictionary:
			payload = parsed
	qa_command.emit(command, payload)


func _install_script() -> String:
	return """
(() => {
  const INPUT_ID = 'forge-description-input';
  const ROOT_ID = 'forge-description-native';
  const CLEAR_ID = 'forge-description-clear';
  let root = document.getElementById(ROOT_ID);
  let input = document.getElementById(INPUT_ID);
  let clear = document.getElementById(CLEAR_ID);
  let revision = Number(input?.dataset?.forgeRevision || 0);
  let composing = false;
  const emitDescription = (kind, bump = false) => {
    if (bump) revision += 1;
    if (input) input.dataset.forgeRevision = String(revision);
    window.__forgeGodotDescriptionCallback?.(kind, input?.value || '', revision, composing);
  };

  if (!root) {
    root = document.createElement('div');
    root.id = ROOT_ID;
    root.setAttribute('data-forge-native-input', 'true');
    Object.assign(root.style, {
      position: 'fixed', display: 'none', alignItems: 'stretch', gap: '6px',
      zIndex: '1000', pointerEvents: 'auto', boxSizing: 'border-box'
    });

    input = document.createElement('input');
    input.id = INPUT_ID;
    input.type = 'text';
    input.maxLength = 512;
    input.placeholder = 'Describe your weapon';
    input.autocomplete = 'off';
    input.autocapitalize = 'sentences';
    input.spellcheck = true;
    input.setAttribute('enterkeyhint', 'done');
    input.setAttribute('aria-label', 'Weapon description');
    Object.assign(input.style, {
      minWidth: '0', flex: '1 1 auto', height: '100%', padding: '0 12px',
      border: '2px solid #5578a4', borderRadius: '7px', outline: 'none',
      background: '#101721', color: '#edf4ff', caretColor: '#65d9ff',
      font: '600 16px system-ui, -apple-system, sans-serif', boxSizing: 'border-box',
      touchAction: 'manipulation', WebkitUserSelect: 'text', userSelect: 'text'
    });

    clear = document.createElement('button');
    clear.id = CLEAR_ID;
    clear.type = 'button';
    clear.textContent = '×';
    clear.setAttribute('aria-label', 'Clear description');
    Object.assign(clear.style, {
      flex: '0 0 auto', height: '100%', minWidth: '44px', padding: '0',
      border: '2px solid #65d9ff', borderRadius: '7px', background: '#1a3150',
      color: '#edf4ff', font: '700 25px system-ui, -apple-system, sans-serif',
      boxSizing: 'border-box', touchAction: 'manipulation', cursor: 'pointer'
    });

    input.addEventListener('focus', () => {
      input.style.borderColor = '#65d9ff';
      emitDescription('focus');
    });
    input.addEventListener('blur', () => {
      input.style.borderColor = '#5578a4';
      if (composing) {
        composing = false;
        emitDescription('compositionend', true);
      }
      emitDescription('blur');
    });
    input.addEventListener('input', () => {
      emitDescription('input', true);
    });
    input.addEventListener('change', () => emitDescription('change', true));
    input.addEventListener('compositionstart', () => {
      composing = true;
      emitDescription('compositionstart');
    });
    input.addEventListener('compositionend', () => {
      composing = false;
      emitDescription('compositionend', true);
    });
    clear.addEventListener('click', (event) => {
      event.preventDefault();
      event.stopPropagation();
      input.value = '';
      emitDescription('clear', true);
      input.focus({ preventScroll: true });
    });
    const pressClear = () => {
      clear.style.background = '#65d9ff';
      clear.style.color = '#091424';
    };
    const releaseClear = () => {
      clear.style.background = '#1a3150';
      clear.style.color = '#edf4ff';
    };
    clear.addEventListener('pointerdown', pressClear, { passive: true });
    clear.addEventListener('pointerup', releaseClear, { passive: true });
    clear.addEventListener('pointercancel', releaseClear, { passive: true });
    clear.addEventListener('blur', releaseClear, { passive: true });
    root.append(input, clear);
    document.body.appendChild(root);
  }

  const safeProbe = document.createElement('div');
  Object.assign(safeProbe.style, {
    position: 'fixed', visibility: 'hidden', pointerEvents: 'none',
    paddingTop: 'env(safe-area-inset-top)', paddingRight: 'env(safe-area-inset-right)',
    paddingBottom: 'env(safe-area-inset-bottom)', paddingLeft: 'env(safe-area-inset-left)'
  });
  document.body.appendChild(safeProbe);

  const metrics = () => {
    const viewport = window.visualViewport;
    const safe = getComputedStyle(safeProbe);
    return {
      width: viewport?.width || window.innerWidth,
      height: viewport?.height || window.innerHeight,
      offsetLeft: viewport?.offsetLeft || 0,
      offsetTop: viewport?.offsetTop || 0,
      scale: viewport?.scale || 1,
      safeTop: parseFloat(safe.paddingTop) || 0,
      safeRight: parseFloat(safe.paddingRight) || 0,
      safeBottom: parseFloat(safe.paddingBottom) || 0,
      safeLeft: parseFloat(safe.paddingLeft) || 0,
      inputFocused: document.activeElement === input
    };
  };

  const updateLayout = (layout) => {
    const canvas = document.getElementById('canvas') || document.querySelector('canvas');
    if (!canvas || !layout.visible) {
      root.style.display = 'none';
      return;
    }
    const canvasRect = canvas.getBoundingClientRect();
    const scaleX = canvasRect.width / Math.max(layout.logicalWidth, 1);
    const scaleY = canvasRect.height / Math.max(layout.logicalHeight, 1);
    root.style.left = `${canvasRect.left + layout.x * scaleX}px`;
    root.style.top = `${canvasRect.top + layout.y * scaleY}px`;
    root.style.width = `${layout.width * scaleX}px`;
    root.style.height = `${layout.height * scaleY}px`;
    root.style.display = 'flex';
    clear.style.width = `${Math.max(44, layout.height * scaleY)}px`;
  };

  window.__forgeMobileInput = {
    metrics,
    updateLayout,
    setValue: (value) => {
      const next = String(value ?? '');
      if (input.value !== next) {
        input.value = next;
        emitDescription('programmatic', true);
      }
    },
    value: () => input.value,
    snapshot: () => ({
      value: input.value,
      revision,
      composing,
      connected: input.isConnected,
      focused: document.activeElement === input
    }),
    focus: () => input.focus({ preventScroll: true }),
    blur: () => input.blur(),
    clear: () => { input.value = ''; emitDescription('clear', true); },
    commitForRequest: () => {
      input.blur();
      requestAnimationFrame(() => {
        if (composing) {
          composing = false;
          emitDescription('compositionend', true);
        }
        emitDescription('commit');
      });
    }
  };

  const qaEnabled = new URLSearchParams(window.location.search).get('qa') === 'm1b1';
  if (qaEnabled) {
    let latestState = {};
    let latestControls = {};
    const cssRect = (rect, logicalWidth, logicalHeight) => {
      if (!rect) return null;
      const canvas = document.getElementById('canvas') || document.querySelector('canvas');
      if (!canvas) return null;
      const box = canvas.getBoundingClientRect();
      const scaleX = box.width / Math.max(logicalWidth, 1);
      const scaleY = box.height / Math.max(logicalHeight, 1);
      return {
        x: box.left + rect.x * scaleX,
        y: box.top + rect.y * scaleY,
        width: rect.width * scaleX,
        height: rect.height * scaleY
      };
    };
    window.__forgeM1B1Test = {
      state: () => structuredClone(latestState),
      controls: () => structuredClone(latestControls),
      setScenario: (name, options = {}) => window.__forgeGodotQaCallback?.(
        'scenario', JSON.stringify({ name: String(name), options })
      ),
      setDeveloperMode: (enabled) => window.__forgeGodotQaCallback?.(
        'developer_mode', JSON.stringify({ enabled: Boolean(enabled) })
      ),
      _update: (payload) => {
        latestState = payload.state || {};
        latestControls = {};
        for (const [name, value] of Object.entries(payload.controls || {})) {
          latestControls[name] = Array.isArray(value)
            ? value.map((rect) => cssRect(rect, payload.logicalWidth, payload.logicalHeight))
            : cssRect(value, payload.logicalWidth, payload.logicalHeight);
        }
      }
    };
  }

  let frame = 0;
  const notifyViewport = () => {
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(() => window.__forgeGodotViewportCallback?.('viewport'));
  };
  window.addEventListener('orientationchange', notifyViewport, { passive: true });
  window.addEventListener('resize', notifyViewport, { passive: true });
  window.visualViewport?.addEventListener('resize', notifyViewport, { passive: true });
  window.visualViewport?.addEventListener('scroll', notifyViewport, { passive: true });
  notifyViewport();
})();
"""
