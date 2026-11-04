-- Demo entry policy only. Native departure ends group activities; it is not a lease.
local M={}
local function group(character)return character:GetZoiGroupId() end
local function free(character)return group(character).Value==inzoi.FB1ZoiGroupId().Value end
function M.leave(character)
    if free(character) then return end
    local manager=assert(inzoi.getB2Manager("FB2ZoiGroupManager"))
    local original=group(character)
    local ok,err=pcall(function()
        manager:RemoveZoiGroupMember(original,character,inzoi.EB1ZoiGroupLeaveReason.UserSelf,false)
    end)
    if free(character) then
        print("[SceneZOI] Demo group departure: "..tostring(character:GetEntityId().Value).." left group "..tostring(original.Value))
        return
    end
    -- Do not disband a different group if another handler moved this Zoi.
    assert(group(character).Value==original.Value,"The Zoi changed groups during departure; Scene Mode was cancelled")
    local broken,why=pcall(function()manager:BreakZoiGroup(original,true)end)
    assert(free(character),"Could not leave or disband the gameplay group: "..tostring(why or err or "membership unchanged"))
    print("[SceneZOI] Demo group departure: disbanded group "..tostring(original.Value).." after member departure failed ("..tostring(ok and "membership unchanged" or err)..", "..tostring(broken)..")")
end
return M
