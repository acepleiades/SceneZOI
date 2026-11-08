local Runtime = require("Zoi.SceneZOI")
local Starter = require("Zoi.SceneZOIStarter")
local M = {}

local function character(self, component)
    if not self.character then
        local ok, actor = pcall(function() return component:GetOwner() end)
        if ok and actor then
            Runtime.on_begin(self, actor)
            -- Early component callbacks can expose an owner with an invalid ID.
            -- Resolve it again until the current actor is registered.
            if self.registered_id then self.character = actor end
        end
    end
    return self.character
end

---@param self table
---@param owner UB1AppearanceComponent
function M.on_begin(self, owner)
    character(self, owner)
end

---@param self table
---@param owner UB1AppearanceComponent
function M.on_tick(self, owner, dt)
    local actor = character(self, owner)
    if actor then Runtime.on_tick(self, actor, dt) end
end

---@param self table
---@param owner UB1AppearanceComponent
function M.on_lua_message(self, owner, kind, content)
    local actor = character(self, owner)
    if not actor then return end
    Runtime.on_lua_message(self, actor, kind, content)
    Starter.on_lua_message(self, actor, kind, content)
end

---@param self table
---@param owner UB1AppearanceComponent
function M.on_end(self, owner)
    if self.character then Runtime.on_end(self, self.character) end
    self.character = nil
end

return M
