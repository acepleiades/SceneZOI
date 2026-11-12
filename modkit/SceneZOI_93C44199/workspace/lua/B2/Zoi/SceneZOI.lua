local Config = require("SceneZOI.Config")
local Protocol = require("SceneZOI.Protocol")
local Outfit = require("SceneZOI.Outfit")
local Wardrobe = require("SceneZOI.Wardrobe")
local Json = require("SceneZOI.Json")
local SceneData = require("SceneZOI.SceneData")
local Binding = require("SceneZOI.Binding")
local Save=require("SceneZOI.SaveGuard")
local Recovery=require("SceneZOI.SaveRecovery")
local Members=require("SceneZOI.SceneMembers")
local M = {}

local function reply(owner, token, kind, detail, revision, diagnostic)
    local packet = Protocol.pack(token, kind, detail or "ok", revision or 0)
    if diagnostic then packet = packet .. "|" .. tostring(diagnostic):gsub("[^%w_.:+%-]", "_"):sub(1, 1200) end
    inzoi.message.send_to_client(owner:GetEntityId(), "SceneZOI.Reply", packet)
end

local function set_autonomy(owner, value, follow_parent)
    local option = owner.AutonomyOption.AutonomyEnable
    option.Value, option.bFollowParent = value, follow_parent
    owner:RefreshAutonomyOptionCache()
    local component = owner:GetComponent(inzoi.EB2ComponentType.Autonomy)
    local enabled = owner:IsAutonomyEnable()
    component:OnAutonomyOptionChanged(enabled)
    component:SendAutonomyEnablePacket(enabled, false)
end

-- If this Zoi's client actor has unloaded, its own reply cannot arrive. Say so through the controlled Zoi.
local function relay_release(owner, token)
    local ok, _, data = inzoi.cli.execute("entity.get_possessed")
    local controlled = ok and data and data:match('"entity_id"%s*:%s*"?(%d+)')
    local own = Protocol.id(owner:GetEntityId())
    if not controlled or controlled == own then return end
    local target = inzoi.FB1EntityId()
    target.Value = tonumber(controlled)
    inzoi.message.send_to_client(target, "SceneZOI.Reply", Protocol.pack(token, "released_unloaded", own))
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

local function release(self, owner, silent)
    local lease = self.lease
    if not lease then return end
    lease.releasing = true
    local errors = {}
    -- Retain the original snapshot until every step succeeds; retries skip completed steps.
    local function restore(key, fn)
        if lease.restored[key] then return end
        local ok, err = pcall(fn)
        if ok then lease.restored[key] = true else errors[#errors + 1] = tostring(err) end
    end
    restore("furniture", function() if lease.saved_furniture then require('SceneZOI.FurnitureLease').restore_saved(owner,lease.saved_furniture)end end)
    restore("outfit", function() Outfit.restore(owner, lease) end)
    restore("position", function()
        -- Before the first anchor the simulation has not moved this Zoi.
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
        Members.remove(owner:GetEntityId())
        if lease.recovery_request then
            self.recovery_done=self.recovery_done or {};self.recovery_done[lease.recovery_request]=true
            Save.reply(owner,lease.recovery_request,'recovered')
        end
        self.retired[lease.token] = true
        self.retired_order[#self.retired_order + 1] = lease.token
        if #self.retired_order > 32 then self.retired[table.remove(self.retired_order, 1)] = nil end
        if not silent then
            reply(owner, lease.token, "released", "ok", lease.stay_refused and 1 or 0)
            pcall(relay_release, owner, lease.token)
        end
    else
        local message = table.concat(errors, "; ")
        if lease.last_error ~= message then
            lease.last_error = message
            print("[SceneZOI] Cleanup will retry: " .. message)
            if not silent then reply(owner, lease.token, "release_pending", "restore_error", message) end
        end
    end
end

local function clear_task_queue(owner, interaction)
    -- Autonomy does not stop user-queued tasks. Remove the backlog before cancel
    -- advances it, and keep new requests from taking over an already-ready lease.
    if not interaction:IsQueueEmpty() then
        local ok, message = inzoi.cli.execute("interaction.clear_queue entity_id=" ..
            Protocol.id(owner:GetEntityId()) .. " cancel_current=false")
        assert(ok, message or "Could not clear queued tasks")
    end
end

local function tasks_idle(owner, lease, interaction)
    if owner:IsPlayingInteraction() then
        lease.idle_ticks = 0
        local queue_id = tostring(interaction:GetCurrentInteractionQueueId())
        if lease.cancel_queue_id ~= queue_id then
            local ok, message = inzoi.cli.execute("interaction.cancel entity_id=" .. Protocol.id(owner:GetEntityId()))
            assert(ok, message or "Could not interrupt the current task")
            lease.cancel_queue_id = queue_id
        end
        return false
    end
    lease.cancel_queue_id = nil
    lease.idle_ticks = math.min(lease.idle_ticks + 1, 2)
    return lease.idle_ticks >= 2
end

-- Only layer motions that can conflict with the scene pose. Posture and
-- locomotion still belong to the game, as do unrelated protected motions.
local task_overlay_groups = {UpperGroup = true, LeftArmGroup = true, RightArmGroup = true}

local function task_overlays(owner)
    local target = " entity_id=" .. Protocol.id(owner:GetEntityId())
    local ok, _, data = inzoi.cli.execute("motion.get_current" .. target)
    if not ok or type(data) ~= "string" then return {} end
    local decoded, state = pcall(Json.decode, data)
    if not decoded or type(state) ~= "table" or type(state.motions) ~= "table" then return {} end
    local result = {}
    for _, motion in ipairs(state.motions) do
        if task_overlay_groups[motion.group] and motion.non_interruptible == false and
            type(motion.anim_id) == "string" and motion.anim_id:match("^[%w_%-]+$") then
            result[#result + 1] = motion
        end
    end
    return result
end

local function wait_for_overlay_cut(owner, lease)
    if lease.overlay_cut_wait ~= nil then return lease.overlay_cut_wait > 0 end
    lease.overlay_cut_wait = 0
    local rows = {}
    for _, motion in ipairs(task_overlays(owner)) do
        local name = motion.montage_id
        if type(name) == "string" and #name <= 128 and name:match("^[%w_%-]+$") then
            rows[#rows + 1] = motion.anim_id .. ":" .. name
            if #rows == 8 then break end
        end
    end
    if #rows == 0 then return false end
    -- The rendered montage is still active here. Native cancellation can start
    -- blending it before a later presentation-side stop can find it.
    lease.overlay_cut_wait = .3
    local sent = pcall(reply, owner, lease.token, "overlay_cut", table.concat(rows, "+"), lease.revision)
    if not sent then lease.overlay_cut_wait = 0 end
    return lease.overlay_cut_wait > 0
end

local function stop_task_overlays(owner)
    local target = " entity_id=" .. Protocol.id(owner:GetEntityId())
    for _, motion in ipairs(task_overlays(owner)) do
        local stopped, message = inzoi.cli.execute("motion.stop" .. target .. " anim_id=" .. motion.anim_id)
        if not stopped then print("[SceneZOI] Could not stop task overlay: " .. tostring(message)) end
    end
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

local function advance_prepare(self, owner)
    local lease = self.lease
    if not lease or lease.releasing or not lease.committed then return end
    local interaction = assert(owner:GetComponent(inzoi.EB2ComponentType.Interaction), "Missing interaction component")
    clear_task_queue(owner, interaction)
    if wait_for_overlay_cut(owner, lease) or not tasks_idle(owner, lease, interaction) or lease.ready then return end
    if owner:IsAutonomyEnable() then return end
    if not lease.tasks_settled then
        -- Gameplay can keep upper-body and grab loops alive after the task is idle.
        suspend_grab_poses(owner, lease)
        stop_task_overlays(owner)
        local location, rotation = owner:GetLocation(), owner:GetRotation()
        lease.entry_location = UE.FVector(location.X, location.Y, location.Z)
        lease.entry_rotation = UE.FRotator(rotation.Pitch, rotation.Yaw, rotation.Roll)
        lease.tasks_settled = true
        owner:SetCollisionEnabled(false)
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
    if self.retired[token] then reply(owner, token, "released", "ok"); return end
    if self.lease then
        if self.lease.token ~= token then reply(owner, token, "rejected", "busy"); return end
        local lease = self.lease
        lease.remaining = Config.lease_timeout
        if lease.releasing then return end
        if revision == lease.revision + 1 then
            if unmerged == "1" then Outfit.keep_unmerged(owner, lease) end
            lease.node, lease.revision, lease.ready = node, revision, false
            assert(role == lease.role, "Session role cannot change")
            Binding.validate(node, role, lease.body)
            advance_prepare(self, owner)
        elseif revision == lease.revision and not lease.committed then
            Save.offer(owner,lease)
        elseif revision == lease.revision and lease.ready then
            reply(owner, token, "ready", lease.body .. ":" .. lease.control, lease.revision)
            inzoi.message.send_to_client(owner:GetEntityId(), "SceneZOI.Reply", Wardrobe.inventory(owner, lease))
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
        token = token, role = role, body = body, control = controlled==Protocol.id(owner:GetEntityId()) and "controlled" or "npc", node = node, revision = revision, remaining = Config.lease_timeout, restored = {}, idle_ticks = 0,
        collision = owner:IsCollisionEnabled(), local_value = option.Value, follow_parent = option.bFollowParent,
        entry_location = UE.FVector(location.X, location.Y, location.Z),
        entry_rotation = UE.FRotator(rotation.Pitch, rotation.Yaw, rotation.Roll),
    }
    Members.add(owner:GetEntityId())
    Outfit.recover(owner,node.cleanup_layers)
    self.lease.grab_snapshot = capture_grab_poses(owner)
    Wardrobe.capture(owner, self.lease)
    -- Capture only. The UI must cache this save record before any native mutation.
    Save.offer(owner,self.lease)
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
            release(self, owner, true)
            reply(owner, token, "rejected", "prepare_error", 0, err)
        end
    elseif kind == 'SceneZOI.Commit' then
        local lease=self.lease
        if not lease or lease.token~=token or lease.releasing then return end
        local ok,err=pcall(function()
            if not lease.committed then
                lease.committed = true
                set_autonomy(owner, false, false)
            end
            advance_prepare(self,owner)
        end)
        if not ok then
            release(self,owner,true)
            reply(owner,token,'rejected','prepare_error',0,err)
        end
    elseif kind == "SceneZOI.OverlayCut" then
        local lease = self.lease
        if lease and lease.token == token and not lease.releasing and lease.overlay_cut_wait and
            lease.overlay_cut_wait > 0 and tonumber(fields[2]) == lease.revision then
            lease.overlay_cut_wait = 0
        end
    elseif kind == 'SceneZOI.Recover' then
        self.recovery_done=self.recovery_done or {}
        if self.recovery_done[token]then Save.reply(owner,token,'recovered');return end
        local data=Json.decode((assert(Protocol.decode(fields[2]),'Invalid recovery packet')))
        -- This lease already released itself; restoring again would move a Zoi that has since walked away.
        if self.retired[data.token]then Save.reply(owner,token,'recovered');return end
        if self.lease and (not self.lease.releasing or self.lease.token~=data.token)then return end
        if not self.lease then self.lease=assert(Recovery.lease(data),'Missing recovery record')end
        self.lease.recovery_request=token
        release(self,owner,true)
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
        if self.lease and self.lease.token == token then
            -- Only stay if the game agrees this floor is walkable; otherwise go back as usual.
            self.lease.stay = fields[2] == "stay" and require("SceneZOI.Placement").walkable(owner)
            self.lease.stay_refused = fields[2] == "stay" and not self.lease.stay
            release(self, owner)
        else
            -- Retire even an unseen token: a delayed Prepare must not reacquire it.
            self.retired[token] = true
            reply(owner, token, "released", "ok")
        end
    elseif self.lease and self.lease.token == token and not self.lease.releasing then
        if kind == "SceneZOI.Heartbeat" then self.lease.remaining = Config.lease_timeout
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
        release(self, owner)
    end
end

local function update(self, owner, dt)
    local lease = self.lease
    if not lease then return end
    dt = math.max(tonumber(dt) or 0, 0)
    lease.remaining = lease.remaining - dt
    if lease.overlay_cut_wait then lease.overlay_cut_wait = math.max(0, lease.overlay_cut_wait - dt) end
    if lease.releasing or lease.remaining <= 0 then release(self, owner); return end
    -- The game can re-enable autonomy even after playback has started.
    if lease.committed then
        local option = owner.AutonomyOption.AutonomyEnable
        if option.Value or option.bFollowParent or owner:IsAutonomyEnable() then
            set_autonomy(owner, false, false)
        end
    end
    advance_prepare(self, owner)
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
        release(self, owner)
    end
end

---@param self table
---@param owner FB2Character
function M.on_savegame(self, owner)
    -- Scene ownership is temporary; do not serialize its disabled-autonomy lease into the save.
    release(self, owner)
    return {}
end

---@param self table
---@param owner FB2Character
function M.on_loadgame(self, owner)
    release(self, owner)
end

---@param self table
---@param owner FB2Character
function M.on_end(self, owner)
    release(self, owner)
end

return M
