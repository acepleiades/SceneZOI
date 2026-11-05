(function () {
    'use strict';
    function text(v) { return String(v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;'); }
    function hex(v) { if (!v) return '00'; return encodeURIComponent(v).replace(/%([0-9a-f]{2})|([^%])/gi,function(_,b,c){return b||('0'+c.charCodeAt(0).toString(16)).slice(-2);}); }
    function unhex(v) { if (v==='00') return ''; if (!/^(?:[0-9a-f]{2})+$/i.test(v)) throw Error('Invalid voice data'); return decodeURIComponent(v.replace(/../g,function(b){return '%'+b;})); }
    function object(v) { return v && typeof v==='object' && !Array.isArray(v); }
    function key(v) { return typeof v==='string' && v.length>0 && v.length<=96 && /^[ -~]+$/.test(v) && v===v.trim().toLowerCase(); }
    function label(v) { return typeof v==='string' && v.trim() && v.length<=160 && !/[\x00-\x1f]/.test(v); }
    function validate(d) {
        if (!object(d) || !['archetypes','contexts','sets','participants'].every(function(k){return object(d[k]);})) throw Error('Invalid voice catalog');
        Object.keys(d.archetypes).forEach(function(id){var a=d.archetypes[id];if(!key(id)||!object(a)||!label(a.label)||['male','female'].indexOf(a.body)<0)throw Error('Invalid voice archetype');});
        Object.keys(d.contexts).forEach(function(id){if(!key(id)||!object(d.contexts[id])||!label(d.contexts[id].label))throw Error('Invalid voice context');});
        Object.keys(d.sets).forEach(function(id){var s=d.sets[id],a=object(s)&&d.archetypes[s.archetype];if(!key(id)||!a||!label(s.label)||s.body!==a.body||!d.contexts[s.context])throw Error('Invalid voice set');});
        Object.keys(d.participants).forEach(function(id){
            var p=d.participants[id],a=object(p)&&p.archetype&&d.archetypes[p.archetype];
            if(!/^\d+$/.test(id)||!object(p)||['male','female'].indexOf(p.body)<0||!object(p.sets)||(p.archetype&&(!a||a.body!==p.body))||(p.error!=null&&typeof p.error!=='string'))throw Error('Invalid voice participant');
            Object.keys(p.sets).forEach(function(c){var s=d.sets[p.sets[c]];if(!s||s.context!==c||s.archetype!==p.archetype||s.body!==p.body)throw Error('Mixed voice archetypes');});
        });return d;
    }
    window.SceneZOIVoiceUI={validate:validate,create:function(o){
        var container=o.container, choosing=null, markup=null, session='', pending=null, count=0, ack=0, reading=false, selected=null;
        var data={archetypes:{},contexts:{},sets:{},participants:{}}, message='';
        function state(){return o.state();}
        function reset(){choosing=null;markup=null;pending=null;count=0;ack=0;data={archetypes:{},contexts:{},sets:{},participants:{}};message='';}
        function options(body,a,c){return Object.keys(data.sets).filter(function(id){var s=data.sets[id];return s.body===body&&s.archetype===a&&s.context===c;}).sort();}
        function dropdown(title,id,current,entries,disabled){
            return '<label>'+text(title)+'</label><button type="button" class="voice-select" data-voice-open="'+text(id)+'" aria-expanded="'+(choosing===id)+'"'+(disabled?' disabled':'')+'>'+text(current)+'</button>'+
                '<div class="voice-choices" style="display:'+(choosing===id?'block':'none')+'">'+entries.map(function(e){return '<button type="button" data-voice-action="'+text(id)+'" data-voice-value="'+text(e.id)+'"'+(disabled?' disabled':'')+'>'+text(e.label)+'</button>';}).join('')+'</div>';
        }
        function render(){
            var s=state(),next=s.client+':'+s.sequence;
            if(next!==session){reset();session=next;}
            if(!s.active||s.exiting){pending=null;choosing=null;}
            var id=o.selected();if(id!==selected){selected=id;choosing=null;}
            var p=data.participants[id],disabled=!p||o.busy()||!!pending;
            if(disabled||!o.visible())choosing=null;
            var entries=[{id:'',label:window.SceneZOILocalization.text('None (silent)')}];
            Object.keys(data.archetypes).sort().forEach(function(a){if(p&&data.archetypes[a].body===p.body)entries.push({id:a,label:data.archetypes[a].label});});
            var html=dropdown(window.SceneZOILocalization.text('Voice archetype'),'archetype',p&&p.archetype?data.archetypes[p.archetype].label:window.SceneZOILocalization.text('None (silent)'),entries,disabled);
            if(p&&p.archetype){
                Object.keys(data.contexts).sort().forEach(function(c){
                    var ids=options(p.body,p.archetype,c),choices=[{id:'',label:window.SceneZOILocalization.text('None (silent)')}].concat(ids.map(function(i){return {id:i,label:data.sets[i].label};}));
                    html+=dropdown(data.contexts[c].label,hex(c),p.sets[c]?data.sets[p.sets[c]].label:window.SceneZOILocalization.text('None (silent)'),choices,disabled||!ids.length);
                });
            }
            html+='<div class="voice-status" role="status">'+text(pending?window.SceneZOILocalization.text('Saving voice preferences...'):window.SceneZOILocalization.text(message)||(p&&p.error?window.SceneZOILocalization.text('Voice audio is unavailable. See diagnostics.'):'')||(!p?window.SceneZOILocalization.text('Loading voices...'):(!entries.length?window.SceneZOILocalization.text('No voices installed.'):window.SceneZOILocalization.text('Voice choices are kept for future sessions.'))))+'</div>';
            if(html!==markup){container.innerHTML=html;markup=html;}
        }
        function attribute(target,name){while(target&&target!==container){var v=target.getAttribute&&target.getAttribute(name);if(v!==null&&v!==undefined)return v;target=target.parentNode;}return null;}
        container.addEventListener('click',function(event){
            if(o.busy()||pending)return;
            var open=attribute(event.target,'data-voice-open');
            if(open!==null){choosing=choosing===open?null:open;o.closeExpression();render();o.changed();return;}
            var action=attribute(event.target,'data-voice-action'),value=attribute(event.target,'data-voice-value');
            if(action===null||value===null||!data.participants[selected])return;
            var s=state();choosing=null;
            pending=['SZ2',s.client,String(s.sequence),'voice',String(++count),selected,action,hex(value),String(s.revision)].join('|');
            o.write('voice',pending).catch(function(){});render();o.changed();
        });
        setInterval(function(){
            var s=state();if(!s.active||s.exiting||reading)return;
            var requested=s.client+':'+s.sequence;reading=true;
            o.cfg('uimod.cfg_load','voice_state').then(function(value){
                var n=state(),raw=value&&value.value!==undefined?value.value:value;
                if(!n.active||n.exiting||requested!==n.client+':'+n.sequence||typeof raw!=='string')return;
                var f=raw.split('|'),a=Number(f[4]);
                if(f.length!==7||f[0]!=='SZ2'||f[1]!==n.client||f[2]!==String(n.sequence)||Number(f[3])!==n.revision||!Number.isInteger(a)||a<ack||['busy','ok','voice_invalid','voice_stale','voice_storage'].indexOf(f[5])<0)return;
                var incoming=validate(JSON.parse(unhex(f[6])));
                if(session!==requested){reset();session=requested;}
                data=incoming;ack=a;if(pending&&ack>=count)pending=null;count=Math.max(count,ack);
                message=f[5].indexOf('voice_')===0?window.SceneZOILocalization.text('Could not save that voice choice. Try again.'):'';render();o.changed();
            }).catch(function(){}).then(function(){reading=false;});
        },475);
        return {update:render,busy:function(){return !!pending;},close:function(){choosing=null;},retry:function(){if(pending&&state().active&&!state().exiting)o.write('voice',pending).catch(function(){});}};
    }};
})();
