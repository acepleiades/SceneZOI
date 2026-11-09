package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local P=require('SceneZOI.Protocol');local J=require('SceneZOI.Json')
local cfg,enabled,interval={},true,'15'
local writes,sets={},{}
local fail_read,fail_write,fail_set,partial=false,false,false,false
inzoi={cli={execute=function(command)
 if command=='gameplay.get_settings'then
  if fail_read then fail_read=false;return false,'read failed'end
  return true,'',J.encode({auto_save_enabled=enabled and '1'or '0',auto_save_interval=interval})
 elseif command:find('gameplay.set_autosave',1,true)==1 then
  assert(not command:find('interval',1,true),'Only lease the enabled flag')
  sets[#sets+1]=command
  if partial then partial=false;enabled=false;error('partial setting failure')end
  if fail_set then fail_set=false;return false,'setting failed'end
  enabled=command:match('enable=(%w+)')=='true';return true
 elseif command:find('uimod.cfg_save',1,true)==1 then
  if fail_write then fail_write=false;return false,'cfg failed'end
  cfg.lease=command:match(' value=(.*)');writes[#writes+1]=cfg.lease;return true
 elseif command:find('uimod.cfg_load',1,true)==1 then return true,'',cfg.lease end
 error(command)
end}}
local A=require('SceneZOI.Autosave');A.boot();assert(not A.busy())
A.acquire('scene.1');assert(not enabled and A.busy()and interval=='15');assert(P.unpack(writes[1])[3]=='held')
assert(not pcall(A.acquire,'other'),'Never recapture our disabled setting')
A.tick(true);assert(not enabled);assert(A.restore()and enabled and not A.busy());assert(P.unpack(cfg.lease)[3]=='released')
local count=#sets;enabled=false;A.acquire('off');A.restore();assert(not enabled and #sets==count,'Originally disabled autosave must remain untouched')
enabled=true;fail_read=true;assert(not pcall(A.acquire,'read')and enabled and not A.busy())
fail_write=true;assert(not pcall(A.acquire,'write')and enabled and not A.busy(),'Persist ownership before native mutation')
partial=true;assert(not pcall(A.acquire,'partial')and not enabled and A.busy());A.tick(false);assert(enabled and not A.busy())
A.acquire('retry');fail_set=true;assert(not A.restore()and A.busy()and not enabled);A.tick(false);assert(enabled and not A.busy())
A.acquire('clear');fail_write=true;assert(not A.restore()and A.busy()and enabled);A.tick(false);assert(not A.busy())
-- Simulate a fresh environment after a crash: only local durable ownership survives.
A.acquire('crash');package.loaded['SceneZOI.Autosave']=nil;A=require('SceneZOI.Autosave');A.boot();assert(enabled and not A.busy())
enabled=false;package.loaded['SceneZOI.Autosave']=nil;A=require('SceneZOI.Autosave');A.boot();assert(not enabled,'A released lease must not override a later user preference')
-- One suspension moves between eligible scenes without touching the game setting again.
package.loaded['SceneZOI.Autosave']=nil;A=require('SceneZOI.Autosave');enabled=true;A.boot()
A.transfer('scene.a');assert(not enabled and A.owner()=='scene.a'and not A.restoring())
local before=#sets;A.transfer('scene.b');assert(not enabled and A.owner()=='scene.b'and #sets==before,'A transfer must not rewrite the setting')
assert(P.unpack(cfg.lease)[2]=='scene.b'and P.unpack(cfg.lease)[3]=='held')
A.transfer('scene.b');assert(#sets==before)
fail_set=true;assert(not A.restore()and A.restoring());A.tick(false);assert(enabled and not A.busy()and not A.restoring())
A.transfer('scene.c');fail_set=true;assert(not A.restore()and A.restoring());A.transfer('scene.d');assert(A.owner()=='scene.d'and not A.restoring()and not enabled,'A new owner adopts a failed restoration')
assert(A.restore()and enabled)
print('Autosave lease passed: enabled/disabled originals, unchanged interval, no recapture, read/persist/partial-write failures, idle retries and crash/boot recovery.')
