local Selection=require("SceneZOIStarter.Selection")
local SimulationRoute=require("SceneZOI.SimulationRoute")
local M={}
function M.on_begin()
    require("Systems.B2ZoiGroupManager")
    require('Components.B2SlotComponent')
    Selection.bind()
end
function M.on_tick(first, second)
    -- Global native hooks can supply delta directly or after their Lua state.
    local dt=type(second)=='number'and second or type(first)=='number'and first or 0
    SimulationRoute.tick(dt)
    Selection.tick()
    require('SceneZOI.NativeGetUp').tick(dt)
    require('SceneZOI.FurnitureLease').tick()
end
function M.on_end() Selection.clear();require('SceneZOI.FurnitureLease').clear() end
return M
