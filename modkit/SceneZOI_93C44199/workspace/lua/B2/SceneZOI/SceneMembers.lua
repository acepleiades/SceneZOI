-- Zois currently held by a scene, across every running session.
local Protocol = require("SceneZOI.Protocol")
local M = {}
local members, spoken = {}, {}

-- A bubble already up when the Zoi joins would otherwise outlast the start of the scene.
local function clear(entity_id, id)
    local native = inzoi.FB2Script_SpeechBubble
    local context = inzoi.FB2ScriptContext(entity_id, entity_id, inzoi.EB1ScriptReason.Interaction)
    local execute = inzoi.FB1Execute()
    execute.BaseObject = inzoi.EB1BaseObject.Self
    native.Execute_RemoveInnerThoughtIcon(context, execute)
    if spoken[id] then
        execute.S1 = spoken[id]
        spoken[id] = nil
        native.Execute_RemoveSpeechBubble(context, execute)
    end
end

function M.add(entity_id)
    local id = Protocol.id(entity_id)
    members[id] = true
    local ok, err = pcall(clear, entity_id, id)
    if not ok then print("[SceneZOI] Could not clear a bubble: " .. tostring(err)) end
end

function M.remove(entity_id) members[Protocol.id(entity_id)] = nil end
function M.has(entity_id) return members[Protocol.id(entity_id)] == true end
function M.remember_speech(entity_id, bubble_id) spoken[Protocol.id(entity_id)] = bubble_id end

return M
