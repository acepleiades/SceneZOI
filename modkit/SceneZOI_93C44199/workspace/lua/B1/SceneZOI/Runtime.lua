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
local Controller=require('SceneZOI.Controller')
local Save=require('SceneZOI.SaveBridge')
local Autosave=require('SceneZOI.Autosave')
local Addons=require('SceneZOI.AddonAPI')
local Search=require('SceneZOI.SceneSearch')
local SceneVisuals=require('SceneZOI.SceneVisuals')
local Control=require('SceneZOI.AddonControl')
local Effects=require('SceneZOI.AddonEffects')
local ModeGuard=require('SceneZOI.ModeGuard')
local Sessions=require('SceneZOI.Sessions')
local Plan = require("SceneZOI.Plan")
local serial = 0
local poll_elapsed = 0
local state_value
local boot_request, last_save_request
local direct_serial, focus_serial = 0, 0
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

-- Only the session the controls are bound to writes the controls' mailboxes.
local function has_panel(current) return Sessions.focused() == current end

local function publish_phase(current, phase, code)
    if has_panel(current) then publish(current.client, current.sequence, phase, code) end
end

local function phase_of(current)
    return current.stopping and "exiting" or current.preparing and "preparing" or "playing"
end

-- Tells the controls which session they now show; the panel follows the controlled Zoi.
local function publish_focus()
    focus_serial = focus_serial + 1
    local current = Sessions.focused()
    local value = current and Protocol.pack(focus_serial, current.token, current.client, current.sequence,
        current.revision, current.node.id, phase_of(current)) or Protocol.pack(focus_serial, "none")
    pcall(inzoi.cli.execute, command("uimod.cfg_save", "focus_session") .. " value=" .. value)
end

local function publish_playback(current)
    if not has_panel(current) then return end
    local clock = current.clock
    local packet = Protocol.pack(current.client, current.sequence, current.last_speed_command, clock.index,
        string.format("%.4f", clock.scale), string.format("%.4f", clock.effective))
    if current.playback_state == packet then return end
    local ok, message = inzoi.cli.execute(command("uimod.cfg_save", "playback_state") .. " value=" .. packet)
    if ok then current.playback_state = packet
    else M.diagnostic("Playback status will retry: " .. tostring(message)) end
end

local function playback_request(raw)
    local current = Sessions.focused()
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

-- Only the scene with the controlled Zoi may hold the single global autosave suspension.
local function reconcile_autosave()
    local focused = Sessions.focused()
    if focused and not focused.stopping then
        local ok, err = pcall(Autosave.transfer, focused.token)
        if not ok then M.diagnostic("Autosave suspension failed: " .. tostring(err)) end
    else
        Autosave.restore() -- Independent retries continue while idle if the setting write fails.
    end
end

-- What this session's cleanup could not confirm stays in the journal for later recovery.
local function retain_unconfirmed(old)
    local unconfirmed = {}
    for _, participant in ipairs(old.participants) do
        if not participant.released then unconfirmed[#unconfirmed + 1] = participant.id end
    end
    for _, participant in ipairs(old.unloaded or {}) do
        if participant.restoration == "deferred_recovery" then unconfirmed[#unconfirmed + 1] = participant.id end
    end
    pcall(Save.finish, old.token, unconfirmed, old.furniture ~= nil and not old.furniture_released)
    return #unconfirmed == 0
end

local function finish_stop(old, code)
    if not Sessions.has(old) then return end
    local had_panel = has_panel(old)
    Sessions.remove(old)
    if had_panel and Catalog.publish then pcall(Catalog.publish)end
    reconcile_autosave()
    code = code or "ok"
    old.ended = true
    old.cleanup_code=code
    local confirmed = retain_unconfirmed(old)
    old.cleanup_complete=Session.cleanup_complete(old) and confirmed
    Effects.retain(old)
    notify(old, "session_ended", code)
    Control.ended(old,Session.snapshot(old))
    local controlled = Session.controlled(old)
    local normal = {ok = true, saving = true, character_editor = true, addon_requested = true, lifetime_expired = true, owner_expired = true}
    -- A scene with no panel still retires its request ID, silently.
    remember(old.client, old.sequence, normal[code] and "idle" or "error", code, controlled and controlled.actor, not had_panel)
    if had_panel then
        pcall(inzoi.cli.execute,command('uimod.cfg_save','last_exit')..' value='..Protocol.pack(old.client,old.sequence,code,old.stop_code))
        publish_focus()
        if code=='saving'then
            pcall(require('SceneZOI.Localization').toast,'SceneZOI ended because the game is saving.')
        end
    end
    M.diagnostic("Ended " .. old.token .. ": " .. code)
end

-- Only an ordinary end may leave Zois where the scene put them; anything else uses the original snapshot.
local function stays_in_place(old)
    return old.exit_policy == "stay" and (old.stop_code == "ok" or old.stop_code == "addon_requested" or old.stop_code == "lifetime_expired")
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
    local stay = stays_in_place(old)
    for _, participant in ipairs(old.participants) do
        participant.keep_position = stay
        if not participant.client_restored then
            local ok, err = pcall(Native.restore, participant)
            participant.client_restored = ok
            if not ok and participant.restore_error ~= tostring(err) then
                participant.restore_error = tostring(err)
                M.diagnostic("Client restore failed: " .. tostring(err))
            end
        end
        if not participant.released then
            local ok, err = pcall(tell, participant, "SceneZOI.Release", Protocol.pack(old.token, stay and "stay" or "restore"))
            if not ok then M.diagnostic("Release delivery failed: " .. tostring(err)) end
        end
    end
    if Sessions.has(old) and Session.cleanup_complete(old)then
        finish_stop(old, old.stop_code)
    end
end

local function stop_session(old, code)
    if old.stopping then request_release(old); return end
    -- Initialize all cleanup state before callbacks can acknowledge a release.
    old.stop_reason=code or 'ok'
    old.stop_origin=old.stop_origin or {source='framework',reason=old.stop_reason}
    old.stopping, old.stop_code, old.age, old.heartbeat = true, code or "ok", 0, 0
    reconcile_autosave()
    if has_panel(old) then
        pcall(inzoi.cli.execute,command('uimod.cfg_save','last_stop')..' value='..Protocol.pack(old.client,old.sequence,old.stop_code,old.node.id))
    end
    notify(old, "session_ending", old.stop_code)
    publish_phase(old, "exiting", old.stop_code)
    request_release(old)
end

-- With a token: that session. Without one: the session the controls show.
function M.stop(code, token)
    if token then
        local target = Sessions.get(token)
        if target then stop_session(target, code) end
        return
    end
    if code=='mod_unloaded'then Autosave.restore()end
    if code=='mod_unloaded'or code=='saving'then
        for _,current in ipairs(Sessions.list())do stop_session(current,code)end
        if code=='mod_unloaded'then SceneVisuals.restore()end
        return
    end
    local old = Sessions.focused()
    if old then stop_session(old, code) end
end

local function publish_node(current, code)
    if not has_panel(current) then return end
    local packet = Protocol.pack(current.client, current.sequence, current.revision,
        current.node.id, current.last_navigation, code or "ok")
    if current.node_state == packet then return end
    local ok, message = inzoi.cli.execute(command("uimod.cfg_save", "navigation_state") .. " value=" .. packet)
    assert(ok, message or "Could not publish scene navigation")
    current.node_state = packet
end

local function publish_plan(current)
    if not has_panel(current) then return end
    local plan = current.plan
    local packet = plan and Protocol.pack(current.client, current.sequence, 1, plan.auto_mode and 1 or 0, plan.stage, plan.stage_count)
        or Protocol.pack(current.client, current.sequence, 0, 0, 0, 0)
    if current.plan_state == packet then return end
    pcall(inzoi.cli.execute, command("uimod.cfg_save", "plan_state") .. " value=" .. packet)
    current.plan_state = packet
end

local function prepare_packet(current, participant)
    return Protocol.pack(current.token, current.initiator, current.node.id, current.revision,
        current.subsystems:keep_body_unmerged(participant, current.node, require("SceneZOI.Binding").resolve(current.participants, current.node)) and 1 or 0, participant.role,
        Protocol.encode(Json.encode(Catalog.simulation(current.node,participant))))
end

local function refresh_libraries()
    -- Native data packs can finish mounting after this Lua mod's boot callback.
    -- Refresh before capturing a session; a library stays stable while any session runs.
    if Sessions.count() > 0 then return end
    require("SceneZOI.DataFiles").refresh()
    require("SceneZOI.ExpressionLibrary").refresh()
    require("SceneZOI.FacialPoseLibrary").refresh()
    require("SceneZOI.VoiceLibrary").refresh()
    Localization.refresh()
    Catalog.refresh()
end

local function create_session(client, sequence, initiator, node_id, roster, furniture_id, addon)
    local node = Catalog.get(node_id)
    if addon then assert(Search.allowed(Catalog.get_snapshot().nodes,node,addon.restrictions),'Scene is restricted for this session')end
    assert((node.furniture~=nil)==(furniture_id~=nil),'Scene requires the matching furniture context')
    local furniture=furniture_id and Furniture.prepare(furniture_id,node)or nil
    local participants, participant_ids, seen, roles = {}, {}, {}, {}
    for assignment in roster:gmatch("[^+]+") do
        local role, id = assignment:match("^([%w_.-]+):(%d+)$")
        assert(role and node.participants[role] and not roles[role] and not seen[id], "Invalid or duplicate role assignment")
        local holder = Sessions.holder(id)
        assert(not holder or (addon and holder == addon.token), "A participant is already in a scene")
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
    assert(not Save.overlaps(participant_ids, furniture_id), "restore_pending")
    if not addon then assert(Sessions.reserve(current.token, participant_ids, furniture_id)) end
    return current
end

-- A standing scene that would crowd another one moves to the nearest safe floor. Beds are simply busy.
local function plan_placement(current, must_fit)
    if current.furniture then return end
    local owner = current.participants[1]
    for _, participant in ipairs(current.participants) do
        if participant.role == current.node.anchor_participant then owner = participant end
    end
    local point = owner.actor:K2_GetActorLocation()
    if Sessions.spot_free(current.token, point, Config.standing_spacing_cm) then
        Sessions.claim_spot(current.token, point)
        return
    end
    current.placement_pending, current.placement_must_fit = true, must_fit
    local taken = {}
    for _, spot in ipairs(Sessions.spots(current.token)) do
        taken[#taken + 1] = string.format("%.1f,%.1f", spot.X, spot.Y)
    end
    tell(owner, "SceneZOI.Placement", Protocol.pack(current.token, Config.standing_spacing_cm,
        Protocol.encode(table.concat(taken, ";"))))
end

local function begin(fields)
    refresh_libraries()
    local client, sequence, _, initiator, node_id, roster = table.unpack(fields)
    assert(initiator and roster, "Scene entry needs an initiator and explicit role assignments")
    local addon=Addons.context(fields[8],fields)
    assert(addon or not Addons.has_pending(),'Another scene start is pending')
    local furniture_id=fields[7]~='none'and fields[7]or nil
    local current = create_session(client, sequence, initiator, node_id, roster, furniture_id, addon)
    Sessions.add(current)
    Sessions.focus(current)
    Addons.created(addon,current)
    if Catalog.publish then Catalog.publish(current)end
    Autosave.transfer(current.token)
    publish(client, sequence, "preparing", "ok")
    publish_focus()
    publish_plan(current)
    plan_placement(current, false)
    notify(current, "session_preparing")
    M.diagnostic("Preparing " .. current.token)
    for _,participant in ipairs(current.participants)do tell(participant,'SceneZOI.Prepare',prepare_packet(current,participant))end
end

-- Every start limit in one place: NPC-only scenes are capped, a player's own never are.
function M.npc_only_count()
    local count = 0
    for _, current in ipairs(Sessions.list()) do if current.npc_only then count = count + 1 end end
    return count
end

local function start_distance_ok(anchor, others, limit)
    local origin = anchor:K2_GetActorLocation()
    for _, actor in ipairs(others) do
        local point = actor:K2_GetActorLocation()
        local dx, dy, dz = point.X - origin.X, point.Y - origin.Y, point.Z - origin.Z
        if dx * dx + dy * dy + dz * dz > limit * limit then return false end
    end
    return true
end

-- Checked again just before playback: they may have drifted since the start was accepted.
local function participants_close(current)
    if not current.max_start_distance_cm then return true end
    local anchor, actors = current.participants[1].actor, {}
    for _, person in ipairs(current.participants) do
        actors[#actors + 1] = person.actor
        if person.role == current.node.anchor_participant then anchor = person.actor end
    end
    return start_distance_ok(anchor, actors, current.max_start_distance_cm)
end

function M.check_start_distance(node, bindings, limit)
    local anchor = assert(M.actors[bindings[node.anchor_participant]], "Participant is not loaded")
    local others = {}
    for _, id in pairs(bindings) do others[#others + 1] = assert(M.actors[id], "Participant is not loaded") end
    assert(start_distance_ok(anchor, others, limit), "participant_too_far")
end

-- A scene that does not need the panel: no UI round trip, and it can run beside the player's own.
function M.start_background(row)
    local npc_only = not row.has_household
    assert(not npc_only or M.npc_only_count() < Config.max_npc_sessions, "session_limit")
    refresh_libraries()
    local entry = row.entry
    local assignments = {}
    for role, id in pairs(entry.bindings) do assignments[#assignments + 1] = role .. ":" .. id end
    table.sort(assignments)
    direct_serial = direct_serial + 1
    local current = create_session("host", tostring(direct_serial), entry.initiator, entry.node,
        table.concat(assignments, "+"), entry.furniture, row)
    current.npc_only, current.lifetime, current.exit_policy = npc_only, row.lifetime, row.placement.exit
    if row.plan then current.plan = Plan.new(row.plan) end
    current.max_start_distance_cm = row.placement.max_start_distance_cm
    Sessions.add(current)
    Addons.created(row, current)
    plan_placement(current, true)
    notify(current, "session_preparing")
    M.diagnostic("Preparing background " .. current.token)
    for _,participant in ipairs(current.participants)do tell(participant,'SceneZOI.Prepare',prepare_packet(current,participant))end
    return current.token
end

function M.renew_session(id)
    local current = assert(Sessions.get(id), "session_not_found")
    current.lease_age = 0
end
function M.furniture_reply(actor,fields)
    local c=Sessions.get(fields[1])
    if not c or not c.furniture or fields[2]~=c.furniture.id or actor~=c.furniture_owner.actor then return end
    if c.stopping then if fields[3]=='released'then c.furniture_released=true end;return end
    if fields[3]~='held'then stop_session(c,'furniture_unavailable');return end
    if not c.furniture_ready then
        c.furniture_ready=true
        for _,p in ipairs(c.participants)do tell(p,'SceneZOI.Commit',Protocol.pack(c.token))end
    end
end

local function start_playback(current)
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
    publish_phase(current, "playing", "ok")
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

-- The actor is gone: stop touching it, and report honestly what is known about its restoration.
local function drop_unloaded(current, actor)
    for index, participant in ipairs(current.participants) do
        if participant.actor == actor then
            table.remove(current.participants, index)
            current.unloaded = current.unloaded or {}
            current.unloaded[#current.unloaded + 1] = participant
            participant.restoration = participant.released and "restored" or "deferred_recovery"
            return true
        end
    end
end

function M.unregister(actor)
    -- Teardown may already have reset GetEntityId() to Invalid.
    local id = registered_actor_ids[actor] or Protocol.id(actor:GetEntityId())
    registered_actor_ids[actor]=nil
    unregistrations=unregistrations+1;last_unregistered_id=id
    if M.actors[id] ~= actor then non_owner_unregistrations=non_owner_unregistrations+1 end
    for _, current in ipairs(Sessions.list()) do
        if drop_unloaded(current, actor) then stop_session(current, "participant_unloaded") end
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
    if fields then Save.offer(Sessions.get(fields[1]),actor,fields)end
end

function M.reply(actor, content)
    local fields = Protocol.unpack(content)
    if fields and fields[2] == "released_unloaded" then
        -- Relayed through the controlled Zoi: this participant's own client actor is gone.
        pcall(Save.resolve, fields[1], fields[3])
        local owner = Sessions.get(fields[1])
        for _, participant in ipairs(owner and owner.unloaded or {}) do
            if participant.id == fields[3] then participant.released, participant.restoration = true, "released_on_unload" end
        end
        return
    end
    local current = fields and Sessions.get(fields[1])
    if not current then return end
    local kind, detail = fields[2], fields[3]
    if kind == "placement" then
        if current.stopping or not current.placement_pending then return end
        current.placement_pending = nil
        local x, y, z = tonumber(fields[3]), tonumber(fields[4]), tonumber(fields[5])
        if x and y and z then
            current.spot = {X = x, Y = y, Z = z}
            Sessions.claim_spot(current.token, current.spot)
        elseif current.placement_must_fit then
            stop_session(current, "placement_unavailable")
        end
        return
    end
    if fields[5] and kind ~= "outfit" then M.diagnostic("Participant preparation failed: " .. fields[5]) end
    if current.stopping then
        if kind ~= "released" then return end
        for _, participant in ipairs(current.participants) do
            if participant.actor == actor then participant.released, participant.restoration = true, "restored" end
        end
        if detail ~= "ok" then current.stop_code = "restore_error" end
        if Session.cleanup_complete(current)then
            finish_stop(current, current.stop_code)
        end
        return
    end
    if kind == "outfit" then OutfitControl.receive(current, actor, fields); return end
    if current.outfit_change and kind == "ready" then return end
    if kind == "rejected" then stop_session(current, detail or "prepare_error"); return end
    if kind == "released" then stop_session(current, detail == "ok" and "interrupted" or detail); return end
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
        if not ok then stop_session(current, "binding_error"); return end
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
    publish_phase(current, "preparing", "ok")
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
        stop_session(current, "transition_destination_error")
        return false
    end
    change_node(current, node, assets, duration, loaded)
    return true
end

local function navigate(raw)
    local current = Sessions.focused()
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
    if current.node.kind == "transition" or Plan.locked(current) then
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
    publish_phase(current, "preparing", "ok")
    tell(change.participant, "SceneZOI.Outfit", outfit_packet(current))
end
local function outfit_request(raw)
    local current = Sessions.focused()
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
    publish_phase(current, "playing", "ok")
end

local function auto_mode_request(raw)
    local current = Sessions.focused()
    local fields = Protocol.unpack(raw)
    if not current or current.stopping or not fields or fields[1] ~= current.client or
        fields[2] ~= current.sequence or fields[3] ~= "auto_mode" then return end
    local count = tonumber(fields[4])
    if not count or count % 1 ~= 0 or count <= (current.last_auto_mode or 0) then return end
    current.last_auto_mode = count
    if Plan.set_auto(current, fields[5] == "1") then
        notify(current, "plan_auto_mode_changed")
        publish_plan(current)
    end
end

-- Every control carries its own session identity, so it can be read whatever the request mailbox holds.
local function apply_panel_controls(focused)
    playback_request(read("playback"))
    outfit_request(read("outfit"))
    Settings.request(focused,"task_rates",read("settings_task_rates"))
    Settings.request(focused,"audio",read("settings_audio"))
    Personality.request(focused,read("personality"))
    VoicePersonality.request(focused,read("voice"))
    navigate(read("navigation"))
    auto_mode_request(read("auto_mode"))
end

local function poll()
    -- Cleanup finishing is too early for input focus: wait for the DOM close acknowledgement.
    local focused = Sessions.focused()
    local focus_raw = read("focus")
    local focus = Protocol.unpack(focus_raw)
    if not focused and focus_raw ~= last_focus and focus then
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
    -- A save exits every scene, whether or not one has a panel.
    local save_request = read("save_request")
    if save_request and save_request ~= last_save_request then
        last_save_request = save_request
        for _, current in ipairs(Sessions.list()) do
            if not current.stopping then stop_session(current, "saving") end
        end
    end
    -- A heartbeat can never replace Start or Exit: it has its own mailbox.
    local heartbeat = Protocol.unpack(read("heartbeat"))
    if focused and heartbeat and heartbeat[1] == focused.client and heartbeat[2] == focused.sequence then
        -- Config persists: an unchanged old heartbeat must not keep a disconnected UI alive.
        if heartbeat[4] ~= focused.last_heartbeat then
            focused.last_heartbeat, focused.ui_age = heartbeat[4], 0
        end
    end
    local raw = read("request")
    local fields = raw ~= boot_request and Protocol.unpack(raw) or nil
    -- An add-on's start never wrote a Start packet, and a switch of control leaves another scene's there.
    local leaving = focused and fields and fields[1] == focused.client and fields[2] == focused.sequence and
        (fields[3] == "exit" or fields[3] == "save")
    if focused and not leaving then apply_panel_controls(focused) end
    if not raw or raw == boot_request then return end
    if not fields or #fields < 3 then return end
    local client, sequence, action = fields[1], fields[2], fields[3]
    local previous = completed[client .. "|" .. sequence]
    if previous then
        if not focused or client==focused.client and sequence==focused.sequence then publish(client,sequence,previous.phase,previous.code)end
        return
    end
    -- The mailbox keeps a scene's Start packet: while that scene is out of focus it is not a new request.
    for _, current in ipairs(Sessions.list()) do
        if current ~= focused and current.client == client and current.sequence == sequence then return end
    end
    if focused then
        if client ~= focused.client or sequence ~= focused.sequence then
            if action == "start" then
                remember(client,sequence,"error","busy",nil,true)
                pcall(require('SceneZOI.Localization').toast,'A SceneZOI scene is already in progress. End it before starting another.')
            end
            return
        end
        if action == "exit" or action == "save" then M.stop(action=="save"and "saving"or "ok") end
        return
    end
    if action == "start" then
        if Autosave.restoring()then remember(client,sequence,"error","restore_pending");return end
        local ok, err = pcall(begin, fields)
        if not ok then
            Addons.fail_start(fields[8],err)
            M.diagnostic("Entry failed: " .. tostring(err))
            if Sessions.focused() then M.stop("entry_error")
            else remember(client, sequence, "error", tostring(err):find("already in a scene", 1, true) and "busy" or "entry_error") end
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
    last_save_request = read("save_request")
    last_focus = read("focus")
    publish("none", 0, "idle", "ok")
    inzoi.cli.execute(command("uimod.cfg_save", "runtime_build") .. " value=" .. Config.build .. "")
    M.diagnostic("Runtime ready")
end

-- The controls follow the Zoi the player controls.
local function bind_panel(current)
    current.ui_age, current.unfocused_age = 0, 0
    state_value = nil
    current.playback_state, current.node_state, current.outfit_state = nil, nil, nil
    current.last_task_payload, current.personality_state, current.voice_state = nil, nil, nil
    Settings.forget(current)
    publish(current.client, current.sequence, phase_of(current), "ok")
    publish_node(current)
    publish_playback(current)
    current.plan_state = nil
    publish_plan(current)
    if Catalog.publish then pcall(Catalog.publish, current) end
end

local function update_focus()
    local known, id = pcall(Controller.controlled_id, M.actors)
    if not known or not id then return end -- An unknown lookup is not evidence of a switch.
    local target = Sessions.get(Sessions.holder(id))
    local old = Sessions.focused()
    if target == old then return end
    Sessions.focus(target)
    if old then old.unfocused_age = 0 end
    publish_focus()
    if target then bind_panel(target) elseif Catalog.publish then pcall(Catalog.publish) end
    reconcile_autosave()
end

-- Every scene that can run without a panel has a finite life.
local function background_limit_reached(current, dt)
    current.unfocused_age = (current.unfocused_age or 0) + dt
    if current.unfocused_age >= Config.background_max_seconds then return "lifetime_expired" end
    local lifetime = current.lifetime
    if not lifetime then
        return current.unfocused_age >= Config.manual_background_seconds and "lifetime_expired" or nil
    end
    if lifetime.deadline_seconds and current.unfocused_age >= lifetime.deadline_seconds then return "lifetime_expired" end
    if lifetime.lease_seconds then
        current.lease_age = (current.lease_age or 0) + dt
        if current.lease_age >= lifetime.lease_seconds then return "owner_expired" end
    end
end

local function update(dt)
    dt = Clock.delta(dt)
    local focused = Sessions.focused()
    if not focused then Localization.tick(dt)end
    poll_elapsed = poll_elapsed + dt
    if poll_elapsed >= Config.poll_interval then
        poll_elapsed=0;Autosave.tick(focused~=nil);Save.tick(M.actors);poll();update_focus()
    end
    local mode=ModeGuard.update(dt,Sessions.count()>0 or pending_focus~=nil)
    if mode.editor then
        for _,current in ipairs(Sessions.list())do if not current.stopping then stop_session(current,'character_editor')end end
    end
    if pending_focus then
        pending_focus.age = pending_focus.age + dt
        -- Let the UI click dispatch settle; never steal focus from a newly opened scene.
        if Sessions.focused() then pending_focus = nil
        elseif pending_focus.age >= 0.1 and (not pending_focus.checked_at or pending_focus.age-pending_focus.checked_at>=Config.poll_interval) then
            pending_focus.checked_at=pending_focus.age
            local allowed,context=ModeGuard.can_restore_input()
            local reason=not context.known and 'lookup_pending' or context.editor and 'character_editor' or context.blocked and 'modal_ui' or 'gameplay'
            if not allowed and pending_focus.deferred_reason~=reason then
                pending_focus.deferred_reason=reason
                pcall(inzoi.cli.execute,command('uimod.cfg_save','input_restore')..' value='..Protocol.pack(pending_focus.client,pending_focus.sequence,'deferred',reason))
            end
            if allowed then
                local actor = Controller.focus_actor(M.actors,pending_focus.actor)
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
    Control.tick(dt,Sessions.focused(),function(key)
        for _,current in ipairs(Sessions.list())do Effects.release(current,key)end
    end)
end

-- Carries out what a plan asked for. Every automatic move goes through the same validated handoff.
local function apply_plan(current, action)
    if action.event then notify(current, action.event); publish_plan(current) end
    if action.stop then stop_session(current, action.stop); return end
    if not action.navigate then return end
    local ok, node, assets, duration, loaded = pcall(function()
        local target = Catalog.destination(current.node, action.navigate, current)
        require("SceneZOI.Binding").resolve(current.participants, target)
        local clips, length = Catalog.load(target)
        return target, clips, length, Subsystems.load(target, length, current)
    end)
    if not ok then
        M.diagnostic("Automatic navigation failed: " .. tostring(node))
        current.plan.state, current.plan.outcome = "finished", "goal_unreachable"
        stop_session(current, "goal_unreachable")
        return
    end
    change_node(current, node, assets, duration, loaded)
end

local function advance(current, dt)
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
    if not Sessions.has(current) or current.stopping then return end
    if not has_panel(current) then
        local expired = background_limit_reached(current, dt)
        if expired then stop_session(current, expired); return end
    end
    if current.furniture then
        local valid,detail=Furniture.valid(current.furniture)
        if not valid then M.diagnostic('Furniture changed: '..tostring(detail));stop_session(current,'furniture_changed');return end
    end
    current.subsystems:guard()
    if has_panel(current) then
        current.ui_age = current.ui_age + dt
        if current.ui_age > Config.lease_timeout then stop_session(current, "ui_disconnected"); return end
    end
    if current.preparing and current.age > Config.prepare_timeout then
        local code = current.outfit_change and "outfit_timeout" or not current.participants_ready and "prepare_timeout"
            or current.preparation_stage == "attachment" and "attachment_timeout" or "appearance_timeout"
        local change = current.outfit_change
        local operation = change and (" outfit=" .. change.participant.id .. ":" .. change.item .. ":enabled=" .. change.enabled ..
            ":count=" .. change.counter .. ":ack=" .. tostring(change.acknowledged)) or ""
        M.diagnostic("Preparation failed: node=" .. current.node.id .. " stage=" .. code .. operation .. " " .. Appearance.status(current))
        stop_session(current, code)
        return
    end
    if current.heartbeat >= Config.heartbeat_interval then
        current.heartbeat = 0
        if current.preparing then
            M.diagnostic("Preparing " .. current.token .. " node=" .. current.node.id .. " " .. Appearance.status(current) .. " " .. current.subsystems:status())
        elseif has_panel(current) then
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
            if resources_ready and pose_ready and not current.placement_pending then
                if current.outfit_change then finish_outfit(current)
                elseif not current.started and not participants_close(current) then
                    stop_session(current, "participant_too_far")
                    return
                else start_playback(current) end
            end
        else current.preparation_stage = "appearance" end
    end
    Effects.tick(current,dt,function(p,item,enabled)
        begin_outfit(current,{participant=p,item=item,piece=p.outfit_items[item],enabled=enabled and '1'or '0',acknowledged=false})
    end)
    if not current.preparing then
        Control.sample(current,dt,game_scale)
        current.clock:advance(dt, game_scale, math.min(2, CompletionEffects.multiplier(current.completion_effects,dt,game_scale)*Control.speed(current)*Plan.speed(current)))
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
        local action = Plan.tick(current, dt, game_scale)
        if action then apply_plan(current, action) end
    end
    if not has_panel(current) then return end
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
    -- A failure in the shared poll must not end a scene, and one scene must not end another.
    local polled, poll_err = pcall(update, dt)
    if not polled then M.diagnostic("Runtime poll failed: " .. tostring(poll_err)) end
    local step = Clock.delta(dt)
    for _, current in ipairs(Sessions.list()) do
        local ok, err = pcall(advance, current, step)
        if not ok then
            M.diagnostic("Runtime update failed: " .. tostring(err))
            local restored, restore_err = pcall(stop_session, current, "runtime_error")
            if not restored then
                M.diagnostic("Emergency cleanup failed: " .. tostring(restore_err))
                finish_stop(current, "restore_error")
            end
        end
    end
    local visual_members,visual_active={},false
    for _,current in ipairs(Sessions.list())do
        if not current.stopping then
            visual_active=true
            for _,person in ipairs(current.participants)do visual_members[person.id]=true end
        end
    end
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
    local current=Sessions.get(id)
    return current and current.addon_id==addon_id and current.addon_client_id==client_id or false
end
function M.navigate_to(id,scene_id)
    local current=assert(Sessions.get(id),'session_not_found')
    assert(not current.stopping and not current.preparing,'session_not_ready')
    assert(current.node.kind~='transition'and not Plan.locked(current),'navigation_locked')
    local target=Catalog.get(scene_id,current)
    assert(require('SceneZOI.DataValidation').equal(target.furniture,current.node.furniture),'incompatible_furniture')
    require('SceneZOI.Binding').resolve(current.participants,target)
    local clips,length=Catalog.load(target)
    local loaded=Subsystems.load(target,length,current)
    change_node(current,target,clips,length,loaded)
    return {accepted=true,scene_id=scene_id}
end

function M.api_control_event(req)
    local focused=Sessions.focused()
    if not focused then return end
    focused.event_index=(focused.event_index or 0)+1
    local snapshot=Session.snapshot(focused)
    snapshot.integration={addon_id=req.addon_id,client_id=req.client_id,operation=req.operation}
    Events.emit('addon_control_changed',snapshot)
end
function M.set_auto_mode(id, enabled)
    local current = assert(Sessions.get(id), "session_not_found")
    assert(current.plan, "session_has_no_plan")
    assert(not current.stopping, "session_not_ready")
    if Plan.set_auto(current, enabled) then
        notify(current, "plan_auto_mode_changed")
        publish_plan(current)
    end
    return {auto_mode = current.plan.auto_mode}
end
function M.api_session(id)
    return assert(type(id)=='string'and Sessions.get(id),'session_not_found')
end
function M.release_integration(key)
    Control.release(Sessions.focused(),key)
    for _,current in ipairs(Sessions.list())do Effects.release(current,key);Control.release(current,key)end
end
function M.api_speed(current,index)
    if current.clock:select(index)then notify(current,'playback_speed_changed')end
    publish_playback(current)
end
function M.api_navigation(current)
    local rows=Json.array({})
    if current.node.kind=='transition'or Plan.locked(current)then return {navigation=rows,locked=true}end
    for _,edge in ipairs(current.node.navigation)do
        local ok,target=pcall(Catalog.get,edge.target,current)
        if ok and require('SceneZOI.DataValidation').equal(target.furniture,current.node.furniture)and pcall(require('SceneZOI.Binding').resolve,current.participants,target)then rows[#rows+1]=require('SceneZOI.DataValidation').copy(edge)end
    end
    return {navigation=rows,locked=current.preparing or current.stopping}
end
function M.is_active()return Sessions.focused()~=nil end
function M.any_active()return Sessions.count()>0 end

-- Without an ID: the session the controls show.
function M.snapshot(id)
    local current=Sessions.focused()
    if id then current=Sessions.get(id) end
    return current and Session.snapshot(current) or nil
end

function M.snapshots()
    local rows=Json.array({})
    for _,current in ipairs(Sessions.list())do rows[#rows+1]=Session.snapshot(current)end
    return rows
end

return M
