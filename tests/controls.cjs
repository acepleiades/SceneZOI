require('./fixtures/localization.cjs');
const fs = require('fs');
const vm = require('vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const source = fs.readFileSync(path.resolve(__dirname, '../modkit/SceneZOI_93C44199/ui/scenezoi/app.js'), 'utf8');
function fixture(options = {}) {
  const elements = {};
  for (const id of ['title-text', 'close-btn', 'scene-status', 'scene-exit', 'scene-navigation', 'speed-down', 'speed-up', 'speed-label', 'speed-dots', 'scene-tools', 'outfit-toggle', 'view-options', 'scene-settings', 'outfit-panel', 'outfit-close', 'outfit-selector', 'outfit-participants', 'outfit-status', 'outfit-pieces', 'outfit-title', 'personality-fields', 'personality-status', 'expression-set', 'expression-choices', 'voice-fields', 'settings-fields', 'outfit-selector-wrap', 'settings-status-audio', 'settings-status-task_rates', 'task-rate-settings', 'audio-volume-settings', ...['sfx','female','male','task-female','task-male'].flatMap(k=>['slider','number','fill','thumb'].map(v=>'volume-'+v+'-'+k))]) {
    elements[id] = {style: {}, listeners: {}, setAttribute(k,v){this[k]=v;}, addEventListener(k, cb) { this.listeners[k] = cb; }};
  }
  elements['scene-navigation'].parentNode={insertBefore(el){elements[el.id]=el;}};
  const classes=new Set(),documentListeners={};
  const root = {id:'app-root',style: {},classList:{toggle(name,on){on?classes.add(name):classes.delete(name);}},setAttribute(){}, offsetLeft:100, offsetTop:100, offsetWidth:410, offsetHeight:210,appendChild(el){elements[el.id]=el;},insertAdjacentHTML(){}};
  const timers = {}, deferred = [], hover = [], rects = [], commands = [];
  let controlled = options.controlled === undefined ? 20524 : options.controlled;
  const genders = {20522:'Male',20524:'Female',...(options.genders || {})};
  let characterFailure = options.characterFailure || false;
  let activated, navigationState = '', playbackState = '', wardrobeState = '', state = '', hidden = 0, blurred = 0, failWrite = false;
  let personalityState = '';let catalogState='';let taskState='';let focusState='';let planState='';
  let deferNavigation = false, resolveNavigation;
  const context = {
    wf: {root, state:{}, content:{}, MOD_ID:'SceneZOI_93C44199'},
    document:{addEventListener(name,fn){(documentListeners[name]??=[]).push(fn);},createElement(){return {style:{},listeners:{},addEventListener(k,cb){this.listeners[k]=cb;},classList:{add(){},remove(){},toggle(){}},setAttribute(){},innerHTML:""};},getElementById:id=>id==='app-root'?root:elements[id],activeElement:{blur(){blurred++;}}},
    window:{addEventListener(){}},
    inzoi:{
      saveState:{register(cb){context.saveProvider=cb;}},
      trigger:{onActivated(cb){activated=cb;}},
      view:{hide(){hidden++;},hover(value){hover.push(value);},setContentRect(...rect){rects.push(rect);}},
      cli:{execute(command,params){
        commands.push({command,params});
        if (command==='ui.get_blocking') return Promise.resolve({success:true,data:{blocked:false,pause_reasons:[]}});
        if (command === 'entity.get_possessed') return Promise.resolve({success:true,data:{entity_id:controlled}});
        if (command === 'entity.get_character_info') {
          if (characterFailure) return Promise.reject(Error('Injected character lookup failure'));
          return Promise.resolve({success:true,data:{entity_id:params.entity_id,gender:genders[params.entity_id],bio_gender:genders[params.entity_id]==='Male'?'Female':'Male',growth_step:options.growth || 'Youth'}});
        }
        if (command==='uimod.cfg_load' && params?.key==='focus_session') return Promise.resolve({success:true,data:{value:focusState}});
        if (command==='uimod.cfg_load' && params?.key==='plan_state') return Promise.resolve({success:true,data:{value:planState}});
        if (command==='uimod.cfg_load' && params?.key==='navigation_state' && deferNavigation) {
          deferNavigation=false;return new Promise(resolve=>{resolveNavigation=resolve;});
        }
        if (failWrite && params?.key==='request') { failWrite=false; return Promise.reject(Error('Injected bridge failure')); }
        return Promise.resolve({success:true,data:command==='entity.get_possessed'?{entity_id:20524}:{value:params?.key==='navigation_state'?navigationState:params?.key==='playback_state'?playbackState:params?.key==='outfit_state'?wardrobeState:params?.key==='personality_state'?personalityState:params?.key==='catalog_state'?catalogState:params?.key==='task_state'?taskState:state}});
      }}
    },
    setInterval(cb,time){const earlier=timers[time];timers[time]=earlier?()=>{earlier();cb();}:cb;},setTimeout(cb){deferred.push(cb);},Promise,Date,Math,String,Number,Error,JSON
  };
  context.window = context;
  context.addEventListener = function() {};
  vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, 'fixtures/catalog.js'), 'utf8'), context);
  vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, '../modkit/SceneZOI_93C44199/ui/scenezoi/panel-state.js'),'utf8'),context);
  vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, '../modkit/SceneZOI_93C44199/ui/scenezoi/voice-ui.js'),'utf8'),context);
  vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, '../modkit/SceneZOI_93C44199/ui/scenezoi/settings-ui.js'),'utf8'),context);
  vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, '../modkit/SceneZOI_93C44199/ui/scenezoi/outfit-ui.js'),'utf8'),context);
  vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, '../modkit/SceneZOI_93C44199/ui/scenezoi/task-ui.js'),'utf8'),context);
  vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, '../modkit/SceneZOI_93C44199/ui/scenezoi/save-guard.js'),'utf8'),context);
  vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, '../modkit/SceneZOI_93C44199/ui/scenezoi/addon-bridge.js'),'utf8'),context);
  vm.runInNewContext(source,context);

  return {elements,root,timers,commands,hover,rects,classes,clickHide(){for(const fn of documentListeners.click)fn({target:{id:'hide-btn'},preventDefault(){},stopImmediatePropagation(){}});},start:()=>context.SceneZOIControls.start({initiator:String(controlled),node:'scenezoi.standing_idle',bindings:{male:'20522',female:'20524'}}),setTasks:s=>{taskState=s;},setFocus:s=>{focusState=s;},setPlan:s=>{planState=s;},setState:s=>{state=s;},setNavigation:s=>{navigationState=s;},setPlayback:s=>{playbackState=s;},setWardrobe:s=>{wardrobeState=s;},setPersonality:s=>{personalityState=s;},
    deferNavigation:()=>{deferNavigation=true;},resolveNavigation:value=>resolveNavigation({success:true,data:{value}}),
    setControlled:value=>{controlled=value;},setGender:(entity,value)=>{genders[entity]=value;},setCharacterFailure:value=>{characterFailure=value;},
    catalog:context.SceneZOICatalog,setCatalog:value=>{catalogState=value;},readCatalog:()=>context.SceneZOICatalog,refreshCatalog:()=>context.SceneZOIControls.refreshCatalog(),decline:(...args)=>context.SceneZOIControls.decline(...args),content:context.wf.content,hidden:()=>hidden,blurred:()=>blurred,failWrite:()=>{failWrite=true;},runDeferred:()=>deferred.splice(0).forEach(cb=>cb())};
}
async function flush(){for(let i=0;i<60;i++)await Promise.resolve();}
const writes=(ui,key)=>ui.commands.filter(c=>c.params?.key===key).map(c=>c.params.value);
async function run(){
  const hiddenPanel=fixture();await hiddenPanel.start();await flush();hiddenPanel.clickHide();
  assert(hiddenPanel.classes.has('scene-compact'));
  for(let i=0;i<12;i++){hiddenPanel.timers[1000]();await flush();}
  assert.equal(writes(hiddenPanel,'heartbeat').length,12,'Hidden presentation must keep session heartbeats running beyond the lease timeout');
  assert.equal(hiddenPanel.hidden(),0,'The native view must never be suspended');
  const savingExit=fixture();await savingExit.start();await flush();
  const savingFields=writes(savingExit,'request').at(-1).split('|');
  savingExit.setState(`SZ2|${savingFields[1]}|1|idle|saving`);savingExit.timers[250]();await flush();
  assert.equal(savingExit.root.style.visibility,'hidden','Saving exits close controls through the normal idle path');
  savingExit.runDeferred();await flush();assert.match(writes(savingExit,'focus').at(-1),/\|closed$/);
  // The panel follows the controlled Zoi's scene, whoever started it, and a new start keeps this panel's own identity.
  const follower=fixture();await flush();
  assert.notEqual(follower.root.style.visibility,'visible');
  follower.setFocus('SZ2|1|host.5.6|host|6|3|scenezoi.standing_idle|playing');follower.timers[250]();await flush();
  assert.equal(follower.root.style.visibility,'visible','Controlling a participant shows that scene');
  follower.timers[1000]();await flush();
  assert.match(writes(follower,'heartbeat').at(-1),/^SZ2\|host\|6\|/,'The panel speaks for the scene it shows');
  follower.setFocus('SZ2|2|none');follower.timers[250]();await flush();
  assert.equal(follower.root.style.visibility,'hidden','A Zoi outside every scene shows no panel');
  follower.runDeferred();await flush();
  await follower.start();await flush();
  const ownStart=writes(follower,'request').at(-1).split('|');
  assert.notEqual(ownStart[1],'host','A start after following another scene keeps this panel identity');
  assert.equal(ownStart[2],'1','This panel sequence is untouched by the scene it followed');
  // A scene with a plan shows the Auto-mode toggle, and the toggle sends one counted command.
  const planned=fixture();await flush();
  planned.setFocus('SZ2|1|host.5.6|host|6|3|scenezoi.standing_idle|playing');planned.timers[250]();await flush();
  planned.setPlan('SZ2|host|6|1|1|1|3');planned.timers[250]();await flush();
  const toggle=planned.elements['scene-auto-mode'];
  assert(toggle,'The toggle exists for a planned scene');
  assert.equal(toggle.style.display,'block','It is shown while the scene has a plan');
  assert.doesNotMatch(planned.elements['scene-navigation'].innerHTML||'',/data-option/,'Manual choices are hidden while Auto-mode drives');
  toggle.listeners.click();await flush();
  assert.match(writes(planned,'auto_mode').at(-1),/^SZ2\|host\|6\|auto_mode\|\d+\|0$/,'Turning it off names the scene it controls');
  planned.setPlan('SZ2|host|6|1|0|1|3');planned.timers[250]();await flush();
  toggle.listeners.click();await flush();
  assert.match(writes(planned,'auto_mode').at(-1),/\|1$/,'And back on');
  const counts=writes(planned,'auto_mode').map(v=>Number(v.split('|')[4]));assert(counts[1]>counts[0],'Each command is newer than the last');
  planned.setFocus('SZ2|2|none');planned.timers[250]();await flush();
  assert.equal(toggle.style.display,'none','A panel with no scene shows no toggle');
  const manual=fixture();await flush();
  manual.setFocus('SZ2|1|ui.1.2|ui.1|2|1|scenezoi.standing_idle|playing');manual.timers[250]();await flush();
  manual.setPlan('SZ2|ui.1|2|0|0|0|0');manual.timers[250]();await flush();
  assert.equal(manual.elements['scene-auto-mode'].style.display,'none','A manual scene has no toggle');
  const editorExit=fixture();await editorExit.start();await flush();
  const editorClient=writes(editorExit,'request').at(-1).split('|')[1];
  editorExit.setState(`SZ2|${editorClient}|1|idle|character_editor`);editorExit.timers[250]();await flush();
  assert.equal(editorExit.root.style.visibility,'hidden','Create a Zoi interruption must close the panel cleanly');
  await editorExit.start();await flush();
  assert.match(writes(editorExit,'request').at(-1),/\|2\|start\|/,'Returning from the editor must allow a fresh session');
  const discovery=fixture();
  const encode=value=>Buffer.from(JSON.stringify(value),'utf8').toString('hex');
  discovery.setCatalog(encode({nodes:{'designer.hub':{id:'designer.hub',label:'Neutral 日本語',navigation:[]}}}));
  await discovery.refreshCatalog();assert.deepEqual(Object.keys(discovery.readCatalog().nodes),['designer.hub']);
  assert.equal(discovery.readCatalog().nodes['designer.hub'].label,'Neutral 日本語');
  discovery.setCatalog(encode({nodes:{}}));await discovery.refreshCatalog();assert.equal(Object.keys(discovery.readCatalog().nodes).length,0);
  discovery.setCatalog('not hex');await assert.rejects(discovery.refreshCatalog());assert.equal(Object.keys(discovery.readCatalog().nodes).length,0);
  discovery.decline('20522','picker.test');await flush();assert.match(writes(discovery,'focus').at(-1),/\|rejected\|20522\|picker.test$/);
  const ui=fixture();
  let client;
  for(let sequence=1;sequence<=20;sequence++){
    ui.start();await flush();
    const start=writes(ui,'request').at(-1);
    const fields=start.split('|');client=fields[1];
    assert.deepEqual(fields.slice(2),[String(sequence),'start','20524','scenezoi.standing_idle','female:20524+male:20522']);
    ui.timers[1000]();await flush();
    assert.equal(writes(ui,'request').at(-1),start,'retry must reuse the exact Start request');
    assert.match(writes(ui,'heartbeat').at(-1),new RegExp(`\\|${sequence}\\|heartbeat\\|`));
    ui.setState(`SZ2|${client}|${sequence}|playing|ok`);ui.timers[250]();await flush();
    const requestCount=writes(ui,'request').length;
    for(let i=0;i<12;i++){ui.timers[1000]();await flush();}
    assert.equal(writes(ui,'request').length,requestCount,'heartbeats must not replace commands');
    ui.elements['scene-exit'].listeners.click();await flush();
    const exit=writes(ui,'request').at(-1);assert.equal(exit,`SZ2|${client}|${sequence}|exit`);
    // An old playing acknowledgement must not cancel the pending Exit.
    ui.setState(`SZ2|${client}|${sequence}|playing|ok`);ui.timers[250]();await flush();
    ui.timers[1000]();await flush();assert.equal(writes(ui,'request').at(-1),exit);
    assert.equal(ui.elements['scene-exit'].disabled,true);
    ui.setState(`SZ2|${client}|${sequence}|exiting|ok`);ui.timers[250]();await flush();
    assert.equal(ui.root.style.visibility,'visible');
    ui.setState(`SZ2|${client}|${sequence}|idle|ok`);ui.timers[250]();await flush();
    assert.equal(ui.root.style.visibility,'hidden');assert.deepEqual(ui.rects.at(-1),[-10000,-10000,1,1]);
    ui.runDeferred();await flush();
    assert.equal(writes(ui,'focus').at(-1),`SZ2|${client}|${sequence}|closed`);
    assert.equal(ui.hidden(),0);assert.equal(ui.blurred(),sequence);
  }
  ui.start();await flush();
  ui.setState(`SZ2|${client}|20|idle|ok`);ui.timers[250]();await flush();
  assert.equal(ui.root.style.visibility,'visible','previous-session acknowledgements must be ignored');
  const retry=fixture();retry.failWrite();retry.start();await flush();
  assert.match(retry.elements['scene-status'].textContent,/Retrying/);
  retry.timers[1000]();await flush();assert.equal(writes(retry,'request')[0],writes(retry,'request')[1]);
  assert(ui.hover.length>0 && ui.hover.every(v=>v===false));
  const nav=fixture();nav.start();await flush();
  const id=writes(nav,'request').at(-1).split('|')[1];
  nav.setState(`SZ2|${id}|1|playing|ok`);nav.timers[250]();await flush();
  nav.setNavigation(`SZ2|${id}|1|1|scenezoi.standing_idle|0|ok`);nav.timers[300]();await flush();
  assert.match(nav.elements['scene-navigation'].innerHTML,/Example/);
  nav.elements['scene-navigation'].listeners.click({target:{getAttribute:()=> 'example.enter'}});await flush();
  const request=writes(nav,'navigation').at(-1);
  assert.equal(request,`SZ2|${id}|1|navigate|1|example.enter|1`);
  nav.timers[1000]();await flush();assert.equal(writes(nav,'navigation').at(-1),request);
  nav.setNavigation(`SZ2|${id}|1|1|scenezoi.standing_idle|0|ok`);nav.timers[300]();await flush();
  assert.equal(nav.elements['scene-navigation'].innerHTML,'','Old navigation state must not unlock a pending command');
  nav.setNavigation(`SZ2|${id}|1|2|example.standing_idle|1|ok`);nav.timers[300]();await flush();
  assert.match(nav.elements['scene-navigation'].innerHTML,/Bow/);
  nav.deferNavigation();nav.timers[300]();await flush();
  nav.elements['scene-exit'].listeners.click();await flush();
  const count=writes(nav,'navigation').length;nav.timers[1000]();await flush();
  assert.equal(writes(nav,'navigation').length,count,'Exit must cancel navigation retries');
  nav.setState(`SZ2|${id}|1|idle|ok`);nav.timers[250]();await flush();
  assert.equal(nav.root.style.visibility,'hidden');
  nav.resolveNavigation(`SZ2|${id}|1|2|example.standing_idle|1|ok`);await flush();
  assert.equal(nav.root.style.visibility,'hidden','A delayed navigation reply cannot reopen the exited panel');
  const speed=fixture();speed.start();await flush();
  const speedClient=writes(speed,'request').at(-1).split('|')[1];
  speed.setState(`SZ2|${speedClient}|1|playing|ok`);speed.timers[250]();await flush();
  speed.elements['speed-up'].listeners.click();await flush();
  assert.equal(writes(speed,'playback').at(-1),`SZ2|${speedClient}|1|speed|1|3`);
  assert.equal(speed.elements['speed-label'].textContent,'x1.50');
  speed.timers[1000]();await flush();
  assert.equal(writes(speed,'playback').at(-1),`SZ2|${speedClient}|1|speed|1|3`);
  speed.setPlayback(`SZ2|${speedClient}|1|0|2|1.0000|1.0000`);speed.timers[350]();await flush();
  assert.equal(speed.elements['speed-label'].textContent,'x1.50','Old acknowledgement reset an in-flight speed change');
  speed.setPlayback(`SZ2|${speedClient}|1|1|3|0.0000|0.0000`);speed.timers[350]();await flush();
  assert.match(speed.elements['scene-status'].textContent,/Paused/);
  speed.elements['speed-up'].listeners.click();await flush();
  assert.equal(speed.elements['speed-label'].textContent,'x2.00');
  assert.equal(speed.elements['speed-up'].disabled,true);
  speed.elements['scene-exit'].listeners.click();await flush();
  const speedWrites=writes(speed,'playback').length;speed.timers[1000]();await flush();
  assert.equal(writes(speed,'playback').length,speedWrites,'Exit left speed retries active');
  assert.match(ui.content.innerHTML,/&lt;/);
  assert.match(ui.content.innerHTML,/&gt;/);
  const captions=fixture();
  const choices=captions.catalog.nodes['example.standing_idle'].navigation;
  choices[0].label='Return...';
  choices[1].label='';
  delete choices[2].label;
  choices[3].label='Custom <caption> & text';
  captions.start();await flush();
  const captionClient=writes(captions,'request').at(-1).split('|')[1];
  captions.setState(`SZ2|${captionClient}|1|playing|ok`);captions.timers[250]();await flush();
  captions.setNavigation(`SZ2|${captionClient}|1|1|example.standing_idle|0|ok`);captions.timers[300]();await flush();
  assert.match(captions.elements['scene-navigation'].innerHTML,/Return\.\.\./);
  assert.match(captions.elements['scene-navigation'].innerHTML,/Wave/);
  assert.match(captions.elements['scene-navigation'].innerHTML,/Handshake/);
  assert.match(captions.elements['scene-navigation'].innerHTML,/Custom &lt;caption> &amp; text/);
  console.log('Navigation captions passed: custom plain text, missing/empty destination-name fallback and escaped markup.');
  const wardrobe=fixture();
  wardrobe.start();await flush();
  const wardrobeClient=writes(wardrobe,'request').at(-1).split('|')[1];
  wardrobe.setState(`SZ2|${wardrobeClient}|1|playing|ok`);wardrobe.timers[250]();await flush();
  wardrobe.setNavigation(`SZ2|${wardrobeClient}|1|1|example.standing_idle|0|ok`);wardrobe.timers[300]();await flush();
  const hex=s=>Buffer.from(s,'utf8').toString('hex');
  const row=(on)=>`piece1:accessory:${hex('Bag')}:${hex('Bag: <Canvas> & "mod"')}:${on?1:0}:${hex('bag_id')}`;
  const inventory=(ack,on,status='ok',session=1)=>`SZ2|${wardrobeClient}|${session}|1|${ack}|${status}|20524:${hex('ZoÃ« Jang')}:${hex(row(on))}+20522:${hex('Jonovan Jang')}:${hex('none')}`;
  wardrobe.setWardrobe(inventory(0,true));wardrobe.timers[400]();await flush();
  wardrobe.elements['outfit-toggle'].listeners.click();
  assert.equal(wardrobe.elements['outfit-panel'].style.display,'flex');
  assert.equal(wardrobe.elements['scene-tools'].style.display,'flex');
  assert.equal(wardrobe.elements['outfit-selector'].textContent,'ZoÃ« Jang');
  assert.match(wardrobe.elements['outfit-pieces'].innerHTML,/Bag: &lt;Canvas> &amp; &quot;mod&quot;/);
  assert.match(wardrobe.elements['outfit-pieces'].innerHTML,/aria-checked="true"/);
  assert.equal(typeof wardrobe.elements['view-options'].listeners.click,'function');
  assert.equal(typeof wardrobe.elements['scene-settings'].listeners.click,'function');
  wardrobe.elements['scene-settings'].listeners.click();
  assert.equal(wardrobe.elements['outfit-title'].textContent,'Scene Settings');
  assert.equal(wardrobe.elements['outfit-selector-wrap'].style.display,'none');
  assert.equal(wardrobe.elements['settings-fields'].style.display,'block');
  assert.equal(wardrobe.elements['outfit-pieces'].style.display,'none');
  assert.equal(wardrobe.elements['scene-settings']['aria-expanded'],'true');
  wardrobe.elements['view-options'].listeners.click();
  assert.equal(wardrobe.elements['settings-fields'].style.display,'none');
  assert.equal(wardrobe.elements['outfit-title'].textContent,'Personality Management');
  wardrobe.elements['outfit-toggle'].listeners.click();
  // The hit rectangle includes attached controls and follows dragging.
  assert(wardrobe.rects.at(-1)[1]<wardrobe.root.offsetTop && wardrobe.rects.at(-1)[2]>wardrobe.root.offsetWidth);
  wardrobe.root.offsetLeft=700;wardrobe.root.offsetTop=480;
  wardrobe.elements['outfit-close'].listeners.click();
  assert.equal(wardrobe.elements['outfit-panel'].style.display,'none');
  assert.equal(wardrobe.rects.at(-1)[0],700);assert.equal(wardrobe.rects.at(-1)[1],440);
  wardrobe.elements['outfit-toggle'].listeners.click();
  const clickPiece=()=>wardrobe.elements['outfit-pieces'].listeners.click({target:{getAttribute:k=>k==='data-piece'?'piece1':null}});
  clickPiece();await flush();
  const outfitCommand=writes(wardrobe,'outfit').at(-1);
  assert.equal(outfitCommand,`SZ2|${wardrobeClient}|1|outfit|1|20524|piece1|0|1`);
  clickPiece();wardrobe.timers[1000]();await flush();
  assert(writes(wardrobe,'outfit').every(v=>v===outfitCommand),'A retry must reuse the absolute outfit command');
  assert.equal(wardrobe.elements['scene-navigation'].innerHTML,'','Navigation overtook a manual outfit update');
  wardrobe.setWardrobe(inventory(0,true));wardrobe.timers[400]();await flush();
  assert.match(wardrobe.elements['outfit-pieces'].innerHTML,/disabled/,'Old acknowledgement unlocked a pending edit');
  wardrobe.setWardrobe(inventory(1,false));wardrobe.timers[400]();await flush();
  assert.match(wardrobe.elements['outfit-pieces'].innerHTML,/aria-checked="false"/);
  assert(!wardrobe.elements['outfit-pieces'].innerHTML.includes(' disabled'));
  // Selecting another participant preserves the first person's starting rows.
  wardrobe.elements['outfit-participants'].listeners.click({target:{getAttribute:k=>k==='data-participant'?'20522':null}});
  assert.equal(wardrobe.elements['outfit-pieces'].innerHTML,'');
  wardrobe.elements['outfit-participants'].listeners.click({target:{getAttribute:k=>k==='data-participant'?'20524':null}});
  assert.match(wardrobe.elements['outfit-pieces'].innerHTML,/aria-checked="false"/);
  wardrobe.elements['outfit-toggle'].listeners.click();assert.equal(wardrobe.elements['outfit-panel'].style.display,'none');
  wardrobe.elements['outfit-toggle'].listeners.click();clickPiece();await flush();
  wardrobe.elements['scene-exit'].listeners.click();await flush();
  assert.equal(wardrobe.elements['outfit-panel'].style.display,'none');
  assert.equal(wardrobe.elements['scene-tools'].style.display,'none');
  const manualWrites=writes(wardrobe,'outfit').length;wardrobe.timers[1000]();await flush();
  assert.equal(writes(wardrobe,'outfit').length,manualWrites,'Exit left outfit retries active');
  wardrobe.setWardrobe(inventory(2,true));wardrobe.timers[400]();await flush();
  assert.equal(wardrobe.elements['outfit-panel'].style.display,'none','Late outfit acknowledgement reopened a closed panel');
  const personality=fixture();personality.start();await flush();
  const pc=writes(personality,'request').at(-1).split('|')[1];
  personality.setState(`SZ2|${pc}|1|playing|ok`);personality.timers[250]();await flush();
  personality.setNavigation(`SZ2|${pc}|1|1|example.standing_idle|0|ok`);personality.timers[300]();await flush();
  personality.setWardrobe(`SZ2|${pc}|1|1|0|ok|20524:${hex('ZoÃ«')}:${hex('none')}+20522:${hex('Jonovan')}:${hex('none')}`);
  personality.timers[400]();await flush();
  const metadata=[['example.pleasure_face','Pleasure face','female'],['example.downer','Downer','female'],['example.grinning_face','Grinning face','female'],['example.troubled_face','Troubled face','female'],['example.confident','Confident','male']].map(([id,label,body])=>`${hex(id)}:${hex(label)}:${body}`).join('+');
  const ps=(ack,set='example.pleasure_face',rev=1,code='ok',available=metadata)=>`SZ2|${pc}|1|${rev}|${ack}|${code}|20524:${hex('ZoÃ«')}:female:${hex(set)||'00'}:00+20522:${hex('Jonovan')}:male:${available==='none'?'00':hex('example.confident')}:00|${available}`;
  personality.setPersonality(ps(0));personality.timers[450]();await flush();
  personality.elements['outfit-toggle'].listeners.click();
  personality.elements['view-options'].listeners.click();
  assert.equal(personality.elements['outfit-title'].textContent,'Personality Management');
  assert.equal(personality.elements['outfit-pieces'].style.display,'none');
  assert.equal(personality.elements['personality-fields'].style.display,'block');
  assert.equal((personality.elements['expression-choices'].innerHTML.match(/data-expression=/g)||[]).length,4);
  assert.equal(personality.elements['expression-choices'].style.display,'none');
  personality.elements['expression-set'].listeners.click();
  assert.equal(personality.elements['expression-choices'].style.display,'block');
  personality.elements['expression-choices'].listeners.click({target:{getAttribute:k=>k==='data-expression'?'example.downer':null}});await flush();
  assert.equal(personality.elements['expression-choices'].style.display,'none');
  const pp=writes(personality,'personality').at(-1);assert.equal(pp,`SZ2|${pc}|1|personality2|1|20524|${hex("example.downer")}|1`);
  personality.timers[1000]();await flush();assert.equal(writes(personality,'personality').at(-1),pp);
  personality.setPersonality(ps(0));personality.timers[450]();await flush();
  assert(personality.elements['expression-set'].disabled,'Old acknowledgement must not finish a pending preference');
  personality.setPersonality(ps(1,'example.downer'));personality.timers[450]();await flush();
  assert.equal(personality.elements['expression-set'].textContent,'Downer');assert(!personality.elements['expression-set'].disabled);
  personality.setPersonality(ps(0));personality.timers[450]();await flush();
  assert.equal(personality.elements['expression-set'].textContent,'Downer','An older preference packet rolled back the acknowledged selection');
  personality.setPersonality(ps(1,'example.confident'));personality.timers[450]();await flush();
  assert.equal(personality.elements['expression-set'].textContent,'Downer','A mismatched-body definition was accepted');
  personality.elements['outfit-participants'].listeners.click({target:{getAttribute:k=>k==='data-participant'?'20522':null}});
  assert.equal((personality.elements['expression-choices'].innerHTML.match(/data-expression=/g)||[]).length,1);
  assert.match(personality.elements['expression-choices'].innerHTML,/Confident/);
  personality.setPersonality(ps(1,'',1,'ok','none'));personality.timers[450]();await flush();
  assert(personality.elements['expression-set'].disabled);assert.equal(personality.elements['expression-set'].textContent,'No expression sets available');
  assert.match(personality.elements['personality-status'].textContent,/No expression sets installed/);
  const extra=metadata+'+'+hex('designer tongue set')+':'+hex('Designer <custom>')+':male';
  personality.setPersonality(ps(1,'example.downer',1,'ok',extra));personality.timers[450]();await flush();
  assert.match(personality.elements['expression-choices'].innerHTML,/Designer &lt;custom>/,'Runtime installed definition was not added');
  personality.elements['outfit-toggle'].listeners.click();
  assert.equal(personality.elements['personality-fields'].style.display,'none');
  assert.equal(personality.elements['outfit-title'].textContent,'Outfit Management');
  personality.elements['view-options'].listeners.click();personality.elements['scene-exit'].listeners.click();await flush();
  assert.equal(personality.elements['outfit-panel'].style.display,'none');
  personality.setPersonality(ps(1));personality.timers[450]();await flush();assert.equal(personality.elements['outfit-panel'].style.display,'none');
    // Exercise the actual combined app/task/outfit layout and native hit rectangle.
    const tasksUI=fixture();tasksUI.start();await flush();
    const tc=writes(tasksUI,'request').at(-1).split('|')[1];
    tasksUI.setState(`SZ2|${tc}|1|playing|ok`);tasksUI.timers[250]();await flush();
    tasksUI.setNavigation(`SZ2|${tc}|1|1|scenezoi.standing_idle|0|ok`);tasksUI.timers[300]();await flush();
    tasksUI.elements['view-options'].listeners.click();
    const oldLeft=parseFloat(tasksUI.elements['outfit-panel'].style.left);
    const taskRow={participant_id:'1',participant_name:'Zoi',task_id:'spell',label:'Spell',percent:50,value:45,maximum:90,color:'#3185c3',track_color:'#bfbfbf',text_color:'#222222'};
    function taskFrame(rows,n){return `SZ2|${tc}|1|1|${n}|`+Buffer.from(JSON.stringify({rows})).toString('hex');}
    tasksUI.setTasks(taskFrame([taskRow],1));tasksUI.timers[150]();await flush();
    assert.equal(parseFloat(tasksUI.elements['outfit-panel'].style.left),oldLeft+142);
    assert(tasksUI.rects.at(-1)[2]>=tasksUI.root.offsetWidth*2+152);
    tasksUI.root.offsetHeight=510;tasksUI.root.offsetWidth=350;
    tasksUI.timers[150]();await flush();
    assert.equal(tasksUI.elements['scene-tasks'].style.height,'510px');
    assert.equal(parseFloat(tasksUI.elements['outfit-panel'].style.left),350+10+142);
    tasksUI.setTasks(taskFrame([],2));tasksUI.timers[150]();await flush();
    assert.equal(parseFloat(tasksUI.elements['outfit-panel'].style.left),360);
    tasksUI.elements['scene-exit'].listeners.click();await flush();assert.equal(tasksUI.elements['scene-tasks'].style.display,'none');
    console.log('Combined panels passed: task tray priority, configuration shift/return, resize, hit bounds and Exit.');
  const transitionUI=fixture();transitionUI.start();await flush();
  const trc=writes(transitionUI,'request').at(-1).split('|')[1];
  transitionUI.catalog.nodes['example.transition']={id:'example.transition',label:'Transition',kind:'transition',destination:'example.standing_idle',navigation:[{id:'should_not_show',target:'example.standing_idle'}]};
  transitionUI.setState(`SZ2|${trc}|1|playing|ok`);transitionUI.timers[250]();await flush();
  transitionUI.setNavigation(`SZ2|${trc}|1|1|example.transition|0|ok`);transitionUI.timers[300]();await flush();
  assert.equal(transitionUI.elements['scene-navigation'].innerHTML,'');assert.match(transitionUI.elements['scene-status'].textContent,/Transition in progress/);
  const attempts=writes(transitionUI,'navigation').length;
  transitionUI.elements['scene-navigation'].listeners.click({target:{getAttribute:()=> 'should_not_show'}});await flush();assert.equal(writes(transitionUI,'navigation').length,attempts);
  assert.equal(transitionUI.elements['speed-up'].disabled,false);transitionUI.elements['speed-up'].listeners.click();await flush();assert(writes(transitionUI,'playback').length>0);
  transitionUI.setNavigation(`SZ2|${trc}|1|2|example.standing_idle|0|ok`);transitionUI.timers[300]();await flush();assert.match(transitionUI.elements['scene-navigation'].innerHTML,/Bow/);
  transitionUI.elements['scene-exit'].listeners.click();await flush();assert.equal(writes(transitionUI,'request').at(-1).split('|').at(-1),'exit');
  console.log('Transition UI passed: hidden/locked navigation, live speed controls, automatic destination reappearance and Exit.');
  console.log('Personality UI passed: exclusive panels, native participant selector, four female/one male options, absolute preference retries, stale acknowledgements, selection isolation and Exit closure.');
  console.log('Outfit controls passed: UTF-8/escaped starting items, participant selection, absolute/retried toggles, stale acknowledgement, attached hit bounds, close/reopen and immediate Exit closure.');
  console.log('Controls checks passed: 20 sessions, separate heartbeats, stable command retries, stale acknowledgements, pending Exit, transient write failure, persistent native view, focus/hover release.');
}
run().catch(e=>{console.error(e);process.exitCode=1;});
