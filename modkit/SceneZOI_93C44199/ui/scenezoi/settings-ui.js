(function () {
    'use strict';
    function createGroup(options,group,keys,labels,note,min,max,format) {
        format=format||{unit:'%',initial:100};
        function unit(){return format.translated?window.SceneZOILocalization.text(format.unit):format.unit;}
        function valueText(value){return value+(format.translated?' ':'')+unit();}
        var container=options.container, session='', values=keys.map(function(){return format.initial;}), count=0, ack=0, pending=null;
        var ready=false, serverBusy=true, reading=false, dragging=null, message='';
        var hint=note?'<p id="settings-hint-'+group+'" class="audio-settings-note" data-i18n="'+note+'">'+window.SceneZOILocalization.html(note)+'</p>':'';
        container.innerHTML=hint+keys.map(function(key,i){
            if(format.toggle)return '<button id="setting-toggle-'+key+'" class="debug-start-toggle" type="button" role="switch" aria-checked="false"'+(note?' aria-describedby="settings-hint-'+group+'"':'')+'>'+
                '<span class="debug-switch-track" aria-hidden="true"><span class="debug-switch-thumb"></span></span>'+
                '<span class="debug-start-label" data-i18n="'+labels[i]+'">'+window.SceneZOILocalization.html(labels[i])+'</span></button>';
            return '<div class="audio-setting"><label data-i18n="'+labels[i]+'" id="volume-label-'+key+'" for="volume-number-'+key+'">'+window.SceneZOILocalization.html(labels[i])+'</label>'+
                '<div class="audio-setting-row"><div id="volume-slider-'+key+'" class="volume-slider" role="slider" tabindex="0" aria-labelledby="volume-label-'+key+'" aria-valuemin="'+min+'" aria-valuemax="'+max+'">'+
                '<span class="volume-track"></span><span id="volume-fill-'+key+'" class="volume-fill"></span><span id="volume-thumb-'+key+'" class="volume-thumb"></span></div>'+
                '<input id="volume-number-'+key+'" type="text" inputmode="numeric" maxlength="3" aria-labelledby="volume-label-'+key+'" autocomplete="off"><span'+(format.translated?' data-i18n="'+format.unit+'"':'')+'>'+window.SceneZOILocalization.html(format.unit)+'</span></div></div>';
        }).join('')+'<div id="settings-status-'+group+'" role="status" aria-live="polite"></div>';
        var sliders=format.toggle?[]:keys.map(function(k){return document.getElementById('volume-slider-'+k);});
        var inputs=keys.map(function(k){return document.getElementById((format.toggle?'setting-toggle-':'volume-number-')+k);});
        var status=document.getElementById('settings-status-'+group);
        function state(){return options.state();}
        function available(){var s=state();return ready && !serverBusy && s.active && !s.exiting && !s.pendingNavigation;}
        function update(){
            var s=state(),key=s.client+':'+s.sequence;
            if(key!==session){session=key;values=keys.map(function(){return format.initial;});count=s.counterBase||0;ack=0;pending=null;ready=false;serverBusy=true;dragging=null;message='';}
            if(!s.active || s.exiting){pending=null;dragging=null;}
            if(!options.visible())dragging=null;
            var enabled=available();
            keys.forEach(function(k,i){
                inputs[i].disabled=!enabled;
                if(format.toggle){inputs[i].setAttribute('aria-checked',String(values[i]===1));return;}
                sliders[i].setAttribute('aria-disabled',enabled?'false':'true');
                sliders[i].setAttribute('aria-valuenow',String(values[i]));
                sliders[i].setAttribute('aria-valuetext',valueText(values[i]));
                sliders[i].tabIndex=enabled?0:-1;
                if(document.activeElement!==inputs[i])inputs[i].value=String(values[i]);
                document.getElementById('volume-fill-'+k).style.width=((values[i]-min)*100/(max-min))+'%';
                document.getElementById('volume-thumb-'+k).style.left=((values[i]-min)*100/(max-min))+'%';
            });
            status.textContent=!ready?window.SceneZOILocalization.text('Loading settings...'):serverBusy?window.SceneZOILocalization.text('Preparing scene...'):pending?window.SceneZOILocalization.text('Saving settings...'):window.SceneZOILocalization.text(message || 'Saved for future scene sessions.');
        }
        function commit(){
            if(!available())return;
            var s=state();
            pending=['SZ2',s.client,String(s.sequence),'settings_'+group,String(++count),String(s.revision)].concat(values.map(String)).join('|');
            message='';options.write('settings_'+group,pending).catch(function(){});update();
        }
        function position(i,event){
            var rect=sliders[i].getBoundingClientRect();
            if(rect.width<=0)return;
            values[i]=Math.max(min,Math.min(max,Math.round(min+(event.clientX-rect.left)*(max-min)/rect.width)));
            inputs[i].value=String(values[i]);update();
        }
        if(format.toggle)inputs.forEach(function(button,i){
            button.addEventListener('click',function(){
                if(!available())return;
                values[i]=1-values[i];commit();
            });
        });
        sliders.forEach(function(slider,i){
            slider.addEventListener('mousedown',function(event){
                if(!available() || event.button!==0)return;
                event.preventDefault();dragging=i;position(i,event);
            });
            slider.addEventListener('keydown',function(event){
                if(!available())return;
                var next=values[i];
                if(event.key==='ArrowLeft'||event.key==='ArrowDown')next--;
                else if(event.key==='ArrowRight'||event.key==='ArrowUp')next++;
                else if(event.key==='PageDown')next-=10;
                else if(event.key==='PageUp')next+=10;
                else if(event.key==='Home')next=min;
                else if(event.key==='End')next=max;
                else return;
                event.preventDefault();values[i]=Math.max(min,Math.min(max,next));commit();
            });
            function typed(){
                if(!available())return;
                var raw=inputs[i].value.trim();
                if(!/^\d{1,3}$/.test(raw)||Number(raw)<min||Number(raw)>max){message=window.SceneZOILocalization.text(window.SceneZOILocalization.text('Enter a whole number from {min} to {max}.'),{min:min,max:max});inputs[i].value=String(values[i]);update();return;}
                var value=Number(raw);inputs[i].value=String(value);message='';
                if(value!==values[i]){values[i]=value;commit();}else update();
            }
            inputs[i].addEventListener('change',typed);
            inputs[i].addEventListener('keydown',function(event){if(event.key==='Enter'){event.preventDefault();typed();}});
        });
        document.addEventListener('mousemove',function(event){if(dragging!==null && available())position(dragging,event);});
        document.addEventListener('mouseup',function(){if(dragging===null)return;dragging=null;commit();});
        window.addEventListener('blur',function(){dragging=null;update();});
        function retry(){if(pending && state().active && !state().exiting)options.write('settings_'+group,pending).catch(function(){});}
        setInterval(function(){
            update();var s=state();if(!s.active || s.exiting || reading)return;
            var requested=session;reading=true;
            options.cfg('uimod.cfg_load','settings_'+group+'_state').then(function(data){
                var now=state(),raw=data && data.value!==undefined?data.value:data;
                if(!now.active || now.exiting || requested!==now.client+':'+now.sequence || typeof raw!=='string')return;
                var f=raw.split('|'),rev=Number(f[3]),received=Number(f[4]);
                if(f.length!==6+keys.length || f[0]!=='SZ2' || f[1]!==now.client || f[2]!==String(now.sequence) || rev!==now.revision ||
                    !Number.isInteger(received) || received<ack || ['ok','busy','settings_invalid','settings_stale','settings_storage'].indexOf(f[5])<0)return;
                var incoming=f.slice(6).map(Number);
                if(incoming.some(function(v){return !Number.isInteger(v)||v<min||v>max;}))return;
                ready=true;serverBusy=f[5]==='busy';ack=received;count=Math.max(count,ack);
                if(!pending || received>=Number(pending.split('|')[4])){
                    if(dragging===null)values=incoming;
                    var settled=!!pending;pending=null;
                    if(f[5].indexOf('settings_')===0)message=window.SceneZOILocalization.text('Could not save those settings. Try again.');
                    else if(settled)message='';
                }
                update();
            }).catch(function(){}).then(function(){reading=false;});
        },425);
        update();return {update:update,retry:retry};
    }
    window.SceneZOISettingsUI={create:function(options){
        options.container.innerHTML='<h3 class="settings-section-title"><span data-i18n="Task Progress">'+window.SceneZOILocalization.html("Task Progress")+'</span></h3><div id="task-rate-settings"></div><h3 class="settings-section-title"><span data-i18n="Audio Volume">'+window.SceneZOILocalization.html("Audio Volume")+'</span></h3><div id="audio-volume-settings"></div><h3 class="settings-section-title"><span data-i18n="NPC Scenes">'+window.SceneZOILocalization.html("NPC Scenes")+'</span></h3><div id="npc-scene-settings"></div><h3 class="settings-section-title" data-i18n="Debug">'+window.SceneZOILocalization.html('Debug')+'</h3><div id="debug-start-settings"></div>';
        function groupOptions(id){return {container:document.getElementById(id),state:options.state,visible:options.visible,write:options.write,cfg:options.cfg};}
        var tasks=createGroup(groupOptions('task-rate-settings'),'task_rates',['task-female','task-male'],['Female Task Progress Rate','Male Task Progress Rate'],'100% uses authored progress. Choose 10% to 500%.',10,500);
        var audio=createGroup(groupOptions('audio-volume-settings'),'audio',['sfx','female','male'],['Sound Effects','Female Voice Sets','Male Voice Sets'],'100% uses the authored volume. 0% mutes the channel.',0,200);
        var npc=createGroup(groupOptions('npc-scene-settings'),'npc_scene',['npc-scene-length'],['Default NPC Scene Length'],'How long a scene between Zois you do not control lasts, unless an add-on asks for longer. Choose 5 to 120 in-game minutes. It applies to new scenes.',5,120,{unit:'in-game min',translated:true,initial:15});
        var debugStart=createGroup(groupOptions('debug-start-settings'),'debug_start',['manual-start'],['SceneZOI manual start'],'Use the picker to start scenes from your Zoi or supported furniture.',0,1,{toggle:true,initial:0});
        return {update:function(){tasks.update();audio.update();npc.update();debugStart.update();},retry:function(){tasks.retry();audio.retry();npc.retry();debugStart.retry();}};
    }};
})();
