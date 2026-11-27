require('./fixtures/localization.cjs');
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const elements={},docEvents={},timers=[],writes=[];
for(const key of ['sfx','female','male','task-female','task-male'])for(const part of ['slider','number','fill','thumb'])elements['volume-'+part+'-'+key]={style:{},value:'',setAttribute(k,v){this[k]=v;},addEventListener(k,f){this[k]=f;},getBoundingClientRect(){return {left:100,width:200};}};
for(const k of ['settings-status-audio','settings-status-task_rates','audio-volume-settings','task-rate-settings','debug-start-settings','settings-status-debug_start'])elements[k]={};
elements['setting-toggle-manual-start']={addEventListener(k,f){this[k]=f;},setAttribute(k,v){this[k]=v;}};
for(const suffix of ['','-editor','-person','-mesh','-bone','-X','-Y','-Z','-export','-status']){
 elements['attachment-preview'+suffix]={style:{},value:'',addEventListener(k,f){this[k]=f;}};
}
let taskRaw='',debugRaw='',settingsReads=0;
let previewRaw='',previewReads=0,previewDeferred=null;
let s={client:'test',sequence:1,revision:2,active:true,exiting:false,pendingNavigation:null},raw='',visible=true,deferred=null;
const document={getElementById:k=>elements[k],activeElement:null,addEventListener(k,f){(docEvents[k]??=[]).push(f);}};
for(const [id,input] of Object.entries(elements)){
 if(!/^volume-number-|^attachment-preview-[XYZ]$/.test(id))continue;
 input.select=function(){this.selectionStart=0;this.selectionEnd=this.value.length;};
 input.focus=function(){document.activeElement=this;this.focusin?.();};
}
const context={window:{addEventListener(){}},document,setInterval(f){timers.push(f);},Number,String,Object,Math,Promise};
vm.runInNewContext(fs.readFileSync('modkit/SceneZOI_93C44199/ui/scenezoi/settings-ui.js','utf8'),context);
const ui=context.window.SceneZOISettingsUI.create({container:{},state:()=>s,visible:()=>visible,write(k,v){writes.push({k,v});return Promise.resolve();},cfg(command,key){if(key.startsWith('settings_'))settingsReads++;if(key==='settings_task_rates_state')return Promise.resolve({value:taskRaw});if(key==='settings_debug_start_state')return Promise.resolve({value:debugRaw});if(key==='attachment_preview_state'){previewReads++;return previewDeferred?new Promise(resolve=>{previewDeferred=resolve;}):Promise.resolve({value:previewRaw});}return deferred?new Promise(resolve=>{deferred.resolve=resolve;}):Promise.resolve({value:raw});}});
const number=k=>elements['volume-number-'+k],slider=k=>elements['volume-slider-'+k];
const event=x=>({button:0,clientX:x,preventDefault(){}});
function frame(ack=0,values=[100,100,100],code='ok',rev=s.revision){return ['SZ2',s.client,s.sequence,rev,ack,code,...values].join('|');}
async function poll(){timers[1]();for(let i=0;i<10;i++)await Promise.resolve();}
function typed(k,value){number(k).value=value;number(k).change();}
function replaceByTyping(input,value){
 const next=input.value.slice(0,input.selectionStart)+value+input.value.slice(input.selectionEnd);
 assert(next.length<=3,'The current value must be selected before typing into a full percentage field');
 input.value=next;
}
function enter(input,type,fields){
 let prevented=false;
 input[type]({...fields,preventDefault(){prevented=true;}});
 assert(prevented,`Handled Enter event must prevent default: ${type}`);
}
(async()=>{
 visible=false;
 for (const tick of timers.slice(0,4)) tick();
 assert.equal(settingsReads,0,'A closed settings panel must leave settings state alone');
 visible=true;
 assert(number('sfx').disabled);raw=frame();await poll();assert(!number('sfx').disabled);
 s.paused=true;ui.update();const pausedWrites=writes.length;
 assert(number('sfx').disabled);typed('sfx','80');enter(number('sfx'),'keydown',{key:'Enter'});
 slider('sfx').mousedown(event(175));docEvents.mousemove.forEach(f=>f(event(240)));docEvents.mouseup.forEach(f=>f());
 assert.equal(writes.length,pausedWrites,'Paused numeric/slider events must not submit or queue settings');
 s.paused=false;ui.update();assert(!number('sfx').disabled);
 slider('sfx').mousedown(event(175));assert.equal(number('sfx').value,'75');assert.equal(writes.length,0,'Dragging previews without flooding persistent storage');
 docEvents.mousemove.forEach(f=>f(event(240)));docEvents.mouseup.forEach(f=>f());assert.equal(writes.at(-1).v,'SZ2|test|1|settings_audio|1|2|140|100|100');
 ui.retry();assert.equal(writes.length,2);assert.equal(writes[0].v,writes[1].v);
 raw=frame();await poll();assert.equal(number('sfx').value,'140','Unacknowledged frames must not undo a pending edit');
 number('female').value='0';
 enter(number('female'),'keydown',{keyCode:13});
 enter(number('female'),'keypress',{charCode:13});
 enter(number('female'),'keyup',{which:13});
 assert.equal(writes.length,3,'A complete legacy Enter sequence applies the value once');
 assert.equal(writes.at(-1).v,'SZ2|test|1|settings_audio|2|2|140|0|100');
 raw=frame(1,[140,100,100]);await poll();assert.equal(number('female').value,'0','Older acknowledgements must not replace a newer full snapshot');
 visible=false;
 raw=frame(2,[140,0,100]);await poll();assert.match(elements['settings-status-audio'].textContent,/Saved/);
 const closedReads=settingsReads;await poll();assert.equal(settingsReads,closedReads,'A hidden edit may finish without restoring background settings reads');
 visible=true;
 typed('male','201');typed('male','-1');typed('male','1.5');typed('male','');assert.equal(writes.length,3);assert.match(elements['settings-status-audio'].textContent,/whole number/);
 raw=frame(2,[140,0,100]);await poll();assert.match(elements['settings-status-audio'].textContent,/whole number/,'Polling must not erase validation feedback before it can be read');
 slider('male').keydown({key:'End',preventDefault(){}});assert.match(writes.at(-1).v,/\|140\|0\|200$/);
 raw=frame(3,[140,0,200]);await poll();raw=frame(2);await poll();assert.equal(number('male').value,'200');
 typed('sfx','25');raw=frame(4,[140,0,200],'settings_storage');await poll();assert.equal(number('sfx').value,'140');assert.match(elements['settings-status-audio'].textContent,/Could not save/);
 raw=frame(5,[1,2,999]);await poll();assert.equal(number('sfx').value,'140','Malformed frames must reject all values');
 raw=frame(5,[1,2,3],'ok',1);await poll();assert.equal(number('sfx').value,'140','Stale revision must be rejected');
 raw=frame(4,[140,0,200]);await poll();s.pendingNavigation='moving';ui.update();assert(number('sfx').disabled);s.pendingNavigation=null;
 deferred={};timers[1]();const old=deferred;s={...s,sequence:2};ui.update();old.resolve({value:raw});for(let i=0;i<10;i++)await Promise.resolve();assert(number('sfx').disabled,'An old asynchronous result must not unlock a new session');deferred=null;
 raw=frame(0,[140,0,200]);await poll();assert.equal(number('male').value,'200','New sessions load global preferences');
 slider('sfx').mousedown(event(100));visible=false;ui.update();docEvents.mouseup.forEach(f=>f());assert.equal(writes.length,5,'Closing a panel cancels an unfinished drag');
 visible=true;typed('female','80');s.exiting=true;ui.update();const before=writes.length;ui.retry();assert.equal(writes.length,before);assert(number('sfx').disabled);
 s.exiting=false;ui.update();
 taskRaw=frame(0,[100,100]);timers[0]();for(let i=0;i<10;i++)await Promise.resolve();
 assert(!number('task-female').disabled && !number('task-male').disabled);
 const previousAudio=number('male').value;
 const taskField=number('task-female');
 let prevented=false;
 assert.equal(typeof taskField.mousedown,'function','Clicking a percentage must focus it for replacement');
 taskField.mousedown({button:0,preventDefault(){prevented=true;}});
 assert(prevented && document.activeElement===taskField);
 assert.deepEqual([taskField.selectionStart,taskField.selectionEnd],[0,3]);
 const beforeTyping=writes.length;
 replaceByTyping(taskField,'50');
 assert.equal(writes.length,beforeTyping,'Typing should wait for the usual commit');
 enter(number('task-female'),'keydown',{code:'NumpadEnter'});
 assert.deepEqual([taskField.selectionStart,taskField.selectionEnd],[0,2]);
 taskField.mousedown({button:0,preventDefault(){assert.fail('An already focused field must allow normal caret placement');}});
 number('task-male').focus();
 replaceByTyping(number('task-male'),'200');
 enter(number('task-male'),'keyup',{keyCode:13});
 assert.equal(writes.at(-1).k,'settings_task_rates');assert.match(writes.at(-1).v,/\|settings_task_rates\|2\|2\|50\|200$/);
 assert.equal(number('male').value,previousAudio,'Task edits must not alter volume controls');
 taskRaw=frame(1,[50,100]);timers[0]();for(let i=0;i<10;i++)await Promise.resolve();assert.equal(number('task-male').value,'200','An older task ack must not undo the other task slider');
 taskRaw=frame(2,[50,200]);timers[0]();for(let i=0;i<10;i++)await Promise.resolve();
 slider('task-female').mousedown(event(100));docEvents.mouseup.forEach(f=>f());assert.match(writes.at(-1).v,/\|10\|200$/);
 ui.retry();assert.equal(writes.at(-1).k,'settings_task_rates','Group retries must keep their own mailbox');
 taskRaw=frame(3,[10,200]);timers[0]();for(let i=0;i<10;i++)await Promise.resolve();
 const writesBeforeInvalid=writes.length;
 typed('task-male','9');typed('task-male','501');assert.equal(writes.length,writesBeforeInvalid);
 assert.match(elements['settings-status-task_rates'].textContent,/10 to 500/);
 slider('task-male').keydown({key:'End',preventDefault(){}});assert.match(writes.at(-1).v,/\|10\|500$/);
 slider('task-female').mousedown(event(200));docEvents.mouseup.forEach(f=>f());assert.match(writes.at(-1).v,/\|255\|500$/,'Dragging must map the new range linearly');
 assert.equal(elements['volume-fill-task-female'].style.width,'50%');
 assert.match(elements['task-rate-settings'].innerHTML,/aria-valuemin="10" aria-valuemax="500"/);
 const markup=fs.readFileSync('modkit/SceneZOI_93C44199/ui/scenezoi/settings-ui.js','utf8');assert(markup.indexOf('Female Task Progress Rate')<markup.indexOf("['Sound Effects'"),'Task sliders must precede volume sliders');
 const css=fs.readFileSync('modkit/SceneZOI_93C44199/ui/scenezoi/index.html','utf8');
 assert.match(css,/#settings-status-task_rates, #settings-status-audio \{ font-size: 12px/,'Both settings hint/status blocks must use the shared 12px presentation');
 assert.doesNotMatch(markup,/npc-scene-settings|Default NPC session duration/);
 const debug=elements['setting-toggle-manual-start'];
 assert(debug.disabled);
 debugRaw=frame(0,[0]);timers[2]();for(let i=0;i<10;i++)await Promise.resolve();
 assert(!debug.disabled && debug['aria-checked']==='false');
 const debugMarkup=elements['debug-start-settings'].innerHTML;
 assert.match(debugMarkup,/<button[^>]+role="switch"[^>]+aria-describedby="settings-hint-debug_start"/);
 assert.match(debugMarkup,/Use the picker to start scenes from your Zoi or supported furniture\.<\/p><button/);
 assert.match(debugMarkup,/>SceneZOI manual start<\/span>/);
 assert.doesNotMatch(debugMarkup,/\(Debug\)/);
 assert.doesNotMatch(elements['debug-start-settings'].innerHTML,/<input/);
 debug.click();assert.match(writes.at(-1).v,/\|settings_debug_start\|1\|2\|1$/);
 debugRaw=frame(1,[1]);timers[2]();for(let i=0;i<10;i++)await Promise.resolve();
 assert.equal(debug['aria-checked'],'true');debug.click();assert.match(writes.at(-1).v,/\|settings_debug_start\|2\|2\|0$/);
 await checkAttachmentPreview();
 console.log('Settings UI passed: drag/keyboard/numeric input, bounded values, coalesced persistence, retry/ack ordering, stale/foreign frames, failure feedback, panel/Exit cancellation and cross-session settings.');
})().catch(e=>{console.error(e);process.exitCode=1;});

async function checkAttachmentPreview(){
 const element=(suffix='')=>elements['attachment-preview'+suffix];
 const frame=(ack,rows,code='ok',token=s.token)=>['SZ2',s.client,s.sequence,s.revision,ack,code,token,Buffer.from(JSON.stringify(rows)).toString('hex')].join('|');
 const poll=async()=>{timers[3]();for(let i=0;i<10;i++)await Promise.resolve();};
 const request=()=>{
  const packet=writes.filter(row=>row.k==='attachment_preview').at(-1);
  assert(packet);
  const [version,client,seq,op,ack,revision,token,hex]=packet.v.split('|');
  assert.deepEqual([version,client,seq,op,revision,token],['SZ2',s.client,String(s.sequence),'attachment_preview',String(s.revision),s.token]);
  return {ack:Number(ack),command:JSON.parse(Buffer.from(hex,'hex').toString())};
 };
 const select=(kind,value)=>element().click({target:{getAttribute(k){return k==='data-preview-select'?kind:k==='data-preview-option'?value:null;}}});
 assert.equal(element().style.display,'none');
 s={...s,playing:true,token:'current-token',counterBase:120};
 const first={participant:'5',name:'A <B>',role:'male',attachment:'pack.prop.male',mesh:'/Pack/Preview.MeshName',bones:['joint_l','joint_r'],rotations:{}};
 const second={participant:'6',name:'Second Zoi',role:'partner',attachment:'pack.prop.partner',mesh:'/Pack/Other.OtherMesh',bones:['base'],rotations:{}};
 previewRaw=frame(0,[first,second],'ok','older-token');
 await poll();
 assert.equal(element().style.display,'none','Older tokens cannot load controls');
 previewRaw=frame(0,[first,second]);
 await poll();
 assert.equal(element().style.display,'block');
 assert.match(element('-person').innerHTML,/A &lt;B&gt;/);
 assert.match(element('-mesh').innerHTML,/MeshName/);
 assert.match(element('-bone').innerHTML,/joint_l/);
 assert(element('-export').disabled,'A scene with no preview edits has nothing to export');
 select('bone','joint_r');
 const x=element('-X'), y=element('-Y');
 x.mousedown({button:0,preventDefault(){}});
 assert.equal(document.activeElement,x);
 assert.deepEqual([x.selectionStart,x.selectionEnd],[0,x.value.length],'Angle fields should also select the current value');
 document.activeElement=null;
 const oldWrites=writes.length;
 x.value='181';x.change();
 assert.equal(writes.length,oldWrites);
 assert.match(element('-status').textContent,/-180 to 180/);
 x.value='23.5';enter(x,'keydown',{keyCode:13});
 enter(x,'keypress',{charCode:13});
 enter(x,'keyup',{keyCode:13});
 x.change();
 const a=request();
 assert.equal(a.ack,121);
 assert.deepEqual(a.command,{action:'rotate',participant:'5',attachment:'pack.prop.male',bone:'joint_r',rotation:[23.5,0,0]});
 y.value='-10';enter(y,'keydown',{key:'Enter'});
 assert.equal(writes.length,oldWrites+1,'Only the latest edit waits for the first acknowledgement');
 ui.retry();
 assert.equal(request().ack,a.ack);
 first.rotations.joint_r=[23.5,0,0];
 previewRaw=frame(a.ack,[first,second]);
 await poll();
 const b=request();
 assert.equal(b.ack,a.ack+1);
 assert.deepEqual(b.command.rotation,[23.5,-10,0]);
 first.rotations.joint_r=b.command.rotation;
 previewRaw=frame(b.ack,[first,second]);
 await poll();
 select('person','6');
 assert.match(element('-mesh').innerHTML,/OtherMesh/);
 assert.equal(x.value,'0','Other targets have separate rotations');
 assert(!element('-export').disabled,'All scene edits can be exported regardless of the selected target');
 element('-export').click();
 const exported=request();
 assert.deepEqual(exported.command,{action:'export'});
 previewRaw=frame(exported.ack,[first,second],'preview_exported');
 await poll();
 assert.match(element('-status').textContent,/scenezoi_runtime\/attachment_pose_reference\.cfg/);

 first.hidden=true;
 previewRaw=frame(exported.ack,[first,second]);
 await poll();
 assert.doesNotMatch(element('-person').innerHTML,/A &lt;B&gt;/);
 assert(!element('-export').disabled,'An edited hidden mesh can be exported while other meshes stay visible');
 previewRaw=frame(exported.ack,[first]);
 await poll();
 assert.equal(element().style.display,'block');
 assert.equal(element('-editor').style.display,'none');
 assert(x.disabled&&!element('-export').disabled,'An edited hidden mesh leaves only Export available');
 for(const [code,pattern] of [
  ['preview_export_empty',/no attachment pose edits/],
  ['preview_export_read',/read the existing/],
  ['preview_export_full',/64 KiB/],
  ['preview_export_write',/write the attachment/]
 ]){
  element('-export').click();
  const attempt=request();
  assert.deepEqual(attempt.command,{action:'export'});
  previewRaw=frame(attempt.ack,[first],code);
  await poll();
  assert.match(element('-status').textContent,pattern);
  assert(!element('-export').disabled,'A failed export can be retried');
 }

 s.paused=true;ui.update();assert(x.disabled && element('-export').disabled);
 const paused=writes.length;x.value='25';enter(x,'keydown',{key:'Enter'});element('-export').click();
 assert.equal(writes.length,paused,'Paused preview edits and exports must do nothing');
 s.paused=false;ui.update();assert(x.disabled && !element('-export').disabled,'Resume preserves hidden-mesh restrictions');
 s.pendingNavigation='pending';ui.update();
 assert(x.disabled);
 s.pendingNavigation=null;
 previewDeferred=true;timers[3]();const finishRead=previewDeferred;await Promise.resolve();
 s={...s,revision:s.revision+1};ui.update();
 finishRead({value:previewRaw});for(let i=0;i<10;i++)await Promise.resolve();
 assert.equal(element().style.display,'none','A late previous revision cannot expose the old attachments');
 previewDeferred=null;
 previewRaw=frame(0,[]);
 await poll();
 assert.equal(element().style.display,'none','The panel disappears when no attachments qualify');
 visible=false;
 const readsBefore=previewReads;
 await poll();
 assert.equal(previewReads,readsBefore,'Preview polling only runs while Scene Settings is open');
}
