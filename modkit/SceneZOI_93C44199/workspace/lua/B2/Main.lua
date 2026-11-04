local Selection=require("SceneZOIStarter.Selection")
local M={}
function M.on_begin()
    require("Systems.B2ZoiGroupManager")
    require('Components.B2SlotComponent')
    Selection.bind()
end
function M.on_tick() Selection.tick();require('SceneZOI.FurnitureLease').tick() end
function M.on_end() Selection.clear();require('SceneZOI.FurnitureLease').clear() end
return M
