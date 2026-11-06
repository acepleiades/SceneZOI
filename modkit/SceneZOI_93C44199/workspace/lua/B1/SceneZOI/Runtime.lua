local Config = require("SceneZOI.Config")
local Protocol = require("SceneZOI.Protocol")
local Native = require("SceneZOI.Native")
local Subsystems = require("SceneZOI.Subsystems")
local Session = require("SceneZOI.Session")
local Playback = require("SceneZOI.Playback")
local Clock = require("SceneZOI.Clock")
local Events = require("SceneZOI.Events")
local Catalog = require("SceneZOI.Catalog")
local Appearance = require("SceneZOI.Appearance")
local OutfitControl = require("SceneZOI.OutfitControl")
local Settings = require("SceneZOI.Settings")
local Localization = require("SceneZOI.Localization")
local Personality = require("SceneZOI.Personality")
local VoicePersonality = require("SceneZOI.VoicePersonality")
local Json = require("SceneZOI.Json")
local M = {actors = {}}
local registrations, unregistrations, non_owner_unregistrations = 0, 0, 0
local last_registered_id, last_unregistered_id
local registered_actor_ids = {}
local deferred_registrations = 0

local CompletionEffects = require('SceneZOI.CompletionEffects')
local Tasks = require('SceneZOI.Tasks')
local TaskRoutes = require('SceneZOI.TaskRoutes')
local Furniture=require('SceneZOI.Furniture')
local ControllerRange=require('SceneZOI.ControllerRange')
local Save=require('SceneZOI.SaveBridge')
local Autosave=require('SceneZOI.Autosave')
local Addons=require('SceneZOI.AddonAPI')
local Search=require('SceneZOI.SceneSearch')
local SceneVisuals=require('SceneZOI.SceneVisuals')
local Control=require('SceneZOI.AddonControl')
local Effects=require('SceneZOI.AddonEffects')
local ModeGuard=require('SceneZOI.ModeGuard')
local session
local serial = 0
local poll_elapsed = 0
local state_value
local boot_request
local completed, completion_order = {}, {}
local pending_focus, last_focus
local rejected_focus = {}

local function command(name, key)
    return name .. " mod_id=" .. Config.mod_id .. " section=" .. Config.section .. " key=" .. key
end

function M.diagnostic(value)
    local safe = tostring(value):gsub("[^%w_.:+%-]", "_"):sub(1, 1500)
    pcall(inzoi.cli.execute, command("uimod.cfg_save", "diagnostic") .. " value=" .. safe)
    -- Cleanup publishes a final status immediately; keep the cause available after it finishes.
    if tostring(value):find("failed:", 1, true) then
        pcall(inzoi.cli.execute, command("uimod.cfg_save", "last_error") .. " value=" .. safe)
    end
    print("[SceneZOI] " .. tostring(value))
end

local function read(key)
    local ok, message, data = inzoi.cli.execute(command("uimod.cfg_load", key))
    if ok then return data or message end
end

local function publish(client, sequence, phase, code)
    local value = Protocol.pack(client or "none", sequence or 0, phase, code or "ok")
    if value == state_value then return end
    local ok, message = inzoi.cli.execute(command("uimod.cfg_save", "state") .. " value=" .. value)
    if ok then state_value = value
    else print("[SceneZOI] Status bridge failed: " .. tostring(message)) end
end

local function remember(client, sequence, phase, code, actor, silent)
    local key = client .. "|" .. sequence
    if not completed[key] then completion_order[#completion_order + 1] = key end
    completed[key] = {phase = phase, code = code, actor = actor}
    if #completion_order > 32 then completed[table.remove(completion_order, 1)] = nil end
    if not silent then publish(client, sequence, phase, code) end
end

local function tell(participant, kind, content)
    inzoi.message.send_to_sim(participant.actor:GetEntityId(), kind, content)
end

local function notify(current, name, code)
    current.event_index = (current.event_index or 0) + 1
    local snapshot = Session.snapshot(current)
    snapshot.event_index = current.event_index
    Events.emit(name, snapshot, code)
end

local function publish_playback(current)
    local clock = current.clock
    local packet = Protocol.pack(current.client, current.sequence, current.last_speed_command, clock.index,
        string.format("%.4f", clock.scale), string.format("%.4f", clock.effective))
    if current.playback_state == packet then return end
    local ok, message = inzoi.cli.execute(command("uimod.cfg_save", "playback_state") .. " value=" .. packet)
    if ok then current.playback_state = packet
    else M.diagnostic("Playback status will retry: " .. tostring(message)) end
end

local function playback_request(raw)
    local current = session
    local fields = Protocol.unpack(raw)
    if not current or current.stopping or not fields or fields[1] ~= current.client or
        fields[2] ~= current.sequence or fields[3] ~= "speed" then return end
    local count, index = tonumber(fields[4]), tonumber(fields[5])
    if not count or count % 1 ~= 0 or count <= 0 or not index or index % 1 ~= 0 or
        not Config.playback_speeds[index] then return end
    if count > current.last_speed_command then
        current.last_speed_command = count
        if current.clock:select(index) then notify(current, "playback_speed_changed") end
    end
    publish_playback(current)
end

local function finish_stop(old, code)
    if session ~= old then return end
    session = nil
    if Catalog.publish then pcall(Catalog.publish)end
    Autosave.restore() -- Independent retries continue while idle if the setting write fails.
    code = code or "ok"
    old.ended = true
    old.cleanup_code=code
    old.cleanup_complete=Session.cleanup_complete(old)
    Effects.retain(old)
    notify(old, "session_ended", code)
    Control.ended(old,Session.snapshot(old))
    local controlled = Session.controlled(old)
    remember(old.client, old.sequence, (code == "ok" or code == "controller_too_far" or code == "saving" or code == "character_editor" or code == "addon_requested") and "idle" or "error", code, controlled and controlled.actor)
    pcall(inzoi.cli.execute,command('uimod.cfg_save','last_exit')..' value='..Protocol.pack(old.client,old.sequence,code,old.stop_code))
    if code=='saving'then
        pcall(require('SceneZOI.Localization').toast,'SceneZOI ended because the game is saving.')
    end
    if code=='controller_too_far'then
        pcall(require('SceneZOI.Localization').toast,'SceneZOI ended because the controlled Zoi moved too far from the scene.')
    end
    M.diagnostic("Ended " .. old.token .. ": " .. code)
end

local function request_release(old)
    if old.furniture and not old.furniture_released then
        local ok,err=pcall(tell,old.furniture_owner,'SceneZOI.Furniture',Protocol.pack(old.token,old.furniture.id,'release'))
        if not ok then M.diagnostic('Furniture release delivery will retry: '..tostring(err))end
    end
    if not old.addon_effects_restored then
        local ok,err=pcall(Effects.restore,old);old.addon_effects_restored=ok
        if not ok then M.diagnostic('Add-on effect cleanup will retry: '..tostring(err))end
    end
    if not old.subsystems_restored then
        local ok, err = pcall(old.subsystems.restore, old.subsystems)
        old.subsystems_restored = ok
        if not ok then M.diagnostic("Attachment cleanup failed: " .. tostring(err)) end
    end
    for _, participant in ipairs(old.participants) do
        if not participant.client_restored then
            local ok, err = pcall(Native.restore, participant)
            participant.client_restored = ok
            if not ok and participant.restore_error ~= tostring(err) then
                participant.restore_error = tostring(err)
                M.diagnostic("Client restore failed: " .. tostring(err))
            end
        end
        if not participant.released then
            local ok, err = pcall(tell, participant, "SceneZOI.Release", Protocol.pack(old.token))
            if not ok then M.diagnostic("Release delivery failed: " .. tostring(err)) end
        end
    end
    if session == old and Session.cleanup_complete(old)then
        finish_stop(old, old.stop_code)
    end
end

function M.stop(code)
    if code=='mod_unloaded'then Autosave.restore()end
    local old = session
    if not old then SceneVisuals.restore(); return end
    if old.stopping then request_release(old); return end
    -- Initialize all cleanup state before callbacks can acknowledge a release.
    old.stop_reason=code or 'ok'
    old.stop_origin=old.stop_origin or {source='framework',reason=old.stop_reason}
    old.stopping, old.stop_code, old.age, old.heartbeat = true, code or "ok", 0, 0
    SceneVisuals.restore() -- Presentation restoration retries independently while idle.
    pcall(inzoi.cli.execute,command('uimod.cfg_save','last_stop')..' value='..Protocol.pack(old.client,old.sequence,old.stop_code,old.node.id))
    notify(old, "session_ending", old.stop_code)
    publish(old.client, old.sequence, "exiting", old.stop_code)
    request_release(old)
end

local function publish_node(current, code)
    local packet = Protocol.pack(current.client, current.sequence, current.revision,
        current.node.id, current.last_navigation, code or "ok")
    if current.node_state == packet then return end
    local ok, message = inzoi.cli.execute(command("uimod.cfg_save", "navigation_state") .. " value=" .. packet)
    assert(ok, message or "Could not publish scene navigation")
    current.node_state = packet
end

local function prepare_packet(current, participant)
    return Protocol.pack(current.token, current.initiator, current.node.id, current.revision,
        current.subsystems:keep_body_unmerged(participant, current.node, require("SceneZOI.Binding").resolve(current.participants, current.node)) and 1 or 0, participant.role,
        Protocol.encode(Json.encode(Catalog.simulation(current.node,participant))))
end

local function begin(fields)
    -- Native data packs can finish mounting after this Lua mod's boot callback.
    -- Refresh before capturing a session; its library remains stable until Exit.
    require("SceneZOI.DataFiles").refresh()
    require("SceneZOI.ExpressionLibrary").refresh()
    require("SceneZOI.FacialPoseLibrary").refresh()
    require("SceneZOI.VoiceLibrary").refresh()
    Localization.refresh()
    Catalog.refresh()
    local client, sequence, _, initiator, node_id, roster = table.unpack(fields)
    assert(initiator and roster, "Scene entry needs an initiator and explicit role assignments")
    local addon=Addons.context(fields[8],fields)
    assert(addon or not Addons.has_pending(),'Another scene start is pending')
    local node = Catalog.get(node_id)
    if addon then assert(Search.allowed(Catalog.get_snapshot().nodes,node,addon.restrictions),'Scene is restricted for this session')end
    local furniture_id=fields[7]~='none'and fields[7]or nil
    assert((node.furniture~=nil)==(furniture_id~=nil),'Scene requires the matching furniture context')
    local furniture=furniture_id and Furniture.prepare(furniture_id,node)or nil
    local participants, participant_ids, seen, roles = {}, {}, {}, {}
    for assignment in roster:gmatch("[^+]+") do
        local role, id = assignment:match("^([%w_.-]+):(%d+)$")
        assert(role and node.participants[role] and not roles[role] and not seen[id], "Invalid or duplicate role assignment")
        local actor = assert(M.actors[id], "All participants must be loaded nearby")
        local participant = Native.capture(actor)
        participant.role = role
        Appearance.capture(participant)
        participants[#participants+1], participant_ids[#participant_ids+1] = participant, id
        roles[role], seen[id] = true, true
    end
    assert(seen[initiator], "Scene initiator must belong to the fixed roster")
    require("SceneZOI.Binding").resolve(participants, node)
    local assets, duration = Catalog.load(node)
    local loaded_subsystems = Subsystems.load(node, duration)
    serial = serial + 1
    local current = Session.new({
        token = client .. "." .. sequence .. "." .. serial, client = client, sequence = sequence,
        initiator = initiator, participant_ids = participant_ids, participants = participants,
        assets = assets, node = node, duration = duration, require_resolved_outfit = true,furniture=furniture,anchor=furniture and furniture.anchor,
    })
    current.tasks = Tasks.new((Catalog.get_snapshot().tasks or {}).definitions or {}, participants)
    for _,person in ipairs(participants) do
        person.task_name = person.outfit_name and Protocol.decode(person.outfit_name) or person.id
    end
    current.subsystems = Subsystems.new(current, loaded_subsystems)
    if furniture then
        current.furniture_owner=participants[1]
        for _,participant in ipairs(participants)do if participant.id==initiator then current.furniture_owner=participant end end
    end
    if addon then
        current.addon_id,current.addon_client_id,current.request_id=addon.req.addon_id,addon.req.client_id,addon.req.request_id
        current.addon_context=require('SceneZOI.DataValidation').copy(addon.context)
        current.session_restrictions=require('SceneZOI.DataValidation').copy(addon.restrictions)
    end
    session = current
    Addons.created(addon,current)
    if Catalog.publish then Catalog.publish(current)end
    Autosave.acquire(current.token)
    publish(client, sequence, "preparing", "ok")
    notify(current, "session_preparing")
    M.diagnostic("Preparing " .. current.token)
    for _,participant in ipairs(participants)do tell(participant,'SceneZOI.Prepare',prepare_packet(current,participant))end
end
function M.furniture_reply(actor,fields)
    local c=session
    if not c or not c.furniture or fields[1]~=c.token or fields[2]~=c.furniture.id or actor~=c.furniture_owner.actor then return end
    if c.stopping then if fields[3]=='released'then c.furniture_released=true end;return end
    if fields[3]~='held'then M.stop('furniture_unavailable');return end
    if not c.furniture_ready then
        c.furniture_ready=true
        for _,p in ipairs(c.participants)do tell(p,'SceneZOI.Commit',Protocol.pack(c.token))end
    end
end

local function start_playback()
    local current = session
    Playback.enter(current)
    current.preparing = false
    for _, participant in ipairs(current.participants) do
        local location, rotation = participant.actor:K2_GetActorLocation(), participant.actor:K2_GetActorRotation()
        tell(participant, "SceneZOI.Anchor", Protocol.pack(current.token,
            location.X, location.Y, location.Z, rotation.Pitch, rotation.Yaw, rotation.Roll))
    end
    current.age = 0
    current.clock:reset_node()
    if not current.started then current.started = true; notify(current, "session_started") end
    Control.enter(current)
    notify(current, "node_entered")
    publish_node(current)
    publish(current.client, current.sequence, "playing", "ok")
    M.diagnostic("Playing " .. current.token .. " node=" .. current.node.id .. " revision=" .. current.revision)
end

function M.register(actor)
    local id = Protocol.id(actor:GetEntityId())
    registrations=registrations+1;last_registered_id=id
    -- A binding can begin before the native actor has its entity ID.
    local value=tonumber(id)
    if not value or value<0 then deferred_registrations=deferred_registrations+1;return nil end
    M.actors[id] = actor
    registered_actor_ids[actor]=id
    return id
end

function M.unregister(actor)
    -- Teardown may already have reset GetEntityId() to Invalid.
    local id = registered_actor_ids[actor] or Protocol.id(actor:GetEntityId())
    registered_actor_ids[actor]=nil
    unregistrations=unregistrations+1;last_unregistered_id=id
    if M.actors[id] ~= actor then non_owner_unregistrations=non_owner_unregistrations+1 end
    if session then
        for _, participant in ipairs(session.participants) do
            if participant.actor == actor then M.stop("participant_unloaded"); break end
        end
    end
    -- A late on_end from an older object must not remove its replacement.
    if M.actors[id] == actor then M.actors[id] = nil end
end

-- Capture only when requested, not every tick or lifecycle callback.
function M.publish_actor_registration_status(requested_id)
    local ids={}
    for id in pairs(M.actors) do ids[#ids+1]=id end
    table.sort(ids)
    local count=#ids
    local equivalent
    for _,id in ipairs(ids) do
        if id~=requested_id and tonumber(id)==tonumber(requested_id) then equivalent=id;break end
    end
    while #ids>64 do table.remove(ids) end
    local identities={}
    for _,id in ipairs(ids) do
        local ok,current_id=pcall(function()return Protocol.id(M.actors[id]:GetEntityId())end)
        identities[#identities+1]={registered_id=id,current_id=ok and current_id or 'unavailable'}
    end
    local value={runtime_build=Config.build,requested_id=requested_id,
        actor_identities=Json.array(identities),deferred_register_calls=deferred_registrations,
        requested_registered=M.actors[requested_id]~=nil,registered_count=count,
        registered_ids=Json.array(ids),equivalent_numeric_id=equivalent,
        register_calls=registrations,unregister_calls=unregistrations,
        non_owner_unregister_calls=non_owner_unregistrations,
        last_registered_id=last_registered_id,last_unregistered_id=last_unregistered_id}
    local ok,message=inzoi.cli.execute(command('uimod.cfg_save','actor_registration')..' value='..Protocol.encode(Json.encode(value)))
    assert(ok,message)
    return value
end

function M.save_reply(actor,content)
    local fields=Protocol.unpack(content)
    if fields then Save.offer(session,actor,fields)end
end

function M.reply(actor, content)
    local fields = Protocol.unpack(content)
    local current = session
    if not current or not fields or fields[1] ~= current.token then return end
    local kind, detail = fields[2], fields[3]
    if fields[5] and kind ~= "outfit" then M.diagnostic("Participant preparation failed: " .. fields[5]) end
    if current.stopping then
        if kind ~= "released" then return end
        for _, participant in ipairs(current.participants) do
            if participant.actor == actor then participant.released = true end
        end
        if detail ~= "ok" then current.stop_code = "restore_error" end
        if Session.cleanup_complete(current)then
            finish_stop(current, current.stop_code)
        end
        return
    end
    if kind == "outfit" then OutfitControl.receive(current, actor, fields); return end
    if current.outfit_change and kind == "ready" then return end
    if kind == "rejected" then M.stop(detail or "prepare_error"); return end
    if kind == "released" then M.stop(detail == "ok" and "interrupted" or detail); return end
    if kind ~= "ready" or not current.preparing or tonumber(fields[4]) ~= current.revision then return end
    for _, participant in ipairs(current.participants) do
        if participant.actor == actor then
            local body, control = detail:match("^(%a+):(%a+)$")
            assert(body and (control=="controlled" or control=="npc"), "Invalid participant identity reply")
            participant.body, participant.control, participant.node_ready = body, control, true
        end
    end
    if Session.all(current, "node_ready") then
        local ok = pcall(Session.bind, current)
        if not ok then M.stop("binding_error"); return end
        -- B2 readiness does not mean that B1 has finished loading/attaching the object.
        -- Keep the scene in Preparing; the B1 tick opens playback only after that barrier.
        current.participants_ready = true
    end
end

local function change_node(current, node, assets, duration, loaded_subsystems)
    assert(Search.allowed(Catalog.get_snapshot().nodes,node,current.session_restrictions),"Scene is restricted for this session")
    notify(current, "node_leaving")
    Playback.leave_node(current)
    local subsystems = Subsystems.new(current, loaded_subsystems)
    Session.change_node(current, node, assets, duration, subsystems)
    notify(current, "node_preparing")
    publish(current.client, current.sequence, "preparing", "ok")
    for _, participant in ipairs(current.participants) do tell(participant, "SceneZOI.Prepare", prepare_packet(current, participant)) end
end

local function route_event(current,route,name,code)
    current.event_index = (current.event_index or 0) + 1
    local snapshot = Session.snapshot(current)
    snapshot.event_index = current.event_index
    snapshot.task_route = require("SceneZOI.DataValidation").copy(route)
    Events.emit(name,snapshot,code)
end

local function route_completion(current,candidates)
    local route=TaskRoutes.select(current,candidates)
    if not route then return end
    local ok,node,assets,duration,loaded=pcall(function()
        local target=Catalog.task_destination(current.node,route,current)
        require("SceneZOI.Binding").resolve(current.participants,target)
        local clips,length=Catalog.load(target)
        return target,clips,length,Subsystems.load(target,length,current)
    end)
    if not ok then
        current.navigation_code="task_route_error"
        M.diagnostic("Task route unavailable: from="..route.source_node_id.." role="..route.participant_role..
            " task="..route.task_id.." target="..route.target.." cause="..tostring(node))
        route_event(current,route,"task_route_failed","task_route_error")
        publish_node(current,current.navigation_code)
        return
    end
    M.diagnostic("Task route selected: from="..route.source_node_id.." role="..route.participant_role..
        " participant="..route.participant_id.." task="..route.task_id.." target="..route.target)
    route_event(current,route,"task_route_selected")
    change_node(current,node,assets,duration,loaded)
end

local function finish_transition(current)
    if current.transition_finished then return true end
    current.transition_finished = true
    notify(current, "transition_completed")
    local ok, node, assets, duration, loaded = pcall(function()
        local target = Catalog.transition_destination(current.node,current)
        require("SceneZOI.Binding").resolve(current.participants, target)
        local clips, length = Catalog.load(target)
        return target, clips, length, Subsystems.load(target, length, current)
    end)
    if not ok then
        M.diagnostic("Transition destination failed: " .. tostring(node))
        M.stop("transition_destination_error")
        return false
    end
    change_node(current, node, assets, duration, loaded)
    return true
end

local function navigate(raw)
    local current = session
    local fields = Protocol.unpack(raw)
    if not current or current.stopping or not fields or fields[1] ~= current.client or
        fields[2] ~= current.sequence or fields[3] ~= "navigate" then return end
    local count, revision = tonumber(fields[4]), tonumber(fields[6])
    if not count or count % 1 ~= 0 or count <= 0 then return end
    -- No new action can overtake an in-flight node change. Retries wait for readiness.
    if current.preparing then return end
    if count <= current.last_navigation then publish_node(current, current.navigation_code); return end
    current.last_navigation = count
    if revision ~= current.revision then
        current.navigation_code = "stale_navigation"
        publish_node(current, current.navigation_code)
        return
    end
    if current.node.kind == "transition" then
        current.navigation_code = "navigation_locked"
        publish_node(current, current.navigation_code)
        return
    end
    -- Validate and load every target resource before touching current playback or outfits.
    local ok, node, assets, duration, loaded_subsystems = pcall(function()
        local target = Catalog.destination(current.node, fields[5],current)
        local clips, length = Catalog.load(target)
        local loaded = Subsystems.load(target, length, current)
        return target, clips, length, loaded
    end)
    if not ok then
        current.navigation_code = "navigation_error"
        M.diagnostic("Navigation rejected: " .. tostring(node))
        publish_node(current, current.navigation_code)
        return
    end
    change_node(current, node, assets, duration, loaded_subsystems)
end

local function outfit_packet(current)
    local change = current.outfit_change
    return Protocol.pack(current.token, change.counter, change.item, change.enabled, current.revision,
        current.subsystems:keep_body_unmerged(change.participant, current.node, current.bindings) and 1 or 0)
end

local function begin_outfit(current,change)
    current.internal_outfit_counter=math.max(current.internal_outfit_counter or 0,change.participant.outfit_counter or 0)+1
    change.counter=current.internal_outfit_counter
    current.outfit_change, current.preparing, current.age, current.appearance_frames = change, true, 0, 0
    current.appearance_wait, current.preparation_stage, current.outfit_code = nil, nil, "ok"
    for _, participant in ipairs(current.participants) do participant.between_nodes = true end
    current.subsystems:begin_outfit(change)
    notify(current, "outfit_changing")
    publish(current.client, current.sequence, "preparing", "ok")
    tell(change.participant, "SceneZOI.Outfit", outfit_packet(current))
end
local function outfit_request(raw)
    local current = session
    if not current or current.stopping then return end
    local change = OutfitControl.request(current, raw)
    if not change then return end
    if change.error then
        current.acknowledged_outfit, current.outfit_code = change.counter, change.error
        return
    end
    change.client_counter=change.counter
    Effects.player_outfit(current,change.participant.id,change.item,change.enabled=='1')
    begin_outfit(current,change)
end

local function finish_outfit(current)
    current.subsystems:enter()
    Playback.refresh_subsystem_tracks(current)
    current.acknowledged_outfit=current.outfit_change.client_counter or current.acknowledged_outfit
    current.outfit_code="ok"
    current.outfit_change, current.preparing, current.age = nil, false, 0
    -- The same node resumes at its held time; no new node, anchor or snapshot.
    for _, participant in ipairs(current.participants) do participant.between_nodes = false end
    notify(current, "outfit_changed")
    publish(current.client, current.sequence, "playing", "ok")
end

local function poll()
    -- Cleanup finishing is too early for input focus: wait for the DOM close acknowledgement.
    local focus_raw = read("focus")
    local focus = Protocol.unpack(focus_raw)
    if not session and focus_raw ~= last_focus and focus then
        local actor
        if focus[3] == "closed" then
            local ended = completed[focus[1] .. "|" .. focus[2]]
            actor = ended and ended.actor
        elseif focus[3] == "rejected" and focus[4] then
            local key = focus[5]
            local candidate = key and rejected_focus[key]
            if candidate and Protocol.id(candidate:GetEntityId()) == focus[4] then actor = candidate; rejected_focus[key] = nil end
        end
        if actor then pending_focus, last_focus = {actor = actor, age = 0,client=focus[1],sequence=focus[2]}, focus_raw end
    end
    -- A heartbeat can never replace Start or Exit: it has its own mailbox.
    local heartbeat = Protocol.unpack(read("heartbeat"))
    if session and heartbeat and heartbeat[1] == session.client and heartbeat[2] == session.sequence then
        -- Config persists: an unchanged old heartbeat must not keep a disconnected UI alive.
        if heartbeat[4] ~= session.last_heartbeat then
            session.last_heartbeat, session.ui_age = heartbeat[4], 0
        end
    end
    local raw = read("request")
    if not raw or raw == boot_request then return end
    local fields = Protocol.unpack(raw)
    if not fields or #fields < 3 then return end
    local client, sequence, action = fields[1], fields[2], fields[3]
    local previous = completed[client .. "|" .. sequence]
    if previous then
        if not session or client==session.client and sequence==session.sequence then publish(client,sequence,previous.phase,previous.code)end
        return
    end
    if session then
        if client ~= session.client or sequence ~= session.sequence then
            if action == "start" then
                remember(client,sequence,"error","busy",nil,true)
                pcall(require('SceneZOI.Localization').toast,'A SceneZOI scene is already in progress. End it before starting another.')
            end
            return
        end
        if action == "exit" or action == "save" then M.stop(action=="save"and "saving"or "ok")
        else
            playback_request(read("playback"))
            outfit_request(read("outfit"))
            Settings.request(session,"task_rates",read("settings_task_rates"))
            Settings.request(session,"audio",read("settings_audio"))
            Personality.request(session,read("personality"))
            VoicePersonality.request(session,read("voice"))
            navigate(read("navigation"))
        end
        return
    end
    if action == "start" then
        if Save.busy()or Autosave.busy()then remember(client,sequence,"error","restore_pending");return end
        local ok, err = pcall(begin, fields)
        if not ok then
            Addons.fail_start(fields[8],err)
            M.diagnostic("Entry failed: " .. tostring(err))
            if session then M.stop("entry_error")
            else remember(client, sequence, "error", "entry_error") end
        end
    elseif action == "exit" or action == "save" then
        -- An Exit arriving before Start also retires this request ID.
        remember(client, sequence, "idle", "ok")
    end
end

function M.boot()
    Localization.refresh()
    Settings.boot()
    Addons.boot()
    Autosave.boot()
    Save.boot()
    -- Persisted Start/Exit packets belong to the previous runtime, not a new session.
    boot_request = read("request")
    last_focus = read("focus")
    publish("none", 0, "idle", "ok")
    inzoi.cli.execute(command("uimod.cfg_save", "runtime_build") .. " value=" .. Config.build .. "")
    M.diagnostic("Runtime ready")
end

local function update(dt)
    dt = Clock.delta(dt)
    if not session then Localization.tick(dt)end
    poll_elapsed = poll_elapsed + dt
    if poll_elapsed >= Config.poll_interval then
        poll_elapsed=0;Autosave.tick(session~=nil);Save.tick(M.actors,session~=nil);poll()
    end
    local mode=ModeGuard.update(dt,session~=nil or pending_focus~=nil)
    if session and not session.stopping and mode.editor then M.stop('character_editor')end
    if pending_focus then
        pending_focus.age = pending_focus.age + dt
        -- Let the UI click dispatch settle; never steal focus from a newly opened scene.
        if session then pending_focus = nil
        elseif pending_focus.age >= 0.1 and (not pending_focus.checked_at or pending_focus.age-pending_focus.checked_at>=Config.poll_interval) then
            pending_focus.checked_at=pending_focus.age
            local allowed,context=ModeGuard.can_restore_input()
            local reason=not context.known and 'lookup_pending' or context.editor and 'character_editor' or context.blocked and 'modal_ui' or 'gameplay'
            if not allowed and pending_focus.deferred_reason~=reason then
                pending_focus.deferred_reason=reason
                pcall(inzoi.cli.execute,command('uimod.cfg_save','input_restore')..' value='..Protocol.pack(pending_focus.client,pending_focus.sequence,'deferred',reason))
            end
            if allowed then
                local actor = ControllerRange.focus_actor(M.actors,pending_focus.actor)
                local finished=pending_focus
                pending_focus = nil
                local ok, err = true,nil
                if actor then ok,err=pcall(Native.release_input,actor)end
                pcall(inzoi.cli.execute,command('uimod.cfg_save','input_restore')..' value='..Protocol.pack(finished.client,finished.sequence,not ok and 'failed' or actor and 'restored' or 'no_actor',reason))
                if not ok then M.diagnostic("Input restore failed: " .. tostring(err)) end
            end
        end
    end
    Effects.idle()
    Control.tick(dt,session,function(key)if session then Effects.release(session,key)end end)
    local current = session
    if not current then return end
    current.age, current.heartbeat = current.age + dt, current.heartbeat + dt
    if current.stopping then
        if current.age > Config.prepare_timeout then finish_stop(current, "restore_timeout")
        elseif current.heartbeat >= Config.heartbeat_interval then
            current.heartbeat = 0
            request_release(current)
        end
        return
    end
    if not current.save_committed and Save.ready(current)then
        current.save_committed=true
        if current.furniture and current.save_ready then
            tell(current.furniture_owner,'SceneZOI.Furniture',Protocol.pack(current.token,current.furniture.id,'acquire',Protocol.encode(Json.encode(current.furniture.profile))))
        else for _,p in ipairs(current.participants)do tell(p,'SceneZOI.Commit',Protocol.pack(current.token))end end
    end
    if session~=current or current.stopping then return end
    local too_far,distance,controlled_id=ControllerRange.update(current,M.actors,dt)
    current.controller_range_diagnostic_age=(current.controller_range_diagnostic_age or 0)+dt
    if current.controller_range_status and (not current.controller_range_reported or current.controller_range_diagnostic_age>=1 or too_far)then
        pcall(inzoi.cli.execute,command('uimod.cfg_save','controller_range')..' value='..Protocol.encode(Json.encode(current.controller_range_status)))
        current.controller_range_reported=true;current.controller_range_diagnostic_age=0
    end
    if too_far then
        M.diagnostic('Automatic exit: controlled='..controlled_id..' distance_cm='..string.format('%.1f',distance))
        M.stop('controller_too_far');return
    end
    if current.furniture then
        local valid,detail=Furniture.valid(current.furniture)
        if not valid then M.diagnostic('Furniture changed: '..tostring(detail));M.stop('furniture_changed');return end
    end
    current.subsystems:guard()
    current.ui_age = current.ui_age + dt
    if current.ui_age > Config.lease_timeout then M.stop("ui_disconnected"); return end
    if current.preparing and current.age > Config.prepare_timeout then
        local code = current.outfit_change and "outfit_timeout" or not current.participants_ready and "prepare_timeout"
            or current.preparation_stage == "attachment" and "attachment_timeout" or "appearance_timeout"
        local change = current.outfit_change
        local operation = change and (" outfit=" .. change.participant.id .. ":" .. change.item .. ":enabled=" .. change.enabled ..
            ":count=" .. change.counter .. ":ack=" .. tostring(change.acknowledged)) or ""
        M.diagnostic("Preparation failed: node=" .. current.node.id .. " stage=" .. code .. operation .. " " .. Appearance.status(current))
        M.stop(code)
        return
    end
    if current.heartbeat >= Config.heartbeat_interval then
        current.heartbeat = 0
        if current.preparing then
            M.diagnostic("Preparing " .. current.token .. " node=" .. current.node.id .. " " .. Appearance.status(current) .. " " .. current.subsystems:status())
        else
            M.diagnostic("Playing " .. current.token .. " " .. current.subsystems:status())
        end
        if current.furniture and current.save_ready then
            tell(current.furniture_owner,'SceneZOI.Furniture',Protocol.pack(current.token,current.furniture.id,
                current.furniture_ready and 'heartbeat'or'acquire',Protocol.encode(Json.encode(current.furniture.profile))))
        end
        for _, participant in ipairs(current.participants) do
            local kind = current.preparing and not current.outfit_change and "SceneZOI.Prepare" or "SceneZOI.Heartbeat"
            tell(participant,kind,prepare_packet(current,participant))
            if current.save_ready and (not current.furniture or current.furniture_ready)and not participant.node_ready then
                tell(participant,'SceneZOI.Commit',Protocol.pack(current.token))
            end
            if current.outfit_change and current.outfit_change.participant == participant then
                tell(participant, "SceneZOI.Outfit", outfit_packet(current))
            end
        end
    end
    local game_scale = Clock.game_scale()
    local previous_scale = current.clock.scale
    current.clock:advance(0, game_scale)
    if previous_scale ~= game_scale then notify(current, "game_clock_changed") end
    local pose_ready = true
    if current.preparing and current.started then pose_ready = Playback.hold(current) end
    if current.preparing and current.participants_ready and (not current.outfit_change or current.outfit_change.acknowledged) then
        if pose_ready and Appearance.ready(current) then
            current.preparation_stage = "attachment"
            local resources_ready = current.subsystems:prepare(current)
            -- Body-region preparation can itself rebuild appearance. Reapply the
            -- held pose after that mutation, and wait if no instance exists yet.
            if current.started then pose_ready = Playback.hold(current) end
            if resources_ready and pose_ready then
                if current.outfit_change then finish_outfit(current) else start_playback() end
            end
        else current.preparation_stage = "appearance" end
    end
    Effects.tick(current,dt,function(p,item,enabled)
        begin_outfit(current,{participant=p,item=item,piece=p.outfit_items[item],enabled=enabled and '1'or '0',acknowledged=false})
    end)
    if not current.preparing then
        Control.sample(current,dt,game_scale)
        current.clock:advance(dt, game_scale, CompletionEffects.multiplier(current.completion_effects,dt,game_scale)*Control.speed(current))
        Playback.sample(current, current.clock:position(current.duration, current.node.kind))
        local completion_routes,completion_payloads={},{}
        if current.tasks then Tasks.update(current.tasks, current, dt * game_scale, function(payload)
            completion_payloads[#completion_payloads+1]=payload
            local candidate=TaskRoutes.candidate(current,payload)
            if candidate then completion_routes[#completion_routes+1]=candidate end
            current.event_index = (current.event_index or 0) + 1
            local snapshot = Session.snapshot(current)
            snapshot.event_index = current.event_index
            snapshot.task, snapshot.participant_id, snapshot.participant_role = payload.task, payload.participant_id, payload.participant_role
                    Events.emit("task_completed", snapshot)
            require("SceneZOI.TaskActions").trigger(current.task_actions, payload)
        end) end
        require('SceneZOI.VoiceResponses').trigger(current.voice_responses,completion_payloads)
        -- Resolve one route only after every participant's completion/event/action is committed.
        if TaskRoutes.select(current,completion_routes) then
            route_completion(current,completion_routes)
        else
            CompletionEffects.trigger(current.completion_effects,completion_payloads)
        end
        if current.clock:finished(current.duration, current.node.kind) then
            if not finish_transition(current) then return end
        end
    end
    publish_playback(current)
    OutfitControl.publish(current)
    Settings.publish(current)
    Personality.publish(current)
    VoicePersonality.publish(current)
    if current.tasks then
        current.task_publish_age = (current.task_publish_age or 0) + dt
        if current.task_publish_age >= 0.1 then
            current.task_publish_age = 0
            local data = Json.encode({rows=Json.array(Tasks.snapshot(current.tasks,current))})
            local versioned = current.revision .. "|" .. data
            if current.last_task_payload ~= versioned then
                current.task_frame = (current.task_frame or 0) + 1
                local packet = Protocol.pack(current.client, current.sequence, current.revision, current.task_frame, Protocol.encode(data))
                local ok, saved = pcall(inzoi.cli.execute, command("uimod.cfg_save", "task_state") .. " value=" .. packet)
                if ok and saved then current.last_task_payload = versioned end
            end
        end
    end
end

---@param dt number
function M.tick(dt)
    local ok, err = pcall(update, dt)
    if not ok then
        M.diagnostic("Runtime update failed: " .. tostring(err))
        local old = session
        local restored, restore_err = pcall(M.stop, "runtime_error")
        if not restored then
            M.diagnostic("Emergency cleanup failed: " .. tostring(restore_err))
            if old then finish_stop(old, "restore_error") end
        end
    end
    local visual_members={}
    if session then for _,person in ipairs(session.participants)do visual_members[person.id]=true end end
    local visual_active=session~=nil and not session.stopping
    local visual_ok, visual_status=pcall(SceneVisuals.tick,M.actors,visual_active,visual_members)
    if visual_ok then
        local packet=Protocol.encode(Json.encode(visual_status))
        if packet~=M.visual_status then
            local saved,save_ok=pcall(inzoi.cli.execute,command('uimod.cfg_save','overhead_visuals')..' value='..packet)
            if saved and save_ok then M.visual_status=packet end
            -- Retain the last active sample after Exit so a failed visual trial is inspectable.
            if visual_active then pcall(inzoi.cli.execute,command('uimod.cfg_save','overhead_visuals_active')..' value='..packet)end
        end
    end
    Events.flush()
end

function M.authorize_rejected_focus(actor, token)
    rejected_focus[token] = actor
end

function M.flush_notifications() Events.flush() end

function M.is_addon_owner(addon_id,client_id,id)
    return session and session.token==id and session.addon_id==addon_id and session.addon_client_id==client_id or false
end
function M.navigate_to(id,scene_id)
    local current=assert(session and session.token==id and session,'session_not_found')
    assert(not current.stopping and not current.preparing,'session_not_ready')
    assert(current.node.kind~='transition','navigation_locked')
    local target=Catalog.get(scene_id,current)
    assert(require('SceneZOI.DataValidation').equal(target.furniture,current.node.furniture),'incompatible_furniture')
    require('SceneZOI.Binding').resolve(current.participants,target)
    local clips,length=Catalog.load(target)
    local loaded=Subsystems.load(target,length,current)
    change_node(current,target,clips,length,loaded)
    return {accepted=true,scene_id=scene_id}
end

function M.api_control_event(req)
    if not session then return end
    session.event_index=(session.event_index or 0)+1
    local snapshot=Session.snapshot(session)
    snapshot.integration={addon_id=req.addon_id,client_id=req.client_id,operation=req.operation}
    Events.emit('addon_control_changed',snapshot)
end
function M.api_session(id)
    return assert(type(id)=='string'and session and session.token==id and session,'session_not_found')
end
function M.release_integration(key)
    if session then Effects.release(session,key)end
    Control.release(session,key)
end
function M.api_speed(current,index)
    if current.clock:select(index)then notify(current,'playback_speed_changed')end
    publish_playback(current)
end
function M.api_navigation(current)
    local rows=Json.array({})
    if current.node.kind=='transition'then return {navigation=rows,locked=true}end
    for _,edge in ipairs(current.node.navigation)do
        local ok,target=pcall(Catalog.get,edge.target,current)
        if ok and require('SceneZOI.DataValidation').equal(target.furniture,current.node.furniture)and pcall(require('SceneZOI.Binding').resolve,current.participants,target)then rows[#rows+1]=require('SceneZOI.DataValidation').copy(edge)end
    end
    return {navigation=rows,locked=current.preparing or current.stopping}
end
function M.is_active()return session~=nil end

function M.snapshot()
    return session and Session.snapshot(session) or nil
end

return M
