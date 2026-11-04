local Lease=require('SceneZOI.FurnitureLease')
local M={};Lease.hooks=true
---@param owner FB2SlotComponent
---@param kind EB1SlotType
---@param param FB2TargetSlotParam
---@param only boolean
---@return boolean
function M.Override_CanOccupySlot(owner,kind,param,only)
 if Lease.blocked(owner)then return false end
 return owner:CanOccupySlot(kind,param,only)
end
---@param owner FB2SlotComponent
---@param kind EB1SlotType
---@param entity FB1EntityId
---@return boolean
function M.Override_CanOccupySlotCheckOnlyEntity(owner,kind,entity)
 if Lease.blocked(owner)then return false end
 return owner:CanOccupySlotCheckOnlyEntity(kind,entity)
end
return M
