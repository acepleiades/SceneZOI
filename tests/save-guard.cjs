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
const journal={version:1,client:'client',sequence:'1',token:'token',participants:{'1':{collision:true},'2':{collision:false}},furniture:[{id:'3',owner:'1'}]};
(async()=>{
 const f=fixture();assert(f.guard.begin(1,['1','2']));assert.equal(f.cfg.save_ready,undefined);
 for(const bad of [{...journal,client:'old'},{...journal,sequence:'0'},{...journal,participants:{'1':{}}}]){
  f.cfg.save_snapshot=JSON.stringify(bad);await f.guard.poll();assert.equal(f.cfg.save_ready,undefined);
 }
 f.cfg.save_snapshot=JSON.stringify(journal);f.fail();await f.guard.poll();
 assert.equal(JSON.stringify(f.state.scenezoiSaveJournal),JSON.stringify(journal),'Journal must be cached before even a failed acknowledgement');
 await f.guard.poll();assert.equal(f.cfg.save_ready,'SZ2|client|1|ready|token');
 assert.deepEqual(f.save().scenezoiSaveJournal,journal);assert.equal(f.saves(),1);
 f.guard.end(true);assert.equal(f.save().scenezoiSaveJournal,null);
 f.load({scenezoiSaveJournal:journal});assert(!f.guard.available());assert(!f.guard.begin(2,['1','2']));
 await f.guard.poll();const packet=f.cfg.save_restore;assert(packet.startsWith('SZ2|client|1|restore|'));
 f.cfg.save_restore_state='SZ2|other|1|ready|ok';await f.guard.poll();assert(f.guard.restoring());assert.equal(f.cfg.save_restore,packet);
 f.guard.end(true);assert(f.guard.restoring(),'Late normal Exit must not erase loaded recovery');
 f.cfg.save_restore_state='SZ2|client|1|ready|ok';await f.guard.poll();assert(f.guard.available());assert.equal(f.state.scenezoiSaveJournal,null);
 assert(f.guard.begin(2,['1','2']));f.cfg.save_snapshot=JSON.stringify({...journal,sequence:'2'});await f.guard.poll();
 f.guard.end(false);assert(f.guard.restoring(),'Cleanup errors must retain and retry the original journal');
 const no=fixture(false);assert(!no.guard.begin(1,['1','2']));assert(!no.guard.available());
 console.log('Save guard passed: cache-before-ack, stale replies, failed writes, save Exit, loaded journal barrier and independent recovery retries.');
})().catch(e=>{console.error(e);process.exit(1);});
