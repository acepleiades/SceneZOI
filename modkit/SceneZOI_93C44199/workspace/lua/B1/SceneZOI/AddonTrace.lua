-- Host-side diagnostics for add-ons using the public message API.
local Json = require("SceneZOI.Json")
local Protocol = require("SceneZOI.Protocol")
local Diagnostics = require("SceneZOI.Diagnostics")
local M = {}

local page_bytes, flush_interval, pages_per_tick = 32768, 1, 4
local sequence = 0
local pending, page = {}, nil
local elapsed, storage_failed = 0, false
local request_fields = {"addon_id", "client_id", "request_id", "operation", "api_version", "expected_instance_id"}
local argument_fields = {
    "participants", "initiator", "furniture_id", "scene_id", "search", "session_restrictions",
    "bindings", "start_mode", "background", "placement", "lifetime", "goals", "restrictions",
    "end_policy", "post_completion_stay_seconds", "task_progress_multiplier", "stages",
    "required_stages", "stage_preferences", "auto_speed", "session_id", "participant_id",
    "task_id", "enabled", "speed_index", "multiplier", "value", "amount", "rate_multiplier",
    "completion_hold", "request_id", "start_request_id", "origin_id", "radius_m",
    "include_unavailable", "reason", "events", "scope", "capabilities", "effect_id",
    "expression_set", "facial_pose", "item_id", "muted",
}
local result_fields = {
    "accepted", "valid", "code", "scene_id", "start_request_id", "autonomous", "stages",
    "route_uncertain", "phase", "session_id", "event", "count", "auto_mode", "speed_index",
    "multiplier", "subscribed", "scope", "runtime_build", "value", "percent", "completions",
    "renewed", "released", "locked", "reservation", "event_cursor", "muted",
}
local session_fields = {
    "id", "node_id", "phase", "revision", "focused", "addon_id", "addon_client_id",
    "speed_index", "effective_speed", "game_scale",
}
local result_lists = {
    scenes = {"scene_id"}, furniture = {"furniture_id", "distance_m", "available", "status"},
    navigation = {"target"}, sessions = session_fields,
}

-- Only project API fields relevant to diagnostics. Restrict nested values to
-- structured data and identifiers, with a shared budget for oversized requests.
local function compact(value, budget, depth)
    if budget.left == 0 then return nil end
    budget.left = budget.left - 1
    local kind = type(value)
    if kind == "boolean" or kind == "number" then return value end
    if kind == "string" and #value <= 96 and value:match("^[%w_.:+*%-]+$") then return value end
    if value == Json.null then return value end
    if kind ~= "table" or depth == 0 then return nil end
    local mt = getmetatable(value)
    if (mt and mt.__jsonkind == "array") or #value > 0 then
        local result = Json.array({})
        for _, item in ipairs(value) do
            if budget.left == 0 then break end
            local entry = compact(item, budget, depth - 1)
            result[#result + 1] = entry == nil and Json.null or entry
        end
        return result
    end
    local result = {}
    for key, item in pairs(value) do
        if budget.left == 0 then break end
        if type(key) == "string" and #key <= 96 and key:match("^[%w_.%-]+$")
            and key ~= "context" and key ~= "addon_context" and key ~= "addon_data"
            and key ~= "participant_addon_data" and key ~= "message" then
            result[key] = compact(item, budget, depth - 1)
        end
    end
    return result
end

local function select_fields(source, fields)
    local result, budget = {}, {left = 256}
    if type(source) ~= "table" then return result end
    for _, key in ipairs(fields) do
        if source[key] ~= nil then result[key] = compact(source[key], budget, 5) end
    end
    return result
end

local function write(row)
    sequence = sequence + 1
    row.sequence = sequence
    local line = Diagnostics.format(Diagnostics.stamp(row)) .. "\n"
    if not page or page.bytes + #line > page_bytes then
        local number = page and page.number + 1 or 1
        local capture = page and page.capture or row.instance_id:gsub("%W", "_")
        page = {capture = capture, number = number, bytes = 0, saved = "", lines = {}}
    end
    if #page.lines == 0 then pending[#pending + 1] = page end
    page.lines[#page.lines + 1] = line
    page.bytes = page.bytes + #line
end

-- Write a batch of complete trace lines through the normal runtime cfg store.
-- Keep the queue intact if the native write fails so the next tick can retry.
function M.flush(max_pages)
    local count = math.min(#pending, max_pages or #pending)
    for _ = 1, count do
        local current = pending[1]
        local key = ("api_trace_%s_%06d"):format(current.capture, current.number)
        local body = current.saved .. table.concat(current.lines)
        if not Diagnostics.save(key, body) then
            if not storage_failed then print("[SceneZOI] Could not save API trace. Will retry.") end
            storage_failed = true
            return
        end
        storage_failed = false
        current.saved, current.lines = body, {}
        table.remove(pending, 1)
    end
end

function M.tick(dt)
    if #pending == 0 then elapsed = 0; return end
    elapsed = elapsed + dt
    if elapsed < flush_interval then return end
    elapsed = 0
    M.flush(pages_per_tick)
end

local function summarize_result(value)
    local result = select_fields(value, result_fields)
    if type(value) ~= "table" then return result end
    local scene = value.scene
    if type(scene) == "table" and scene ~= Json.null then
        result.scene_id = compact(scene.scene_id, {left = 1}, 0)
    end
    if type(value.session) == "table" and value.session ~= Json.null then
        result.session = select_fields(value.session, session_fields)
    end
    for key, fields in pairs(result_lists) do
        local source = value[key]
        if type(source) == "table" then
            local sample = Json.array({})
            for index = 1, math.min(#source, 16) do
                sample[index] = select_fields(source[index], fields)
            end
            result[key] = {count = #source, sample = sample}
        end
    end
    return result
end

local function response(req, reply, endpoint_id, dispatched, replayed)
    local row = select_fields(req, request_fields)
    row.kind, row.instance_id, row.endpoint_id = "call", reply.instance_id, endpoint_id
    row.dispatched, row.replayed = dispatched, replayed == true
    row.ok, row.code = reply.ok, reply.code
    row.arguments = select_fields(req.arguments, argument_fields)
    row.result = summarize_result(reply.result)
    write(row)
end

function M.response(req, reply, endpoint_id, dispatched, replayed)
    pcall(response, req, reply, endpoint_id, dispatched, replayed)
end

function M.rejected(actor, req, instance_id, code, payload)
    pcall(function()
        local row = select_fields(req, request_fields)
        local ok, endpoint_id = pcall(function() return Protocol.id(actor:GetEntityId()) end)
        row.kind, row.instance_id, row.endpoint_id = "rejected", instance_id, ok and endpoint_id or nil
        row.ok, row.code = false, code
        row.payload_bytes = type(payload) == "string" and #payload or nil
        write(row)
    end)
end

return M
