(function(global){
 'use strict';
 var key='scenezoiSaveJournal';
 function create(options){
  var state=options.state, restored=null, restorePacket=null, restoring=false, reading=false, counter=0, acknowledged=null, host=null;
  // Every load starts a new generation: a read or acknowledgement begun before it belongs to the previous world.
  var generation=0;
  var supported=options.sdk&&typeof options.sdk.register==='function';
  function clone(value){return JSON.parse(JSON.stringify(value));}
  function adopt(journal){
   // An empty load still has to reach the runtime: it must forget the previous save's records.
   restored=journal?clone(journal):{version:2,records:[]};
   state[key]=journal?clone(journal):null;
   generation++;restoring=true;restorePacket=null;
   options.stopForLoad();
  }
  var previous=global._onStateLoaded;
  global._onStateLoaded=function(loaded){if(previous)previous(loaded);adopt(loaded&&loaded[key]);};
  if(state[key])adopt(state[key]);
  if(supported)options.sdk.register(function(){
   options.stopForSave();
   if(!Object.prototype.hasOwnProperty.call(state,key))state[key]=null;
   return state;
  });
  function poll(){
   if(reading)return Promise.resolve();
   reading=true;
   var job, started=generation;
   function current(){return started===generation;}
   if(restoring){
    if(!restorePacket){counter++;restorePacket=['SZ2',options.client,String(counter),'restore',options.encode(restored)].join('|');}
    job=options.write('save_restore',restorePacket).then(function(){return options.read('save_restore_state');}).then(function(raw){
     if(!current())return;
     var f=String(raw||'').split('|');
     if(f[0]==='SZ2'&&f[1]===options.client&&f[2]===String(counter)&&(f[3]==='ready'||f[3]==='error')){
      restoring=false;restored=null;restorePacket=null;
     }
    });
   }else{
    // The runtime owns the journal; this view only caches each published revision for the save.
    job=options.read('save_snapshot').then(function(raw){
     if(!current()||!raw||raw===acknowledged)return;
     var data=options.decode(raw);
     if(!data||data.version!==2||typeof data.host!=='string'||!Array.isArray(data.records))return;
     var previousHost=host;
     host=data.host;
     // A Lua reload replaces the host while the UI still has this world's journal.
     // Send it to the new host before acknowledging or caching its empty boot snapshot.
     if(previousHost&&previousHost!==host&&state[key]&&state[key].records.length){
      adopt(state[key]);
      return;
     }
     state[key]=data.records.length?clone(data):null;
     return options.write('save_ready',['SZ2',data.host,String(data.revision),'ready'].join('|')).then(function(){if(current())acknowledged=raw;});
    });
   }
   return job.catch(function(){}).then(function(){reading=false;});
  }
  return {poll:poll,available:function(){return supported&&!restoring;},restoring:function(){return restoring;}};
 }
 global.SceneZOISaveGuard={create:create};
})(window);
