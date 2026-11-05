// Display-only native JSON. English remains usable before the bridge is ready.
(function(){
 'use strict';
 var culture='en-US',data={messages:{},labels:{}},listeners=[],serial=0;
 var aliases={en:'en-US',ko:'ko-KR',ja:'ja-JP',de:'de-DE',fr:'fr-FR',it:'it-IT',es:'es-ES',ru:'ru-RU',pl:'pl-PL',pt:'pt-PT',tr:'tr-TR',nl:'nl-NL',zh:'zh-CN'};
 var canonical={};Object.keys(aliases).forEach(function(k){canonical[aliases[k].toLowerCase()]=aliases[k];});canonical['pt-br']='pt-BR';canonical['zh-tw']='zh-TW';canonical['zh-hans']='zh-CN';canonical['zh-hant']='zh-TW';
 function normalize(v){v=String(v||'').replace(/_/g,'-').toLowerCase();return canonical[v]||aliases[v]||'en-US';}
 function decode(r){if(r&&r.success===false)throw Error('Localization bridge unavailable');var v=r&&r.data!==undefined?r.data:r;return typeof v==='string'?JSON.parse(v):v;}
 function text(english,values){var rows=data.messages||{},value=(rows[culture]||{})[english]||(rows['en-US']||{})[english]||english;return value.replace(/{([\w]+)}/g,function(_,k){return values&&values[k]!==undefined?String(values[k]):'{'+k+'}';});}
 function html(english,values){return text(english,values).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}
 function apply(){
  if(typeof document.querySelectorAll==='function'){
   Array.prototype.forEach.call(document.querySelectorAll('[data-i18n]'),function(e){e.textContent=text(e.getAttribute('data-i18n'));});
   Array.prototype.forEach.call(document.querySelectorAll('[data-i18n-aria]'),function(e){e.setAttribute('aria-label',text(e.getAttribute('data-i18n-aria')));});
  }
 }
 function outfitLabel(kind,key,label,asset){
  var names={Full:'Full outfit',InnerTop:'Undershirt',InnerUnder:'Underwear'};
  var prefix=key+': ',custom=label.indexOf(prefix)===0?label.slice(prefix.length):null;
  var known=['Top','Bottom','Full','Jacket','Shoes','Socks','InnerTop','InnerUnder','Stockings','Gloves','Scarf','Hat','Bag','Glasses','Necklace','Earrings'];
  var title=known.indexOf(key)>=0?text(names[key]||key):text(kind==='garment'?'Clothing':'Accessory');
  if(custom && custom!==asset)return title+': '+custom;
  return title;
 }
 function refresh(){
  var request=++serial;
  return Promise.resolve().then(function(){return Promise.all([inzoi.cli.execute('gameplay.get_settings').then(decode),inzoi.cli.execute('uimod.cfg_load',{mod_id:'SceneZOI_93C44199',section:'scenezoi_runtime',key:'localization_state'}).then(decode)]);}).then(function(results){
   if(request!==serial)return;
   var raw=results[1]&&results[1].value!==undefined?results[1].value:results[1];
   if(typeof raw!=='string'||raw.length>4194304||!/^(?:[0-9a-f]{2})+$/i.test(raw))throw Error('Invalid localization snapshot');
   var next=JSON.parse(decodeURIComponent(raw.replace(/../g,function(b){return '%'+b;})));
   if(!next||!next.messages||!next.labels)throw Error('Invalid localization data');
   data=next;culture=normalize(results[0].language||results[0].Language||next.culture);
   if(document.documentElement)document.documentElement.lang=culture;
   apply();listeners.forEach(function(f){f();});
  }).catch(function(){});
 }
 window.SceneZOILocalization={text:text,html:html,outfitLabel:outfitLabel,refresh:refresh,normalize:normalize,onChange:function(f){listeners.push(f);},culture:function(){return culture;}};
})();
