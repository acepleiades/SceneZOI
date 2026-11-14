(function () {
    'use strict';
    var section = 'scenezoi_runtime';
    var client = 'ui.' + Date.now() + '.' + Math.floor(Math.random() * 1000000);
    var sequence = 0;
    // The panel may show a session it did not start: these keep this panel's own identity for new starts.
    var ownClient = client, ownSequence = 0, counterBase = 0, lastFocus = null, sessionToken = null;
    var hasPlan = false, autoMode = false, autoSpeed = false, autoCount = 0, lastPlan = null, autoButton = null;
    var heartbeat = 0;
    var pendingCommand = null;
    var active = false;
    var checkingStart = false;
    var noticeInitiator = null, noticeToken = null;
    var exiting = false;
    var reading = false;
    var lastState = '';
    var pendingNavigation = null;
    var navigationCount = 0;
    var revision = 0;
    var currentNode = null;
    var playing = false;
    var speeds = [0.50, 1.00, 1.50, 2.00];
    var speedIndex = 2;
    var playbackCounter = 0;
    var acknowledgedPlayback = 0;
    var pendingPlayback = null;
    var gameScale = 1;
    var navigationMarkup = null;
    var writes = Promise.resolve();
    var root = wf.root;
    root.style.visibility = 'hidden';
    document.getElementById('close-btn').style.display = 'none';
    document.getElementById('title-text').textContent = 'SceneZOI';
    wf.content.innerHTML = '<div id="scene-status" role="status" aria-live="polite"></div>' +
        '<div id="scene-navigation" data-i18n-aria="Scene navigation" aria-label="'+window.SceneZOILocalization.html("Scene navigation")+'"></div>' +
        '<div id="scene-footer"><button id="scene-exit" type="button"><span data-i18n="Exit">'+window.SceneZOILocalization.html("Exit")+'</span></button>' +
        '<div id="scene-speed" data-i18n-aria="Animation playback speed" aria-label="'+window.SceneZOILocalization.html("Animation playback speed")+'">' +
        '<button id="speed-down" type="button" data-i18n-aria="Slower animation" aria-label="'+window.SceneZOILocalization.html("Slower animation")+'">&lt;</button>' +
        '<div id="speed-display"><span id="speed-label">x1.00</span><div id="speed-dots" aria-hidden="true"></div></div>' +
        '<button id="speed-up" type="button" data-i18n-aria="Faster animation" aria-label="'+window.SceneZOILocalization.html("Faster animation")+'">&gt;</button></div></div>';
    var status = document.getElementById('scene-status');
    var exit = document.getElementById('scene-exit');
    var navigation = document.getElementById('scene-navigation');
    var speedDown = document.getElementById('speed-down');
    var speedUp = document.getElementById('speed-up');
    var speedLabel = document.getElementById('speed-label');
    var speedDots = document.getElementById('speed-dots');

    var tasks = window.SceneZOITaskUI ? window.SceneZOITaskUI.create({root:root,cfg:cfg,
        state:function(){return {active:active,exiting:exiting,client:client,sequence:sequence,revision:revision};},
        changed:function(){updateHitRect();}}) : null;
    var outfits = window.SceneZOIOutfitUI.create({root:root, cfg:cfg, write:writePacket, tasks:tasks,
        state:function () { return {active:active, playing:playing, exiting:exiting, client:client, sequence:sequence,
            revision:revision, pendingNavigation:pendingNavigation, counterBase:counterBase}; },
        changed:function () { renderNavigation(); renderPlayback(); }});

    function decode(response) {
        if (response && response.success === false) throw new Error(response.message || 'Game command failed');
        var value = response && response.data !== undefined ? response.data : response;
        if (typeof value === 'string') {
            try { return JSON.parse(value); } catch (_) { return value; }
        }
        return value;
    }
    function cfg(command, key, value) {
        var params = {mod_id: wf.MOD_ID, section: section, key: key};
        if (value !== undefined) params.value = value;
        return inzoi.cli.execute(command, params).then(decode);
    }
    var saveGuard=window.SceneZOISaveGuard.create({client:client,state:wf.state,sdk:inzoi.saveState,
        encode:function(v){return Array.prototype.map.call(unescape(encodeURIComponent(JSON.stringify(v))),function(c){return ('0'+c.charCodeAt(0).toString(16)).slice(-2);}).join('');},
        decode:function(v){return JSON.parse(decodeURIComponent(escape(String(v).replace(/../g,function(h){return String.fromCharCode(parseInt(h,16));}))));},
        read:function(key){return cfg('uimod.cfg_load',key).then(function(r){return r&&r.value!==undefined?r.value:r;});},
        write:writePacket,
        stopForSave:function(){
            // Every scene exits for a save, including ones this panel is not showing.
            writePacket('save_request',client+'.'+Date.now()).catch(function(){});
            if(active){exiting=true;playing=false;pendingNavigation=null;pendingPlayback=null;send('save').catch(function(){});}
        },
        stopForLoad:function(){if(active){exiting=true;send('exit').catch(function(){});}}});
    function show(message) {
        if (tasks) tasks.update();
        outfits.update();
        root.style.visibility = 'visible';
        updateHitRect();
        status.textContent = window.SceneZOILocalization.text(message);
        exit.textContent = active ? window.SceneZOILocalization.text('Exit') : window.SceneZOILocalization.text('Dismiss');
        exit.disabled = exiting;
        document.getElementById('title-text').textContent = currentNode ? currentNode.label : 'SceneZOI';
        renderNavigation();
        renderPlayback();
    }
    function openPanel() {
        // Keep the always-on native view running; hiding it suspends its timers.
        if (window.SceneZOIPanel) window.SceneZOIPanel.reset();
        root.style.visibility = 'visible';
        updateHitRect();
    }
    function updateHitRect() {
        if (typeof inzoi.view.setContentRect !== 'function') return;
        // An invisible DOM panel can still intercept world clicks through the native hit rectangle.
        var hidden = root.style.visibility === 'hidden';
        inzoi.view.setContentRect(hidden ? -10000 : root.offsetLeft,
            hidden ? -10000 : root.offsetTop, hidden ? 1 : root.offsetWidth,
            hidden ? 1 : root.offsetHeight);
    }
    function closePanel() {
        var closedSequence = sequence;
        if (window.SceneZOIPanel) window.SceneZOIPanel.reset();
        root.style.visibility = 'hidden';
        if (tasks) tasks.update();
        outfits.update();
        updateHitRect();
        if (document.activeElement && typeof document.activeElement.blur === 'function') {
            document.activeElement.blur();
        }
        function releaseHover() {
            if (typeof inzoi.view.hover === 'function') inzoi.view.hover(false);
            else if (typeof engine !== 'undefined') {
                engine.call('_uimod_request', JSON.stringify({type: 'view', action: 'hover', over: false, promiseId: 0}));
            }
        }
        releaseHover();
        // Release hover after the click dispatch too; never suspend the native view.
        setTimeout(function () {
            if (root.style.visibility !== 'hidden') return;
            releaseHover();
            // The runtime restores game input after this acknowledgement, not before closure.
            var focusFields=['SZ2', client, String(closedSequence), noticeInitiator?'rejected':'closed'];
            if(noticeInitiator)focusFields.push(noticeInitiator,noticeToken);
            noticeInitiator=null;noticeToken=null;
            writePacket('focus', focusFields.join('|')).catch(function () {});
        }, 50);
    }
    function writePacket(key, packet) {
        writes = writes.catch(function () {}).then(function () {
            return cfg('uimod.cfg_save', key, packet);
        });
        return writes;
    }
    function send(action, initiator, roster, node, furniture, apiToken) {
        var fields = ['SZ2', client, String(sequence), action];
        if (initiator && roster) {fields.push(initiator, node, roster);if(furniture||apiToken)fields.push(furniture||"none");if(apiToken)fields.push(apiToken);}
        var packet = fields.join('|');
        pendingCommand = packet;
        return writePacket('request', packet);
    }
    function entityId(value) {
        if (value && typeof value === 'object') value = value.entity_id || value.entityId || value.Value;
        return /^\d+$/.test(String(value)) && Number(value) > 0 ? String(value) : null;
    }
    function clickedTarget(t) {
        // Read only explicit target/context fields, never infer from proximity.
        var values = [];
        function visit(object, depth) {
            if (!object || typeof object !== 'object' || depth > 3) return;
            ['target_entity_id', 'targetEntityId', 'target_id', 'targetId', 'entity_id', 'entityId'].forEach(function (key) {
                var value = entityId(object[key]);
                if (value && values.indexOf(value) < 0) values.push(value);
            });
            var direct = entityId(object.target);
            if (direct && values.indexOf(direct) < 0) values.push(direct);
            ['target', 'context', 'payload', 'params', 'data'].forEach(function (key) { visit(object[key], depth + 1); });
        }
        visit(t, 0);
        return values.length === 1 ? values[0] : null;
    }
    window.addEventListener('error', function (event) {
        cfg('uimod.cfg_save', 'ui_error', String(event.message || 'UI error')).catch(function () {});
    });
    cfg('uimod.cfg_save', 'ui_boot', client).catch(function () {});
    cfg('uimod.cfg_save', 'ui_build', '20261114-autonomous-presets-ui-1').catch(function () {});
    function declineStart(initiator,token) {
        if (active) return;
        root.style.visibility = 'hidden';
        updateHitRect();
        if (document.activeElement && typeof document.activeElement.blur === 'function') document.activeElement.blur();
        inzoi.view.hover(false);
        initiator = entityId(initiator);
        if (initiator) {
            var fields=['SZ2',client,String(sequence),'rejected',initiator];
            if(typeof token==='string'&&/^[a-zA-Z0-9_.:+-]+$/.test(token))fields.push(token);
            writePacket('focus',fields.join('|')).catch(function(){});
        }
    }
    window.SceneZOICatalog = window.SceneZOICatalog || {nodes:{}};
    var lastCatalog='', catalogRequest=0, catalogApplied=0;
    function refreshCatalog(){
        var request=++catalogRequest;
        return cfg('uimod.cfg_load','catalog_state').then(function(data){
            var raw=data && data.value!==undefined?data.value:data;
            if(typeof raw!=='string'||!raw)return window.SceneZOICatalog;
            if(raw.length>4194304||!/^(?:[0-9a-f]{2})+$/i.test(raw))throw new Error('Invalid scene catalog snapshot');
            if(request<catalogApplied)return window.SceneZOICatalog;
            catalogApplied=request;
            if(raw===lastCatalog)return window.SceneZOICatalog;
            var parsed=JSON.parse(decodeURIComponent(raw.replace(/../g,function(byte){return '%'+byte;})));
            if(!parsed||!parsed.nodes||typeof parsed.nodes!=='object'||Array.isArray(parsed.nodes))throw new Error('Invalid scene catalog');
            Object.keys(parsed.nodes).forEach(function(id){
                var node=parsed.nodes[id];
                if(!node||node.id!==id||typeof node.label!=='string'||!Array.isArray(node.navigation))throw new Error('Invalid scene catalog node');
            });
            lastCatalog=raw;window.SceneZOICatalog=parsed;return parsed;
        });
    }
    window.SceneZOILocalization.refresh().then(function(){outfits.update();renderNavigation();});
    refreshCatalog().catch(function(){});
    setInterval(function(){if(!active&&!checkingStart)refreshCatalog().catch(function(){});},2000);
    window.SceneZOIControls = {
        bootId: ownClient,
        clickedTarget: clickedTarget,
        refreshCatalog: refreshCatalog,
        decline: declineStart,
        available: function(){return !active && !checkingStart && saveGuard.available();},
        reject: function(message,initiator,token){
            if(active || checkingStart)return;
            noticeInitiator=entityId(initiator);noticeToken=token;currentNode=null;
            openPanel();show(message);
        },
        start: function (entry) {
            var node=entry.node, initiator=entityId(entry.initiator);
            if (!window.SceneZOICatalog.nodes[node]) return Promise.reject(new Error('Unknown requested scene.'));
            if (active || checkingStart || !saveGuard.available()) return Promise.resolve(false);
            var roster=Object.keys(entry.bindings).sort().map(function(role){
                var id=entityId(entry.bindings[role]);
                if (!id || !/^[a-z][a-z0-9_.-]*$/.test(role)) throw new Error('Invalid role assignment');
                return role+':'+id;
            }).join('+');
            checkingStart = true;
            return window.SceneZOILocalization.refresh().then(function(){return inzoi.cli.execute('entity.get_possessed');}).then(decode).then(function(data){
                if (!initiator || entityId(data)!==initiator) {declineStart(initiator);return false;}
                client=ownClient;sequence=++ownSequence;counterBase=0;sessionToken=null;
                hasPlan=false;autoMode=false;autoSpeed=false;lastPlan=null;
                active=true;exiting=false;noticeInitiator=null;noticeToken=null;
                pendingNavigation=null;navigationCount=0;revision=0;currentNode=null;playing=false;
                pendingPlayback=null;playbackCounter=0;acknowledgedPlayback=0;speedIndex=2;gameScale=1;
                heartbeat=0;pendingCommand=null;
                openPanel();show(window.SceneZOILocalization.text('Preparing Scene Mode…'));
                return send('start',initiator,roster,node,entry.furniture,entry.api_token).then(function(){return true;});
            }).catch(function(error){
                if(pendingCommand){show(window.SceneZOILocalization.text('Retrying the scene request…'));return false;}
                if(active){active=false;pendingCommand=null;show(window.SceneZOILocalization.text('Could not request Scene Mode.'));}
                return false;
            }).then(function(started){checkingStart=false;return started;});
        }

    };
    var addonBridge=window.SceneZOIAddonBridge.create({
        read:function(key){return cfg('uimod.cfg_load',key).then(function(r){return r&&r.value!==undefined?r.value:r;});},
        write:writePacket,refresh:refreshCatalog,start:function(entry){return window.SceneZOIControls.start(entry);}});
    setInterval(function(){addonBridge.poll();},250);
    exit.addEventListener('click', function () {
        if (!active) { closePanel(); return; }
        exiting = true; pendingNavigation = null; pendingPlayback = null; playing = false;
        show(window.SceneZOILocalization.text('Exiting and restoring all participants…'));
        send('exit').catch(function () {
            show(window.SceneZOILocalization.text('Retrying Exit and waiting for all participants…'));
        });
    });
    // Ended on purpose or by its own limits: nothing for the player to dismiss.
    var quietEnds = {ok: true, saving: true, character_editor: true, lifetime_expired: true, owner_expired: true,
        goal_unreachable: true, required_stage_unavailable: true, no_progress: true, playback_budget_exceeded: true};
    var errors = {
        transition_destination_error: window.SceneZOILocalization.text('The transition finished, but its destination could not load. The scene has ended.'),
        busy: window.SceneZOILocalization.text('A participant is already owned by another scene.'),
        binding_error: window.SceneZOILocalization.text('The selected Zois do not match this scene’s roles.'),
        body_type: window.SceneZOILocalization.text('This scene requires compatible adult body skeletons.'),
        eligibility: window.SceneZOILocalization.text('The selected Zois do not meet the participant requirements for this scene.'),
        possession_changed: window.SceneZOILocalization.text('The controlled Zoi changed before the scene could start.'),
        entry_error: window.SceneZOILocalization.text('Scene entry failed. The diagnostic records contain the reason.'),
        prepare_error: window.SceneZOILocalization.text('A participant could not enter Scene Mode.'),
        prepare_timeout: window.SceneZOILocalization.text('The current tasks did not finish or all participants did not acknowledge preparation.'),
        appearance_timeout: window.SceneZOILocalization.text('The participants’ appearance did not finish updating. The blocking clothing slot or animation state was recorded in the diagnostic log.'),
        attachment_timeout: window.SceneZOILocalization.text('The scene attachment did not finish preparing. Details were recorded in the diagnostic log.'),
        playback_error: window.SceneZOILocalization.text('Scene playback failed; cleanup was requested.'),
        ui_disconnected: window.SceneZOILocalization.text('The scene ended because its control panel disconnected.'),
        outfit_timeout: window.SceneZOILocalization.text('The outfit did not finish updating. Cleanup was requested.'),
        restore_error: window.SceneZOILocalization.text('Cleanup reported an error. Check the diagnostic records before continuing.'),
        restore_timeout: window.SceneZOILocalization.text('Scene cleanup did not finish. Check the diagnostic records.'),
        runtime_error: window.SceneZOILocalization.text('The scene stopped after a runtime error. Cleanup was requested.')
    };
    setInterval(function () {
        outfits.retry();
        // Retry the same scene ID until acknowledged; a retry must never create a second scene.
        if (pendingCommand) writePacket('request', pendingCommand).catch(function () {});
        if (pendingNavigation && !exiting) writePacket('navigation', pendingNavigation).catch(function () {});
        if (pendingPlayback && !exiting) writePacket('playback', pendingPlayback).catch(function () {});
        if (active && !exiting) {
            writePacket('heartbeat', ['SZ2', client, String(sequence), 'heartbeat', String(++heartbeat)].join('|')).catch(function () {});
            if (window.SceneZOIPanel && window.SceneZOIPanel.snapshot) {
                var panel = window.SceneZOIPanel.snapshot();
                panel.client=client;panel.sequence=sequence;panel.playing=playing;panel.exiting=exiting;
                panel.node=currentNode && currentNode.id || null;panel.visibility=root.style.visibility;
                writePacket('panel_state', JSON.stringify(panel)).catch(function () {});
            }
        }
    }, 1000);
    setInterval(function () {
        saveGuard.poll();
        // The generated window scaffold can report layout later; keep its hidden hit area off-screen.
        if (root.style.visibility === 'hidden') updateHitRect();
        if (reading) return;
        reading = true;
        cfg('uimod.cfg_load', 'state').then(function (data) {
            var value = data && data.value !== undefined ? data.value : data;
            if (typeof value !== 'string' || value === lastState) return;
            refreshCatalog().then(function(){renderNavigation();}).catch(function(){});
            lastState = value;
            var fields = value.split('|');
            // Late status from an older panel/session must not close or reset the current one.
            if (fields[0] !== 'SZ2' || fields[1] !== client || fields[2] !== String(sequence)) return;
            var phase = fields[3], code = fields[4];
            // Playing/Preparing may arrive after Exit; preserve the pending Exit and its retries.
            if (phase === 'playing') {
                if (!exiting) { pendingCommand = null; playing = true; show(playingMessage()); }
            }
            else if (phase === 'preparing') {
                if (!exiting) { pendingCommand = null; playing = false; show(window.SceneZOILocalization.text('Preparing all participants…')); }
            }
            else if (phase === 'exiting') { exiting = true; pendingNavigation = null; pendingPlayback = null; playing = false; show(window.SceneZOILocalization.text('Restoring all participants…')); }
            else {
                active = false; exiting = false; pendingNavigation = null; pendingPlayback = null; playing = false;
                pendingCommand = null;
                if (phase === 'idle' && quietEnds[code]) closePanel();
                else show(errors[code] || window.SceneZOILocalization.text(window.SceneZOILocalization.text('Scene ended: {code}'),{code:code}));
            }
        }).catch(function () {}).then(function () { reading = false; });
    }, 250);
    // The panel follows the controlled Zoi: it shows that Zoi's scene, or nothing.
    function detachPanel() {
        sessionToken = null;
        if (!active) return;
        active = false; exiting = false; playing = false; currentNode = null;
        pendingCommand = null; pendingNavigation = null; pendingPlayback = null;
        client = ownClient; sequence = ownSequence; counterBase = 0;
        hasPlan = false; autoMode = false; autoSpeed = false; lastPlan = null;
        renderAutoMode();
        closePanel();
    }
    function attachPanel(f) {
        client = f[3]; sequence = Number(f[4]) || 0;
        active = true; exiting = f[7] === 'exiting'; playing = f[7] === 'playing'; heartbeat = 0;
        pendingCommand = null; pendingNavigation = null; pendingPlayback = null;
        noticeInitiator = null; noticeToken = null; lastState = ''; gameScale = 1;
        hasPlan = false; autoMode = false; autoSpeed = false; lastPlan = null;
        // Counters must beat anything this session has already acknowledged from an earlier binding.
        counterBase = Math.floor(Date.now() / 1000);
        navigationCount = counterBase; playbackCounter = counterBase; acknowledgedPlayback = 0;
        revision = Number(f[5]) || 0;
        currentNode = window.SceneZOICatalog.nodes[f[6]] || null;
        refreshCatalog().then(function () {
            currentNode = window.SceneZOICatalog.nodes[f[6]] || currentNode;
            if (active) show(playing ? playingMessage() : window.SceneZOILocalization.text('Preparing all participants…'));
        }).catch(function () {});
        openPanel();
        show(playing ? playingMessage() : window.SceneZOILocalization.text('Preparing all participants…'));
    }
    function applyFocus(f) {
        if (f[0] !== 'SZ2') return;
        if (f[2] === 'none') { detachPanel(); return; }
        if (active && client === f[3] && String(sequence) === f[4] && (!sessionToken || sessionToken === f[2])) {
            sessionToken = f[2];
            return;
        }
        sessionToken = f[2];
        attachPanel(f);
    }
    var readingFocus = false;
    setInterval(function () {
        if (readingFocus) return;
        readingFocus = true;
        cfg('uimod.cfg_load', 'focus_session').then(function (data) {
            var value = data && data.value !== undefined ? data.value : data;
            if (typeof value !== 'string' || value === lastFocus) return;
            lastFocus = value;
            applyFocus(value.split('|'));
        }).catch(function () {}).then(function () { readingFocus = false; });
    }, 250);
    function escapeText(value) {
        return String(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
    }
    function renderAutoMode() {
        if (!autoButton) return;
        autoButton.style.display = hasPlan && active && !exiting ? 'block' : 'none';
        autoButton.textContent = window.SceneZOILocalization.text('Auto-mode');
        if (autoButton.classList.toggle) autoButton.classList.toggle('selected', autoMode);
        autoButton.setAttribute('aria-pressed', autoMode ? 'true' : 'false');
    }
    function applyPlan(value) {
        var fields = value.split('|');
        if (fields[0] !== 'SZ2' || fields[1] !== client || fields[2] !== String(sequence)) return;
        hasPlan = fields[3] === '1'; autoMode = hasPlan && fields[4] === '1';
        autoSpeed = autoMode && fields[7] === '1';
        renderAutoMode(); renderNavigation(); renderPlayback();
    }
    function ensureAutoButton() {
        if (autoButton || !navigation || !navigation.parentNode || !navigation.parentNode.insertBefore) return;
        autoButton = document.createElement('button');
        autoButton.id = 'scene-auto-mode'; autoButton.type = 'button';
        navigation.parentNode.insertBefore(autoButton, navigation);
        autoButton.addEventListener('click', function () {
            if (!active || exiting || !hasPlan) return;
            var enabled = autoMode ? '0' : '1';
            autoCount = Math.max(autoCount + 1, counterBase + 1);
            writePacket('auto_mode', ['SZ2', client, String(sequence), 'auto_mode', String(autoCount), enabled, String(revision)].join('|')).catch(function () {});
        });
    }
    var readingPlan = false;
    setInterval(function () {
        if (!active || readingPlan) return;
        readingPlan = true;
        cfg('uimod.cfg_load', 'plan_state').then(function (data) {
            var value = data && data.value !== undefined ? data.value : data;
            if (typeof value !== 'string' || value === lastPlan) return;
            lastPlan = value;
            applyPlan(value);
        }).catch(function () {}).then(function () { readingPlan = false; });
    }, 250);
    function renderNavigation() {
        var html = '';
        ensureAutoButton();
        if (active && playing && !exiting && !pendingNavigation && !autoMode && !outfits.busy() && currentNode && currentNode.kind !== 'transition') {
            html = currentNode.navigation.map(function (edge) {
                var target = window.SceneZOICatalog.nodes[edge.target];
                var caption = typeof edge.label === 'string' && edge.label.trim()
                    ? edge.label : target ? target.label : edge.target;
                return '<button type="button" data-option="' + escapeText(edge.id) + '">' + escapeText(caption) + '</button>';
            }).join('');
        }
        // Preserve the user's scroll position while status/clock polling continues.
        if (html !== navigationMarkup) { navigation.innerHTML = html; navigationMarkup = html; }
        updateHitRect();
    }
    navigation.addEventListener('click', function (event) {
        var option = event.target && event.target.getAttribute('data-option');
        if (!option || !sessionToken || !active || !playing || exiting || pendingNavigation || autoMode || outfits.busy() || !currentNode || currentNode.kind === 'transition') return;
        if (!currentNode.navigation.some(function (edge) { return edge.id === option; })) return;
        pendingNavigation = ['SZ2', client, String(sequence), 'navigate', String(++navigationCount), option, String(revision), sessionToken].join('|');
        writePacket('navigation', pendingNavigation).catch(function () {});
        show(window.SceneZOILocalization.text('Changing scene…'));
    });
    var readingNavigation = false;
    setInterval(function () {
        if (!active || exiting || readingNavigation) return;
        readingNavigation = true;
        cfg('uimod.cfg_load', 'navigation_state').then(function (data) {
            if (!active || exiting) return;
            var value = data && data.value !== undefined ? data.value : data;
            if (typeof value !== 'string') return;
            var fields = value.split('|');
            if (fields[0] !== 'SZ2' || fields[1] !== client || fields[2] !== String(sequence)) return;
            if (!sessionToken || fields[7] !== sessionToken) return;
            var nextRevision = Number(fields[3]), acknowledged = Number(fields[5]);
            if (nextRevision < revision || !window.SceneZOICatalog.nodes[fields[4]]) return;
            if (pendingNavigation && acknowledged < navigationCount) return;
            revision = nextRevision; currentNode = window.SceneZOICatalog.nodes[fields[4]];
            if (pendingNavigation && acknowledged === navigationCount) pendingNavigation = null;
            if (fields[6] === 'task_route_error') show(window.SceneZOILocalization.text('The automatic scene could not load. The current scene continues.'));
            else if (fields[6] === 'navigation_error') show(window.SceneZOILocalization.text('That scene could not load. The current scene continues.'));
            else if (fields[6] === 'navigation_locked') show(playingMessage());
            else if (fields[6] === 'stale_navigation') show(window.SceneZOILocalization.text('Scene navigation changed. Choose again.'));
            else if (playing) show(playingMessage());
            renderNavigation();
        }).catch(function () {}).then(function () { readingNavigation = false; });
    }, 300);
    function playingMessage() {
        return gameScale === 0 ? window.SceneZOILocalization.text('Paused with the game clock') : currentNode && currentNode.kind === 'transition' ? window.SceneZOILocalization.text('Transition in progress') : '';
    }
    function renderPlayback() {
        speedLabel.textContent = 'x' + speeds[speedIndex - 1].toFixed(2);
        speedDown.disabled = !active || !playing || exiting || autoSpeed || speedIndex === 1;
        speedUp.disabled = !active || !playing || exiting || autoSpeed || speedIndex === speeds.length;
        speedDots.innerHTML = speeds.map(function (_, index) {
            return '<span class="speed-dot' + (index + 1 === speedIndex ? ' selected' : '') + '"></span>';
        }).join('');
    }
    function selectSpeed(index) {
        if (!active || !playing || exiting || autoSpeed || index < 1 || index > speeds.length || index === speedIndex) return;
        speedIndex = index;
        pendingPlayback = ['SZ2', client, String(sequence), 'speed', String(++playbackCounter), String(index)].join('|');
        writePacket('playback', pendingPlayback).catch(function () {});
        renderPlayback();
    }
    speedDown.addEventListener('click', function () { selectSpeed(speedIndex - 1); });
    speedUp.addEventListener('click', function () { selectSpeed(speedIndex + 1); });
    var readingPlayback = false;
    setInterval(function () {
        if (!active || exiting || readingPlayback) return;
        readingPlayback = true;
        cfg('uimod.cfg_load', 'playback_state').then(function (data) {
            if (!active || exiting) return;
            var value = data && data.value !== undefined ? data.value : data;
            if (typeof value !== 'string') return;
            var fields = value.split('|');
            if (fields[0] !== 'SZ2' || fields[1] !== client || fields[2] !== String(sequence)) return;
            var acknowledged = Number(fields[3]), index = Number(fields[4]), scale = Number(fields[5]);
            if (!Number.isInteger(acknowledged) || acknowledged < acknowledgedPlayback ||
                !Number.isInteger(index) || index < 1 || index > speeds.length || !Number.isFinite(scale) || scale < 0) return;
            if (pendingPlayback && acknowledged < playbackCounter) return;
            acknowledgedPlayback = acknowledged;
            if (pendingPlayback && acknowledged >= playbackCounter) pendingPlayback = null;
            speedIndex = index; gameScale = scale;
            renderPlayback();
            if (playing && !pendingNavigation) status.textContent = playingMessage();
        }).catch(function () {}).then(function () { readingPlayback = false; });
    }, 350);
    renderPlayback();
    window.addEventListener('beforeunload', function () { if (active) send('exit'); });
})();
