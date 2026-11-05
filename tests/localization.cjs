const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const css=fs.readFileSync('modkit/SceneZOI_93C44199/ui/scenezoi/index.html','utf8');
assert.match(css,/<link[^>]+href="coui:\/\/inzoi\/mod\/inzoi-fonts\.css"/);
// The title rendered CJK while these controls showed boxes: their override
// narrowed the native stack to Latin/Korean faces. Apply the whole stack.
for(const selector of ['#scene-navigation button','#scene-exit','#scene-restore']){
 const rules=Array.from(css.replace(/\/\*[\s\S]*?\*\//g,'').matchAll(/([^{}]+)\{([^{}]*)\}/g)).filter(m=>m[1].split(',').some(s=>s.trim()===selector));
 const fonts=rules.map(m=>m[2].match(/font-family:\s*([^;]+);/)).filter(Boolean);
 assert(fonts.length>0,selector+' must set its native multilingual control font explicitly');
 assert.equal(fonts.at(-1)[1],'var(--inzoi-font-ui)',selector+' must retain the CJK fallback faces');
}
let language='fr-FR',pending=[],calls=0;
const dictionary={culture:'en-US',messages:{'en-US':{Exit:'Exit'},'fr-FR':{Exit:'Quitter','From {min} to {max}':'De {min} à {max}','Bag':'Sac'}},labels:{}};
const raw=Buffer.from(JSON.stringify(dictionary)).toString('hex');
const context={window:{},document:{documentElement:{}},Promise,Array,Object,String,JSON,decodeURIComponent,inzoi:{cli:{execute(command){calls++;return Promise.resolve({success:true,data:command==='gameplay.get_settings'?{language}:{value:raw}});}}}};
vm.runInNewContext(fs.readFileSync('modkit/SceneZOI_93C44199/ui/scenezoi/localization.js','utf8'),context);
const L=context.window.SceneZOILocalization;
(async()=>{
 assert.equal(L.text('Exit'),'Exit');await L.refresh();assert.equal(L.text('Exit'),'Quitter');assert.equal(context.document.documentElement.lang,'fr-FR');
 assert.equal(L.text('From {min} to {max}',{min:10,max:500}),'De 10 à 500');assert.equal(L.text('Missing'),'Missing');
 assert.equal(L.html('<script>'), '&lt;script&gt;');assert.equal(L.outfitLabel('accessory','Bag','Bag: bag_asset','bag_asset'),'Sac');assert.equal(L.outfitLabel('accessory','Bag','Bag: My bag','bag_asset'),'Sac: My bag');
 language='xx';await L.refresh();assert.equal(L.text('Exit'),'Exit');
 language='ja-JP';await L.refresh();assert.equal(L.text('Exit'),'Exit','An absent translation keeps English');
 console.log('Localization UI passed: language changes, English entry fallback, placeholder formatting, safe text/markup and preserved custom outfit names.');
})().catch(e=>{console.error(e);process.exitCode=1;});
