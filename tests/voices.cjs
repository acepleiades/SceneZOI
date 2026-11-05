require('./fixtures/localization.cjs');
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const file='modkit/SceneZOI_93C44199/ui/scenezoi/voice-ui.js';
const timers=[],writes=[];let raw='',selected='1',blocked=false;
let state={client:'test',sequence:1,revision:1,active:true,playing:true,exiting:false};
const container={innerHTML:'',addEventListener(k,f){this[k]=f;}};
const context={window:{},setInterval(f){timers.push(f);},encodeURIComponent,decodeURIComponent,JSON,Number,String,Error,Array,Object};
vm.runInNewContext(fs.readFileSync(file,'utf8'),context);
const library={archetypes:{mature:{label:'Mature',body:'female'},cute:{label:'Cute',body:'female'}},contexts:{breath:{label:'Breath'},'third author':{label:'Third author 日本語'}},sets:{'mature.breath':{label:'Megu Hiiragi',archetype:'mature',context:'breath',body:'female'},'cute.breath':{label:'Cute Set',archetype:'cute',context:'breath',body:'female'}},participants:{'1':{body:'female',archetype:'mature',sets:{breath:'mature.breath'}},'2':{body:'male',sets:{}}}};
const ui=context.window.SceneZOIVoiceUI.create({container,state:()=>state,selected:()=>selected,visible:()=>true,busy:()=>blocked,closeExpression(){},changed(){},write(k,v){writes.push({k,v});return Promise.resolve();},cfg(){return Promise.resolve({value:raw});}});
const hex=v=>Buffer.from(v).toString('hex');
function frame(d,ack=0,revision=state.revision){return ['SZ2',state.client,state.sequence,revision,ack,'ok',hex(JSON.stringify(d))].join('|');}
async function poll(){timers[0]();for(let i=0;i<10;i++)await Promise.resolve();}
function click(attrs){container.click({target:{getAttribute(k){return attrs[k]??null;},parentNode:container}});}
(async()=>{
 ui.update();raw=frame(library);await poll();
 assert.match(container.innerHTML,/Third author 日本語/);assert.match(container.innerHTML,/Mature/);assert.match(container.innerHTML,/Megu Hiiragi/);
 click({'data-voice-open':'archetype'});assert.match(container.innerHTML,/aria-expanded="true"/);
 click({'data-voice-action':'archetype','data-voice-value':'cute'});assert.equal(writes.at(-1).v,'SZ2|test|1|voice|1|1|archetype|63757465|1');assert(ui.busy());
 ui.retry();assert.equal(writes.length,2);
 const changed=structuredClone(library);changed.participants['1'].archetype='cute';changed.participants['1'].sets.breath='cute.breath';
 raw=frame(changed,1);await poll();assert(!ui.busy());assert.match(container.innerHTML,/Cute Set/);
 raw=frame(library,0);await poll();assert.match(container.innerHTML,/Cute Set/,'An old acknowledgement must not replace the new profile');
 raw=frame(library,2,0);await poll();assert.match(container.innerHTML,/Cute Set/,'A stale revision must be rejected');
 const mixed=structuredClone(changed);mixed.participants['1'].sets.breath='mature.breath';raw=frame(mixed,2);await poll();assert.match(container.innerHTML,/Cute Set/,'A mixed-archetype frame must be rejected transactionally');
 selected='2';ui.update();assert(!container.innerHTML.includes('data-voice-action="archetype" data-voice-value="cute"'),'Male choices must exclude female archetypes');assert.match(container.innerHTML,/None \(silent\)/);
 selected='1';ui.update();click({'data-voice-action':hex('breath'),'data-voice-value':''});assert.match(writes.at(-1).v,/\|voice\|2\|1\|627265617468\|00\|1$/);
 state.exiting=true;ui.update();assert(!ui.busy());const n=writes.length;ui.retry();assert.equal(writes.length,n);
 state={...state,sequence:2,exiting:false};ui.update();assert.match(container.innerHTML,/Loading voices/,'A new session must discard the old roster');
 console.log('Voice UI passed: runtime contexts, custom picker interaction, persistence commands, retry/ack ordering, stale/mixed-frame rejection, body filtering, silence and Exit/session reset.');
})().catch(e=>{console.error(e);process.exitCode=1;});
