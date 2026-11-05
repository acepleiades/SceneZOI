require('./fixtures/localization.cjs');
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const base='modkit/SceneZOI_93C44199/ui/scenezoi/';
const listeners={},classes=new Set(),reports=[],hovers=[],timers={};
let state={blocked:false,pause_reasons:[]},blurred=0,requests=0,resolvePoll=null,saved=0;
const root={id:'app-root',style:{},offsetLeft:100,offsetTop:200,offsetWidth:320,offsetHeight:410,
 classList:{toggle(name,on){on?classes.add(name):classes.delete(name);}},_saveWindowState(){saved++;},setAttribute(k,v){this[k]=v;},appendChild(el){el.parentNode=this;}};
const document={getElementById:id=>id==='app-root'?root:null,createElement:()=>({classList:{add(){},remove(){}},setAttribute(k,v){this[k]=v;}}),activeElement:{blur(){blurred++;}},
 addEventListener(name,fn){(listeners[name]??=[]).push(fn);},dispatchEvent(e){emit(e.type,e.target||document);}};
const ctx={document,window:{},inzoi:{view:{setContentRect(...args){reports.push(args);},hover(v){hovers.push(v);}},
 cli:{execute(command){assert.equal(command,'ui.get_blocking');requests++;if(resolvePoll===true)return new Promise(r=>resolvePoll=r);return Promise.resolve({success:true,data:state});}}},
 setInterval(fn,ms){timers[ms]=fn;},MouseEvent:function(type){this.type=type;},JSON,Promise};
function emit(type,target,fields={}){let stopped=false;const event={type,target,...fields,preventDefault(){},stopImmediatePropagation(){stopped=true;}};
 for(const fn of listeners[type]||[]){fn(event);if(stopped)break;}return stopped;}
async function flush(){for(let i=0;i<15;i++)await Promise.resolve();}
vm.runInNewContext(fs.readFileSync(base+'panel-state.js','utf8'),ctx);
(async()=>{
 await flush();assert(!classes.has('scene-menu-blocked'));
 // Simulate a late native injected hide button with an icon as the click target.
 const hide={id:'hide-btn',parentNode:root},icon={parentNode:hide},restore={id:'scene-restore',parentNode:root};
 assert(emit('mousedown',icon));assert(emit('mouseup',icon));assert(emit('click',icon));
 assert(classes.has('scene-compact'));assert.equal(root._savedW,320);assert.equal(root._savedH,410);
 root.offsetWidth=134;root.offsetHeight=36;
 // Attached panel/scaffold bounds must collapse to just the restore tab.
 ctx.inzoi.view.setContentRect(0,0,1000,900);assert.deepEqual(reports.at(-1),[100,200,134,36]);
 for(let i=0;i<100;i++){timers[125]();await flush();}
 assert(classes.has('scene-compact'),'Polling never reopens a deliberately hidden panel');
 assert(emit('click',restore));assert(!classes.has('scene-compact'));
 root.offsetWidth=320;root.offsetHeight=410;
 ctx.inzoi.view.setContentRect(100,160,800,450);assert.deepEqual(reports.at(-1),[100,160,800,450]);
 state={blocked:true,primary_kind:'modal_ui',input_block_ui_type:'GameMenu'};timers[125]();await flush();
 assert(classes.has('scene-menu-blocked'));assert.deepEqual(reports.at(-1),[-10000,-10000,1,1]);
 assert.equal(root['aria-disabled'],'true');ctx.inzoi.view.hover(true);assert.equal(hovers.at(-1),false);
 for(const name of ['mousedown','mouseup','click','wheel','keydown','keyup','contextmenu'])assert(emit(name,{id:'scene-exit',parentNode:root}),name);
 emit('click',icon);assert(!classes.has('scene-compact'),'Native hide cannot run behind a menu');
 state={blocked:false,pause_reasons:['UserPause']};timers[125]();await flush();
 assert(!classes.has('scene-menu-blocked'),'Time-control pause alone must leave controls usable');
 assert(!emit('click',{id:'scene-exit',parentNode:root}));
 assert.equal(root['aria-disabled'],'false');ctx.inzoi.view.hover(true);assert.equal(hovers.at(-1),true);
 emit('click',icon);ctx.window.SceneZOIPanel.reset();assert(!classes.has('scene-compact'),'New entry resets the hidden presentation');
 root.style.left='-280px';root.offsetLeft=-280;emit('click',icon);assert.equal(root.style.left,'0px','Restore tab must remain on-screen');
 emit('click',restore);assert.equal(root.style.left,'-280px','Expanded position is restored');root.offsetLeft=100;
 emit('click',icon);
 emit('mousedown',restore,{clientX:110,clientY:210,button:0});
 emit('mousemove',document,{clientX:170,clientY:250});
 assert.equal(root.style.left,'160px');assert.equal(root.style.top,'240px');
 assert(emit('mouseup',document,{clientX:170,clientY:250}));
 emit('click',restore);assert(classes.has('scene-compact'),'Mouseup/native click after dragging must not restore');
 assert.equal(saved,1,'Dragging persists the new placement with the expanded size');
 emit('mousedown',restore,{clientX:170,clientY:250,button:0});
 emit('mousemove',restore,{clientX:172,clientY:251});
 emit('mouseup',restore,{clientX:172,clientY:251});
 assert(!classes.has('scene-compact'),'Small pointer jitter must remain a normal restore click');
 assert.equal(root.style.left,'160px');assert.equal(root.style.top,'240px','Restored panel follows the dragged tab');
 assert.equal(root._savedW,320);assert.equal(root._savedH,410);
 emit('click',icon);emit('mousedown',restore,{clientX:110,clientY:210,button:0});
 emit('mousemove',document,{clientX:-900,clientY:3000});
 emit('mouseup',document);assert.equal(root.style.left,'0px');assert.equal(root.style.top,'1044px','Drag clamps restore tab into viewport');
 ctx.window.SceneZOIPanel.reset();
 root.style.visibility='hidden';ctx.inzoi.view.setContentRect(100,200,320,410);assert.deepEqual(reports.at(-1),[-10000,-10000,1,1]);
 resolvePoll=true;timers[125]();const count=requests;timers[125]();assert.equal(requests,count,'Only one native modal query may be in flight');
 resolvePoll({success:true,data:state});await flush();
 const css=fs.readFileSync(base+'index.html','utf8');
 assert.match(css,/#scene-navigation button, #scene-exit, #scene-restore \{ font-family: var\(--inzoi-font-ui\);/);
 assert(css.indexOf('src="window.js"')<css.indexOf('src="panel-state.js"'));
 assert(css.indexOf('src="panel-state.js"')<css.indexOf('src="outfit-ui.js"'));
 for(const id of ['scene-tools','scene-tasks','outfit-panel'])assert(css.includes('#app-root.scene-menu-blocked #'+id+'::after'));
 assert(!fs.readFileSync(base+'panel-state.js','utf8').includes("action: 'hide'"));
 console.log('Panel state passed: injected hide capture, restore, expanded size, hidden bounds, modal input/dimming, time pause, serialized polling.');
})().catch(e=>{console.error(e);process.exit(1);});
