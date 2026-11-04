local Entry=require("SceneZOIStarter.Entry")
local M={}
---@param self table
---@param owner AB1Character
---@param kind string
---@param content string
function M.on_lua_message(self,owner,kind,content)
    if kind=='SceneZOI.FurnitureReply'then require('SceneZOI.Furniture').reply(owner,content);return end
    if kind=="SceneZOIStarter.Selection" then Entry.reply(owner,content) end
end
return M
