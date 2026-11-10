-- Native chunk. A bubble or thought icon made by a game script names its Zoi here, so a Zoi in a
-- scene goes without them while every other Zoi's pass through untouched.
local Members = require("SceneZOI.SceneMembers")
local M = {}

local function bubble_owner(context, execute)
    return execute.BaseObject == inzoi.EB1BaseObject.Target and context.TargetEntityId or context.SelfEntityId
end

local function withheld(context, execute)
    local ok, held = pcall(function() return Members.has(bubble_owner(context, execute)) end)
    -- A failed lookup must never cost the game its bubble.
    return ok and held
end

---@param context FB2ScriptContext
---@param execute FB1Execute
function M.Override_Execute_AddSpeechBubble(context, execute)
    if withheld(context, execute) then return end
    pcall(function() Members.remember_speech(bubble_owner(context, execute), execute.S1) end)
    return inzoi.FB2Script_SpeechBubble.Execute_AddSpeechBubble(context, execute)
end

---@param context FB2ScriptContext
---@param execute FB1Execute
function M.Override_Execute_AddInnerThoughtIcon(context, execute)
    if withheld(context, execute) then return end
    return inzoi.FB2Script_SpeechBubble.Execute_AddInnerThoughtIcon(context, execute)
end

return M
