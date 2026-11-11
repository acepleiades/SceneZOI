-- Component bindings preserve the Zoi wildcard namespace for independent mods.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local Json=require('SceneZOI.Json')
local base='modkit/SceneZOI_93C44199/workspace/lua/'
local file=assert(io.open(base..'lua_manifest.json','rb'))
local manifest=Json.decode(file:read('*a'));file:close()

local expected={B1='B1AppearanceComponent', B2='Appearance'}
for env,key in pairs(expected) do
    local bindings=manifest.bindings[env]
    assert(#bindings==1 and bindings[1].type=='Component' and bindings[1].key==key)
    assert(bindings[1].script=='Components.SceneZOICharacter')
end
assert(manifest.chunkScripts.B2[1]=='Systems.B2ZoiGroupManager')
assert(manifest.chunkScripts.B2[2]=='Components.B2SlotComponent')
assert(manifest.chunkScripts.B2[3]=='Scripts.B2Script_SpeechBubble')

local id={Value=12}
local actor={}
local current_actor
local lookups=0
local unassigned={}
local ready=false
local component={GetOwner=function() return ready and actor or unassigned end,GetOwnerEntityId=function() return id end}
local old_inzoi=inzoi
inzoi={FB1EntityId=function() return {} end,getB2Manager=function(name)
    assert(name=='FB2EntityManager')
    return {FindCharacter=function(_,value)
        assert(value.Value==id.Value)
        lookups=lookups+1
        return ready and current_actor or nil
    end}
end}
local handlers={'on_begin','on_tick','on_lua_message','on_savegame','on_loadgame','on_end'}
for _,env in ipairs({'B1','B2'}) do
    local runtime,starter={},{}
    local received={}
    for _,name in ipairs(handlers) do
        runtime[name]=function(self,owner)
            if env=='B1' and name=='on_begin' then
                if owner==unassigned then return end
                self.registered_id='12'
            end
            assert(owner==(env=='B1' and actor or current_actor), 'Stale character handle')
            received[#received+1]='runtime.'..name
            self.used=true
        end
        starter[name]=function(self,owner)
            assert(owner==(env=='B1' and actor or current_actor), 'Stale character handle')
            if env=='B2' then assert(not self.used, 'Runtime and starter must have separate state') end
            received[#received+1]='starter.'..name
        end
    end
    local module_env=setmetatable({require=function(name)
        if name=='Zoi.SceneZOI' then return runtime end
        assert(name=='Zoi.SceneZOIStarter')
        return starter
    end},{__index=_G})
    local receiver=assert(loadfile(base..env..'/Components/SceneZOICharacter.lua','t',module_env))()
    local state={}
    ready=false
    receiver.on_begin(state,component)
    assert(#received==0 and state.character==nil)
    ready=true
    current_actor={}
    receiver.on_tick(state,component,.1)
    current_actor={}
    receiver.on_lua_message(state,component,'SceneZOI.Test','payload')
    if env=='B2' then
        local count=lookups
        receiver.on_tick(state,component,.1)
        assert(lookups==count, 'Idle tick should not resolve a character')
        current_actor={}
        assert(type(receiver.on_savegame(state,component))=='table')
        current_actor={}
        receiver.on_loadgame(state,component)
        current_actor={}
    else
        ready=false
    end
    receiver.on_end(state,component)
    assert(state.character==nil and state.entity_id==nil)
    local sequence=table.concat(received,',')
    if env=='B1' then
        assert(sequence=='runtime.on_begin,runtime.on_tick,runtime.on_lua_message,starter.on_lua_message,runtime.on_end',sequence)
    else
        assert(sequence=='runtime.on_begin,runtime.on_tick,starter.on_tick,runtime.on_lua_message,starter.on_lua_message,runtime.on_savegame,starter.on_savegame,runtime.on_loadgame,starter.on_loadgame,runtime.on_end,starter.on_end',sequence)
    end
end
inzoi=old_inzoi
print('Component bindings passed: no Zoi declarations, deferred owner resolution, message routing and lifecycle forwarding.')
