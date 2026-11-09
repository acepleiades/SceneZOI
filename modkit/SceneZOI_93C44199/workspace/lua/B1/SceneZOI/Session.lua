local Binding = require("SceneZOI.Binding")
local Clock = require("SceneZOI.Clock")
local OutfitState = require("SceneZOI.OutfitState")
local M = {}

function M.new(options)
    local current = options
    current.revision, current.last_navigation, current.last_speed_command = 1, 0, 0
    current.clock = Clock.new()
    require('SceneZOI.AddonControl').init(current)
    current.preparing, current.elapsed, current.heartbeat, current.ui_age, current.age = true, 0, 0, 0, 0
    for index, participant in ipairs(current.participants) do
        participant.id = current.participant_ids[index]
        participant.control = participant.control or "npc"
    end
    return current
end

function M.bind(current)
    current.bindings = Binding.resolve(current.participants, current.node)
    for role, participant in pairs(current.bindings) do
        participant.role = role
        local directive = current.node.outfits and current.node.outfits[role]
        participant.removed_slots = OutfitState.merge(participant.removed_slots, directive and directive.remove_slots)
    end
end

function M.all(current, field)
    for _, participant in ipairs(current.participants) do if not participant[field] then return false end end
    return true
end

function M.cleanup_complete(current)
    return current.addon_effects_restored and current.subsystems_restored and
        M.all(current,'released')and M.all(current,'client_restored')and
        (not current.furniture or current.furniture_released)or false
end

function M.controlled(current)
    for _, participant in ipairs(current.participants) do
        if participant.control == "controlled" then return participant end
    end
end

function M.change_node(current, node, assets, duration, subsystems)
    current.node, current.assets, current.duration, current.subsystems = node, assets, duration, subsystems
    current.revision, current.age, current.appearance_frames = current.revision + 1, 0, 0
    current.appearance_wait, current.preparation_stage = nil, nil
    current.preparing, current.participants_ready, current.navigation_code = true, false, "ok"
    current.clock:reset_node()
    current.transition_finished = nil
    current.bindings, current.tracks = nil, {}
    for _, participant in ipairs(current.participants) do participant.node_ready = false end
end

function M.snapshot(current)
    local participants, tracks = {}, {}
    local function row(participant)
        return {id = participant.id, control = participant.control,
            body = participant.body, role = participant.role,expression_error=participant.expression_error,facial_pose_error=participant.facial_pose_error,voice_error=participant.voice_error,
            restoration=participant.restoration}
    end
    for _, participant in ipairs(current.participants) do participants[#participants + 1] = row(participant) end
    for _, participant in ipairs(current.unloaded or {}) do participants[#participants + 1] = row(participant) end
    for _, track in ipairs(current.tracks or {}) do
        tracks[#tracks + 1] = {id = track.id, kind = track.kind, participant_id = track.participant_id}
    end
    return {event_index=current.event_index or 0,addon_client_id=current.addon_client_id,
        focused=require('SceneZOI.Sessions').focused()==current,
        result_facts=require('SceneZOI.AddonControl').facts(current),
        task_state=current.tasks and require('SceneZOI.Tasks').inspect(current.tasks,current)or {},
        addon_data=require('SceneZOI.DataValidation').copy(current.node.addon_data or {}),
        participant_addon_data=require('SceneZOI.DataValidation').copy(current.node.participant_addon_data or {}),
        addon_id=current.addon_id,request_id=current.request_id,addon_context=require('SceneZOI.DataValidation').copy(current.addon_context),
        session_restrictions=require('SceneZOI.DataValidation').copy(current.session_restrictions),
        content_rating=current.node.content_rating,tags=require('SceneZOI.DataValidation').copy(current.node.tags or {}),
        participant_tags=require('SceneZOI.DataValidation').copy(current.node.participant_tags or {}),
        actions=require('SceneZOI.DataValidation').copy(current.node.actions or {}),
        furniture_id=current.furniture and current.furniture.id,
        id = current.token, node_id = current.node.id, revision = current.revision,
        node_kind = current.node.kind, destination = current.node.destination,
        phase = current.ended and "ended" or current.stopping and "exiting" or current.preparing and "preparing" or "playing",
        participants = participants, tracks = tracks, speed_index = current.clock.index,
        task_progress = current.tasks and require("SceneZOI.DataValidation").copy(current.tasks.participants) or {},
        game_scale = current.clock.scale, effective_speed = current.clock.effective,
        completion_effects = require("SceneZOI.CompletionEffects").snapshot(current.completion_effects)}
end

return M
