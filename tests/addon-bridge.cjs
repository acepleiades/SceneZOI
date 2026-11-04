const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict'),path=require('path');
const source=fs.readFileSync(path.resolve(__dirname,'../modkit/SceneZOI_93C44199/ui/scenezoi/addon-bridge.js'),'utf8');
const context={};context.window=context;vm.runInNewContext(source,context);
let raw='none',starts=0,fail=false;const written=[];
const encode=v=>Buffer.from(JSON.stringify(v)).toString('hex');
const bridge=context.SceneZOIAddonBridge.create({read:()=>Promise.resolve(raw),write:(key,value)=>{written.push(JSON.parse(Buffer.from(value,'hex')));return Promise.resolve();},refresh:()=>Promise.resolve(),start:entry=>{starts++;assert(entry.bindings);return fail?Promise.reject(Error('not ready')):Promise.resolve(true);}});
async function flush(){for(let i=0;i<20;i++)await Promise.resolve();}
(async()=>{
 bridge.poll();await flush();assert.equal(starts,0);
 raw=encode({token:'one',entry:{bindings:{a:'1',b:'2'}}});bridge.poll();bridge.poll();await flush();assert.equal(starts,1);assert.deepEqual(written.at(-1),{token:'one',started:true});
 bridge.poll();await flush();assert.equal(starts,1,'Repeated mailbox samples must not restart a session');
 raw=encode({token:'two',entry:{bindings:{a:'1',b:'2'}}});fail=true;bridge.poll();await flush();assert.equal(starts,2);assert.equal(written.at(-1).started,false);
 console.log('Add-on UI bridge passed: complete entry forwarding, one start per token, in-flight polling and explicit refusal.');
})().catch(e=>{console.error(e);process.exit(1);});
