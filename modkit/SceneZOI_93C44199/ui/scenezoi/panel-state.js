// Presentation only: the always-on controls receiver must keep ticking while hidden.
(function () {
    'use strict';
    var root = document.getElementById('app-root');
    var compact = false, blocked = false, reading = null, pressed = null, expandedPosition = null;
    var readCount = 0, readStatus = 'none', nativeState = null, lastInput = null;
    var readTimeout = 2000;
    var drag = null, suppressRestoreClick = false;
    var restore = document.createElement('button');
    restore.id = 'scene-restore';
    restore.type = 'button';
    restore.textContent = window.SceneZOILocalization.text('Show SceneZOI');
    restore.setAttribute('aria-label', window.SceneZOILocalization.text('Show SceneZOI controls'));
    root.appendChild(restore);
    window.SceneZOILocalization.onChange(function(){restore.textContent=window.SceneZOILocalization.text('Show SceneZOI');restore.setAttribute('aria-label',window.SceneZOILocalization.text('Show SceneZOI controls'));});

    // Both the generated manager and the attached-panel controller report bounds.
    // Gate their final reports so an invisible/blocked view cannot swallow menu clicks.
    var report = inzoi.view.setContentRect;
    if (typeof report === 'function') inzoi.view.setContentRect = function () {
        if (blocked || root.style.visibility === 'hidden') {
            return report.call(inzoi.view, -10000, -10000, 1, 1);
        }
        if (compact) return report.call(inzoi.view, root.offsetLeft, root.offsetTop, root.offsetWidth, root.offsetHeight);
        return report.apply(inzoi.view, arguments);
    };
    var hover = inzoi.view.hover;
    if (typeof hover === 'function') inzoi.view.hover = function (over) {
        return hover.call(inzoi.view, blocked ? false : over);
    };
    function refresh() {
        root.classList.toggle('scene-compact', compact);
        root.classList.toggle('scene-menu-blocked', blocked);
        root.setAttribute('aria-disabled', blocked ? 'true' : 'false');
        // inZOI also injects a direct-to-native rect watcher. Its measurement does
        // not know about attached panels or modality; our controller reports both.
        window.__uimod_rectActive = false;
        if (typeof inzoi.view.setContentRect === 'function') {
            inzoi.view.setContentRect(root.offsetLeft, root.offsetTop, root.offsetWidth, root.offsetHeight);
        }
    }
    function release() {
        if (document.activeElement && typeof document.activeElement.blur === 'function') document.activeElement.blur();
        if (typeof inzoi.view.hover === 'function') inzoi.view.hover(false);
    }
    function collapse(value) {
        if (value === compact) { refresh(); return; }
        if (value && !compact) {
            // The scaffold persists the expanded size, even while our compact tab is visible.
            if (root._savedW == null) root._savedW = root.offsetWidth;
            if (root._savedH == null) root._savedH = root.offsetHeight;
            expandedPosition = {left:root.style.left, top:root.style.top};
            // The expanded title may be only partly on-screen. Keep its shorter
            // restore tab reachable without changing the expanded placement.
            root.style.left = Math.max(0, Math.min(root.offsetLeft, (window.innerWidth || 1920) - 134)) + 'px';
            root.style.top = Math.max(0, Math.min(root.offsetTop, (window.innerHeight || 1080) - 36)) + 'px';
        } else if (!value && expandedPosition) {
            root.style.left = expandedPosition.left;
            root.style.top = expandedPosition.top;
            expandedPosition = null;
        }
        compact = value;
        drag = null; pressed = null;
        restore.classList.remove('scene-dragging');
        release(); refresh();
    }
    function action(target) {
        while (target && target !== root) {
            if (target.id === 'hide-btn') return 'hide';
            if (target.id === 'scene-restore') return 'restore';
            target = target.parentNode;
        }
        return null;
    }
    function consume(event) {
        event.preventDefault(); event.stopImmediatePropagation();
    }
    // Capture before the game's injected button listener, scaffold dragging and
    // synthetic clicks. Mouseup handles cohtml builds that omit native click.
    document.addEventListener('mousedown', function (event) {
        var a = action(event.target);
        if (!a) return;
        if (event.button != null && event.button !== 0) { consume(event); return; }
        suppressRestoreClick = false;
        pressed = blocked ? null : a;
        if (!blocked && compact && a === 'restore') {
            drag = {x:event.clientX, y:event.clientY, left:root.offsetLeft, top:root.offsetTop, moved:false};
        }
        consume(event);
    }, true);
    document.addEventListener('mousemove', function (event) {
        if (!drag || blocked) return;
        var dx = event.clientX - drag.x, dy = event.clientY - drag.y;
        if (!drag.moved && dx * dx + dy * dy < 16) return;
        drag.moved = true;
        restore.classList.add('scene-dragging');
        root.style.left = Math.max(0, Math.min(drag.left + dx, (window.innerWidth || 1920) - 134)) + 'px';
        root.style.top = Math.max(0, Math.min(drag.top + dy, (window.innerHeight || 1080) - 36)) + 'px';
        refresh(); consume(event);
    }, true);
    document.addEventListener('mouseup', function (event) {
        var a = action(event.target), previous = pressed; pressed = null;
        if (drag) {
            var moved = drag.moved; drag = null;
            restore.classList.remove('scene-dragging');
            if (moved) {
                // Restore the panel at the tab's new position, retaining full size.
                expandedPosition = {left:root.style.left, top:root.style.top};
                if (typeof root._saveWindowState === 'function') root._saveWindowState();
                suppressRestoreClick = true;
                consume(event); return;
            }
        }
        if (!a) return;
        consume(event);
        if (!blocked && previous === a) collapse(a === 'hide');
    }, true);
    document.addEventListener('click', function (event) {
        var a = action(event.target);
        if (!a) return;
        consume(event);
        if (a === 'restore' && suppressRestoreClick) { suppressRestoreClick = false; return; }
        if (!blocked) collapse(a === 'hide');
    }, true);
    ['mousedown', 'mouseup', 'click', 'dblclick', 'contextmenu', 'wheel', 'keydown', 'keyup'].forEach(function (name) {
        document.addEventListener(name, function (event) {
            if (name === 'mousedown' || name === 'click') lastInput = {type:name,target:event.target && event.target.id || '',blocked:blocked};
            if (blocked) consume(event);
        }, true);
    });
    function poll() {
        refresh();
        var now = Date.now();
        if (reading && now - reading.started < readTimeout) return;
        if (reading) readStatus = 'timeout';
        var request = {id:++readCount,started:now};
        reading = request;
        Promise.resolve().then(function () { if (reading === request) return inzoi.cli.execute('ui.get_blocking'); }).then(function (response) {
            // A timed-out reply or a reply from an earlier session cannot relock this panel.
            if (reading !== request) return;
            if (response && response.success === false) { readStatus = 'error'; return; }
            var state = response && response.data !== undefined ? response.data : response;
            if (typeof state === 'string') state = JSON.parse(state);
            if (!state || typeof state.blocked !== 'boolean') { readStatus = 'invalid'; return; }
            readStatus = 'ok';
            nativeState = {blocked:state.blocked,primary_kind:state.primary_kind || '',primary_detail:state.primary_detail || '',
                input_block_ui_type:state.input_block_ui_type || '',esc_stack_remains:!!state.esc_stack_remains,pause_reasons:state.pause_reasons || []};
            // Native modal state, never simulation speed or pause_reasons alone.
            var next = state.blocked;
            if (next !== blocked) {
                // End a drag/resize before blocking document mouseup handlers.
                if (next) {
                    try { document.dispatchEvent(new MouseEvent('mouseup', {bubbles:true})); }
                    catch (_) {
                        var up = document.createEvent('MouseEvents');
                        up.initEvent('mouseup', true, true); document.dispatchEvent(up);
                    }
                }
                blocked = next; pressed = null;
                if (blocked) release();
                refresh();
            }
        }).catch(function () { if (reading === request) readStatus = 'error'; }).then(function () { if (reading === request) reading = null; });
    }
    window.SceneZOIPanel = {
        reset: function () { reading = null; readStatus = 'reset'; collapse(false); poll(); },
        snapshot: function () { return {blocked:blocked,compact:compact,read_status:readStatus,
            request_id:readCount,request_age_ms:reading ? Math.max(0,Date.now()-reading.started) : 0,native:nativeState,last_input:lastInput}; }
    };
    setInterval(poll, 125);
    poll();
})();
