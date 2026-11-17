package.path = "modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;" .. package.path
local function noop() end
local scans, rebuilds, ticks = 0, 0, 0
package.loaded["SceneZOI.DataFiles"] = {refresh = function() scans = scans + 1 end}
package.loaded["SceneZOI.Catalog"] = {refresh = function(force)
    assert(force, "Each startup must recheck availability of mounted assets")
    rebuilds = rebuilds + 1
end}
for _, name in ipairs({"ExpressionLibrary", "FacialPoseLibrary", "VoiceLibrary"}) do
    package.loaded["SceneZOI." .. name] = {refresh = noop}
end
package.loaded["SceneZOI.Runtime"] = {boot = noop, stop = noop, flush_notifications = noop,
    tick = function() ticks = ticks + 1 end, actors = {}, is_active = function() return false end}
package.loaded["SceneZOI.SimulationRoute"] = {boot = noop, tick = noop}
package.loaded["SceneZOI.Diagnostics"] = {tick = noop, shutdown = noop}
package.loaded["SceneZOI.AddonAPI"] = {tick = noop}
package.loaded["SceneZOIStarter.Entry"] = {boot = noop, tick = noop, stop = noop, is_ready = function() return true end}
package.loaded["SceneZOIStarter.Menu"] = {tick = noop, stop = noop}

local Main = require("Main")
Main.on_begin()
for _ = 1, 300 do Main.on_tick(0.2, 0.2) end
assert(scans == 1 and rebuilds == 1 and ticks == 300, "Idle gameplay must not rescan the declaration table")
Main.on_end()
Main.on_begin()
assert(scans == 2 and rebuilds == 2, "A new Lua lifecycle must discover mounted content again")
print("Content discovery passed: startup and reload rebuild the catalog, and normal gameplay never polls it.")
