(function(global){
 'use strict';
 var key='scenezoiSaveJournal';
 function create(options){
  var state=options.state, current=null, restored=null, restorePacket=null, restoring=false, reading=false, counter=0;
  var supported=options.sdk&&typeof options.sdk.register==='function';
  function clone(value){return JSON.parse(JSON.stringify(value));}
  function adopt(journal){
   if(!journal)return;
   restored=clone(journal);restoring=true;restorePacket=null;
   options.stopForLoad();
  }
  var previous=global._onStateLoaded;
  global._onStateLoaded=function(loaded){if(previous)previous(loaded);adopt(loaded&&loaded[key]);};
  adopt(state[key]);
  if(supported)options.sdk.register(function(){
   if(current)options.stopForSave();
   if(!Object.prototype.hasOwnProperty.call(state,key))state[key]=null;
   return state;
  });
  function begin(sequence,ids){
   if(!supported||restoring)return false;
   current={sequence:String(sequence),ids:ids.slice(),ready:false};
   // No native mutation is permitted until a complete journal is acknowledged.
   state[key]={version:1,participants:{},furniture:[]};return true;
  }
  function end(clean){
   current=null;
   if(clean&&!restoring)state[key]=null;
   else if(!clean&&state[key])adopt(state[key]);
  }
  function poll(){
   if(reading)return Promise.resolve();
   reading=true;
   var job;
   if(restoring){
    if(!restorePacket){counter++;restorePacket=['SZ2',options.client,String(counter),'restore',options.encode(restored)].join('|');}
    job=options.write('save_restore',restorePacket).then(function(){return options.read('save_restore_state');}).then(function(raw){
     var f=String(raw||'').split('|');
     if(f[0]==='SZ2'&&f[1]===options.client&&f[2]===String(counter)&&f[3]==='ready'){
      restoring=false;restored=null;restorePacket=null;state[key]=null;
     }
    });
   }else if(current&&!current.ready){
    job=options.read('save_snapshot').then(function(raw){
     if(!raw)return;
     var data=options.decode(raw), run=current;
     if(!run||data.version!==1||data.client!==options.client||String(data.sequence)!==run.sequence||!data.token)return;
     if(!data.participants||!Array.isArray(data.furniture))return;
     var ids=Object.keys(data.participants).sort(),wanted=run.ids.slice().sort();
     if(JSON.stringify(ids)!==JSON.stringify(wanted))return;
     state[key]=clone(data);
     return options.write('save_ready',['SZ2',options.client,run.sequence,'ready',data.token].join('|')).then(function(){if(current===run)run.ready=true;});
    });
   }else job=Promise.resolve();
   return job.catch(function(){}).then(function(){reading=false;});
  }
  return {begin:begin,end:end,poll:poll,available:function(){return supported&&!restoring;},restoring:function(){return restoring;}};
 }
 global.SceneZOISaveGuard={create:create};
})(window);
