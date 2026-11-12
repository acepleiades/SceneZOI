local Runtime = require("Zoi.SceneZOI")
local Starter = require("Zoi.SceneZOIStarter")
local M = {}

---@param self table
---@param owner FB2Character
function M.on_begin(self, owner)
    if self.runtime then return end
    self.runtime, self.starter = {}, {}
    Runtime.on_begin(self.runtime, owner)
end

---@param self table
---@param owner FB2Character
---@param dt number
function M.on_tick(self, owner, dt)
    if not self.runtime then return end
    if self.runtime.lease then Runtime.on_tick(self.runtime, owner, dt) end
    if self.starter.saved_beds then Starter.on_tick(self.starter, owner, dt) end
end

---@param self table
---@param owner FB2Character
---@param kind string
---@param content string
function M.on_lua_message(self, owner, kind, content)
    if kind:sub(1, 9) ~= "SceneZOI." and kind ~= "SceneZOIStarter.Select" then return end
    if kind == "SceneZOI.Route" then
        require("SceneZOI.SimulationRoute").receive(owner, content)
        return
    end
    M.on_begin(self, owner)
    Runtime.on_lua_message(self.runtime, owner, kind, content)
    Starter.on_lua_message(self.starter, owner, kind, content)
end

---@param self table
---@param owner FB2Character
function M.on_savegame(self, owner)
    if not self.runtime then return {} end
    Runtime.on_savegame(self.runtime, owner)
    Starter.on_savegame(self.starter, owner)
    return {}
end

---@param self table
---@param owner FB2Character
function M.on_loadgame(self, owner)
    if not self.runtime then return end
    Runtime.on_loadgame(self.runtime, owner)
    Starter.on_loadgame(self.starter, owner)
end

---@param self table
---@param owner FB2Character
function M.on_end(self, owner)
    if not self.runtime then return end
    Runtime.on_end(self.runtime, owner)
    Starter.on_end(self.starter, owner)
    self.runtime, self.starter = nil, nil
end

return M
