(function(global){
 'use strict';
 global.SceneZOIAddonBridge={create:function(options){
  var last=null,busy=false;
  function decode(raw){return JSON.parse(decodeURIComponent(String(raw).replace(/../g,function(h){return '%'+h;})));}
  function encode(value){return Array.prototype.map.call(unescape(encodeURIComponent(JSON.stringify(value))),function(c){return ('0'+c.charCodeAt(0).toString(16)).slice(-2);}).join('');}
  return {poll:function(){
   if(busy)return;busy=true;
   options.read('api_start').then(function(raw){
    if(!raw||raw==='none'||raw===last)return;
    var request=decode(raw);if(!request.token||!request.entry)throw Error('Invalid add-on start');
    last=raw;
    return options.refresh().then(function(){return options.start(request.entry);}).then(function(started){
     return options.write('api_start_result',encode({token:request.token,started:started===true}));
    }).catch(function(error){return options.write('api_start_result',encode({token:request.token,started:false,message:String(error.message||error)}));});
   }).catch(function(){}).then(function(){busy=false;});
  }};
 }};
})(window);
