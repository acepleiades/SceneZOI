// This transient integration view owns no scene controls, focus or session timer.
(function () {
    'use strict';
    var writing = false, ready = false;
    var launcherId = 'launcher.' + Date.now() + '.' + Math.floor(Math.random() * 1000000);
    var build = '20261112-launcher-handshake-1';
    function decode(result) {
        if (result && result.success === false) throw new Error(result.message);
        var value = result && result.data !== undefined ? result.data : result;
        return typeof value === 'string' ? JSON.parse(value) : value;
    }
    function cfg(command, key, value) {
        var args = {mod_id: 'SceneZOI_93C44199', section: 'scenezoi_runtime', key: key};
        if (value !== undefined) args.value = value;
        return inzoi.cli.execute(command, args).then(decode);
    }
    function close() {
        writing = false;
        // Native interaction-menu activation toggles a view. Retire this launcher
        // after every dispatch so the next activation always opens it once.
        inzoi.view.hide();
    }
    function waitReady(attempt) {
        return Promise.all([cfg('uimod.cfg_load','selection_host_ready'),cfg('uimod.cfg_load','selection_ui_ready')]).catch(function(){return [];}).then(function(values){
            var packets=values.map(function(v){return String(v && v.value!==undefined?v.value:v || '').split('|');});
            var host=packets[0]||[], receiver=packets[1]||[];
            if(host[0]==='SZ2' && host[2]==='ready' && receiver[0]==='SZ2' && receiver[1]===host[1] &&
                receiver[2]==='ready' && receiver[3] && receiver[4]===launcherId)return receiver[3];
            if(attempt>=50)throw new Error('Scene UI did not become ready');
            return new Promise(function(resolve){setTimeout(resolve,100);}).then(function(){return waitReady(attempt+1);});
        });
    }
    function announce(){
        // Get an acknowledgement from the current controls before hiding this view.
        cfg('uimod.cfg_save','selection_launcher_ready',['SZ2',launcherId,'waiting',build].join('|')).then(function(){
            return waitReady(0);
        }).then(function(receiver){
            return cfg('uimod.cfg_save','selection_launcher_ready',['SZ2',launcherId,'ready',receiver,build].join('|'));
        }).then(function(){
            ready=true;
            if(!writing)close();
        },function(){setTimeout(announce,500);});
    }
    inzoi.trigger.onActivated(function (event) {
        if(event && event.triggerId==='scenezoi_starter_lifetime'){if(ready && !writing)close();return;}
        if (!event || event.triggerId !== 'scenezoi_demo' && event.triggerId !== 'scenezoi_furniture' || writing) return;
        writing = true;
        return window.SceneZOILocalization.refresh().then(function(){return inzoi.cli.execute('entity.get_possessed');}).then(decode).then(function (current) {
            var controlled = String(current.entity_id);
            if (!/^\d+$/.test(controlled) || event.triggerId==='scenezoi_demo' && String(event.targetEntityId) !== controlled) return;
            var bed=event.triggerId==='scenezoi_furniture'?String(event.targetEntityId):'none';
            if(bed!=='none' && !/^\d+$/.test(bed))return;
            return waitReady(0).then(function(){return cfg('uimod.cfg_load', 'state');}).then(function (data) {
                var raw = data && data.value !== undefined ? data.value : data;
                var phase = String(raw || '').split('|')[3];
                if (phase && phase !== 'idle' && phase !== 'error') {
                    return inzoi.cli.execute('toast.show',{message:window.SceneZOILocalization.text('A SceneZOI scene is already in progress. End it before starting another.'),lifetime:5,immediate:true});
                }
                var token = 'pick.' + Date.now() + '.' + Math.floor(Math.random() * 1000000);
                return cfg('uimod.cfg_save', 'selection_request', ['SZ2', token, 'open', controlled, bed].join('|'));
            });
        }).then(close, close);
    });
    // Warm the callback at load, before exposing the menu; never cold-create it on the first click.
    window.SceneZOILocalization.refresh();
    announce();
})();
