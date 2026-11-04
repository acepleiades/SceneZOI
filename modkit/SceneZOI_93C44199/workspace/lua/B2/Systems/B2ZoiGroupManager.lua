local Selection=require("SceneZOIStarter.Selection")
local M={}
Selection.bind()
---@param owner FB2ZoiGroupManager
---@param kind EB1ZoiGroupType
---@param leader FB1EntityId
---@param characters FB2Character[]
---@param toast boolean
---@return FB1ZoiGroupId
function M.Override_CreateZoiGroup(owner,kind,leader,characters,toast)
    if Selection.create(leader,characters) then return inzoi.FB1ZoiGroupId() end
    return owner:CreateZoiGroup(kind,leader,characters,toast)
end
return M
