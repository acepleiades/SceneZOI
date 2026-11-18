local Config = require("SceneZOI.Config")
local Protocol = require("SceneZOI.Protocol")
local Outfit = require("SceneZOI.Outfit")
local Wardrobe = require("SceneZOI.Wardrobe")
local Json = require("SceneZOI.Json")
local SceneData = require("SceneZOI.SceneData")
local Binding = require("SceneZOI.Binding")
local Save=require("SceneZOI.SaveGuard")
local Recovery=require("SceneZOI.SaveRecovery")
local M = {}

local function renew_lease(lease, kind)
    lease.renewed_at = os.time()
    local timing = lease.lease_timing
    if not timing then
        timing = {prepare_received = 0, heartbeat_received = 0, commit_received = 0, tick_count = 0,
            total_tick_seconds = 0, since_renew_tick_seconds = 0, last_dt = 0, max_dt = 0, clock_rollbacks = 0}
        lease.lease_timing = timing
    end
    timing[kind] = timing[kind] + 1
    timing.since_renew_tick_seconds = 0
    timing.acquired_at = timing.acquired_at or lease.renewed_at
end

local function lease_expiry_detail(lease, now)
    -- No per-tick writes: send this bounded sample only if the watchdog fires.
    local ok, detail = pcall(function()
        local timing = lease.lease_timing or {}
        -- Compact names keep the complete sample within Diagnostics.detail's cap.
        return ("timeout:%.3f+elapsed:%.3f+prepares:%d+heartbeats:%d+ticks:%d+tick_total:%.3f" ..
            "+tick_since_renew:%.3f+last_dt:%.3f+max_dt:%.3f+age:%.3f+clock_rollbacks:%d"):format(
            Config.lease_timeout, now - lease.renewed_at, timing.prepare_received or 0,
            timing.heartbeat_received or 0, timing.tick_count or 0, timing.total_tick_seconds or 0,
            timing.since_renew_tick_seconds or 0, timing.last_dt or 0, timing.max_dt or 0,
            math.max(0, now - (timing.acquired_at or lease.renewed_at)), timing.clock_rollbacks or 0)
    end)
    return ok and detail or "lease_timing_unavailable"
end

local function send_reply(entity_id, packet, diagnostic)
    if diagnostic then packet = packet .. "|" .. tostring(diagnostic):gsub("[^%w_.:+%-]", "_"):sub(1, 1200) end
    inzoi.message.send_to_client(entity_id, "SceneZOI.Reply", packet)
end

local function reply(owner, token, kind, detail, revision, diagnostic)
    send_reply(owner:GetEntityId(), Protocol.pack(token, kind, detail or "ok", revision or 0), diagnostic)
end

local function reply_released(owner, token, stay_refused, cause, diagnostic)
    send_reply(owner:GetEntityId(), Protocol.pack(token, "released", "ok", stay_refused and 1 or 0, cause), diagnostic)
end

local function resolved_autonomy(owner)
    return inzoi.getB2Manager("FB2AutonomyOptionManager"):ResolveToggleOption(
        owner, inzoi.EB1AutonomyOptionType.AutonomyEnable)
end

local function set_autonomy(owner, value, follow_parent, lease)
    local option = owner.AutonomyOption.AutonomyEnable
    option.Value, option.bFollowParent = value, follow_parent
    owner:RefreshAutonomyOptionCache()
    local component = owner:GetComponent(inzoi.EB2ComponentType.Autonomy)
    -- Notify the resolved option, not the aggregate activity/eligibility query.
    -- It can remain true while the policy is disabled; feeding it back would
    -- notify the component to enable autonomy again.
    local enabled = resolved_autonomy(owner)
    if lease then lease.autonomy_requested, lease.autonomy_notified = value, enabled end
    component:OnAutonomyOptionChanged(enabled)
    component:SendAutonomyEnablePacket(enabled, false)
end

-- If this Zoi's client actor has unloaded, its own reply cannot arrive. Say so through the controlled Zoi.
local function relay_release(owner, token, cause, diagnostic)
    local ok, _, data = inzoi.cli.execute("entity.get_possessed")
    local controlled = ok and data and data:match('"entity_id"%s*:%s*"?(%d+)')
    local own = Protocol.id(owner:GetEntityId())
    if not controlled or controlled == own then return end
    local target = inzoi.FB1EntityId()
    target.Value = tonumber(controlled)
    send_reply(target, Protocol.pack(token, "released_unloaded", own, cause), diagnostic)
end

local function grab_state(posture, hand)
    if not posture or not posture:GetCurrentGrabObject(hand) then return end
    local state = posture:GetGrabState(hand)
    return Protocol.id(state.EntityId), tostring(state.GrabId)
end

local function capture_grab_poses(owner)
    local posture = owner:GetComponent(inzoi.EB2ComponentType.Posture)
    if not posture then return end
    local hands = inzoi.EB1HandType
    local poses = {}
    for _, hand in ipairs({hands.LeftHand, hands.RightHand}) do
        local id, pose = grab_state(posture, hand)
        if id and pose ~= "None" and #pose <= 128 and pose:match("^[%w_%-]+$") then
            poses[#poses + 1] = {hand = hand, id = id, pose = pose}
        end
    end
    if #poses > 0 then return poses end
end

local function release(self, owner, silent, cause, diagnostic)
    local lease = self.lease
    if not lease then return end
    if not lease.release_cause then
        -- The first caller explains the release even if restoration retries later.
        lease.release_cause, lease.release_diagnostic = cause, diagnostic
    end
    lease.releasing = true
    local errors = {}
    -- Retain the original snapshot until every step succeeds; retries skip completed steps.
    local function restore(key, fn)
        if lease.restored[key] then return end
        local ok, err = pcall(fn)
        if ok then lease.restored[key] = true else errors[#errors + 1] = tostring(err) end
    end
    restore("furniture", function() if lease.saved_furniture then require('SceneZOI.FurnitureLease').restore_saved(owner,lease.saved_furniture,lease.token)end end)
    restore("outfit", function() Outfit.restore(owner, lease) end)
    restore("position", function()
        -- Exit can arrive before the first anchor. Skip native position writes
        -- until the lease actually moved the Zoi, unless restoring from a save.
        if lease.stay or not (lease.location or lease.recovering) then return end
        owner:SetLocationAndRotationOnlySimul(lease.entry_location, lease.entry_rotation, false)
    end)
    restore("grab_poses", function()
        if not lease.grab_poses then return end
        local posture = owner:GetComponent(inzoi.EB2ComponentType.Posture)
        if not posture then return end
        for index, original in pairs(lease.grab_poses) do
            local id, pose = grab_state(posture, original.hand)
            if id == original.id and pose == "None" then
                posture:SetGrabId(original.hand, original.pose)
            end
            lease.grab_poses[index] = nil
        end
    end)
    restore("collision", function()
        if lease.tasks_settled or lease.recovering then owner:SetCollisionEnabled(lease.collision) end
    end)
    restore("autonomy", function()
        if not (lease.committed or lease.recovering) then return end
        -- Restore inheritance too; an effective boolean alone would override household settings.
        set_autonomy(owner, lease.local_value, lease.follow_parent)
    end)
    if #errors == 0 then
        self.lease = nil
        if lease.recovery_request then
            self.recovery_done=self.recovery_done or {};self.recovery_done[lease.recovery_request]=true
            Save.reply(owner,lease.recovery_request,'recovered')
        end
        self.retired[lease.token] = true
        self.retired_order[#self.retired_order + 1] = lease.token
        if #self.retired_order > 32 then self.retired[table.remove(self.retired_order, 1)] = nil end
        if not silent then
            reply_released(owner, lease.token, lease.stay_refused, lease.release_cause, lease.release_diagnostic)
            pcall(relay_release, owner, lease.token, lease.release_cause, lease.release_diagnostic)
        end
    else
        local message = table.concat(errors, "; ")
        if lease.last_error ~= message then
            lease.last_error = message
            print("[SceneZOI] Cleanup will retry: " .. message)
            if not silent then reply(owner, lease.token, "release_pending", "restore_error", 0, message) end
        end
    end
end

local function clear_task_queue(owner, interaction)
    -- Cancelling the running interaction can advance the waiting queue. Clear
    -- it first and keep it clear even after the participant is ready.
    if not interaction:IsQueueEmpty() then
        local ok, message = inzoi.cli.execute("interaction.clear_queue entity_id=" ..
            Protocol.id(owner:GetEntityId()) .. " cancel_current=false")
        assert(ok, message or "Could not clear queued tasks")
    end
end

local function report_prepare_wait(owner, lease, phase, queue_id, interaction)
    if lease.ready then return end
    local key = phase .. ":" .. (queue_id or "") .. ":" .. lease.revision
    local now = os.time()
    if lease.reported_wait == key and now == lease.wait_reported_at then return end
    lease.reported_wait = key
    lease.wait_reported_at = now
    -- Diagnostic reads and delivery must never affect readiness or cleanup.
    pcall(function()
        local function identifier(value)
            return type(value) == "string" and #value <= 96 and value:match("^[%w_.:+%-]+$") and value or "none"
        end
        local action, interaction_id
        if interaction then
            local ok, action_value = pcall(function() return interaction:GetCurrentActionType() end)
            if ok then
                action = tostring(action_value)
                if type(inzoi.EB1ActionType) == "table" then
                    for name, value in pairs(inzoi.EB1ActionType) do
                        if value == action_value then action = name; break end
                    end
                end
            end
            local found, bag = pcall(function() return interaction:GetCurrentInteractionBagId() end)
            if found then interaction_id = bag end
        end
        local fields = {lease.token, "prepare_wait", phase, lease.revision,
            identifier(queue_id), identifier(action), identifier(interaction_id), "none", "none", "none"}
        if phase == "autonomy_enabled" then
            local option = owner.AutonomyOption.AutonomyEnable
            fields[8], fields[9], fields[10] = option.Value and "1" or "0", option.bFollowParent and "1" or "0",
                lease.autonomy_disable_attempts or 0
        end
        -- A repeated phase alone cannot tell whether native ticks stopped or
        -- the effective autonomy query still disagrees. Sample receipt and tick
        -- counters together; only bounded, primitive observations leave B2.
        local timing = lease.lease_timing or {}
        local sample = {control_at_prepare = lease.control, progress_source = lease.progress_source,
            progress_attempts = lease.progress_attempts or 0, simulation_ticks = timing.tick_count or 0,
            prepare_received = timing.prepare_received or 0, heartbeat_received = timing.heartbeat_received or 0,
            commit_received = timing.commit_received or 0,
            autonomy_requested = lease.autonomy_requested, autonomy_notified = lease.autonomy_notified}
        if lease.last_tick_wall then sample.seconds_since_native_tick = math.max(0, now - lease.last_tick_wall) end
        if lease.last_commit_wall then sample.seconds_since_commit = math.max(0, now - lease.last_commit_wall) end
        local function observe(name, fn)
            local ok, value = pcall(fn)
            if ok and (type(value) == "boolean" or type(value) == "number" or
                (type(value) == "string" and #value <= 96)) then sample[name] = value end
        end
        observe("autonomy_effective", function() return owner:IsAutonomyEnable() end)
        local manager_ok, manager = pcall(function() return inzoi.getB2Manager("FB2AutonomyOptionManager") end)
        if manager_ok and manager then
            observe("autonomy_resolved", function() return manager:ResolveToggleOption(owner, inzoi.EB1AutonomyOptionType.AutonomyEnable) end)
            observe("global_autonomy", function() return manager:GetGlobalOption().AutonomyEnable.Value end)
            observe("follow_global", function() return manager:IsFollowGlobalAutonomyEnabled() end)
            observe("active_mode", function() return manager.bActiveMode end)
        end
        observe("controlled_id", function()
            local ok, _, data = inzoi.cli.execute("entity.get_possessed")
            return ok and data and data:match('"entity_id"%s*:%s*"?(%d+)')
        end)
        observe("zoi_group", function() return Protocol.id(owner:GetZoiGroupId()) end)
        observe("character_group_type", function() return tostring(owner:GetCharacterGroupType()) end)
        observe("autonomy_state", function() return tostring(owner:GetComponent(inzoi.EB2ComponentType.Autonomy):GetAutonomyState()) end)
        fields[11] = Protocol.encode(Json.encode(sample))
        inzoi.message.send_to_client(owner:GetEntityId(), "SceneZOI.Reply", Protocol.pack(table.unpack(fields)))
    end)
end

local function tasks_idle(owner, lease, interaction, queue_id)
    if queue_id then
        lease.idle_ticks = 0
        -- Read the task before cancellation can clear the native interaction.
        report_prepare_wait(owner, lease, "interaction_cancelling", queue_id, interaction)
        if lease.cancel_queue_id ~= queue_id then
            local ok, message = inzoi.cli.execute("interaction.cancel entity_id=" .. Protocol.id(owner:GetEntityId()))
            assert(ok, message or "Could not interrupt the current task")
            lease.cancel_queue_id = queue_id
        end
        return false
    end
    lease.cancel_queue_id = nil
    lease.idle_ticks = math.min(lease.idle_ticks + 1, 2)
    if lease.idle_ticks < 2 then
        report_prepare_wait(owner, lease, "confirming_idle")
        return false
    end
    return true
end

local function native_id(value)
    return type(value) == "string" and #value <= 128 and value:match("^[%w_%-]+$")
end

local function current_montages(owner)
    local target = " entity_id=" .. Protocol.id(owner:GetEntityId())
    local ok, _, data = inzoi.cli.execute("motion.get_current" .. target)
    if not ok or type(data) ~= "string" then return {} end
    local decoded, state = pcall(Json.decode, data)
    if not decoded or type(state) ~= "table" or type(state.motions) ~= "table" then return {} end
    return state.motions
end

local function interruptible(motion)
    return motion.non_interruptible == false and native_id(motion.anim_id) and
        native_id(motion.montage_id) and native_id(motion.group)
end

local function montage_key(motion)
    return motion.anim_id .. ":" .. motion.montage_id .. ":" .. motion.group
end

local function scan_task_overlays(owner, lease, interaction, queue_id)
    if lease.overlay_scan then return true end
    local new_task = queue_id and lease.overlay_queue ~= queue_id
    if not new_task and (lease.overlay_poll_wait or 0) > 0 then return false end
    local previous = not new_task and lease.overlay_seen or {}
    lease.overlay_poll_wait, lease.overlay_queue = .25, queue_id
    local seen, rows, requested = {}, {}, {}
    for _, motion in ipairs(current_montages(owner)) do
        if interruptible(motion) then
            local key = montage_key(motion)
            if previous[key] then
                seen[key] = true
            elseif not seen[key] and #rows < 8 then
                seen[key], requested[key] = true, true
                rows[#rows + 1] = key
            end
        end
    end
    lease.overlay_seen = seen
    if #rows == 0 then return false end
    local source = queue_id and interaction:GetCurrentInteractionId()
    lease.overlay_sequence = (lease.overlay_sequence or 0) + 1
    local scan = {id = lease.overlay_sequence, requested = requested, remaining = .3}
    lease.overlay_scan = scan
    -- B1 has the native animation declarations and rendered instances. Ask it
    -- before cancelling the interaction, which can put a montage into blend-out.
    local packet = Protocol.pack(lease.token, "overlay_cut", table.concat(rows, "+"), lease.revision,
        scan.id, native_id(source) and source or "none")
    local sent = pcall(inzoi.message.send_to_client, owner:GetEntityId(), "SceneZOI.Reply", packet)
    if not sent then lease.overlay_scan = nil end
    return lease.overlay_scan ~= nil
end

local function stop_approved_overlays(owner, lease, fields)
    local scan = lease.overlay_scan
    if not scan or tonumber(fields[2]) ~= lease.revision or tonumber(fields[3]) ~= scan.id then return end
    lease.overlay_scan = nil
    if not fields[4] or fields[4] == "none" then return end
    local accepted, counts = {}, {}
    for key in fields[4]:gmatch("[^+]+") do
        if scan.requested[key] then accepted[key] = true end
    end
    local target = " entity_id=" .. Protocol.id(owner:GetEntityId())
    local motions = current_montages(owner)
    for _, motion in ipairs(motions) do
        local id = motion.anim_id
        if native_id(id) then counts[id] = (counts[id] or 0) + 1 end
    end
    for _, motion in ipairs(motions) do
        local id = motion.anim_id
        -- Native simulation can stop only by animation ID. When an ID is
        -- shared, leave its other variants alone after the exact render cut.
        if counts[id] == 1 and interruptible(motion) and accepted[montage_key(motion)] then
            local ok, message = inzoi.cli.execute("motion.stop" .. target .. " anim_id=" .. id)
            if not ok then print("[SceneZOI] Could not stop task overlay: " .. tostring(message)) end
            if not lease.tasks_settled then
                lease.overlay_settling = lease.overlay_settling or {}
                lease.overlay_settling[montage_key(motion)] = true
                lease.overlay_settle_wait = lease.overlay_settle_wait or .5
            end
        end
    end
end

local function settle_task_overlays(owner, lease, paused)
    -- The native end section cannot advance while paused. The client-side cut
    -- and the simulation's stop request have already happened.
    if not lease.overlay_settling or paused then return true end
    if (lease.overlay_settle_poll or 0) > 0 then return false end
    lease.overlay_settle_poll = .1
    for _, motion in ipairs(current_montages(owner)) do
        if interruptible(motion) and lease.overlay_settling[montage_key(motion)] then
            if lease.overlay_settle_wait == 0 then
                print("[SceneZOI] Task overlay still reported after stop: " .. motion.anim_id)
                return true
            end
            report_prepare_wait(owner, lease, "overlay_cut")
            return false
        end
    end
    return true
end

local function suspend_grab_poses(owner, lease)
    if not lease.grab_snapshot then return end
    local posture = owner:GetComponent(inzoi.EB2ComponentType.Posture)
    for _, original in ipairs(lease.grab_snapshot) do
        local id, pose = grab_state(posture, original.hand)
        if id == original.id and pose == original.pose then
            lease.grab_poses = lease.grab_poses or {}
            lease.grab_poses[#lease.grab_poses + 1] = original
            -- The game regenerates the loop from the pose ID. Keep the held entity.
            posture:StopGrabLoopAnimation(original.hand)
            posture:SetGrabId(original.hand, "None")
        end
    end
end

local function advance_prepare(self, owner, first_commit, paused, source)
    local lease = self.lease
    if not lease or lease.releasing or not lease.committed then return end
    lease.progress_attempts = (lease.progress_attempts or 0) + 1
    lease.progress_source = source or "commit"
    -- IsAutonomyEnable reports activity eligibility, not the resolved policy.
    -- An idle NPC can return true even after the native autonomy setter disables
    -- it. Confirm local suppression and its resolved policy on every entry;
    -- the separate queue, two-idle-observation and overlay barriers still apply.
    local option = owner.AutonomyOption.AutonomyEnable
    if first_commit or option.Value or option.bFollowParent or resolved_autonomy(owner) then
        lease.autonomy_disable_attempts = (lease.autonomy_disable_attempts or 0) + 1
        set_autonomy(owner, false, false, lease)
    end
    local interaction = assert(owner:GetComponent(inzoi.EB2ComponentType.Interaction), "Missing interaction component")
    clear_task_queue(owner, interaction)
    local queue_id = owner:IsPlayingInteraction() and tostring(interaction:GetCurrentInteractionQueueId())
    if scan_task_overlays(owner, lease, interaction, queue_id) and (not lease.ready or queue_id) then
        report_prepare_wait(owner, lease, "overlay_cut")
        return
    end
    if not tasks_idle(owner, lease, interaction, queue_id) or lease.ready then return end
    if option.Value or option.bFollowParent or resolved_autonomy(owner) then
        report_prepare_wait(owner, lease, "autonomy_enabled")
        return
    end
    if not lease.tasks_settled then
        -- Gameplay can keep upper-body and grab loops alive after the task is idle.
        if not lease.grab_suspended then
            suspend_grab_poses(owner, lease)
            lease.grab_suspended = true
        end
        if not settle_task_overlays(owner, lease, paused) then return end
        lease.overlay_settling, lease.overlay_settle_wait, lease.overlay_settle_poll = nil, nil, nil
        local location, rotation = owner:GetLocation(), owner:GetRotation()
        lease.entry_location = UE.FVector(location.X, location.Y, location.Z)
        lease.entry_rotation = UE.FRotator(rotation.Pitch, rotation.Yaw, rotation.Roll)
        lease.tasks_settled = true
        owner:SetCollisionEnabled(false)
    end
    -- The requested layout is inert until the host cached our save snapshot.
    -- Initial acquisition and later revisions use the same committed path.
    if lease.keep_unmerged then Outfit.keep_unmerged(owner, lease) end
    if not lease.wardrobe then
        -- Task cleanup and the first layout refresh can resolve a different
        -- outfit. Freeze those settled pieces before the scene removes any;
        -- capturing in Prepare can retain an old outfit and omit current items.
        Outfit.apply(owner, lease, {})
        Wardrobe.capture(owner, lease)
    end
    local directive = lease.node.outfits and lease.node.outfits[lease.role]
    Outfit.apply(owner, lease, directive and directive.remove_slots or {})
    lease.ready = true
    reply(owner, lease.token, "ready", lease.body .. ":" .. lease.control, lease.revision)
    inzoi.message.send_to_client(owner:GetEntityId(), "SceneZOI.Reply", Wardrobe.inventory(owner, lease))
end

local function prepare(self, owner, token, initiator, node_id, revision, unmerged, role, snapshot)
    revision = tonumber(revision)
    local decoded=assert(Protocol.decode(snapshot),"Missing scene snapshot")
    local node = SceneData.simulation(Json.decode(decoded))
    assert(node.id==node_id,"Scene snapshot identity mismatch")
    assert(node and revision and revision >= 1 and revision % 1 == 0, "Invalid scene node preparation")
    assert(unmerged == "0" or unmerged == "1", "Invalid participant body layout")
    local requested_unmerged = unmerged == "1"
    if self.retired[token] then reply_released(owner, token, false, "retired_prepare"); return end
    if self.lease then
        if self.lease.token ~= token then reply(owner, token, "rejected", "busy"); return end
        local lease = self.lease
        renew_lease(lease, "prepare_received")
        if lease.releasing then return end
        if revision == lease.revision + 1 then
            lease.keep_unmerged = requested_unmerged
            lease.node, lease.revision, lease.ready = node, revision, false
            lease.overlay_scan, lease.overlay_seen, lease.overlay_poll_wait = nil, nil, nil
            assert(role == lease.role, "Session role cannot change")
            Binding.validate(node, role, lease.body)
            advance_prepare(self, owner, false, false, "prepare_revision")
        elseif revision == lease.revision then
            lease.keep_unmerged = requested_unmerged
            if not lease.committed then Save.offer(owner, lease)
            elseif requested_unmerged then
                -- A same-node appearance refresh can introduce a body/region
                -- after the first Ready. Recheck flags through the normal gate.
                lease.ready = false
                advance_prepare(self, owner, false, false, "prepare_retry")
            elseif lease.ready then
                reply(owner, token, "ready", lease.body .. ":" .. lease.control, lease.revision)
                inzoi.message.send_to_client(owner:GetEntityId(), "SceneZOI.Reply", Wardrobe.inventory(owner, lease))
            else
                -- Host retries must also progress a committed participant whose
                -- native entity ticks are delayed. Keep the same task/idle and
                -- autonomy gates used by Commit; receipt alone is not Ready.
                advance_prepare(self, owner, false, false, "prepare_retry")
            end
        end
        return
    end
    local requirement=assert(node.participants[role],"Missing participant role")
    if requirement.body_age and owner:GetBodyAgeType()~=inzoi.EB1BodyAgeType[requirement.body_age]then
        reply(owner,token,"rejected","body_type");return
    end
    if requirement.growth_steps then
        local permitted=false
        for _,step in ipairs(requirement.growth_steps)do if owner:GetGrowthStep()==inzoi.EB1GrowthStep[step]then permitted=true end end
        if not permitted then reply(owner,token,"rejected","eligibility");return end
    end
    -- Tracks follow the rendered body, which can differ from simulation/bio gender.
    local appearance = owner:GetComponent(inzoi.EB2ComponentType.Appearance)
    local gender = appearance and appearance:GetAppearanceSetting().Gender
    local body = gender == inzoi.EB1GenderType.Male and "male"
        or gender == inzoi.EB1GenderType.Female and "female" or nil
    if not body then reply(owner, token, "rejected", "binding_error"); return end
    Binding.validate(node, role, body)
    local ok,_,data=inzoi.cli.execute("entity.get_possessed")
    local controlled=ok and data and data:match('"entity_id"%s*:%s*"?(%d+)')
    local option = owner:GetAutonomyOption().AutonomyEnable
    local location, rotation = owner:GetLocation(), owner:GetRotation()
    self.lease = {
        token = token, role = role, body = body, control = controlled==Protocol.id(owner:GetEntityId()) and "controlled" or "npc", node = node, revision = revision, keep_unmerged = requested_unmerged, restored = {}, idle_ticks = 0,
        collision = owner:IsCollisionEnabled(), local_value = option.Value, follow_parent = option.bFollowParent,
        entry_location = UE.FVector(location.X, location.Y, location.Z),
        entry_rotation = UE.FRotator(rotation.Pitch, rotation.Yaw, rotation.Roll),
    }
    renew_lease(self.lease, "prepare_received")
    Outfit.recover(owner,node.cleanup_layers)
    self.lease.grab_snapshot = capture_grab_poses(owner)
    -- Capture only. The UI must cache this save record before any native mutation.
    Save.offer(owner,self.lease)
    report_prepare_wait(owner, self.lease, "awaiting_commit")
end

---@param self table
---@param owner FB2Character
function M.on_begin(self, owner)
    self.lease, self.retired, self.retired_order = nil, {}, {}
    Outfit.recover(owner)
end

local function receive(self, owner, kind, content)
    local fields = Protocol.unpack(content)
    if not fields then return end
    local token = fields[1]
    if kind == "SceneZOI.Prepare" then
        local ok, err = pcall(prepare, self, owner, token, fields[2], fields[3], fields[4], fields[5], fields[6], fields[7])
        if not ok then
            release(self, owner, true, "prepare_error", err)
            reply(owner, token, "rejected", "prepare_error", 0, err)
        end
    elseif kind == 'SceneZOI.Commit' then
        local lease=self.lease
        if not lease or lease.token~=token or lease.releasing then return end
        local ok,err=pcall(function()
            local timing = lease.lease_timing
            if timing then timing.commit_received = (timing.commit_received or 0) + 1 end
            lease.last_commit_wall = os.time()
            local first_commit = not lease.committed
            lease.committed = true
            advance_prepare(self,owner,first_commit)
        end)
        if not ok then
            release(self,owner,true,"prepare_error",err)
            reply(owner,token,'rejected','prepare_error',0,err)
        end
    elseif kind == "SceneZOI.OverlayCut" then
        local lease = self.lease
        if lease and lease.token == token and not lease.releasing then
            stop_approved_overlays(owner, lease, fields)
        end
    elseif kind == 'SceneZOI.Recover' then
        self.recovery_done=self.recovery_done or {}
        if self.recovery_done[token]then Save.reply(owner,token,'recovered');return end
        local data=Json.decode((assert(Protocol.decode(fields[2]),'Invalid recovery packet')))
        -- This lease already released itself; restoring again would move a Zoi that has since walked away.
        if self.retired[data.token]then Save.reply(owner,token,'recovered');return end
        if self.lease and self.lease.token~=data.token then return end
        if not self.lease then self.lease=assert(Recovery.lease(data),'Missing recovery record')end
        self.lease.recovery_request=token
        release(self,owner,true,"save_recovery")
    elseif kind == "SceneZOI.Outfit" then
        local lease = self.lease
        local count, revision = tonumber(fields[2]), tonumber(fields[5])
        if not lease or lease.token ~= token or lease.releasing or not lease.ready or revision ~= lease.revision or
            not count or count % 1 ~= 0 or count <= 0 or (fields[4] ~= "0" and fields[4] ~= "1") then return end
        if count > (lease.outfit_counter or 0) then
            if not Wardrobe.toggle(lease, fields[3], fields[4] == "1") then return end
            if fields[6] == "1" then Outfit.keep_unmerged(owner, lease) end
            Outfit.apply(owner, lease, {})
            lease.outfit_counter = count
        end
        inzoi.message.send_to_client(owner:GetEntityId(), "SceneZOI.Reply", Wardrobe.inventory(owner, lease))
    elseif kind == "SceneZOI.Placement" then
        local ok, x, y, z = pcall(require("SceneZOI.Placement").find, owner, tonumber(fields[2]), Protocol.decode(fields[3]))
        if not ok then print("[SceneZOI] Floor search failed: " .. tostring(x)) end
        reply(owner, token, "placement", ok and x or "none", ok and y or 0, ok and z and tostring(z) or nil)
    elseif kind == "SceneZOI.Release" then
        if not self.lease and not self.retired[token] and fields[3] and fields[3] ~= "none" then
            local data = Json.decode((assert(Protocol.decode(fields[3]), "Invalid release snapshot")))
            assert(data.token == token, "Release snapshot does not match this session")
            self.lease = assert(Recovery.lease(data), "Missing release snapshot")
        end
        if self.lease and self.lease.token == token then
            -- Only stay if the game agrees this floor is walkable; otherwise go back as usual.
            self.lease.stay = not self.lease.recovering and fields[2] == "stay" and require("SceneZOI.Placement").walkable(owner)
            self.lease.stay_refused = fields[2] == "stay" and not self.lease.stay
            release(self, owner, false, "host_request")
        else
            -- Retire even an unseen token: a delayed Prepare must not reacquire it.
            self.retired[token] = true
            reply_released(owner, token, false, "host_request")
        end
    elseif self.lease and self.lease.token == token and not self.lease.releasing then
        if kind == "SceneZOI.Heartbeat" then renew_lease(self.lease, "heartbeat_received")
        elseif kind == "SceneZOI.Anchor" and #fields == 7 then
            local values = {}
            for index = 2, 7 do
                values[index] = tonumber(fields[index])
                if not values[index] then return end
            end
            self.lease.location = UE.FVector(values[2], values[3], values[4])
            self.lease.rotation = UE.FRotator(values[5], values[6], values[7])
            owner:SetLocationAndRotationOnlySimul(self.lease.location, self.lease.rotation, false)
        end
    end
end

---@param self table
---@param owner FB2Character
---@param kind string
---@param content string
function M.on_lua_message(self, owner, kind, content)
    local ok, err = pcall(receive, self, owner, kind, content)
    if not ok then
        print("[SceneZOI] Participant message failed: " .. tostring(err))
        release(self, owner, false, "participant_message_error", err)
    end
end

local function update(self, owner, dt)
    local lease = self.lease
    if not lease then return end
    if lease.releasing then release(self, owner, false, "lease_expired"); return end
    dt = math.max(tonumber(dt) or 0, 0)
    local timing = lease.lease_timing
    lease.last_tick_wall = os.time()
    if timing then
        timing.tick_count = timing.tick_count + 1
        timing.total_tick_seconds = timing.total_tick_seconds + dt
        timing.since_renew_tick_seconds = timing.since_renew_tick_seconds + dt
        timing.last_dt, timing.max_dt = dt, math.max(timing.max_dt, dt)
    end
    if lease.overlay_scan then
        lease.overlay_scan.remaining = lease.overlay_scan.remaining - dt
        if lease.overlay_scan.remaining <= 0 then lease.overlay_scan = nil end
    end
    if lease.overlay_settle_wait then lease.overlay_settle_wait = math.max(0, lease.overlay_settle_wait - dt) end
    if lease.overlay_poll_wait then lease.overlay_poll_wait = math.max(0, lease.overlay_poll_wait - dt) end
    if lease.overlay_settle_poll then lease.overlay_settle_poll = math.max(0, lease.overlay_settle_poll - dt) end
    -- NPC callbacks may contain accumulated time from before the last renewal.
    -- A lease measures the host's absence, using real time instead. The supported
    -- wall clock has whole-second resolution: > grants its rounding grace.
    local now = os.time()
    if now < lease.renewed_at then
        lease.renewed_at = now
        if timing then timing.clock_rollbacks = timing.clock_rollbacks + 1 end
    end
    if now - lease.renewed_at > Config.lease_timeout then
        release(self, owner, false, "lease_expired", lease_expiry_detail(lease, now))
        return
    end
    advance_prepare(self, owner, false, dt == 0, "tick")
    -- B2 owns simulation placement; B1 separately pins the rendered actor and animation time.
    if lease.location then owner:SetLocationAndRotationOnlySimul(lease.location, lease.rotation, false) end
end

---@param self table
---@param owner FB2Character
---@param dt number
function M.on_tick(self, owner, dt)
    local ok, err = pcall(update, self, owner, dt)
    if not ok then
        print("[SceneZOI] Participant update failed: " .. tostring(err))
        release(self, owner, false, "participant_update_error", err)
    end
end

---@param self table
---@param owner FB2Character
function M.on_savegame(self, owner)
    -- Scene ownership is temporary; do not serialize its disabled-autonomy lease into the save.
    release(self, owner, false, "simulation_save")
    return {}
end

---@param self table
---@param owner FB2Character
function M.on_loadgame(self, owner)
    release(self, owner, false, "simulation_load")
end

---@param self table
---@param owner FB2Character
function M.on_end(self, owner)
    release(self, owner, false, "simulation_end")
end

return M
