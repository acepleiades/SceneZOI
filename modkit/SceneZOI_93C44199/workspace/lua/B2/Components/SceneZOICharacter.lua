local Outfit = require("SceneZOI.Outfit")
local M = {}

---@param self table
---@param owner FB2AppearanceComponent
function M.on_begin(self, owner)
    local id = owner:GetOwnerEntityId()
    local value = tonumber(id.Value)
    if not value or value < 0 then return end
    local manager = inzoi.getB2Manager("FB2EntityManager")
    local actor = manager and manager:FindCharacter(id)
    if actor then Outfit.recover(actor) end
end

return M
