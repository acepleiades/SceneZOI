local Runtime = require("SceneZOI.Runtime")
local Entry = require("SceneZOIStarter.Entry")
local M = {}
local discovery_elapsed = 0

function M.on_begin()
    require("SceneZOI.DataFiles").refresh()
    require("SceneZOI.ExpressionLibrary").refresh()
    require("SceneZOI.FacialPoseLibrary").refresh()
    require("SceneZOI.VoiceLibrary").refresh()
    require("SceneZOI.Catalog").refresh()
    Runtime.boot()
    Entry.boot()
end

---@param dt number
function M.on_tick(dt, module_dt)
    discovery_elapsed = discovery_elapsed + (module_dt or dt)
    if discovery_elapsed >= 2 then
        discovery_elapsed = 0
        if not Runtime.is_active() then
            local files = require("SceneZOI.DataFiles")
            local previous = files.get()
            if files.refresh() ~= previous then
                require("SceneZOI.ExpressionLibrary").refresh()
                require("SceneZOI.FacialPoseLibrary").refresh()
                require("SceneZOI.VoiceLibrary").refresh()
                require("SceneZOI.Catalog").refresh()
            end
        end
    end
    require("SceneZOIStarter.Menu").tick(Runtime.actors, Entry.is_ready(),module_dt or dt)
    Runtime.tick(module_dt or dt)
    require("SceneZOI.AddonAPI").tick(module_dt or dt)
    Entry.tick(module_dt or dt, Runtime.actors, Runtime.is_active())
end

function M.on_end()
    Entry.stop()
    Runtime.stop("mod_unloaded")
    Runtime.flush_notifications()
end

return M
