(function () {
    'use strict';
    var section = 'scenezoi_runtime';
    var client = 'ui.' + Date.now() + '.' + Math.floor(Math.random() * 1000000);
    var sequence = 0;
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
        '<div id="scene-navigation" aria-label="Scene navigation"></div>' +
        '<div id="scene-footer"><button id="scene-exit" type="button">Exit</button>' +
        '<div id="scene-speed" aria-label="Animation playback speed">' +
        '<button id="speed-down" type="button" aria-label="Slower animation">&lt;</button>' +
        '<div id="speed-display"><span id="speed-label">x1.00</span><div id="speed-dots" aria-hidden="true"></div></div>' +
        '<button id="speed-up" type="button" aria-label="Faster animation">&gt;</button></div></div>';
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
            revision:revision, pendingNavigation:pendingNavigation}; },
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
        stopForSave:function(){if(active){exiting=true;playing=false;pendingNavigation=null;pendingPlayback=null;send('save').catch(function(){});}},
        stopForLoad:function(){if(active){exiting=true;send('exit').catch(function(){});}}});
    function show(message) {
        if (tasks) tasks.update();
        outfits.update();
        root.style.visibility = 'visible';
        updateHitRect();
        status.textContent = message;
        exit.textContent = active ? 'Exit' : 'Dismiss';
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
    cfg('uimod.cfg_save', 'ui_build', '20261104-addons-ui-1').catch(function () {});
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
    refreshCatalog().catch(function(){});
    setInterval(function(){if(!active&&!checkingStart)refreshCatalog().catch(function(){});},2000);
    window.SceneZOIControls = {
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
            return inzoi.cli.execute('entity.get_possessed').then(decode).then(function(data){
                if (!initiator || entityId(data)!==initiator) {declineStart(initiator);return false;}
                active=true;exiting=false;noticeInitiator=null;noticeToken=null;sequence++;
                pendingNavigation=null;navigationCount=0;revision=0;currentNode=null;playing=false;
                pendingPlayback=null;playbackCounter=0;acknowledgedPlayback=0;speedIndex=2;gameScale=1;
                heartbeat=0;pendingCommand=null;
                saveGuard.begin(sequence,Object.keys(entry.bindings).map(function(role){return entityId(entry.bindings[role]);}));
                openPanel();show('Preparing Scene Mode…');
                return send('start',initiator,roster,node,entry.furniture,entry.api_token).then(function(){return true;});
            }).catch(function(error){
                if(pendingCommand){show('Retrying the scene request…');return false;}
                if(active){active=false;pendingCommand=null;show(error.message || 'Could not request Scene Mode.');}
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
        show('Exiting and restoring all participants…');
        send('exit').catch(function () {
            show('Retrying Exit and waiting for all participants…');
        });
    });
    var errors = {
        transition_destination_error: 'The transition finished, but its destination could not load. The scene has ended.',
        busy: 'A participant is already owned by another scene.',
        binding_error: 'The selected Zois do not match this scene’s roles.',
        body_type: 'This demo supports the adult body skeletons used by the animation rigs.',
        eligibility: 'The selected Zois do not meet the participant requirements for this scene.',
        possession_changed: 'The controlled Zoi changed before the scene could start.',
        entry_error: 'Scene entry failed. The diagnostic records contain the reason.',
        prepare_error: 'A participant could not enter Scene Mode.',
        prepare_timeout: 'The current tasks did not finish or all participants did not acknowledge preparation.',
        appearance_timeout: 'The participants’ appearance did not finish updating. The blocking clothing slot or animation state was recorded in the diagnostic log.',
        attachment_timeout: 'The scene attachment did not finish preparing. Details were recorded in the diagnostic log.',
        playback_error: 'Scene playback failed; cleanup was requested.',
        ui_disconnected: 'The scene ended because its control panel disconnected.',
        outfit_timeout: 'The outfit did not finish updating. Cleanup was requested.',
        restore_error: 'Cleanup reported an error. Check the diagnostic records before continuing.',
        restore_timeout: 'Scene cleanup did not finish. Check the diagnostic records.',
        runtime_error: 'The scene stopped after a runtime error. Cleanup was requested.'
    };
    setInterval(function () {
        outfits.retry();
        // Retry the same scene ID until acknowledged; a retry must never create a second scene.
        if (pendingCommand) writePacket('request', pendingCommand).catch(function () {});
        if (pendingNavigation && !exiting) writePacket('navigation', pendingNavigation).catch(function () {});
        if (pendingPlayback && !exiting) writePacket('playback', pendingPlayback).catch(function () {});
        if (active && !exiting) {
            writePacket('heartbeat', ['SZ2', client, String(sequence), 'heartbeat', String(++heartbeat)].join('|')).catch(function () {});
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
                if (!exiting) { pendingCommand = null; playing = false; show('Preparing all participants…'); }
            }
            else if (phase === 'exiting') { exiting = true; pendingNavigation = null; pendingPlayback = null; playing = false; show('Restoring all participants…'); }
            else {
                active = false; exiting = false; pendingNavigation = null; pendingPlayback = null; playing = false;
                pendingCommand = null;
                if (phase === 'idle' && (code === 'ok' || code === 'controller_too_far' || code === 'saving')) {saveGuard.end(true);closePanel();}
                else {saveGuard.end(false);show(errors[code] || ('Scene ended: ' + code));}
            }
        }).catch(function () {}).then(function () { reading = false; });
    }, 250);
    function escapeText(value) {
        return String(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
    }
    function renderNavigation() {
        var html = '';
        if (active && playing && !exiting && !pendingNavigation && !outfits.busy() && currentNode && currentNode.kind !== 'transition') {
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
        if (!option || !active || !playing || exiting || pendingNavigation || outfits.busy() || !currentNode || currentNode.kind === 'transition') return;
        if (!currentNode.navigation.some(function (edge) { return edge.id === option; })) return;
        pendingNavigation = ['SZ2', client, String(sequence), 'navigate', String(++navigationCount), option, String(revision)].join('|');
        writePacket('navigation', pendingNavigation).catch(function () {});
        show('Changing scene…');
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
            var nextRevision = Number(fields[3]), acknowledged = Number(fields[5]);
            if (nextRevision < revision || !window.SceneZOICatalog.nodes[fields[4]]) return;
            if (pendingNavigation && acknowledged < navigationCount) return;
            revision = nextRevision; currentNode = window.SceneZOICatalog.nodes[fields[4]];
            if (pendingNavigation && acknowledged === navigationCount) pendingNavigation = null;
            if (fields[6] === 'task_route_error') show('The automatic scene could not load. The current scene continues.');
            else if (fields[6] === 'navigation_error') show('That scene could not load. The current scene continues.');
            else if (fields[6] === 'navigation_locked') show(playingMessage());
            else if (fields[6] === 'stale_navigation') show('Scene navigation changed. Choose again.');
            else if (playing) show(playingMessage());
            renderNavigation();
        }).catch(function () {}).then(function () { readingNavigation = false; });
    }, 300);
    function playingMessage() {
        return gameScale === 0 ? 'Paused with the game clock' : currentNode && currentNode.kind === 'transition' ? 'Transition in progress' : '';
    }
    function renderPlayback() {
        speedLabel.textContent = 'x' + speeds[speedIndex - 1].toFixed(2);
        speedDown.disabled = !active || !playing || exiting || speedIndex === 1;
        speedUp.disabled = !active || !playing || exiting || speedIndex === speeds.length;
        speedDots.innerHTML = speeds.map(function (_, index) {
            return '<span class="speed-dot' + (index + 1 === speedIndex ? ' selected' : '') + '"></span>';
        }).join('');
    }
    function selectSpeed(index) {
        if (!active || !playing || exiting || index < 1 || index > speeds.length || index === speedIndex) return;
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
