-- SceneZOI leaves the Zoi wildcard namespace available to independent mods.
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
        if name=='SceneZOI.Outfit' then return {recover=function(owner) assert(owner==current_actor) end} end
        assert(name=='Zoi.SceneZOIStarter')
        return starter
    end},{__index=_G})
    if env=='B2' then
        local appearance=assert(loadfile(base..env..'/Components/SceneZOICharacter.lua','t',module_env))()
        local receiver=assert(loadfile(base..env..'/Zoi/SimulationReceiver.lua','t',module_env))()
        ready=true
        local state={}
        current_actor={}
        appearance.on_begin({},component)
        assert(not appearance.on_lua_message, 'Appearance would duplicate native dynamic messages')
        receiver.on_begin(state,current_actor)
        receiver.on_begin(state,current_actor)
        current_actor={}
        receiver.on_lua_message(state,current_actor,'OtherMod.Message','payload')
        receiver.on_lua_message(state,current_actor,'SceneZOI.Test','payload')
        receiver.on_tick(state,current_actor,.1)
        state.runtime.lease=true
        state.starter.saved_beds={}
        receiver.on_tick(state,current_actor,.1)
        assert(type(receiver.on_savegame(state,current_actor))=='table')
        receiver.on_loadgame(state,current_actor)
        receiver.on_end(state,current_actor)
        assert(state.runtime==nil and state.starter==nil)
        assert(table.concat(received,',')=='runtime.on_begin,runtime.on_lua_message,starter.on_lua_message,runtime.on_tick,starter.on_tick,runtime.on_savegame,starter.on_savegame,runtime.on_loadgame,starter.on_loadgame,runtime.on_end,starter.on_end')
        goto continue
    end
    do
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
    ready=false
    receiver.on_end(state,component)
    assert(state.character==nil)
    local sequence=table.concat(received,',')
    assert(sequence=='runtime.on_begin,runtime.on_tick,runtime.on_lua_message,starter.on_lua_message,runtime.on_end',sequence)
    end
    ::continue::
end
inzoi=old_inzoi
local deliveries={}
local b2,installed={},{}
local function actor_for(value)
    return {
        GetEntityId=function() return {Value=value} end,
        HasLuaModule=function(_,name) return installed[value]==name end,
        AddLuaModule=function(_,name,path)
            assert(path=='Zoi.SimulationReceiver')
            installed[value]=name
        end,
    }
end
local sim={FindCharacter=function(_,native_id) return b2[native_id.Value] end}
local client,simulation,acknowledgement
local route_env=setmetatable({
    require=function(name)
        if name=='SceneZOI.Controller' then return {controlled_id=function() return '7' end} end
        return require(name)
    end,
    inzoi={
        message={
            send_to_sim=function(native_id,kind,content)
                if kind=='SceneZOI.Route' then
                    local relay=b2[native_id.Value]
                    if relay and installed[native_id.Value] then simulation.receive(relay,content) end
                else deliveries[#deliveries+1]=native_id.Value..':'..kind..':'..content end
            end,
            send_to_client=function(native_id,kind,content)
                assert(native_id.Value==7 and kind=='SceneZOI.RouteReady')
                acknowledgement=content
                client.ready(content)
            end,
        },
        FB2ControllerSystem={GetPossessEntityId=function() return {Value=7} end},
        getB2Manager=function() return sim end,
        FB1EntityId=function() return {} end,
    }
},{__index=_G})
client=assert(loadfile(base..'B1/SceneZOI/SimulationRoute.lua','t',route_env))()
simulation=assert(loadfile(base..'B2/SceneZOI/SimulationRoute.lua','t',route_env))()
client.boot()
local actors={['7']=actor_for(7)}
local zoi=actor_for(12)
client.send(zoi,'Prepare','one')
client.send(zoi,'Prepare','one')
client.send(zoi,'Release','one')
client.tick(.2,actors)
assert(#deliveries==0)
b2[7]=actor_for(7)
simulation.tick(.2)
client.tick(.2,actors)
assert(#deliveries==0,'Delivery must wait for a loaded simulation actor')
b2[12]=actor_for(12)
client.tick(.2,actors)
assert(table.concat(deliveries,',')=='12:Prepare:one,12:Release:one')
client.forget('12')
client.send(actor_for(12),'Prepare','replacement')
client.ready(acknowledgement)
assert(#deliveries==2,'A stale acknowledgement must not authorize a replacement actor')
client.tick(.2,actors)
assert(deliveries[3]=='12:Prepare:replacement')
local delayed=actor_for(23)
client.send(delayed,'Depart','cancelled')
client.send(delayed,'Open','cancelled')
client.send(delayed,'Release','unrelated')
client.discard('Depart','cancelled')
client.discard('Open','cancelled')
b2[23]=actor_for(23)
client.tick(.2,actors)
assert(deliveries[4]=='23:Release:unrelated' and #deliveries==4,
    'Cancelled commands must not reach a simulation actor after attachment')
print('SceneZOI bindings passed: scoped simulation attachment, acknowledgement and lifecycle forwarding.')
