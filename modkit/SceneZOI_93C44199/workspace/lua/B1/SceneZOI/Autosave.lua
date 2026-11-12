-- Persist global setting ownership before disabling, so a later framework boot
-- can undo our change even after a crash without a game save.
local C=require('SceneZOI.Config')
local P=require('SceneZOI.Protocol')
local J=require('SceneZOI.Json')
local M={}
local lease,last_error,releasing
local function cfg(action,value)
 local command='uimod.cfg_'..action..' mod_id='..C.mod_id..' section='..C.section..' key=autosave_lease'
 if value then command=command..' value='..value end
 return inzoi.cli.execute(command)
end
local function write(state,token)
 local ok,message=cfg('save',P.pack('autosave',token,state));assert(ok,message or 'Autosave lease write failed')
end
local function native_settings()
 local ok,settings=pcall(function()
  local settings=UE.UGameUserSettings.GetGameUserSettings()
  if settings and type(settings.EnableAutoSave)=='boolean' and type(settings.SaveSettings)=='function' then return settings end
 end)
 if ok then return settings end
end
local function set_enabled(enabled,settings)
 if settings then
  -- Save the owned flag without reapplying rendering or other game settings.
  settings.EnableAutoSave=enabled
  assert(settings.EnableAutoSave==enabled,'Could not change autosave')
  settings:SaveSettings()
 else
  local ok,message=inzoi.cli.execute('gameplay.set_autosave enable='..tostring(enabled))
  assert(ok,message or 'Could not change autosave')
 end
end
function M.acquire(token)
 assert(not lease,'Previous autosave restoration is pending')
 local settings=native_settings()
 local enabled
 if settings then
  enabled=settings.EnableAutoSave
 else
  local ok,message,data=inzoi.cli.execute('gameplay.get_settings')
  assert(ok,message or 'Could not read autosave setting')
  local flag=J.decode(data or message).auto_save_enabled
  assert(flag=='1'or flag=='0','Unknown autosave setting')
  enabled=flag=='1'
 end
 if not enabled then return end
 write('held',token)
 lease=token
 set_enabled(false,settings)
end
-- Hands the suspension to another eligible scene without touching the game setting.
function M.transfer(token)
 if lease==token then return end
 if not lease then M.acquire(token);return end
 write('held',token)
 lease,releasing=token,false
end
function M.restore()
 if not lease then return true end
 releasing=true
 local ok,err=pcall(function()
  set_enabled(true,native_settings())
  write('released',lease)
 end)
 if ok then lease,last_error,releasing=nil,nil,false
 elseif tostring(err)~=last_error then
  last_error=tostring(err);print('[SceneZOI] Autosave restoration will retry: '..last_error)
 end
 return ok
end
function M.boot()
 local ok,message,data=cfg('load')
 local fields=ok and P.unpack(data or message)
 lease=fields and fields[1]=='autosave'and fields[3]=='held'and fields[2]or nil
 last_error,releasing=nil,false
 M.restore()
end
function M.busy()return lease~=nil end
function M.owner()return lease end
-- A failed restoration is still retrying; separate from a scene holding the suspension.
function M.restoring()return lease~=nil and releasing==true end
function M.tick(active)if not active then M.restore()end end
return M
