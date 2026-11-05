require('./fixtures/localization.cjs');
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
let state={client:'test',sequence:1,revision:1,active:true,exiting:false},raw='',changed=0;
const timers=[],elements={};
const root={offsetLeft:100,offsetTop:200,offsetWidth:320,offsetHeight:410,clientLeft:1,clientTop:1,appendChild(el){elements[el.id]=el;}};
const document={createElement(){return {style:{},setAttribute(){},innerHTML:''};},getElementById(id){return elements[id]||null;}};
const ctx={window:{},document,setInterval(fn){timers.push(fn);},JSON,Number,String,Array,Object,Math,isFinite,decodeURIComponent};
vm.runInNewContext(fs.readFileSync('modkit/SceneZOI_93C44199/ui/scenezoi/task-ui.js','utf8'),ctx);
const tray=ctx.window.SceneZOITaskUI.create({root,state:()=>state,cfg:()=>Promise.resolve({value:raw}),changed(){changed++;}});
const row={participant_id:'1',participant_name:'Alice <Zoi>',task_id:'spell',label:'Spell charging',percent:50,value:45,maximum:90,color:'#3185c3',track_color:'#bfbfbf',text_color:'#222222'};
function frame(rows,n=1,revision=1,sequence=1){return ['SZ2','test',sequence,revision,n,Buffer.from(JSON.stringify({rows})).toString('hex')].join('|');}
async function poll(){timers[0]();for(let i=0;i<12;i++)await Promise.resolve();}
(async()=>{
 tray.update();assert.equal(tray.width(),0);assert.equal(tray.bounds(),null);
 raw=frame([row]);await poll();assert.equal(tray.width(),142);assert.deepEqual(Array.from(tray.bounds()),[430,200,132,410]);
 const el=elements['scene-tasks'];assert.match(el.innerHTML,/50%/);assert.match(el.innerHTML,/Alice &lt;Zoi>/);assert.match(el.innerHTML,/d="M 43 6.88 A 36.12 36.12 0 0 1 43.0000 79.1200"/);
 assert(!el.innerHTML.includes('stroke-dasharray'));
 for(const [percent,end]of [[0,null],[25,'79.1200 43.0000'],[75,'6.8800 43.0000'],[99,'40.7310 6.9513'],[100,null]]){
   raw=frame([{...row,percent,value:percent*.9}],10+percent);await poll();
   if(percent===0)assert(!el.innerHTML.includes('<path'),'Zero has only gray track');
   else if(percent===100)assert.equal((el.innerHTML.match(/<circle/g)||[]).length,2,'Full progress has full colored circle');
   else {assert.match(el.innerHTML,new RegExp('A 36.12 36.12 0 '+(percent>50?'1':'0')+' 1'));if(percent!==99)assert(el.innerHTML.includes(end));}
 }
 // Use subsequent counters beyond the range above.

 root.offsetHeight=520;root.offsetWidth=400;tray.update();assert.equal(el.style.height,'520px');assert.equal(el.style.left,'409px');
 raw=frame([],0);await poll();assert.equal(tray.width(),142,'Older frames cannot clear tray');
 raw=frame([],2,0);await poll();assert.equal(tray.width(),142,'Stale revisions rejected');
 raw=frame([{...row,color:'url(unsafe)'}],2);await poll();assert.equal(tray.width(),142,'Invalid frame rejected atomically');
 const many=Array.from({length:12},(_,i)=>({...row,participant_id:String(i),participant_name:'Participant '+i}));
 raw=frame(many,113);await poll();assert.equal((el.innerHTML.match(/class="scene-task"/g)||[]).length,12);
 raw=frame([],114);await poll();assert.equal(tray.width(),0);assert.equal(tray.bounds(),null);
 raw=frame([row],115);await poll();state.exiting=true;tray.update();assert.equal(tray.width(),0);
 state={...state,exiting:false,sequence:2};tray.update();raw=frame([row],99,1,1);await poll();assert.equal(tray.width(),0,'Old session cannot repopulate tray');
 const css=fs.readFileSync('modkit/SceneZOI_93C44199/ui/scenezoi/index.html','utf8');assert.match(css,/#scene-task-list[^}]*overflow-y: scroll/);
 console.log('Task tray passed: ring percentages, escaped labels, multiple actors, resizing, empty/Exit removal, stale session/revision/frame rejection and validated presentation.');
})().catch(e=>{console.error(e);process.exit(1);});
