(function () {
    'use strict';
    function escape(v){return String(v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;');}
    function color(v){return typeof v==='string' && /^#[0-9a-f]{6}$/i.test(v);}
    function number(v){return typeof v==='number' && isFinite(v);}
    // Use actual arc geometry: the game's SVG renderer does not honor dashed strokes.
    function progressShape(percent,color){
        if(percent<=0)return '';
        if(percent>=100)return '<circle cx="43" cy="43" r="36.12" fill="none" stroke="'+color+'" stroke-width="8.6"/>';
        var angle=percent*Math.PI/50;
        var x=(43+36.12*Math.sin(angle)).toFixed(4),y=(43-36.12*Math.cos(angle)).toFixed(4);
        return '<path d="M 43 6.88 A 36.12 36.12 0 '+(percent>50?'1':'0')+' 1 '+x+' '+y+'" fill="none" stroke="'+color+'" stroke-width="8.6"/>';
    }
    window.SceneZOITaskUI={create:function(options){
        var root=options.root, tray=document.createElement('div');tray.id='scene-tasks';
        tray.setAttribute('aria-label',window.SceneZOILocalization.text('Scene tasks'));tray.style.display='none';root.appendChild(tray);
        var rows=[],key='',frame=0,reading=false,markup='',visible=false;
        function update(){
            var s=options.state(),next=s.client+':'+s.sequence;
            if(next!==key){key=next;rows=[];frame=0;markup='';}
            if(!s.active || s.exiting)rows=[];
            visible=!!(s.active && !s.exiting && rows.length);
            tray.style.display=visible?'flex':'none';
            layout();
        }
        function layout(){
            tray.style.left=(root.offsetWidth+10-(root.clientLeft||0))+'px';
            tray.style.top=-(root.clientTop||0)+'px';tray.style.height=root.offsetHeight+'px';
        }
        function render(){
            var html='<div id="scene-tasks-heading"><span data-i18n="Scene Tasks">'+window.SceneZOILocalization.html("Scene Tasks")+'</span></div><div id="scene-task-list">';
            rows.forEach(function(r){
                var percent=Math.max(0,Math.min(100,r.percent));
                // Fixed SVG viewport matches the overlay; progress uses a real partial path.
                html+='<div class="scene-task"><div class="task-participant">'+escape(r.participant_name)+'</div>'+
                    '<div class="task-ring" role="progressbar" aria-label="'+escape(r.participant_name+' '+r.label)+'" aria-valuemin="0" aria-valuemax="100" aria-valuenow="'+percent.toFixed(2)+'">'+
                    '<svg width="86" height="86" viewBox="0 0 86 86"><circle cx="43" cy="43" r="36.12" fill="none" stroke="'+r.track_color+'" stroke-width="8.6"/>'+
                    progressShape(percent,r.color)+'</svg>'+
                    '<div class="task-percent" style="color:'+r.text_color+'"><span>'+Math.floor(percent)+'%</span></div></div><div class="task-label">'+escape(r.label)+'</div></div>';
            });html+='</div>';
            if(html!==markup){var list=document.getElementById('scene-task-list'),scroll=list?list.scrollTop:0;tray.innerHTML=html;markup=html;
                list=document.getElementById('scene-task-list');if(list)list.scrollTop=scroll;}
        }
        function valid(r){return r && typeof r.participant_id==='string' && typeof r.participant_name==='string' && typeof r.task_id==='string' && typeof r.label==='string' && number(r.percent) && r.percent>=0 && r.percent<=100 && number(r.value) && number(r.maximum) && r.maximum>0 && r.value>=0 && r.value<=r.maximum && color(r.color) && color(r.track_color) && color(r.text_color);}
        function poll(){
            update();options.changed();var s=options.state();if(!s.active || s.exiting || reading)return;
            var requestKey=key,revision=s.revision;reading=true;
            options.cfg('uimod.cfg_load','task_state').then(function(data){
                var raw=data && data.value!==undefined?data.value:data;
                if(typeof raw!=='string' || raw.length>4194304)return;
                var p=raw.split('|'),now=options.state();
                if(key!==requestKey || !now.active || now.exiting || now.revision!==revision || p.length!==6 || p[0]!=='SZ2' || p[1]!==now.client || Number(p[2])!==Number(now.sequence) || Number(p[3])!==now.revision || !/^\d+$/.test(p[4]) || Number(p[4])<=frame || !/^(?:[0-9a-f]{2})+$/i.test(p[5]))return;
                var value=JSON.parse(decodeURIComponent(p[5].replace(/../g,function(b){return '%'+b;})));
                if(!value || !Array.isArray(value.rows) || value.rows.length>8192 || !value.rows.every(valid))return;
                rows=value.rows;frame=Number(p[4]);render();update();options.changed();
            }).catch(function(){}).then(function(){reading=false;});
        }
        setInterval(poll,150);
        return {update:update,width:function(){update();return visible?142:0;},bounds:function(){
            update();if(!visible)return null;
            return [root.offsetLeft+root.offsetWidth+10,root.offsetTop,132,root.offsetHeight];
        }};
    }};
})();
