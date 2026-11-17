package.path = "modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;" .. package.path
local J = require("SceneZOI.Json")
local V = require("SceneZOI.DataValidation")
local P = require("SceneZOI.Protocol")
local Sessions = require("SceneZOI.Sessions")
local actors = {}
for id, body in ipairs({"male", "female"}) do
    actors[tostring(id)] = {id=tostring(id),body=body,GetEntityId=function() return {Value=id} end}
end
local node = {id="example.scene",participants={first={body="male"},second={body="female"}}}
local data = {nodes={[node.id]=node},metadata={},tasks={definitions={}}}
local rows, cfg, responses, traces = {}, {}, {}, {}
local API
package.loaded["SceneZOI.Catalog"] = {get_snapshot=function() return data end}
package.loaded["SceneZOI.Traits"] = {capture=function(actor) return {id=actor.id,body=actor.body} end}
package.loaded["SceneZOI.SceneSearch"] = {
    criteria=function(_,value) return value or {} end,
    find=function() return {{scene_id=node.id,bindings={first="1",second="2"}}} end,
    allowed=function() return true end,
    random=function(found) return found[1] end,
}
package.loaded["SceneZOI.Plan"] = {
    fields={"end_policy"},
    parse=function(args) return {end_policy=args.end_policy,stage_count=1} end,
    pick_entry=function(_,_,found) return found[1] end,
}
package.loaded["SceneZOI.AddonServices"] = {execute=function() return false end}
package.loaded["SceneZOI.SaveBridge"] = {restore_waiting=function() return false end,overlaps=function() return false end}
package.loaded["SceneZOI.Autosave"] = {restoring=function() return false end}
package.loaded["SceneZOI.Diagnostics"] = {
    boot=function() end,note_addon=function() end,record=function() end,
    record_api_trace=function(row) traces[#traces+1]=row end,
}
package.loaded["SceneZOI.Runtime"] = {
    actors=actors,snapshot=function() return nil end,check_start_distance=function() end,
    start_background=function(row)
        rows[#rows+1]=row
        API.created(row,{token="done"})
        Sessions.release("done")
    end,
}
package.loaded["SceneZOI.SimulationRoute"] = {
    send=function(actor,kind,content) API.departure_reply(actor,content.."|ok|npc") end,
    discard=function() end,
}
UE = {UGameplayStatics={GetPlayerController=function()
    return {GetCharacterEntityId=function() return {Value=1} end}
end}}
inzoi = {cli={execute=function(command)
    local key=command:match(" key=([%w_]+)")
    if command:find("cfg_save",1,true) then cfg[key]=command:match(" value=(.*)");return true end
    return true,"",cfg[key]
end},message={send_to_sim=function(_,kind,content)
    if kind=="SceneZOI.API.Response" then responses[#responses+1]=J.decode(content) end
end}}
API = require("SceneZOI.AddonAPI")
local serial=0
local function request(operation,args)
    serial=serial+1
    API.receive(actors["1"],J.encode({api_version=1,addon_id="example.addon",client_id="client",
        request_id="request."..serial,operation=operation,arguments=args or {}}))
    return responses[#responses]
end
local function reset() Sessions.reset();API.boot() end
local function args(selection)
    return {initiator="1",participants={"1","2"},scene_id=node.id,appearance=selection}
end
local selected={['2']={body_variant=false,attachment_variants={body_region=false,tongue="external.prop"}}}
reset()
assert(request("get_version").result.features.appearance_variants==1)
local reply=request("validate_start",args(selected))
assert(reply.ok and reply.result.valid and Sessions.holder("1")==nil)

-- Validation is shared by preflight and every start path, before reservations.
for _,invalid in ipairs({false,J.null,J.array({}),{['3']={}},{female={}},{['2']={body_variant=true}},
    {['2']={body_variant="bad id"}},{['2']={attachment_variants={body_region=true}}},
    {['2']={unexpected=true}}}) do
    reply=request("validate_start",args(invalid))
    assert(reply.ok and reply.result.valid==false)
    reply=request("start_scene",args(invalid))
    assert(not reply.ok and Sessions.holder("1")==nil and not API.has_pending())
end
local many={['2']={attachment_variants={}}}
for index=1,17 do many['2'].attachment_variants['slot'..index]=false end
assert(not request("start_scene",args(many)).ok)

-- Missing variant definitions remain an optional runtime fallback, not an API shape error.
for _,operation in ipairs({"start_scene","start_at_hub","start_random_scene","start_autonomous_scene"}) do
    reset()
    local inputs=args(selected);inputs.background=true
    if operation=="start_autonomous_scene" then inputs.end_policy={type="duration",seconds=30,clock="real"} end
    reply=request(operation,inputs)
    assert(reply.ok and reply.result.accepted)
    local trace=traces[#traces]
    assert(trace.arguments.appearance['2'].body_variant==false)
    assert(trace.arguments.appearance['2'].attachment_variants.body_region==false)
    assert(trace.arguments.appearance['2'].attachment_variants.tongue=="external.prop")
    API.tick(.5);API.tick(.1)
    local row=rows[#rows]
    assert(V.equal(row.appearance,selected))
    assert(row.appearance~=row.req.arguments.appearance and
        row.appearance['2'].attachment_variants~=row.req.arguments.appearance['2'].attachment_variants)
end

-- A controlled start carries the same copied choices through the UI handshake.
reset()
reply=request("start_scene",args(selected))
assert(reply.ok and API.has_pending())
API.tick(.5);API.tick(.1)
local bridge=J.decode(assert(P.decode(cfg.api_start)))
local row=API.context(bridge.token,{"ui","1","start","1",node.id,"first:1+second:2","none",bridge.token})
assert(V.equal(row.appearance,selected))
API.fail_start(bridge.token,"test cleanup")
assert(Sessions.holder("1")==nil)

reset()
reply=request("start_scene",args(nil))
assert(reply.ok,"Existing callers may omit appearance")
print("Appearance start API passed: all start modes, preflight, roster membership, copied choices, UI handoff, optional fallback and traces.")
