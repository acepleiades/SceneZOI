package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local Json=require('SceneZOI.Json')
local Protocol=require('SceneZOI.Protocol')
local restored=0
package.loaded['SceneZOI.Native']={release_input=function()restored=restored+1 end}
package.loaded['SceneZOI.Localization']={tick=function()end}
package.loaded['SceneZOI.SaveBridge']={tick=function()end}
package.loaded['SceneZOI.Autosave']={tick=function()end}
package.loaded['SceneZOI.AddonEffects']={idle=function()end}
package.loaded['SceneZOI.AddonControl']={tick=function()end}
package.loaded['SceneZOI.SceneVisuals']={tick=function()return {}end}
local cfg={}
local blocked=false
local reasons={'CharacterCustomization'}
inzoi={cli={execute=function(command)
    if command=='ui.get_blocking'then return true,'',Json.encode({blocked=blocked,pause_reasons=reasons})end
    local key=command:match(' key=([^ ]+)')
    if command:find('uimod.cfg_save',1,true)then cfg[key]=command:match(' value=(.*)');return true,''end
    if command:find('uimod.cfg_load',1,true)then return cfg[key]~=nil,'',cfg[key]end
    error('Unexpected native command: '..command)
end}}
local Runtime=require('SceneZOI.Runtime')
local actor={GetEntityId=function()return {Value=1}end}
Runtime.register(actor)
Runtime.authorize_rejected_focus(actor,'test.entry')
cfg.focus=Protocol.pack('test.client',1,'rejected','1','test.entry')
for _=1,20 do Runtime.tick(.2)end
assert(not cfg.last_error,cfg.last_error)
assert(restored==0,'A completed panel must not steal focus while Create a Zoi owns input')
assert(cfg.input_restore==Protocol.pack('test.client',1,'deferred','character_editor'))
reasons={};blocked=true
for _=1,5 do Runtime.tick(.2)end
assert(restored==0,'Do not steal focus from a native modal menu either')
assert(cfg.input_restore==Protocol.pack('test.client',1,'deferred','modal_ui'))
blocked=false
Runtime.tick(.2)
assert(restored==1,'Returning to gameplay must complete deferred input restoration')
assert(cfg.input_restore==Protocol.pack('test.client',1,'restored','gameplay'))
for _=1,5 do Runtime.tick(.2)end
assert(restored==1,'A deferred restore must run exactly once')
-- The next picker/session must have independent ownership, with no old focus retry.
Runtime.authorize_rejected_focus(actor,'test.next')
cfg.focus=Protocol.pack('test.client',2,'rejected','1','test.next')
Runtime.tick(.2)
assert(restored==2,'The next interaction must restore input normally')
assert(not cfg.last_error,cfg.last_error)
print('Runtime input lifecycle passed: real focus acknowledgement waits through CAZ/modal UI, resumes once, then handles the next interaction.')
