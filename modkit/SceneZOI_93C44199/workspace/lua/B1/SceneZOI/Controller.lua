-- The Zoi the player controls right now, always read from the game.
local M={}

function M.focus_actor(actors,preferred)
    for _,actor in pairs(actors)do if actor==preferred then return actor end end
    local _,actor=next(actors)
    return actor
end

function M.controlled_id(actors)
    local context=M.focus_actor(actors)
    if not context then return nil end
    local controller=UE.UGameplayStatics.GetPlayerController(context,0)
    if not controller then return nil end
    return tostring(controller:GetCharacterEntityId().Value)
end

return M
