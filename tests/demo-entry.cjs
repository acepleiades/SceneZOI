require('./fixtures/localization.cjs');
const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict'),path=require('path');
const base=path.join(__dirname,'../modkit/SceneZOI_93C44199/ui');
const receiver=fs.readFileSync(path.join(base,'scenezoi/demo-entry.js'),'utf8');
const launcher=fs.readFileSync(path.join(base,'scenezoi-starter/app.js'),'utf8');
async function flush(){for(let i=0;i<45;i++)await Promise.resolve();}
function fixture(controlled='1',body={1:'Male',2:'Male',3:'Female',4:'Female'}){
 const values={state:'SZ2|none|0|idle|ok',selection_request:'SZ2|old|open|1',selection_host_ready:'SZ2|host|ready|none'};
 const starts=[],declines=[],declineTokens=[],notices=[],toasts=[];let available=true,activate,timer,visible=false,hides=0,tick=0;const retries=[];
 function cli(command,p){
  if(command==='toast.show'){toasts.push(p);return Promise.resolve({data:{}});}
  if(command==='entity.get_possessed')return Promise.resolve({data:{entity_id:controlled}});
  if(command==='entity.get_character_info')return Promise.resolve({data:{gender:body[p.entity_id],growth_step:'Youth'}});
  if(command==='uimod.cfg_save'){values[p.key]=p.value;return Promise.resolve({data:{}});}
  if(command==='uimod.cfg_load')return Promise.resolve({data:{value:values[p.key] || ''}});
  throw Error(command);
 }
 const common={Promise,Math,JSON,String,Number,Set,Error,Date:{now:()=>++tick}};
 const c={...common,wf:{MOD_ID:'mod'},window:null,
  SceneZOIControls:{available:()=>available,decline:(id,token)=>{declines.push(id);declineTokens.push(token);},reject:(...a)=>notices.push(a),start:e=>{starts.push(e);return Promise.resolve(true);}},
  inzoi:{cli:{execute:cli}},setInterval:(f,t)=>{assert.equal(t,200);timer=f;}};
 c.window=c;vm.runInNewContext(receiver,c);
 const l={...common,setTimeout:(f)=>retries.push(f),inzoi:{cli:{execute:cli},trigger:{onActivated:f=>activate=f},view:{hide:()=>{visible=false;hides++;}}}};
 vm.runInNewContext(launcher,l);
 return {activate:(id=controlled,kind='scenezoi_demo')=>{if(visible){visible=false;return Promise.resolve();}visible=true;return activate({triggerId:kind,targetEntityId:id});},
  poll:()=>timer(),set:(kind,ids,node='scenezoi.standing_idle',roles='female:3+male:1',bed='none')=>values.selection_state=['SZ2',values.selection_request.split('|')[1],kind,ids,node,roles,bed].join('|'),
  starts,declines,declineTokens,notices,toasts,restartHost:()=>{values.selection_host_ready='SZ2|nextHost|ready|none';values.selection_ui_ready='none';},retry:()=>retries.splice(0).forEach(f=>f()),get request(){return values.selection_request;},get hides(){return hides;},setPhase:phase=>{values.state='SZ2|session|1|'+phase+'|ok';},busy:()=>{available=false;values.state='SZ2|session|1|playing|ok';}};
}
async function run(){
 for(const [name,control,ids,node,roles] of [
  ['MF','1','1+3','scenezoi.standing_idle',{male:'1',female:'3'}],
  ['FM','3','3+1','scenezoi.standing_idle',{female:'3',male:'1'}]]){
  const f=fixture(control);await flush();await f.activate();await flush();await f.poll();await flush();
  assert(f.request.includes('|open|'+control));assert.equal(f.hides,2);assert.equal(f.starts.length,0);
  f.set('selected',ids,node,Object.entries(roles).map(([role,id])=>role+':'+id).join('+'));await f.poll();await flush();assert.equal(f.starts.length,1,name);assert.equal(f.starts[0].node,node);assert.deepEqual(JSON.parse(JSON.stringify(f.starts[0].bindings)),roles);
 }
 const bed=fixture();await flush();await bed.activate('50','scenezoi_furniture');await bed.poll();await flush();assert(bed.request.endsWith('|1|50'));
 bed.set('selected','1+3','scenezoi.bed_single_idle','male:1+female:3','50');await bed.poll();await flush();assert.equal(bed.starts[0].furniture,'50');assert.equal(bed.starts[0].node,'scenezoi.bed_single_idle');
 const ff=fixture('3');await flush();await ff.activate();await ff.poll();ff.set('unavailable','no_starting_scene');await ff.poll();await flush();assert.equal(ff.starts.length,0);assert.equal(ff.declines.length,1);assert.equal(ff.declineTokens[0],ff.request.split('|')[1]);
 const cold=fixture();await flush();cold.restartHost();
 const firstClick=cold.activate();await flush();assert.equal(cold.request,'SZ2|old|open|1','Cold entry must wait for receiver readiness');
 await cold.poll();await flush();cold.retry();await firstClick;await flush();assert(cold.request.includes('|open|1'),'The original click must complete without another activation');
 const wrong=fixture();await flush();await wrong.activate('3');await flush();assert.equal(wrong.request,'SZ2|old|open|1');assert.equal(wrong.hides,2);
 const busy=fixture();await flush();busy.busy();await busy.activate();assert.equal(busy.request,'SZ2|old|open|1');assert.equal(busy.hides,2);assert.equal(busy.toasts.length,1);assert.match(busy.toasts[0].message,/already in progress/);
 for(const phase of ['preparing','exiting']){const f=fixture();await flush();f.busy();f.setPhase(phase);await f.activate();assert.equal(f.toasts.length,1);assert.equal(f.request,'SZ2|old|open|1');}
 const failed=fixture();await flush();await failed.activate();await failed.poll();failed.set('error','departure_failed');await failed.poll();await flush();assert.equal(failed.starts.length,0);assert.equal(failed.declines.length,1);
 const repeated=fixture();await flush();
 for(let n=0;n<8;n++){
  const old=repeated.request;await repeated.activate();await flush();assert.notEqual(repeated.request,old,'Every single native activation must write a new request');
  await repeated.poll();repeated.set('cancelled','none');await repeated.poll();await flush();
 }
 assert.equal(repeated.hides,9);assert.equal(repeated.declines.length,8);
 for(const ids of ['1','1+1','3+1','1+2','1+3+4','1+2+3','1+2+3+4']){
  const f=fixture();await flush();await f.activate();await f.poll();f.set('selected',ids);await f.poll();await flush();assert.equal(f.starts.length,0,ids);
 }
 for(const [ids,roles] of [['1+2','first:1+second:2'],['3+4','first:3+second:4'],['1+3+4','one:1+two:3+three:4'],['1+2+3','one:1+two:2+three:3']]){const f=fixture(ids[0]);await flush();await f.activate();await flush();await f.poll();f.set('selected',ids,'other.hub',roles);await f.poll();await flush();assert.equal(f.starts.length,1);assert.equal(f.starts[0].node,'other.hub');}
 console.log('Demo entry passed: separate launcher/receiver, eight single native activations, discovered MF/MM/FF/MFF/MMF roles accepted; unavailable scenes declined, self-only preflight, busy guard/departure failure, stale boot request and cancellation.');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
