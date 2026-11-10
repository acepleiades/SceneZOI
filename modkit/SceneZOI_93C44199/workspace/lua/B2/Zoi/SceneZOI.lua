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

local function set_autonomy(owner, enable)
    local ok, message = inzoi.cli.execute("autonomy.set_enable entity_id=" ..
        Protocol.id(owner:GetEntityId()) .. " enable=" .. tostring(enable))
    assert(ok, message or "Autonomy change failed")
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
        if lease.stay then return end
        owner:SetLocationAndRotationOnlySimul(lease.entry_location, lease.entry_rotation, false)
    end)
    restore("collision", function() owner:SetCollisionEnabled(lease.collision) end)
    restore("autonomy", function()
        local option = owner.AutonomyOption.AutonomyEnable
        -- Restore inheritance too; an effective boolean alone would override household settings.
        option.Value, option.bFollowParent = lease.local_value, lease.follow_parent
        owner:RefreshAutonomyOptionCache()
        local component = owner:GetComponent(inzoi.EB2ComponentType.Autonomy)
        component:OnAutonomyOptionChanged(owner:IsAutonomyEnable())
        component:SendAutonomyEnablePacket(owner:IsAutonomyEnable(), false)
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

local function tasks_idle(owner, lease)
    local interaction = assert(owner:GetComponent(inzoi.EB2ComponentType.Interaction), "Missing interaction component")
    -- Autonomy does not stop user-queued tasks. Remove the backlog before cancel
    -- advances it, and keep new requests from taking over an already-ready lease.
    if not interaction:IsQueueEmpty() then
        local ok, message = inzoi.cli.execute("interaction.clear_queue entity_id=" ..
            Protocol.id(owner:GetEntityId()) .. " cancel_current=false")
        assert(ok, message or "Could not clear queued tasks")
    end
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

local function stop_eating_overlay(owner)
    local target = " entity_id=" .. Protocol.id(owner:GetEntityId())
    local ok, _, data = inzoi.cli.execute("motion.get_current" .. target)
    if not ok or type(data) ~= "string" then return end
    local decoded, state = pcall(Json.decode, data)
    if not decoded or type(state) ~= "table" or type(state.motions) ~= "table" then return end

    for _, motion in ipairs(state.motions) do
        local id = motion.anim_id
        if motion.group == "UpperGroup" and not motion.non_interruptible and type(id) == "string" and
            (id:match("^Dish_Eat_[%w_]+$") or id:match("^Snack_Eat_[%w_]+$")) then
            local stopped, message = inzoi.cli.execute("motion.stop" .. target .. " anim_id=" .. id)
            if not stopped then print("[SceneZOI] Could not stop eating overlay: " .. tostring(message)) end
        end
    end
end

local function advance_prepare(self, owner)
    local lease = self.lease
    if not lease or lease.releasing or not lease.committed then return end
    if not tasks_idle(owner, lease) or lease.ready then return end
    if not lease.tasks_settled then
        -- The task can be idle while its independent upper-body loop still plays.
        stop_eating_overlay(owner)
        local location, rotation = owner:GetLocation(), owner:GetRotation()
        lease.entry_location = UE.FVector(location.X, location.Y, location.Z)
        lease.entry_rotation = UE.FRotator(rotation.Pitch, rotation.Yaw, rotation.Roll)
        owner:SetCollisionEnabled(false)
        lease.tasks_settled = true
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
            if not lease.committed then lease.committed=true;set_autonomy(owner,false)end
            advance_prepare(self,owner)
        end)
        if not ok then
            release(self,owner,true)
            reply(owner,token,'rejected','prepare_error',0,err)
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
    lease.remaining = lease.remaining - math.max(tonumber(dt) or 0, 0)
    if lease.releasing or lease.remaining <= 0 then release(self, owner); return end
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
