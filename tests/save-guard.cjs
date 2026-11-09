require('./fixtures/localization.cjs');
const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict'),path=require('path');
const src=fs.readFileSync(path.resolve(__dirname,'../modkit/SceneZOI_93C44199/ui/scenezoi/save-guard.js'),'utf8');
function fixture(supported=true){
 const state={},cfg={},writes=[],context={};context.window=context;
 vm.runInNewContext(src,context);
 let provider,saves=0,loads=0,fail=false;
 const guard=context.SceneZOISaveGuard.create({state,client:'client',sdk:supported?{register(cb){provider=cb;}}:null,
  encode:JSON.stringify,decode:JSON.parse,read:key=>Promise.resolve(cfg[key]),
  write(key,value){writes.push([key,value]);if(fail){fail=false;return Promise.reject(Error('transient'));}cfg[key]=value;return Promise.resolve();},
  stopForSave(){saves++;},stopForLoad(){loads++;}});
 return {state,cfg,writes,guard,load:v=>context._onStateLoaded(v),save:()=>JSON.parse(JSON.stringify(provider())),fail:()=>{fail=true;},saves:()=>saves,loads:()=>loads};
}
const snapshot=(revision,records)=>({version:2,host:'host.1',revision,records});
const record={token:'scene.1',serial:1,participants:{'1':{collision:true}},furniture:[]};
(async()=>{
 const f=fixture();assert(f.guard.available());
 for(const bad of [{version:1},{version:2,records:[]},{version:2,host:'h',records:{}}]){f.cfg.save_snapshot=JSON.stringify(bad);await f.guard.poll();assert.equal(f.cfg.save_ready,undefined);}
 f.cfg.save_snapshot=JSON.stringify(snapshot(3,[record]));f.fail();await f.guard.poll();
 assert.equal(JSON.stringify(f.state.scenezoiSaveJournal),JSON.stringify(snapshot(3,[record])),'The journal must be cached before even a failed acknowledgement');
 await f.guard.poll();assert.equal(f.cfg.save_ready,'SZ2|host.1|3|ready');
 const count=f.writes.length;await f.guard.poll();assert.equal(f.writes.length,count,'An acknowledged revision is not written again');
 assert.deepEqual(f.save().scenezoiSaveJournal,snapshot(3,[record]));assert.equal(f.saves(),1);
 f.cfg.save_snapshot=JSON.stringify(snapshot(4,[]));await f.guard.poll();assert.equal(f.save().scenezoiSaveJournal,null,'An empty journal is saved as none');
 assert.equal(f.saves(),2,'A save asks every scene to exit even with no panel open');
 f.load({scenezoiSaveJournal:snapshot(9,[record])});assert(!f.guard.available());assert.equal(f.loads(),1);
 await f.guard.poll();const packet=f.cfg.save_restore;assert(packet.startsWith('SZ2|client|1|restore|'));
 assert.equal(JSON.stringify(f.state.scenezoiSaveJournal),JSON.stringify(snapshot(9,[record])),'Loaded records stay cached until the runtime republishes');
 f.cfg.save_restore_state='SZ2|other|1|ready|ok';await f.guard.poll();assert(f.guard.restoring());assert.equal(f.cfg.save_restore,packet);
 f.cfg.save_restore_state='SZ2|client|1|ready|ok';await f.guard.poll();assert(f.guard.available(),'Indexing is enough; absent Zois must not block new scenes');
 const g=fixture();g.load({});await g.guard.poll();assert(g.cfg.save_restore.includes('"records":[]'),'Loading a save with no journal still clears the runtime');
 g.cfg.save_restore_state='SZ2|client|1|error|invalid_recovery';await g.guard.poll();assert(g.guard.available(),'A rejected journal must not block forever');
 const no=fixture(false);assert(!no.guard.available());
 console.log('Save guard passed: cache-before-ack, per-revision acknowledgement, save requests every Exit, loaded journal indexing and empty loads.');
})().catch(e=>{console.error(e);process.exit(1);});
