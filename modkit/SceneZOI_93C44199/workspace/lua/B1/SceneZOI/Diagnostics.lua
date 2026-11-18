local Config = require("SceneZOI.Config")
local Json = require("SceneZOI.Json")
local release_version = require("SceneZOI.ReleaseVersion")
local M = {}

local command = " mod_id=" .. Config.mod_id .. " section=" .. Config.section
local history = {key = "scene_history", max_records = 256, max_bytes = 131072, lines = {}, size = 0}
local environments = {key = "environment_history", max_records = 16, max_bytes = 131072, lines = {}, size = 0}
local api_trace = {key = "api_trace", max_records = 512, max_bytes = 131072, marker = "kind=", lines = {}, size = 0}
local elapsed, inventory_elapsed = 0, 15
local run_id, environment_id, inventory_signature, inventory_revision, record_index = nil, nil, nil, 0, 0
local inventory_pending, release_version_pending
local api_addons = {}
local exit_watches = {}
local prepare_phases = {awaiting_commit = true, overlay_cut = true, interaction_cancelling = true,
    confirming_idle = true, autonomy_enabled = true}
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
    if data:find('"', 1, true) then return false, "Unescaped quote in CFG value" end
    local ok, saved, message = pcall(inzoi.cli.execute, "uimod.cfg_save" .. command .. " key=" .. key
        .. ' value="' .. data .. '"')
    if not ok then return false, saved end
    return saved, message
end

function M.load(key)
    local ok, message, data = inzoi.cli.execute("uimod.cfg_load" .. command .. " key=" .. key)
    if not ok then
        if message and message:find("Key not found", 1, true) then return "" end
        return nil, message
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
    if #line + 1 > journal.max_bytes then return end
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
    fields.release_version = release_version
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

function M.record_api_trace(fields)
    append(api_trace, M.format(M.stamp(fields)))
end

local function identifier(value)
    return type(value) == "string" and #value <= 96 and value ~= "none" and value:match("^[%w_.:+%-]+$") and value or nil
end

function M.prepare_wait(current, participant, fields)
    local phase = fields[3]
    if not prepare_phases[phase] then return end
    local wait = {phase = phase, queue_id = identifier(fields[5]), action_type = identifier(fields[6]),
        interaction_bag_id = identifier(fields[7]), reported_at_seconds = math.floor(current.age * 1000) / 1000}
    if phase == "autonomy_enabled" then
        if fields[8] == "1" or fields[8] == "0" then wait.autonomy_option = fields[8] == "1" end
        if fields[9] == "1" or fields[9] == "0" then wait.autonomy_follows_parent = fields[9] == "1" end
        wait.autonomy_disable_attempts = tonumber(fields[10])
    end
    if type(fields[11]) == "string" and #fields[11] <= 4096 then
        local ok, sample = pcall(function() return Json.decode(require("SceneZOI.Protocol").decode(fields[11])) end)
        if ok and type(sample) == "table" then
            local observed = {}
            for _, name in ipairs({"autonomy_requested", "autonomy_notified", "autonomy_effective", "autonomy_resolved",
                "global_autonomy", "follow_global", "active_mode"}) do
                if type(sample[name]) == "boolean" then observed[name] = sample[name] end
            end
            for _, name in ipairs({"progress_attempts", "simulation_ticks", "prepare_received", "heartbeat_received",
                "commit_received", "seconds_since_native_tick", "seconds_since_commit"}) do
                local value = sample[name]
                if type(value) == "number" and value == value and value >= 0 and value <= 1000000000 then observed[name] = value end
            end
            for _, name in ipairs({"control_at_prepare", "controlled_id", "progress_source", "zoi_group",
                "character_group_type", "autonomy_state"}) do
                observed[name] = identifier(sample[name])
            end
            wait.simulation = observed
        end
    end
    participant.preparation_wait = {revision = current.revision, state = wait}
    if phase == "awaiting_commit" or phase == "confirming_idle" then return end
    local previous = participant.preparation_log
    if previous and previous.revision == current.revision and current.age - previous.age < 1 then return end
    participant.preparation_log = {revision = current.revision, age = current.age}
    M.record("participant_prepare_wait", {session_id = current.token, scene_id = current.node.id,
        revision = current.revision, participant_id = participant.id, role = participant.role, wait = wait})
end

function M.wait_status(current, participant)
    if not current.save_records or not current.save_records[participant.id] then return {phase = "awaiting_snapshot"} end
    if not current.save_ready then return {phase = "awaiting_save_ack"} end
    if current.furniture and not current.furniture_ready then return {phase = "awaiting_furniture"} end
    local latest = participant.preparation_wait
    if latest and latest.revision == current.revision then
        local state = {}
        for key, value in pairs(latest.state) do state[key] = value end
        state.seconds_since_report = math.max(0, math.floor((current.age - state.reported_at_seconds) * 1000) / 1000)
        return state
    end
    return {phase = "awaiting_simulation_status"}
end

local function read_movement(actor)
    local position = actor:K2_GetActorLocation()
    local movement = actor.CharacterMovement
    assert(type(position.X) == "number" and type(position.Y) == "number", "Movement position unavailable")
    return {x = position.X, y = position.Y, mode = tostring(movement.MovementMode),
        custom_mode = movement.CustomMovementMode, collision = actor:GetActorEnableCollision()}
end

local function current_montage(actor)
    local instance = actor.Mesh:GetAnimInstance()
    local montage = instance and instance:GetCurrentActiveMontage()
    return montage and identifier(montage:GetName()) or "none"
end

local function finish_watch(watch, status)
    local sample, first = watch.sample, watch.first
    local moved = watch.distance >= 10
    if not status then
        if not sample then status = "reading_unavailable"
        elseif sample.mode == "0" or sample.mode == "MOVE_None" then status = "movement_disabled"
        elseif watch.samples < 2 then status = "insufficient_samples"
        else status = moved and "movement_observed" or "no_movement_observed" end
    end
    local montage_ok, montage = false, nil
    if sample and status ~= "participant_unavailable" and status ~= "participant_reserved" then
        montage_ok, montage = pcall(current_montage, watch.actor)
    end
    M.record("participant_post_exit", {session_id = watch.token, scene_id = watch.scene_id,
        participant_id = watch.id, role = watch.role, control_at_exit = watch.control,
        cleanup_complete = watch.cleanup_complete, restoration = watch.restoration,
        status = status, samples = watch.samples, expected_movement_mode = watch.expected_mode,
        first_movement_mode = first and first.mode, movement_mode = sample and sample.mode,
        custom_movement_mode = sample and sample.custom_mode,
        expected_collision = watch.expected_collision, collision = sample and sample.collision,
        active_montage = montage_ok and montage or nil,
        movement_observed = moved, horizontal_displacement_cm = math.floor(watch.distance + 0.5)})
end

local function watch_participant(session, participant, status)
    local watch = {actor = participant.actor, id = participant.id, role = participant.role,
        token = session.token, scene_id = session.node.id, control = participant.control,
        cleanup_complete = session.cleanup_complete, restoration = participant.restoration,
        expected_mode = participant.movement_mode ~= nil and tostring(participant.movement_mode) or nil,
        expected_collision = participant.collision, elapsed = 0, next_sample = .4, distance = 0, samples = 0}
    if status then finish_watch(watch, status); return end
    local existing = exit_watches[participant.id]
    if existing then finish_watch(existing, "participant_reserved") end
    exit_watches[participant.id] = watch
end

function M.watch_exit(session)
    for _, participant in ipairs(session.participants) do watch_participant(session, participant) end
    for _, participant in ipairs(session.unloaded or {}) do
        watch_participant(session, participant, "participant_unavailable")
    end
end

function M.tick_exit(dt, actors, holder)
    for id, watch in pairs(exit_watches) do
        watch.elapsed = watch.elapsed + dt
        local status
        if actors[id] ~= watch.actor then status = "participant_unavailable"
        elseif holder(id) then status = "participant_reserved" end
        if not status and watch.elapsed >= watch.next_sample then
            watch.next_sample = watch.elapsed + .5
            local ok, sample = pcall(read_movement, watch.actor)
            if ok then
                watch.samples = watch.samples + 1
                watch.first, watch.sample = watch.first or sample, sample
                local dx, dy = sample.x - watch.first.x, sample.y - watch.first.y
                watch.distance = math.max(watch.distance, math.sqrt(dx * dx + dy * dy))
            end
        end
        if status or watch.elapsed >= 3 then
            exit_watches[id] = nil
            finish_watch(watch, status)
        end
    end
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
    local localization = require("SceneZOI.Localization")
    local function conflict_sample(conflicts)
        local result = {}
        for index = 1, math.min(#conflicts, 16) do result[index] = conflicts[index] end
        return result
    end
    local task_conflicts = catalog.tasks and catalog.tasks.conflicts or {}
    local label_conflicts = localization.conflicts and localization.conflicts() or {}
    local game = query(game_state) or {}
    local report = {
        build = Config.build,
        mounted_ui_mod_ids = query(ui_mods, "uimod.list"), disabled_ui_only_mod_ids = query(ui_mods, "uimod.list_disabled"),
        content_declarations_by_owner = content, declared_scenes_by_namespace = declared,
        playable_scenes_by_namespace = playable, excluded_scene_count = #excluded_ids,
        excluded_scene_sample = blocked, observed_api_addons = keys(api_addons),
        catalog_warning_count = #(catalog.warnings or {}),
        task_conflict_count = #task_conflicts, task_conflicts = conflict_sample(task_conflicts),
        localization_conflict_count = #label_conflicts, localization_conflicts = conflict_sample(label_conflicts),
        game_phase = game.phase, map_id = game.map_id,
        ui_build = query(M.load, "ui_build"), ui_boot = query(M.load, "ui_boot"),
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
        -- A transient read failure leaves the previous run's history unknown.
        -- Keep the new entries pending so the first write cannot erase it.
        local previous = query(M.load, journal.key)
        if type(previous) ~= "string" then
            if not journal.read_failed then
                print("[SceneZOI] Could not read " .. journal.key .. ". Will retry.")
                journal.read_failed = true
            end
            return
        end
        local pending = journal.lines
        journal.lines, journal.size = {}, 0
        local marker = journal.marker or "event="
        for line in previous:gmatch("[^\n]+") do
            if not line:find('"', 1, true) and line:find(marker, 1, true) then append(journal, line) end
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
    if release_version_pending then release_version_pending = not M.save("release_version", release_version) end
    flush(history)
    flush(environments)
    flush(api_trace)
end

function M.boot(id)
    run_id, environment_id, inventory_signature, inventory_revision, record_index = id, nil, nil, 0, 0
    inventory_elapsed, api_addons, inventory_pending = 15, {}, nil
    release_version_pending = not M.save("release_version", release_version)
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
