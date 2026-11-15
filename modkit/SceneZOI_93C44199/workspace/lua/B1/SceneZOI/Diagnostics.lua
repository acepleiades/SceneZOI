local Config = require("SceneZOI.Config")
local Json = require("SceneZOI.Json")
local Protocol = require("SceneZOI.Protocol")
local M = {}

local command = " mod_id=" .. Config.mod_id .. " section=" .. Config.section
local history = {key = "scene_history", max_records = 256, max_bytes = 131072, lines = {}, size = 0}
local environments = {key = "environment_history", max_records = 16, max_bytes = 131072, lines = {}, size = 0}
local elapsed, inventory_elapsed = 0, 15
local run_id, environment_id, inventory_signature, inventory_revision, record_index = nil, nil, nil, 0, 0
local inventory_pending
local api_addons = {}
local scene_events = {
    session_preparing = true, session_started = true, node_preparing = true, node_entered = true,
    plan_auto_mode_changed = true, plan_stage_changed = true, playback_speed_changed = true,
    session_ending = true, session_ended = true, game_clock_changed = true,
    task_completed = true, task_route_selected = true, task_route_failed = true,
    transition_completed = true, plan_goals_met = true, addon_control_changed = true,
}

local function as_text(value, separator)
    if value == Json.null then return "null" end
    if type(value) == "string" then
        if value:match("^[%w_.:+%-]+$") then return value end
        -- Quoted cfg values preserve whitespace but the CLI treats double quotes
        -- as delimiters, even when escaped.
        local escaped = Json.encode(value):sub(2, -2):gsub('\\"', '\\u0022'):gsub("'", "\\u0027")
        return "'" .. escaped .. "'"
    end
    if type(value) ~= "table" then return tostring(value) end
    local parts = {}
    local mt = getmetatable(value)
    if (mt and mt.__jsonkind == "array") or #value > 0 then
        for index, entry in ipairs(value) do parts[index] = as_text(entry) end
        return "[" .. table.concat(parts, ", ") .. "]"
    end
    local fields = {}
    for key in pairs(value) do fields[#fields + 1] = key end
    table.sort(fields)
    for index, key in ipairs(fields) do parts[index] = as_text(key) .. "=" .. as_text(value[key]) end
    local body = table.concat(parts, separator or ", ")
    return separator and body or "{" .. body .. "}"
end

function M.format(fields, separator)
    return as_text(fields, separator or " ")
end

function M.save(key, data)
    if data:find('"', 1, true) then return false end
    local ok, saved = pcall(inzoi.cli.execute, "uimod.cfg_save" .. command .. " key=" .. key
        .. ' value="' .. data .. '"')
    return ok and saved
end

local function load(key)
    local ok, message, data = inzoi.cli.execute("uimod.cfg_load" .. command .. " key=" .. key)
    if not ok then
        if message and message:find("Key not found", 1, true) then return "" end
        return nil
    end
    local raw = data or message
    if not raw or raw == "" then return "" end
    if raw:sub(1, 1) == "{" then
        -- cfg_load escapes apostrophes as \' inside its JSON response.
        -- Match whole escape pairs so that a literal backslash stays intact.
        raw = raw:gsub("\\(.)", function(char)
            return char == "'" and "'" or "\\" .. char
        end)
        return Json.decode(raw).value
    end
    return raw
end

local function append(journal, line)
    journal.lines[#journal.lines + 1] = line
    journal.size = journal.size + #line + 1
    while #journal.lines > journal.max_records or journal.size > journal.max_bytes do
        journal.size = journal.size - #table.remove(journal.lines, 1) - 1
    end
    journal.dirty = true
end

function M.stamp(fields)
    record_index = record_index + 1
    fields.build, fields.run_id, fields.environment_id = Config.build, run_id, environment_id
    fields.record_index, fields.timestamp = record_index, os.time()
    if os.date then fields.time_utc = os.date("!%Y-%m-%dT%H:%M:%SZ", fields.timestamp) end
    return fields
end

function M.detail(value)
    if type(value) ~= "string" then return nil end
    local text = value:match("^.-:%d+:%s*(.*)$") or value
    if text:find("[A-Za-z]:[/\\]") then return "local_path_in_error" end
    return text:gsub("[%c]", " "):sub(1, 240)
end

function M.record(name, fields)
    pcall(function()
        fields.event = name
        append(history, M.format(M.stamp(fields)))
    end)
end

function M.session(snapshot, name, code, context)
    if not scene_events[name] then return end
    context = context or {}
    local participants = Json.array({})
    for _, person in ipairs(snapshot.participants or {}) do
        participants[#participants + 1] = {id = person.id, role = person.role, body = person.body,
            control = person.control, restoration = person.restoration}
    end
    local facts = snapshot.result_facts or {}
    local plan = snapshot.plan or {}
    local task = snapshot.task or {}
    local route = snapshot.task_route or {}
    M.record(name, {session_id = snapshot.id, addon_id = snapshot.addon_id, request_id = snapshot.request_id,
        client = context.client, sequence = context.sequence, source = context.source,
        scene_id = snapshot.node_id, revision = snapshot.revision, event_index = snapshot.event_index,
        phase = snapshot.phase, code = code or "ok", furniture_id = snapshot.furniture_id,
        participants = participants, speed_index = snapshot.speed_index, effective_speed = snapshot.effective_speed, game_scale = snapshot.game_scale,
        plan = snapshot.plan and {auto_mode = plan.auto_mode, state = plan.state, stage = plan.stage,
            stage_count = plan.stage_count, outcome = plan.outcome, end_policy = plan.end_policy,
            real_seconds = plan.real_seconds, game_seconds = plan.game_seconds,
            goals = plan.goals, required_stages = plan.required_stages,
            post_completion_stay_seconds = plan.post_completion_stay_seconds},
        task_id = task.id or task.task_id, completed_by = snapshot.participant_id, completion_index = task.completion_index,
        route_target = route.target_node_id or route.target, integration = snapshot.integration,
        stop_reason = facts.stop_reason, stop_origin = facts.stop_origin,
        playing_seconds = facts.playing_seconds, cleanup_code = facts.cleanup_code, cleanup_complete = facts.cleanup_complete})
end

function M.note_addon(id)
    if id then api_addons[id] = true end
end

local function keys(map)
    local list = Json.array({})
    for id in pairs(map) do list[#list + 1] = id end
    table.sort(list)
    return list
end

local function ui_mods(operation)
    local ok, message, data = inzoi.cli.execute(operation)
    if not ok then return nil end
    local ids = {}
    for _, mod in ipairs(Json.decode(data or message)) do
        local id = mod.parent and mod.parent ~= "" and mod.parent or mod.mod_id
        if id then ids[id] = true end
    end
    return keys(ids)
end

local function query(fn, ...)
    local ok, value = pcall(fn, ...)
    return ok and value or nil
end

local function game_state()
    local ok, message, data = inzoi.cli.execute("game.get_state")
    if ok then return Json.decode(data or message) end
end

local function inventory()
    local declarations = require("SceneZOI.DataFiles").get()
    local catalog = require("SceneZOI.Catalog").get_snapshot()
    local content, declared, playable, blocked = {}, {}, {}, {}
    for kind, documents in pairs(declarations.by_kind or {}) do
        for _, document in ipairs(documents) do
            local owner = document.owner
            local kinds = content[owner] or {}
            kinds[kind] = (kinds[kind] or 0) + 1
            content[owner] = kinds
            if kind == "scene_pack" and type(document.data) == "table" and type(document.data.nodes) == "table" then
                local namespace = type(document.data.id) == "string" and document.data.id or owner
                declared[namespace] = (declared[namespace] or 0) + #document.data.nodes
            end
        end
    end
    for id in pairs(catalog.nodes or {}) do
        local namespace = id:match("^[^.]+")
        playable[namespace] = (playable[namespace] or 0) + 1
    end
    local excluded = catalog.excluded or {}
    local excluded_ids = keys(excluded)
    for index = 1, math.min(#excluded_ids, 64) do
        local id = excluded_ids[index]
        blocked[id] = excluded[id]
    end
    local game = query(game_state) or {}
    local report = {
        build = Config.build,
        mounted_ui_mod_ids = query(ui_mods, "uimod.list"), disabled_ui_only_mod_ids = query(ui_mods, "uimod.list_disabled"),
        content_declarations_by_owner = content, declared_scenes_by_namespace = declared,
        playable_scenes_by_namespace = playable, excluded_scene_count = #excluded_ids,
        excluded_scene_sample = blocked, observed_api_addons = keys(api_addons),
        catalog_warning_count = #(catalog.warnings or {}),
        game_phase = game.phase, map_id = game.map_id,
        ui_build = query(load, "ui_build"), ui_boot = query(load, "ui_boot"),
        registered_content_files = declarations.file_count,
    }
    local signature = M.format(report, "\n")
    if signature ~= inventory_signature then
        inventory_signature = signature
        inventory_revision = inventory_revision + 1
        environment_id = (run_id or tostring(os.time())) .. "." .. inventory_revision
        report.event = "environment_snapshot"
        M.stamp(report)
        append(environments, M.format(report))
        inventory_pending = M.format(report, "\n") .. "\n"
    end
    if inventory_pending and M.save("mod_inventory", inventory_pending) then inventory_pending = nil end
end

function M.catalog_changed()
    inventory_elapsed = 15
end

local function flush(journal)
    if not journal.dirty then return end
    if not journal.loaded then
        local previous = query(load, journal.key)
        if previous == nil then
            if not journal.read_failed then
                print("[SceneZOI] Could not read " .. journal.key .. ". Will retry.")
                journal.read_failed = true
            end
            return
        end
        local legacy = previous:match("^%x+$") and Protocol.decode(previous)
        local pending = journal.lines
        journal.lines, journal.size = {}, 0
        if legacy then
            for line in legacy:gmatch("[^\n]+") do
                local record = query(Json.decode, line)
                if type(record) == "table" then append(journal, M.format(record)) end
            end
        else
            for line in previous:gmatch("[^\n]+") do
                if not line:find('"', 1, true) and line:find("event=", 1, true) then append(journal, line) end
            end
        end
        for _, line in ipairs(pending) do append(journal, line) end
        journal.loaded = true
    end
    if M.save(journal.key, table.concat(journal.lines, "\n") .. "\n") then
        journal.dirty = false
        journal.write_failed = false
    elseif not journal.write_failed then
        print("[SceneZOI] Could not save " .. journal.key .. ". Will retry.")
        journal.write_failed = true
    end
end

function M.flush()
    flush(history)
    flush(environments)
end

function M.boot(id)
    run_id, environment_id, inventory_signature, inventory_revision, record_index = id, nil, nil, 0, 0
    inventory_elapsed, api_addons, inventory_pending = 15, {}, nil
    M.record("runtime_boot", {schema = 2})
end

function M.shutdown()
    M.record("runtime_unloaded", {})
    M.flush()
end

function M.tick(dt)
    elapsed, inventory_elapsed = elapsed + dt, inventory_elapsed + dt
    if inventory_elapsed >= 15 then
        inventory_elapsed = 0
        pcall(inventory)
    end
    if elapsed >= 1 then
        elapsed = 0
        M.flush()
    end
end

return M
