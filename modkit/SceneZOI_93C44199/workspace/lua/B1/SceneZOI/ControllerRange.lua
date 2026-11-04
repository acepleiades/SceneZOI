-- Session lifetime policy uses actual possession, never the captured entry role.
local Config=require('SceneZOI.Config')
local M={}

function M.focus_actor(actors,preferred)
    for _,actor in pairs(actors)do if actor==preferred then return actor end end
    local _,actor=next(actors)
    return actor
end

local function distance(current,actors)
    local context=M.focus_actor(actors)
    if not context then return nil,nil,'no_context' end
    local controller=UE.UGameplayStatics.GetPlayerController(context,0)
    if not controller then return nil,nil,'no_controller' end
    local id=tostring(controller:GetCharacterEntityId().Value)
    for _,participant in ipairs(current.participants)do if participant.id==id then return 0,id,'participant' end end
    local actor=actors[id]
    if not actor then return nil,id,'controlled_actor_not_registered' end
    local owner=current.bindings and current.bindings[current.node.anchor_participant]
    if not owner then
        for _,participant in ipairs(current.participants)do
            if participant.role==current.node.anchor_participant then owner=participant;break end
        end
    end
    owner=owner or current.participants[1]
    local origin=current.anchor and current.anchor.Translation or owner.actor:K2_GetActorLocation()
    local point=actor:K2_GetActorLocation()
    local x,y,z=point.X-origin.X,point.Y-origin.Y,point.Z-origin.Z
    local squared=x*x+y*y+z*z
    if squared~=squared or squared==math.huge then return end
    return math.sqrt(squared),id,'spectator'
end

function M.update(current,actors,dt)
    current.controller_range_poll=(current.controller_range_poll or 0)+dt
    if current.controller_range_poll<Config.poll_interval then return false end
    local delta=current.controller_range_poll;current.controller_range_poll=0
    local ok,distance_cm,id,status=pcall(distance,current,actors)
    current.controller_range_status={controlled_id=ok and id or nil,kind=ok and status or 'lookup_error',
        distance_cm=ok and distance_cm or nil,error=not ok and tostring(distance_cm):sub(1,350) or nil,
        limit_cm=Config.controller_max_distance_cm}
    if not ok or not distance_cm or distance_cm<=Config.controller_max_distance_cm then
        current.controller_outside_age=0
        return false
    end
    current.controller_outside_age=(current.controller_outside_age or 0)+delta
    return current.controller_outside_age>=Config.controller_distance_grace,distance_cm,id
end
return M
