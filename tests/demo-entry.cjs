require('./fixtures/localization.cjs');
const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict'),path=require('path');
const base=path.join(__dirname,'../modkit/SceneZOI_93C44199/ui');
const receiver=fs.readFileSync(path.join(base,'scenezoi/demo-entry.js'),'utf8');
const launcher=fs.readFileSync(path.join(base,'scenezoi-starter/app.js'),'utf8');
async function flush(){for(let i=0;i<45;i++)await Promise.resolve();}
function fixture(controlled='1',body={1:'Male',2:'Male',3:'Female',4:'Female'},fault={}){
 const values={state:'SZ2|none|0|idle|ok',selection_request:'SZ2|old|open|1',selection_host_ready:'SZ2|host|ready|none'};
 if(fault.delayedReceiver){values.selection_ui_ready='SZ2|host|ready|ui.old|launcher.99.1';values.selection_launcher_ready='SZ2|launcher.99.1|ready|ui.old|old';}
 const starts=[],declines=[],declineTokens=[],notices=[],toasts=[];let available=true,activate,timer,visible=false,hides=0,tick=0;const retries=[];
 function cli(command,p){
  if(command==='toast.show'){toasts.push(p);return Promise.resolve({data:{}});}
  if(command==='entity.get_possessed')return Promise.resolve({data:{entity_id:controlled}});
  if(command==='entity.get_character_info')return Promise.resolve({data:{gender:body[p.entity_id],growth_step:'Youth'}});
  if(command==='uimod.cfg_save'){
   if(p.key==='selection_ui_ready'&&fault.readyWrites>0){fault.readyWrites--;return Promise.resolve({success:false,message:'Temporary write failure'});}
   values[p.key]=p.value;return Promise.resolve({data:{}});
  }
  if(command==='uimod.cfg_load'){
   if(p.key==='selection_request'&&fault.requestReads>0){fault.requestReads--;return Promise.resolve({success:false,message:'Temporary read failure'});}
   if(!(p.key in values))return Promise.resolve({success:false,message:'Key not found: '+p.key});
   return Promise.resolve({data:{value:values[p.key]}});
  }
  throw Error(command);
 }
 const common={Promise,Math,JSON,String,Number,Set,Error,Date:{now:()=>++tick}};
 const c={...common,wf:{MOD_ID:'mod'},window:null,
  SceneZOIControls:{bootId:'ui.new',available:()=>available,decline:(id,token)=>{declines.push(id);declineTokens.push(token);},reject:(...a)=>notices.push(a),start:e=>{starts.push(e);return Promise.resolve(true);}},
  inzoi:{cli:{execute:cli}},setInterval:(f,t)=>{assert.equal(t,200);timer=f;}};
 c.window=c;function startReceiver(){vm.runInNewContext(receiver,c);}
 if(!fault.delayedReceiver)startReceiver();
 const l={...common,setTimeout:(f)=>retries.push(f),inzoi:{cli:{execute:cli},trigger:{onActivated:f=>activate=f},view:{hide:()=>{visible=false;hides++;}}}};
 vm.runInNewContext(launcher,l);
 return {activate:(id=controlled,kind='scenezoi_demo')=>{if(visible){visible=false;return Promise.resolve();}visible=true;return activate({triggerId:kind,targetEntityId:id});},
  poll:()=>timer(),set:(kind,ids,node='scenezoi.standing_idle',roles='female:3+male:1',bed='none')=>values.selection_state=['SZ2',values.selection_request.split('|')[1],kind,ids,node,roles,bed].join('|'),
  starts,declines,declineTokens,notices,toasts,restartHost:(name='nextHost')=>{values.selection_host_ready='SZ2|'+name+'|ready|none';values.selection_ui_ready='none';},retry:()=>retries.splice(0).forEach(f=>f()),get request(){return values.selection_request;},get ready(){return values.selection_ui_ready;},get launcher(){return values.selection_launcher_ready;},startReceiver,get hides(){return hides;},setPhase:phase=>{values.state='SZ2|session|1|'+phase+'|ok';},busy:()=>{available=false;values.state='SZ2|session|1|playing|ok';}};
}
async function boot(f){
 await flush();
 for(let i=0;i<5 && !f.hides;i++){await f.poll();f.retry();await flush();}
 assert.equal(f.hides,1,'The launcher hides only once the current receiver acknowledges it');
 assert.equal(f.launcher.split('|')[2],'ready');
 assert.equal(f.launcher.split('|')[3],'ui.new');
 return f;
}
async function run(){
 const startup=fixture('1',undefined,{delayedReceiver:true});await flush();
 assert.equal(startup.hides,0,'An acknowledgement left by the previous UI cannot finish startup');
 assert.equal(startup.launcher.split('|')[2],'waiting');
 startup.startReceiver();await boot(startup);
 for(const fault of [{requestReads:1},{readyWrites:1}]){
  const f=fixture('1',undefined,fault);await flush();assert.equal(f.ready,undefined);
  await boot(f);assert.equal(f.ready,'SZ2|host|ready|ui.new|'+f.launcher.split('|')[1],'Failed readiness work must retry for the same host');
  await f.poll();await flush();assert.equal(f.starts.length,0,'A retried handshake must still discard the stale boot request');
  await f.activate();await f.poll();f.set('selected','1+3');await f.poll();await flush();assert.equal(f.starts.length,1);
 }
 for(const [name,control,ids,node,roles] of [
  ['MF','1','1+3','scenezoi.standing_idle',{male:'1',female:'3'}],
  ['FM','3','3+1','scenezoi.standing_idle',{female:'3',male:'1'}]]){
  const f=await boot(fixture(control));await f.activate();await flush();await f.poll();await flush();
  assert(f.request.includes('|open|'+control));assert.equal(f.hides,2);assert.equal(f.starts.length,0);
  f.set('selected',ids,node,Object.entries(roles).map(([role,id])=>role+':'+id).join('+'));await f.poll();await flush();assert.equal(f.starts.length,1,name);assert.equal(f.starts[0].node,node);assert.deepEqual(JSON.parse(JSON.stringify(f.starts[0].bindings)),roles);
 }
 const bed=await boot(fixture());await bed.activate('50','scenezoi_furniture');await bed.poll();await flush();assert(bed.request.endsWith('|1|50'));
 bed.set('selected','1+3','scenezoi.bed_single_idle','male:1+female:3','50');await bed.poll();await flush();assert.equal(bed.starts[0].furniture,'50');assert.equal(bed.starts[0].node,'scenezoi.bed_single_idle');
 const ff=await boot(fixture('3'));await ff.activate();await ff.poll();ff.set('unavailable','no_starting_scene');await ff.poll();await flush();assert.equal(ff.starts.length,0);assert.equal(ff.declines.length,1);assert.equal(ff.declineTokens[0],ff.request.split('|')[1]);
 const cold=await boot(fixture());const readyBefore=cold.launcher;cold.restartHost();
 await cold.poll();
 assert.equal(cold.launcher,readyBefore,'The hidden launcher need not run to reconnect to a new Lua host');
 assert.equal(cold.ready,'SZ2|nextHost|ready|ui.new|'+readyBefore.split('|')[1]);
 cold.restartHost('thirdHost');
 const firstClick=cold.activate();await flush();assert.equal(cold.request,'SZ2|old|open|1','Cold entry must wait for receiver readiness');
 await cold.poll();await flush();cold.retry();await firstClick;await flush();assert(cold.request.includes('|open|1'),'The original click must complete without another activation');
 const wrong=await boot(fixture());await wrong.activate('3');await flush();assert.equal(wrong.request,'SZ2|old|open|1');assert.equal(wrong.hides,2);
 const busy=await boot(fixture());busy.busy();await busy.activate();assert.equal(busy.request,'SZ2|old|open|1');assert.equal(busy.hides,2);assert.equal(busy.toasts.length,1);assert.match(busy.toasts[0].message,/already in progress/);
 for(const phase of ['preparing','exiting']){const f=await boot(fixture());f.busy();f.setPhase(phase);await f.activate();assert.equal(f.toasts.length,1);assert.equal(f.request,'SZ2|old|open|1');}
 const failed=await boot(fixture());await failed.activate();await failed.poll();failed.set('error','departure_failed');await failed.poll();await flush();assert.equal(failed.starts.length,0);assert.equal(failed.declines.length,1);
 const repeated=await boot(fixture());
 for(let n=0;n<8;n++){
  const old=repeated.request;await repeated.activate();await flush();assert.notEqual(repeated.request,old,'Every single native activation must write a new request');
  await repeated.poll();repeated.set('cancelled','none');await repeated.poll();await flush();
 }
 assert.equal(repeated.hides,9);assert.equal(repeated.declines.length,8);
 for(const ids of ['1','1+1','3+1','1+2','1+3+4','1+2+3','1+2+3+4']){
  const f=await boot(fixture());await f.activate();await f.poll();f.set('selected',ids);await f.poll();await flush();assert.equal(f.starts.length,0,ids);
 }
 for(const [ids,roles] of [['1','solo:1'],['1+2','first:1+second:2'],['3+4','first:3+second:4'],['1+3+4','one:1+two:3+three:4'],['1+2+3','one:1+two:2+three:3']]){const f=await boot(fixture(ids[0]));await f.activate();await flush();await f.poll();f.set('selected',ids,'other.hub',roles);await f.poll();await flush();assert.equal(f.starts.length,1);assert.equal(f.starts[0].node,'other.hub');}
 console.log('Demo entry passed: separate launcher/receiver, eight single native activations, discovered MF/MM/FF/MFF/MMF roles accepted; unavailable scenes declined, self-only preflight, busy guard/departure failure, stale boot request and cancellation.');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
