local Runtime = require("Zoi.SceneZOI")
local Starter = require("Zoi.SceneZOIStarter")
local M = {}

local function find_character(id)
    local manager = inzoi.getB2Manager("FB2EntityManager")
    return manager and manager:FindCharacter(id)
end

local function character(self, component)
    local id = component:GetOwnerEntityId()
    local value = tonumber(id.Value)
    if not value or value < 0 or (self.entity_id and self.entity_id ~= value) then return end
    -- B2 character userdata returned by FindCharacter is callback-scoped.
    -- Retain Lua state and the numeric identity across callbacks.
    local actor = find_character(id)
    if not actor then return end
    if not self.entity_id then
        self.runtime, self.starter = {}, {}
        Runtime.on_begin(self.runtime, actor)
        self.entity_id = value
    end
    return actor
end

---@param self table
---@param owner FB2AppearanceComponent
function M.on_begin(self, owner)
    character(self, owner)
end

---@param self table
---@param owner FB2AppearanceComponent
---@param dt number
function M.on_tick(self, owner, dt)
    if self.entity_id and not self.runtime.lease and not self.starter.saved_beds then return end
    local actor = character(self, owner)
    if not actor then return end
    Runtime.on_tick(self.runtime, actor, dt)
    Starter.on_tick(self.starter, actor, dt)
end

---@param self table
---@param owner FB2AppearanceComponent
---@param kind string
---@param content string
function M.on_lua_message(self, owner, kind, content)
    if kind:sub(1, 9) ~= "SceneZOI." and kind ~= "SceneZOIStarter.Select" then return end
    local actor = character(self, owner)
    if not actor then return end
    Runtime.on_lua_message(self.runtime, actor, kind, content)
    Starter.on_lua_message(self.starter, actor, kind, content)
end

---@param self table
---@param owner FB2AppearanceComponent
function M.on_savegame(self, owner)
    local actor = self.entity_id and character(self, owner)
    if actor then
        Runtime.on_savegame(self.runtime, actor)
        Starter.on_savegame(self.starter, actor)
    end
    return {}
end

---@param self table
---@param owner FB2AppearanceComponent
function M.on_loadgame(self, owner)
    local actor = character(self, owner)
    if actor then
        Runtime.on_loadgame(self.runtime, actor)
        Starter.on_loadgame(self.starter, actor)
    end
end

---@param self table
---@param owner FB2AppearanceComponent
function M.on_end(self, owner)
    if not self.entity_id then return end
    local id = inzoi.FB1EntityId()
    id.Value = self.entity_id
    local actor = find_character(id)
    if actor then
        Runtime.on_end(self.runtime, actor)
        Starter.on_end(self.starter, actor)
    end
    self.entity_id, self.runtime, self.starter = nil, nil, nil
end

return M
