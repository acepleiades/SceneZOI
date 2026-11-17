(function () {
    'use strict';
    function bindTextCommit(input, commit) {
        var sawDown = false, sawPress = false;
        function enter(event) {
            // Cohtml can deliver Return through the legacy keyboard fields.
            if (event.isComposing || !(event.key === 'Enter' || event.key === 'Return' ||
                event.code === 'Enter' || event.code === 'NumpadEnter' ||
                event.keyCode === 13 || event.which === 13 || event.charCode === 13)) return false;
            event.preventDefault();
            return true;
        }
        input.addEventListener('change', commit);
        input.addEventListener('keydown', function (event) {
            if (!enter(event)) return;
            sawDown = true;
            if (!event.repeat) commit();
        });
        input.addEventListener('keypress', function (event) {
            if (!enter(event)) return;
            sawPress = true;
            if (!sawDown && !event.repeat) commit();
        });
        input.addEventListener('keyup', function (event) {
            if (!enter(event)) return;
            if (!sawDown && !sawPress) commit();
            sawDown = sawPress = false;
        });
        input.addEventListener('blur', function () { sawDown = sawPress = false; });
    }
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
            bindTextCommit(inputs[i], typed);
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
    function previewHex(value){
        return encodeURIComponent(JSON.stringify(value)).replace(/%([0-9a-f]{2})|([^%])/gi,function(_,byte,char){
            return byte||('0'+char.charCodeAt(0).toString(16)).slice(-2);
        });
    }
    function previewLabel(value){return String(value).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}
    function rotationValues(value){
        return Array.isArray(value)&&value.length===3&&value.every(function(v){
            return Number.isFinite(v)&&v>=-180&&v<=180;
        });
    }
    function previewRows(encoded){
        if(encoded.length>262144||!/^(?:[0-9a-f]{2})+$/i.test(encoded))throw Error('Invalid attachment preview state');
        var rows=JSON.parse(decodeURIComponent(encoded.replace(/../g,function(byte){return '%'+byte;})));
        function label(v){return typeof v==='string'&&v.length>0&&v.length<=512&&!/[\x00-\x1f]/.test(v);}
        if(!Array.isArray(rows)||!rows.every(function(row){
            return row&&['participant','name','role','attachment','mesh'].every(function(field){return label(row[field]);})
                &&(row.hidden===undefined||typeof row.hidden==='boolean')
                &&Array.isArray(row.bones)&&row.bones.every(label)&&row.rotations&&typeof row.rotations==='object'
                &&!Array.isArray(row.rotations)&&Object.keys(row.rotations).every(function(bone){
                    return row.bones.indexOf(bone)>=0&&rotationValues(row.rotations[bone]);
                });
        }))throw Error('Invalid attachment preview rows');
        return rows.filter(function(row){return row.bones.length>0;});
    }
    function createAttachmentPreview(options){
        var container=options.container, local=window.SceneZOILocalization;
        var title='Attachment pose preview', hint='Use local rotation offsets from the rest pose. Preview edits reset when you leave this scene.';
        var exportLabel='Export reference values';
        var selectors={person:'Zoi',mesh:'Attachment',bone:'Bone'};
        var axes=['X','Y','Z'];
        container.innerHTML='<h3 class="settings-section-title" data-i18n="'+title+'">'+local.html(title)+'</h3>'+
            '<p class="audio-settings-note" data-i18n="'+hint+'">'+local.html(hint)+'</p>'+
            '<div id="attachment-preview-editor">'+Object.keys(selectors).map(function(id){return '<div id="attachment-preview-'+id+'"></div>';}).join('')+
            '<fieldset class="attachment-preview-rotation"><legend data-i18n="Local rotation (degrees)">'+local.html('Local rotation (degrees)')+'</legend>'+
            '<div class="attachment-preview-axes">'+axes.map(function(axis){
                return '<label>'+axis+'<input id="attachment-preview-'+axis+'" type="text" inputmode="decimal" maxlength="12" autocomplete="off"></label>';
            }).join('')+'</div></fieldset></div>'+
            '<button id="attachment-preview-export" type="button" data-i18n="'+exportLabel+'">'+local.html(exportLabel)+'</button>'+
            '<div id="attachment-preview-status" role="status" aria-live="polite"></div>';
        var editor=document.getElementById('attachment-preview-editor'), groups={}, markup={};
        Object.keys(selectors).forEach(function(key){groups[key]=document.getElementById('attachment-preview-'+key);});
        var inputs=axes.map(function(axis){return document.getElementById('attachment-preview-'+axis);});
        var exportButton=document.getElementById('attachment-preview-export'), status=document.getElementById('attachment-preview-status');
        var identity='', revision=-1, count=0, ack=0, reading=false, pending=null, queued=null, serverBusy=true;
        var rows=[], person=null, mesh=null, bone=null, choosing=null, displayed='', message='';
        function sessionKey(state){return state.active&&!state.exiting&&state.token?[state.client,state.sequence,state.token].join('|'):'';}
        function available(){
            var state=options.state();
            return !!identity&&sessionKey(state)===identity&&state.revision===revision&&state.playing&&
                !state.pendingNavigation&&options.visible()&&!serverBusy;
        }
        function selectedRow(){return rows.find(function(row){return !row.hidden&&row.participant===person&&row.attachment===mesh;});}
        function angles(row){
            return Object.prototype.hasOwnProperty.call(row.rotations,bone)?row.rotations[bone]:[0,0,0];
        }
        function dropdown(id,selected,entries,disabled){
            var value=entries.find(function(entry){return entry.value===selected;});
            var label=local.html(selectors[id]), choicesId='attachment-preview-'+id+'-choices';
            var html='<div class="attachment-preview-label" data-i18n="'+selectors[id]+'">'+label+'</div>';
            if(entries.length<=1)html+='<div class="attachment-preview-value">'+(value?previewLabel(value.label):'')+'</div>';
            else html+='<button type="button" class="attachment-preview-picker" data-preview-open="'+id+'" aria-expanded="'+(choosing===id)+'" aria-controls="'+choicesId+'"'+(disabled?' disabled':'')+'>'+
                previewLabel(value.label)+'</button><div id="'+choicesId+'" class="voice-choices" style="display:'+(choosing===id?'block':'none')+'">'+
                entries.map(function(entry){return '<button type="button" data-preview-select="'+id+'" data-preview-option="'+previewLabel(entry.value)+'">'+previewLabel(entry.label)+'</button>';}).join('')+'</div>';
            if(html!==markup[id]){groups[id].innerHTML=html;markup[id]=html;}
        }
        function update(){
            var state=options.state(), next=sessionKey(state);
            if(next!==identity){identity=next;revision=-1;count=state.counterBase||0;}
            if(revision!==state.revision||!identity){
                revision=state.revision;ack=0;pending=null;queued=null;serverBusy=true;
                rows=[];person=null;mesh=null;bone=null;choosing=null;displayed='';message='';
            }
            var visibleRows=rows.filter(function(row){return !row.hidden;});
            var hasEdits=rows.some(function(row){return Object.keys(row.rotations).length>0;});
            container.style.display=visibleRows.length||hasEdits?'block':'none';
            editor.style.display=visibleRows.length?'block':'none';
            if(!visibleRows.length&&!hasEdits)return;
            var disabled=!available();
            if(disabled||pending||!visibleRows.length)choosing=null;
            if(visibleRows.length){
                var people=[];
                visibleRows.forEach(function(row){
                    if(!people.some(function(entry){return entry.value===row.participant;}))people.push({value:row.participant,label:row.name});
                });
                if(!people.some(function(entry){return entry.value===person;}))person=people[0].value;
                var meshes=visibleRows.filter(function(row){return row.participant===person;});
                if(!meshes.some(function(row){return row.attachment===mesh;}))mesh=meshes[0].attachment;
                var row=selectedRow();
                if(row.bones.indexOf(bone)<0)bone=row.bones[0];
                dropdown('person',person,people,disabled||!!pending);
                dropdown('mesh',mesh,meshes.map(function(row){
                    return {value:row.attachment,label:row.mesh.split('.').pop().split('/').pop()};
                }),disabled||!!pending);
                dropdown('bone',bone,row.bones.map(function(name){return {value:name,label:name};}),disabled||!!pending);
                var values=angles(row), renderKey=JSON.stringify([person,mesh,bone,values]);
                if(renderKey!==displayed&&!pending&&!inputs.some(function(input){return document.activeElement===input;})){
                    inputs.forEach(function(input,i){input.value=String(values[i]);});
                    displayed=renderKey;
                }
            }else displayed='';
            inputs.forEach(function(input){input.disabled=disabled||!visibleRows.length||!!(pending&&pending.command.action==='export');});
            exportButton.disabled=disabled||!!pending||!hasEdits;
            status.textContent=local.text(pending?
                (pending.command.action==='export'?'Exporting reference values…':'Applying preview…'):message);
        }
        function send(command){
            var state=options.state(), next=++count;
            var packet=['SZ2',state.client,String(state.sequence),'attachment_preview',String(next),String(revision),state.token,previewHex(command)].join('|');
            pending={count:next,packet:packet,command:command};message='';
            options.write('attachment_preview',packet).catch(function(){});update();
        }
        function applyAngles(){
            if(!available()||!selectedRow()||(pending&&pending.command.action==='export'))return;
            var values=inputs.map(function(input){
                var raw=input.value.trim().replace(',','.');
                return /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$/.test(raw)?Number(raw):NaN;
            });
            if(!rotationValues(values)){message='Enter angles from -180 to 180 degrees.';update();return;}
            var command={action:'rotate',participant:person,attachment:mesh,bone:bone,rotation:values};
            if(pending)queued=JSON.stringify(pending.command)===JSON.stringify(command)?null:command;
            else if(JSON.stringify(angles(selectedRow()))!==JSON.stringify(values))send(command);
            else {message='';update();}
        }
        inputs.forEach(function(input){bindTextCommit(input, applyAngles);});
        container.addEventListener('click',function(event){
            if(!available()||pending)return;
            var target=event.target;
            while(target&&target!==container){
                var open=target.getAttribute&&target.getAttribute('data-preview-open');
                if(open){choosing=choosing===open?null:open;update();return;}
                var select=target.getAttribute&&target.getAttribute('data-preview-select');
                if(select){
                    var value=target.getAttribute('data-preview-option');
                    if(select==='person'&&person!==value){person=value;mesh=null;bone=null;}
                    else if(select==='mesh'&&mesh!==value){mesh=value;bone=null;}
                    else if(select==='bone')bone=value;
                    choosing=null;message='';update();return;
                }
                target=target.parentNode;
            }
        });
        exportButton.addEventListener('click',function(){if(available()&&!exportButton.disabled)send({action:'export'});});
        var results={
            preview_invalid:'Could not apply the preview.',
            preview_stale:'The scene changed. Try again.',
            preview_export_empty:'There are no attachment pose edits to export.',
            preview_export_read:'Could not read the existing attachment pose reference file.',
            preview_export_full:'The attachment pose reference file would exceed 64 KiB.',
            preview_export_write:'Could not write the attachment pose reference file.',
            preview_exported:'Exported to scenezoi_runtime/attachment_pose_reference.cfg.'
        };
        setInterval(function(){
            update();
            var state=options.state(), requested=identity, requestedRevision=revision;
            if(!requested||!state.playing||!options.visible()||reading)return;
            reading=true;
            options.cfg('uimod.cfg_load','attachment_preview_state').then(function(data){
                var now=options.state(), raw=data&&data.value!==undefined?data.value:data;
                if(requested!==sessionKey(now)||requestedRevision!==now.revision||typeof raw!=='string')return;
                var fields=raw.split('|'), received=Number(fields[4]), code=fields[5];
                if(fields.length!==8||fields[0]!=='SZ2'||fields[1]!==now.client||fields[2]!==String(now.sequence)||
                    fields[3]!==String(now.revision)||fields[6]!==now.token||!/^\d+$/.test(fields[4])||!Number.isSafeInteger(received)||
                    received<ack||(code!=='ok'&&code!=='busy'&&!Object.prototype.hasOwnProperty.call(results,code)))return;
                rows=previewRows(fields[7]);ack=received;count=Math.max(count,received);serverBusy=code==='busy';
                if(pending&&received>=pending.count){
                    // Read the host's rotation before applying edits queued during its acknowledgement.
                    pending=null;message=results[code]||'';
                    if(queued&&available()&&rows.some(function(row){return !row.hidden&&row.participant===queued.participant&&row.attachment===queued.attachment&&row.bones.indexOf(queued.bone)>=0;})){
                        var command=queued;queued=null;send(command);
                    }
                    queued=null;
                }
                update();
            }).catch(function(){}).then(function(){reading=false;});
        },480);
        return {update:update,retry:function(){if(pending&&available())options.write('attachment_preview',pending.packet).catch(function(){});}};
    }
    window.SceneZOISettingsUI={create:function(options){
        options.container.innerHTML='<section id="attachment-preview" style="display:none"></section><h3 class="settings-section-title"><span data-i18n="Task Progress">'+window.SceneZOILocalization.html("Task Progress")+'</span></h3><div id="task-rate-settings"></div><h3 class="settings-section-title"><span data-i18n="Audio Volume">'+window.SceneZOILocalization.html("Audio Volume")+'</span></h3><div id="audio-volume-settings"></div><h3 class="settings-section-title"><span data-i18n="NPC Scenes">'+window.SceneZOILocalization.html("NPC Scenes")+'</span></h3><div id="npc-scene-settings"></div><h3 class="settings-section-title" data-i18n="Debug">'+window.SceneZOILocalization.html('Debug')+'</h3><div id="debug-start-settings"></div>';
        function groupOptions(id){return {container:document.getElementById(id),state:options.state,visible:options.visible,write:options.write,cfg:options.cfg};}
        var tasks=createGroup(groupOptions('task-rate-settings'),'task_rates',['task-female','task-male'],['Female Task Progress Rate','Male Task Progress Rate'],'100% uses authored progress. Choose 10% to 500%.',10,500);
        var audio=createGroup(groupOptions('audio-volume-settings'),'audio',['sfx','female','male'],['Sound Effects','Female Voice Sets','Male Voice Sets'],'100% uses the authored volume. 0% mutes the channel.',0,200);
        var npc=createGroup(groupOptions('npc-scene-settings'),'npc_scene',['npc-scene-length'],['Default NPC Scene Length'],'How long a scene between Zois you do not control lasts, unless an add-on asks for longer. Choose 5 to 120 in-game minutes. It applies to new scenes.',5,120,{unit:'in-game min',translated:true,initial:15});
        var debugStart=createGroup(groupOptions('debug-start-settings'),'debug_start',['manual-start'],['SceneZOI manual start'],'Use the picker to start scenes from your Zoi or supported furniture.',0,1,{toggle:true,initial:0});
        var preview=createAttachmentPreview(groupOptions('attachment-preview'));
        return {update:function(){preview.update();tasks.update();audio.update();npc.update();debugStart.update();},retry:function(){preview.retry();tasks.retry();audio.retry();npc.retry();debugStart.retry();}};
    }};
})();
