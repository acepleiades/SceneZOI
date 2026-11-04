-- Persist global setting ownership before disabling, so a later framework boot
-- can undo our change even after a crash without a game save.
local C=require('SceneZOI.Config')
local P=require('SceneZOI.Protocol')
local J=require('SceneZOI.Json')
local M={}
local lease,last_error
local function cfg(action,value)
 local command='uimod.cfg_'..action..' mod_id='..C.mod_id..' section='..C.section..' key=autosave_lease'
 if value then command=command..' value='..value end
 return inzoi.cli.execute(command)
end
local function write(state,token)
 local ok,message=cfg('save',P.pack('autosave',token,state));assert(ok,message or 'Autosave lease write failed')
end
function M.acquire(token)
 assert(not lease,'Previous autosave restoration is pending')
 local ok,message,data=inzoi.cli.execute('gameplay.get_settings')
 assert(ok,message or 'Could not read autosave setting')
 local settings=J.decode(data or message)
 local enabled=settings.auto_save_enabled
 assert(enabled=='1'or enabled=='0','Unknown autosave setting')
 if enabled=='0'then return end
 write('held',token)
 lease=token
 local changed,err=inzoi.cli.execute('gameplay.set_autosave enable=false')
 assert(changed,err or 'Could not suspend autosave')
end
function M.restore()
 if not lease then return true end
 local ok,err=pcall(function()
  local changed,message=inzoi.cli.execute('gameplay.set_autosave enable=true')
  assert(changed,message or 'Could not restore autosave')
  write('released',lease)
 end)
 if ok then lease,last_error=nil,nil
 elseif tostring(err)~=last_error then
  last_error=tostring(err);print('[SceneZOI] Autosave restoration will retry: '..last_error)
 end
 return ok
end
function M.boot()
 local ok,message,data=cfg('load')
 local fields=ok and P.unpack(data or message)
 lease=fields and fields[1]=='autosave'and fields[3]=='held'and fields[2]or nil
 last_error=nil
 M.restore()
end
function M.busy()return lease~=nil end
function M.tick(active)if not active then M.restore()end end
return M
