local Runtime = require("SceneZOI.Runtime")
local Entry = require("SceneZOIStarter.Entry")
local SimulationRoute = require("SceneZOI.SimulationRoute")
local Diagnostics = require("SceneZOI.Diagnostics")
local M = {}

function M.on_begin()
    -- The native call serializes the entire Text table. Polling it during normal
    -- gameplay caused periodic hitches, even when the resulting catalog was unchanged.
    require("SceneZOI.DataFiles").refresh()
    require("SceneZOI.ExpressionLibrary").refresh()
    require("SceneZOI.FacialPoseLibrary").refresh()
    require("SceneZOI.VoiceLibrary").refresh()
    require("SceneZOI.Catalog").refresh(true)
    SimulationRoute.boot()
    Runtime.boot()
    Entry.boot()
end

---@param dt number
function M.on_tick(dt, module_dt)
    Diagnostics.tick(module_dt or dt)
    require("SceneZOIStarter.Menu").tick(Runtime.actors, Entry.is_ready(),module_dt or dt)
    SimulationRoute.tick(module_dt or dt, Runtime.actors)
    Runtime.tick(module_dt or dt)
    require("SceneZOI.AddonAPI").tick(module_dt or dt)
    Entry.tick(module_dt or dt, Runtime.actors, Runtime.is_active())
end

function M.on_end()
    require("SceneZOIStarter.Menu").stop()
    Entry.stop()
    Runtime.stop("mod_unloaded")
    Runtime.flush_notifications()
    Diagnostics.shutdown()
end

return M
