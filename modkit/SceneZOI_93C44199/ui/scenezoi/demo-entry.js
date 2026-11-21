// Native picker handoff. Resolve the returned roster into explicit scene roles.
(function(){
    'use strict';
    var pending=null;
    function decode(r){if(r && r.success===false)throw new Error(r.message);var d=r && r.data!==undefined?r.data:r;return typeof d==='string'?JSON.parse(d):d;}
    function cfg(cmd,key,value){var args={mod_id:wf.MOD_ID,section:'scenezoi_runtime',key:key};if(value!==undefined)args.value=value;return inzoi.cli.execute(cmd,args).then(decode);}
    function stop(p){if(pending!==p)return;pending=null;if(p.pairRequest)cfg('uimod.cfg_save','selection_pair',['SZ2',p.token,'cancel'].join('|')).catch(function(){});window.SceneZOIControls.decline(p.initiator,p.token);}
    function writePairReply(p){
        var packet=p.pairReply;if(!packet || pending!==p)return Promise.resolve();
        return cfg('uimod.cfg_save','selection_pair',packet).then(function(){if(p.pairReply===packet)p.pairReply=null;});
    }
    function selected(p,ids,node,roster,furniture,pairId){
        if(ids.length<1 || new Set(ids).size!==ids.length || ids[0]!==p.initiator){stop(p);return Promise.resolve();}
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
            pending=null;return window.SceneZOIControls.start({initiator:p.initiator,node:node,bindings:bindings,furniture:furniture==='none'?null:furniture,furniture_pair_id:pairId==='none'?null:pairId});
        }).catch(function(){if(pending===p)stop(p);else window.SceneZOIControls.decline(p.initiator,p.token);});
    }
    function poll(){
        var p=pending;if(!p || p.reading)return Promise.resolve();p.reading=true;
        return (p.pairReply?writePairReply(p):Promise.resolve()).then(function(){return cfg('uimod.cfg_load','selection_state');}).then(function(data){
            var raw=data && data.value!==undefined?data.value:data;
            var f=String(raw || '').split('|');
            if(pending!==p || f[0]!=='SZ2' || f[1]!==p.token)return;
            if(f[2]==='choosing_pair'){
                if(p.pairRequest===raw)return;p.pairRequest=raw;
                var choices=JSON.parse(decodeURIComponent(String(f[8]||'').replace(/../g,function(byte){return '%'+byte;})));
                return window.SceneZOIControls.chooseFurniturePair(choices,p.initiator,p.token).then(function(id){
                    if(pending!==p)return;
                    // Keep a failed reply for the next poll. Repeating this exact
                    // token/choice is safe, and does not ask the player to click again.
                    p.pairReply=['SZ2',p.token,id?'choose':'cancel'].concat(id?[id]:[]).join('|');
                    return writePairReply(p);
                });
            }
            if(f[2]==='selected')return selected(p,f[3].split('+'),f[4],f[5],f[6],f[7]);
            if(f[2]==='cancelled' || f[2]==='error' || f[2]==='unavailable')stop(p);
        }).catch(function(){}).then(function(){p.reading=false;});
    }
    var lastRequest, hostToken, launcherToken, lastReadinessCheck=0, watching=false;
    function value(data){return String(data && data.value!==undefined?data.value:data || '');}
    function readRequest(){
        if(pending)return poll();
        return cfg('uimod.cfg_load','selection_request').then(function(data){
            var raw=value(data);if(raw===lastRequest)return;lastRequest=raw;
            var f=raw.split('|');
            if(f[0]!=='SZ2' || f[2]!=='open' || !/^\d+$/.test(f[3]) || !window.SceneZOIControls.available())return;
            pending={token:f[1],initiator:f[3]};return poll();
        });
    }
    function watch(){
        if(watching)return Promise.resolve();
        watching=true;
        var checkReadiness=!hostToken || !window.SceneZOIControls.sceneActive() || Date.now()-lastReadinessCheck>=1000;
        if(checkReadiness)lastReadinessCheck=Date.now();
        var result=checkReadiness?refreshReadiness():readRequest();
        return result.catch(function(){}).then(function(){watching=false;});
    }
    function refreshReadiness(){
        return Promise.all([cfg('uimod.cfg_load','selection_host_ready'),
            cfg('uimod.cfg_load','selection_launcher_ready').catch(function(){return null;})]).then(function(data){
            var host=value(data[0]).split('|'), launcher=value(data[1]).split('|');
            if(host[0]!=='SZ2' || host[2]!=='ready')return;
            var newHost=hostToken!==host[1];
            var token=launcher[0]==='SZ2' && /^launcher\.[0-9.]+$/.test(launcher[1])?launcher[1]:'none';
            if(newHost || launcherToken!==token){
                if(newHost && pending)stop(pending);
                var request=newHost?cfg('uimod.cfg_load','selection_request'):Promise.resolve(lastRequest);
                return request.then(function(raw){
                    var ready=['SZ2',host[1],'ready',window.SceneZOIControls.bootId,token].join('|');
                    return cfg('uimod.cfg_save','selection_ui_ready',ready).then(function(){
                        // Commit the host identity only after the readiness write.
                        // A failed cfg read/write must retry; old Start packets stay retired.
                        lastRequest=value(raw);hostToken=host[1];launcherToken=token;
                    });
                });
            }
            // Consume requests made during a scene so they cannot open a picker after Exit.
            return readRequest();
        });
    }
    watch();
    setInterval(watch,200);
})();
