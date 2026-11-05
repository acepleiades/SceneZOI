local Runtime = require("SceneZOI.Runtime")
local M = {}

---@param self table
---@param owner AB1Character
function M.on_begin(self, owner)
    self.registered_id=Runtime.register(owner)
end

-- Retry only until the native entity ID is ready; no per-frame registration after that.
---@param self table
---@param owner AB1Character
---@param dt number
function M.on_tick(self, owner, dt)
    if not self.registered_id then self.registered_id=Runtime.register(owner)end
end

---@param self table
---@param owner AB1Character
---@param kind string
---@param content string
function M.on_lua_message(self, owner, kind, content)
    if kind=='SceneZOI.API.Request'then require('SceneZOI.AddonAPI').receive(owner,content)
    elseif kind=='SceneZOI.API.DepartReply'then require('SceneZOI.AddonAPI').departure_reply(owner,content)
    elseif kind == "SceneZOI.Reply" then Runtime.reply(owner, content)
    elseif kind == "SceneZOI.Save" then Runtime.save_reply(owner,content)end
end

---@param self table
---@param owner AB1Character
function M.on_end(self, owner)
    Runtime.unregister(owner)
    self.registered_id=nil
end

return M
