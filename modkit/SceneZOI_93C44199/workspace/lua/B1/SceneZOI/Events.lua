-- Runtime observers receive plain snapshots, never mutable session/native objects.
local M = {}
local listeners, next_handle, history, pending = {}, 0, {}, {}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return setmetatable(result,getmetatable(value))
end

function M.subscribe(name, callback)
    assert(type(name) == "string" and type(callback) == "function", "Invalid scene event observer")
    next_handle = next_handle + 1
    listeners[next_handle] = {name = name, callback = callback}
    return next_handle
end

-- Filter the generic completion stream by a content-defined event identifier.
function M.subscribe_task(completion_event, callback)
    require("SceneZOI.DataValidation").id(completion_event)
    assert(type(callback) == "function", "Invalid task observer")
    return M.subscribe("task_completed", function(event)
        if event.task and event.task.completion_event == completion_event then callback(event) end
    end)
end

function M.unsubscribe(handle) listeners[handle] = nil end
function M.history() return copy(history) end

function M.emit(name, snapshot, code)
    local event = copy(snapshot)
    event.name, event.code = name, code or "ok"
    history[#history + 1] = event
    if #history > 32 then table.remove(history, 1) end
    pending[#pending + 1] = event
end

-- Dispatch after the runtime update, so observers cannot interrupt half-prepared state.
function M.flush()
    local delivered = 0
    while #pending > 0 and delivered < 64 do
        local item = table.remove(pending, 1)
        local event = item
        local name = event.name
        delivered = delivered + 1
        local targets = {}
        for handle in pairs(listeners) do targets[#targets + 1] = handle end
        table.sort(targets)
        for _, handle in ipairs(targets) do
            local listener = listeners[handle]
            if listener and (listener.name == name or listener.name == "*") then
                local ok, err = pcall(listener.callback, copy(event))
                if not ok then print("[SceneZOI] Observer failed: " .. tostring(err)) end
            end
        end

    end
    -- Retain excess notifications for the next flush; never discard task completions.
end

return M
