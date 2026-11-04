local Runtime = require("SceneZOI.Runtime")
local M = {}

---@param self table
---@param owner AB1Character
function M.on_begin(self, owner)
    Runtime.register(owner)
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
end

return M
