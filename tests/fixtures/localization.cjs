// Load the real English-fallback formatter before isolated UI modules.
const vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const run=vm.runInNewContext;
vm.runInNewContext=function(source,context,...args){
 if(!context.window)context.window=context;
 if(!context.window.SceneZOILocalization)run(fs.readFileSync(path.resolve(__dirname,'../../modkit/SceneZOI_93C44199/ui/scenezoi/localization.js'),'utf8'),context);
 return run(source,context,...args);
};
