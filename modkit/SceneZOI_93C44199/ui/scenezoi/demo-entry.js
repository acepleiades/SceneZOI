// Temporary demo integration: self-click, native selection, then explicit framework roles.
(function(){
    'use strict';
    var pending=null;
    function decode(r){if(r && r.success===false)throw new Error(r.message);var d=r && r.data!==undefined?r.data:r;return typeof d==='string'?JSON.parse(d):d;}
    function cfg(cmd,key,value){var args={mod_id:wf.MOD_ID,section:'scenezoi_runtime',key:key};if(value!==undefined)args.value=value;return inzoi.cli.execute(cmd,args).then(decode);}
    function stop(p){if(pending!==p)return;pending=null;window.SceneZOIControls.decline(p.initiator,p.token);}
    function selected(p,ids,node,roster,furniture){
        if(ids.length<2 || new Set(ids).size!==ids.length || ids[0]!==p.initiator){stop(p);return Promise.resolve();}
        var bindings={},seen=new Set();
        if(typeof node!=='string'||typeof roster!=='string'){stop(p);return Promise.resolve();}
        for(var item of roster.split('+')){
            var pair=item.split(':');
            if(pair.length!==2 || !/^[a-z][a-z0-9_.-]*$/.test(pair[0]) || bindings[pair[0]] || ids.indexOf(pair[1])<0 || seen.has(pair[1])){stop(p);return Promise.resolve();}
            bindings[pair[0]]=pair[1];seen.add(pair[1]);
        }
        if(seen.size!==ids.length){stop(p);return Promise.resolve();}
        var ready=window.SceneZOIControls.refreshCatalog?window.SceneZOIControls.refreshCatalog():Promise.resolve();
        return ready.then(function(){
            if(pending!==p)return false;
            pending=null;return window.SceneZOIControls.start({initiator:p.initiator,node:node,bindings:bindings,furniture:furniture==='none'?null:furniture});
        }).catch(function(){if(pending===p)stop(p);else window.SceneZOIControls.decline(p.initiator,p.token);});
    }
    function poll(){
        var p=pending;if(!p || p.reading)return Promise.resolve();p.reading=true;
        return cfg('uimod.cfg_load','selection_state').then(function(data){
            var raw=data && data.value!==undefined?data.value:data;
            var f=String(raw || '').split('|');
            if(pending!==p || f[0]!=='SZ2' || f[1]!==p.token)return;
            if(f[2]==='selected')return selected(p,f[3].split('+'),f[4],f[5],f[6]);
            if(f[2]==='cancelled' || f[2]==='error' || f[2]==='unavailable')stop(p);
        }).catch(function(){}).then(function(){p.reading=false;});
    }
    var lastRequest, hostToken, watching=false;
    function value(data){return String(data && data.value!==undefined?data.value:data || '');}
    function watch(){
        if(watching)return Promise.resolve();
        watching=true;
        return cfg('uimod.cfg_load','selection_host_ready').then(function(data){
            var host=value(data).split('|');
            if(host[0]!=='SZ2' || host[2]!=='ready')return;
            if(hostToken!==host[1]){
                if(pending)stop(pending);
                return cfg('uimod.cfg_load','selection_request').then(function(raw){
                    return cfg('uimod.cfg_save','selection_ui_ready',['SZ2',host[1],'ready','none'].join('|')).then(function(){
                        // Commit only after acknowledgement succeeds, so a failed
                        // read/write retries rather than hiding Start forever.
                        lastRequest=value(raw);hostToken=host[1];
                    });
                });
            }
            if(pending)return poll();
            return cfg('uimod.cfg_load','selection_request').then(function(data){
                var raw=value(data);if(raw===lastRequest)return;lastRequest=raw;
                var f=raw.split('|');
                if(f[0]!=='SZ2' || f[2]!=='open' || !/^\d+$/.test(f[3]) || !window.SceneZOIControls.available())return;
                pending={token:f[1],initiator:f[3]};return poll();
            });
        }).catch(function(){}).then(function(){watching=false;});
    }
    watch();
    setInterval(watch,200);
})();
