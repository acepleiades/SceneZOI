(function () {
    'use strict';
    function text(value) {
        return String(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
    }
    function unhex(value) {
        if (value === '00') return '';
        if (!/^(?:[0-9a-f]{2})+$/i.test(value)) throw new Error('Invalid outfit label');
        return decodeURIComponent(value.replace(/../g, function (byte) { return '%' + byte; }));
    }
    window.SceneZOIOutfitUI = {create: function (options) {
        var root = options.root, opened = false, choosing = false, selected = null;
        var mode = 'outfit', personality = {}, personalityCount = 0, personalityAck = 0, personalityPending = null, personalityReading = false;
        var sessionKey = '', participants = [], count = 0, pending = null, reading = false;
        var serverBusy = true, serverRevision = 0, listMarkup = null, selectorMarkup = null;
        root.insertAdjacentHTML('beforeend',
            '<div id="scene-tools" data-i18n-aria="Scene tools" aria-label="'+window.SceneZOILocalization.html("Scene tools")+'">' +
            '<button id="outfit-toggle" type="button" data-i18n-aria="Outfit management" aria-label="'+window.SceneZOILocalization.html("Outfit management")+'" aria-expanded="false"><img src="icons/shirt.png" alt=""></button>' +
            '<button id="view-options" type="button" data-i18n-aria="Personality management" aria-label="'+window.SceneZOILocalization.html("Personality management")+'" aria-expanded="false"><img src="icons/person.png" alt=""></button>' +
            '<button id="scene-settings" type="button" data-i18n-aria="Scene settings" aria-label="'+window.SceneZOILocalization.html("Scene settings")+'" aria-expanded="false"><img src="icons/cog.png" alt=""></button></div>' +
            '<div id="outfit-panel" role="region" data-i18n-aria="Outfit management" aria-label="'+window.SceneZOILocalization.html("Outfit management")+'">' +
            '<div id="outfit-heading"><span id="outfit-title"><span data-i18n="Outfit Management">'+window.SceneZOILocalization.html("Outfit Management")+'</span></span><button id="outfit-close" type="button" data-i18n-aria="Close outfit management" aria-label="'+window.SceneZOILocalization.html("Close outfit management")+'">X</button></div>' +
            '<div id="outfit-selector-wrap"><button id="outfit-selector" type="button" aria-expanded="false"><span data-i18n="Choose a Zoi">'+window.SceneZOILocalization.html("Choose a Zoi")+'</span></button>' +
            '<div id="outfit-participants" role="group" data-i18n-aria="Scene participants" aria-label="'+window.SceneZOILocalization.html("Scene participants")+'"></div></div>' +
            '<div id="outfit-status" role="status" aria-live="polite"></div>' +
             '<div id="outfit-pieces" data-i18n-aria="Starting outfit pieces" aria-label="'+window.SceneZOILocalization.html("Starting outfit pieces")+'"></div>' +
            '<div id="personality-fields"><label for="expression-set"><span data-i18n="Expression set">'+window.SceneZOILocalization.html("Expression set")+'</span></label>' +
            '<button id="expression-set" type="button" data-i18n-aria="Expression set" aria-label="'+window.SceneZOILocalization.html("Expression set")+'" aria-expanded="false"><span data-i18n="Choose an expression set">'+window.SceneZOILocalization.html("Choose an expression set")+'</span></button><div id="expression-choices" role="group" data-i18n-aria="Expression sets" aria-label="'+window.SceneZOILocalization.html("Expression sets")+'"></div>' +
            '<div id="personality-status" role="status" aria-live="polite"></div>' +
            '<div id="voice-fields"></div></div><div id="settings-fields"></div></div>');
        var tools = document.getElementById('scene-tools'), panel = document.getElementById('outfit-panel');
        var toggle = document.getElementById('outfit-toggle'), close = document.getElementById('outfit-close');
        var selector = document.getElementById('outfit-selector'), choices = document.getElementById('outfit-participants');
        var status = document.getElementById('outfit-status'), pieces = document.getElementById('outfit-pieces');
        var personalityToggle = document.getElementById('view-options');
        var expressionSelect = document.getElementById('expression-set');
        var personalityFields = document.getElementById('personality-fields');
        var personalityStatus = document.getElementById('personality-status');
        var library = {sets:Object.create(null)};
        var outfitMessage='',personalityMessage='';
        function hex(value) { return encodeURIComponent(value).replace(/%([0-9a-f]{2})|([^%])/gi, function (_, byte, literal) { return byte || ('0' + literal.charCodeAt(0).toString(16)).slice(-2); }); }
        function validKey(value) { return value.length > 0 && value.length <= 96 && /^[ -~]+$/.test(value) && value === value.trim().toLowerCase(); }
        var expressionMarkup = null, expressionChoosing = false;
        var expressionChoices = document.getElementById('expression-choices');

        var voices = window.SceneZOIVoiceUI.create({container:document.getElementById('voice-fields'),state:state,
            selected:function(){return selected;}, visible:function(){return opened && mode === 'personality';},
            busy:function(){var s=state();return !!pending || !!personalityPending || serverBusy || !s.playing || !!s.pendingNavigation || s.exiting;},
            closeExpression:function(){expressionChoosing=false;},write:options.write,cfg:options.cfg,changed:changed});
        var settingsToggle=document.getElementById('scene-settings');
        var settings=window.SceneZOISettingsUI.create({container:document.getElementById('settings-fields'),state:state,
            visible:function(){return opened && mode==='settings';},write:options.write,cfg:options.cfg});
        function state() { return options.state(); }
        function busy() { var s = state(); return voices.busy() || !!pending || !!personalityPending || serverBusy || !s.playing || !!s.pendingNavigation || s.exiting; }
        function reset() {
            opened = false; choosing = false; selected = null; participants = []; count = state().counterBase || 0; pending = null;
            serverBusy = true; serverRevision = 0; listMarkup = null; selectorMarkup = null;
            outfitMessage='';personalityMessage='';mode = 'outfit'; personality = Object.create(null); library = {sets:Object.create(null)}; personalityCount = state().counterBase || 0; personalityAck = 0; personalityPending = null; expressionMarkup = null; expressionChoosing = false;
        }
        function layout() {
            var vw = window.innerWidth || 1920, vh = window.innerHeight || 1080;
            var borderX = root.clientLeft || 0, borderY = root.clientTop || 0;
            var w = root.offsetWidth, h = Math.min(root.offsetHeight, Math.max(160, vh - 20));
            var taskWidth = options.tasks ? options.tasks.width() : 0;
            var left = w + 10 + taskWidth;
            if (!taskWidth && root.offsetLeft + left + w > vw) left = -w - 10;
            if (!taskWidth && root.offsetLeft + left < 0) left = Math.max(0, vw - w - 10) - root.offsetLeft;
            panel.style.left = (left - borderX) + 'px'; panel.style.top = (Math.max(10 - root.offsetTop, Math.min(0, vh - 10 - root.offsetTop - h)) - borderY) + 'px';
            panel.style.width = w + 'px'; panel.style.height = h + 'px';
            tools.style.left = -borderX + 'px'; tools.style.top = (Math.max(-40, -root.offsetTop) - borderY) + 'px';
        }
        function bounds() {
            layout();
            var x = root.offsetLeft, y = root.offsetTop, right = x + root.offsetWidth, bottom = y + root.offsetHeight;
            if (options.tasks) {
                var tb=options.tasks.bounds();
                if(tb){x=Math.min(x,tb[0]);y=Math.min(y,tb[1]);right=Math.max(right,tb[0]+tb[2]);bottom=Math.max(bottom,tb[1]+tb[3]);}
            }
            if (tools.style.display !== 'none') y = Math.min(y, root.offsetTop + (root.clientTop || 0) + parseFloat(tools.style.top));
            if (panel.style.display !== 'none') {
                var px = root.offsetLeft + (root.clientLeft || 0) + parseFloat(panel.style.left), py = root.offsetTop + (root.clientTop || 0) + parseFloat(panel.style.top);
                x = Math.min(x, px); y = Math.min(y, py);
                right = Math.max(right, px + root.offsetWidth); bottom = Math.max(bottom, py + parseFloat(panel.style.height));
            }
            return [x, y, right - x, bottom - y];
        }
        // The scaffold reports only its own rectangle while dragging/resizing.
        // Extend those reports for this view's attached controls without editing
        // the generated window manager or suspending the always-on native view.
        var report = inzoi.view.setContentRect;
        if (typeof report === 'function') inzoi.view.setContentRect = function () {
            if (root.style.visibility === 'hidden') return report.call(inzoi.view, -10000, -10000, 1, 1);
            return report.apply(inzoi.view, bounds());
        };
        function update() {
            var s = state(), key = s.client + ':' + s.sequence;
            if (key !== sessionKey) { reset(); sessionKey = key; }
            if (!s.active || s.exiting) { opened = false; choosing = false; pending = null; personalityPending = null; expressionChoosing = false; }
            tools.style.display = s.active && !s.exiting ? 'flex' : 'none';
            panel.style.display = opened && s.active && !s.exiting ? 'flex' : 'none';
            toggle.disabled = !s.active || s.exiting;
            toggle.setAttribute('aria-expanded', opened && mode === 'outfit' ? 'true' : 'false');
            toggle.className = opened && mode === 'outfit' ? 'selected' : '';
            personalityToggle.disabled = !s.active || s.exiting;
            personalityToggle.className = opened && mode === 'personality' ? 'selected' : '';
            personalityToggle.setAttribute('aria-expanded', opened && mode === 'personality' ? 'true' : 'false');
            settingsToggle.disabled=!s.active || s.exiting;
            settingsToggle.className=opened && mode==='settings'?'selected':'';
            settingsToggle.setAttribute('aria-expanded',opened && mode==='settings'?'true':'false');
            document.getElementById('outfit-title').textContent = mode === 'settings' ? window.SceneZOILocalization.text('Scene Settings') : mode === 'personality' ? window.SceneZOILocalization.text('Personality Management') : window.SceneZOILocalization.text('Outfit Management');
            panel.setAttribute('aria-label', mode === 'settings' ? window.SceneZOILocalization.text('Scene settings') : mode === 'personality' ? window.SceneZOILocalization.text('Personality management') : window.SceneZOILocalization.text('Outfit management'));
            close.setAttribute('aria-label', mode === 'settings' ? window.SceneZOILocalization.text('Close scene settings') : mode === 'personality' ? window.SceneZOILocalization.text('Close personality management') : window.SceneZOILocalization.text('Close outfit management'));
            document.getElementById('outfit-selector-wrap').style.display=mode==='settings'?'none':'block';
            document.getElementById('settings-fields').style.display=mode==='settings'?'block':'none';
            settings.update();
            pieces.style.display = mode === 'outfit' ? 'block' : 'none';
            status.style.display = mode === 'outfit' ? 'block' : 'none';
            personalityFields.style.display = mode === 'personality' ? 'block' : 'none';
            var profile = personality[selected];
            var expressions = profile ? Object.keys(library.sets).filter(function (id) { return library.sets[id].body === profile.body; }) : [];
            var expressionHtml = expressions.map(function (id) { return '<button type="button" data-expression="' + text(id) + '">' + text(library.sets[id].label) + '</button>'; }).join('');
            if (expressionMarkup !== expressionHtml) { expressionChoices.innerHTML = expressionHtml; expressionMarkup = expressionHtml; }
            expressionSelect.textContent = profile && library.sets[profile.set] ? library.sets[profile.set].label : (profile && !expressions.length ? window.SceneZOILocalization.text('No expression sets available') : window.SceneZOILocalization.text('Choose an expression set'));
            expressionSelect.disabled = !profile || !expressions.length || busy() || !!personalityPending;
            if (expressionSelect.disabled || mode !== 'personality' || !opened) expressionChoosing = false;
            expressionChoices.style.display = expressionChoosing ? 'block' : 'none';
            expressionSelect.setAttribute('aria-expanded', expressionChoosing ? 'true' : 'false');
            if (!profile) personalityStatus.textContent = window.SceneZOILocalization.text('Loading personality...');
            else if (personalityPending) personalityStatus.textContent = window.SceneZOILocalization.text('Saving expression set...');
            else if (profile.error) personalityStatus.textContent = window.SceneZOILocalization.text('Expression is unavailable. See diagnostics.');
            else if (!expressions.length) personalityStatus.textContent = window.SceneZOILocalization.text('No expression sets installed for this body.');
            else personalityStatus.textContent = window.SceneZOILocalization.text(personalityMessage || 'Saved for future scene sessions.');

            voices.update();
            choices.style.display = choosing ? 'block' : 'none';
            selector.setAttribute('aria-expanded', choosing ? 'true' : 'false');
            var person = participants.filter(function (entry) { return entry.id === selected; })[0];
            selector.textContent = person ? person.name : window.SceneZOILocalization.text('Choose a Zoi');
            var selection = participants.map(function (entry) {
                return '<button type="button" data-participant="' + text(entry.id) + '">' + text(entry.name) + '</button>';
            }).join('');
            if (selection !== selectorMarkup) { choices.innerHTML = selection; selectorMarkup = selection; }
            var disabled = busy(), html = person ? person.items.map(function (item) {
                return '<div class="outfit-piece"><span class="outfit-piece-name">' + text(item.label) + '</span>' +
                    '<button type="button" role="switch" aria-label="' + text(item.label) + '" aria-checked="' + item.enabled +
                    '" class="outfit-switch' + (item.enabled ? ' on' : '') + '" data-piece="' + text(item.id) + '"' +
                    (disabled ? ' disabled' : '') + '><span class="outfit-switch-knob"></span></button></div>';
            }).join('') : '';
            if (html !== listMarkup) { pieces.innerHTML = html; listMarkup = html; }
            if (!participants.length) status.textContent = window.SceneZOILocalization.text('Loading starting outfits...');
            else if (pending || serverBusy) status.textContent = window.SceneZOILocalization.text('Updating outfit...');
            else if (!person || !person.items.length) status.textContent = window.SceneZOILocalization.text('No outfit pieces.');
            else status.textContent = window.SceneZOILocalization.text(outfitMessage);
            layout();
        }
        function changed() { update(); options.changed(); }
        toggle.addEventListener('click', function () {
            var s = state(); if (!s.active || s.exiting) return;
            opened = mode !== 'outfit' || !opened; mode = 'outfit'; choosing = false; changed();
        });
        personalityToggle.addEventListener('click', function () {
            var s = state(); if (!s.active || s.exiting) return;
            opened = mode !== 'personality' || !opened; mode = 'personality'; choosing = false; changed();
        });
        settingsToggle.addEventListener('click',function(){
            var s=state();if(!s.active || s.exiting)return;
            opened=mode!=='settings' || !opened;mode='settings';choosing=false;expressionChoosing=false;voices.close();changed();
        });
        expressionSelect.addEventListener('click' , function () {
            if (expressionSelect.disabled) return;
            voices.close();expressionChoosing = !expressionChoosing; choosing = false; changed();
        });
        expressionChoices.addEventListener('click', function (event) {
            var s = state(), profile = personality[selected], id = attribute(event.target, 'data-expression', expressionChoices);
            if (!profile || busy() || !library.sets[id] || library.sets[id].body !== profile.body) return;
            expressionChoosing = false;
            if (id === profile.set) { changed(); return; }
            personalityPending = ['SZ2', s.client, String(s.sequence), 'personality2', String(++personalityCount), selected, hex(id), String(s.revision)].join('|');
            options.write('personality', personalityPending).catch(function () {}); changed();
        });
        close.addEventListener('click', function () { opened = false; choosing = false; changed(); });
        selector.addEventListener('click', function () { expressionChoosing = false; choosing = !choosing; update(); });
        function attribute(target, name, container) {
            while (target && target !== container) {
                var value = target.getAttribute && target.getAttribute(name);
                if (value) return value;
                target = target.parentNode;
            }
        }
        choices.addEventListener('click', function (event) {
            var id = attribute(event.target, 'data-participant', choices);
            if (participants.some(function (entry) { return entry.id === id; })) { selected = id; choosing = false; expressionChoosing = false; status.textContent = ''; changed(); }
        });
        pieces.addEventListener('click', function (event) {
            if (busy()) return;
            var id = attribute(event.target, 'data-piece', pieces), s = state();
            var person = participants.filter(function (entry) { return entry.id === selected; })[0];
            var item = person && person.items.filter(function (entry) { return entry.id === id; })[0];
            if (!item) return;
            pending = ['SZ2', s.client, String(s.sequence), 'outfit', String(++count), person.id, item.id,
                item.enabled ? '0' : '1', String(s.revision)].join('|');
            options.write('outfit', pending).catch(function () {});
            changed();
        });
        function retry() { settings.retry(); voices.retry(); if (personalityPending && state().active && !state().exiting) options.write('personality', personalityPending).catch(function () {}); if (pending && state().active && !state().exiting) options.write('outfit', pending).catch(function () {}); }
        setInterval(function () {
            var s = state(); if (!s.active || s.exiting || reading) return;
            var requestedSession = s.client + ':' + s.sequence;
            reading = true;
            options.cfg('uimod.cfg_load', 'outfit_state').then(function (data) {
                var now = state();
                if (!now.active || now.exiting || requestedSession !== now.client + ':' + now.sequence) return;
                var value = data && data.value !== undefined ? data.value : data;
                if (typeof value !== 'string') return;
                var fields = value.split('|'), rev = Number(fields[3]), ack = Number(fields[4]);
                if (fields[0] !== 'SZ2' || fields[1] !== now.client || fields[2] !== String(now.sequence) ||
                    !Number.isInteger(rev) || rev < now.revision || rev < serverRevision || !Number.isInteger(ack) || ack < 0) return;
                var incoming = [];
                if (fields[6] !== 'none') fields[6].split('+').forEach(function (row) {
                    var columns = row.split(':'); if (columns.length !== 3 || !/^\d+$/.test(columns[0])) throw new Error('Invalid outfit participant');
                    var items = [], rawItems = unhex(columns[2]);
                    if (rawItems !== 'none') rawItems.split('+').forEach(function (item) {
                        var parts = item.split(':'); if (parts.length !== 6 || !/^piece\d+$/.test(parts[0]) || !/^[01]$/.test(parts[4])) throw new Error('Invalid outfit piece');
                        items.push({id:parts[0],label:window.SceneZOILocalization.outfitLabel(parts[1],unhex(parts[2]),unhex(parts[3]),unhex(parts[5])),enabled:parts[4] === '1'});
                    });
                    incoming.push({id:columns[0],name:unhex(columns[1]),items:items});
                });
                participants = incoming; serverRevision = rev; serverBusy = fields[5] === 'busy';
                if (!participants.some(function (entry) { return entry.id === selected; })) selected = participants.length ? participants[0].id : null;
                if (pending && ack >= count && !serverBusy) pending = null;
                outfitMessage = fields[5] === 'outfit_invalid' || fields[5] === 'outfit_stale' ? window.SceneZOILocalization.text('Could not change that piece. Try again.') : '';
                changed();
            }).catch(function () {}).then(function () { reading = false; });
        }, 400);
        update();
        setInterval(function () {
            var s = state(); if (!s.active || s.exiting || personalityReading) return;
            var requested = s.client + ':' + s.sequence; personalityReading = true;
            options.cfg('uimod.cfg_load','personality_state').then(function (data) {
                var now = state(), raw = data && data.value !== undefined ? data.value : data;
                if (!now.active || now.exiting || requested !== now.client + ':' + now.sequence || typeof raw !== 'string') return;
                var f = raw.split('|'), ack = Number(f[4]), rev = Number(f[3]);
                if (f.length !== 8 || !Number.isInteger(ack) || ack < personalityAck || !Number.isInteger(rev)) return;
                if (['busy','ok','personality_invalid','personality_stale','personality_storage'].indexOf(f[5]) < 0) return;
                if (f[0] !== 'SZ2' || f[1] !== now.client || f[2] !== String(now.sequence) || Number(f[3]) !== now.revision) return;
                var incoming = Object.create(null), available = Object.create(null);
                if (f[7] !== 'none') f[7].split('+').forEach(function (row) {
                    var c = row.split(':'), id = unhex(c[0]), label = unhex(c[1]);
                    if (c.length !== 3 || !validKey(id) || !label || /[\x00-\x1f]/.test(label) || ['male','female'].indexOf(c[2]) < 0 || available[id]) throw new Error('Invalid expression definition');
                    available[id] = {label:label,body:c[2]};
                });
                if (f[6] !== 'none') f[6].split('+').forEach(function (row) {
                    var c = row.split(':'), id = unhex(c[3]);
                    if (c.length !== 5 || !/^\d+$/.test(c[0]) || ['male','female'].indexOf(c[2]) < 0 || (id && (!available[id] || available[id].body !== c[2])) || incoming[c[0]]) throw new Error('Invalid personality');
                    incoming[c[0]] = {body:c[2],set:id,error:unhex(c[4])};
                });
                personality = incoming; library.sets = available; personalityAck = ack;
                if (personalityPending && Number(f[4]) >= personalityCount) personalityPending = null;
                personalityMessage = f[5].indexOf('personality_') === 0 ? window.SceneZOILocalization.text('Could not save that expression set. Try again.') : '';
                changed();
            }).catch(function () {}).then(function () { personalityReading = false; });
        }, 450);
        return {update:update, busy:function () { return voices.busy() || !!pending || !!personalityPending; }, retry:retry, bounds:bounds};
    }};
})();
