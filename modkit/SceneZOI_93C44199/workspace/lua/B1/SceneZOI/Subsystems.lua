-- Scene tracks are node-owned; explicitly retained resources live until session release.
-- Pack data selects assets and conditions, never executable hooks.
local Attachment = require("SceneZOI.Attachment")
local Body = require("SceneZOI.BodyRegion")
local Binding = require("SceneZOI.Binding")
local OutfitState = require("SceneZOI.OutfitState")
local Gaze = require("SceneZOI.Gaze")
local Expressions = require("SceneZOI.Expressions")
local Sfx = require("SceneZOI.Sfx")
local Voices = require("SceneZOI.Voices")
local Traits = require("SceneZOI.Traits")
local TaskActions = require("SceneZOI.TaskActions")
local CompletionEffects = require("SceneZOI.CompletionEffects")
local M = {}
M.__index = M

local function copy(value)
    local result = {}
    for key, entry in pairs(value) do result[key] = entry end
    return result
end

local function compatible(spec,owner)
    if not spec._condition then return true end
    if not owner then return false end
    owner.traits=owner.traits or Traits.capture(owner.actor)
    return Traits.matches(spec._condition,owner.traits)
end

local function covered(spec, owner)
    if spec.body_profile then return Body.covered(owner.actor, spec.body_profile) end
    return OutfitState.lower_body_covered(owner.original_garments, owner.removed_slots)
end

local attachment_engine = {
    id = "attachment",
    load = function(node, duration)
        local mesh, patch, animation = Attachment.load(node, duration)
        return {attachment_asset = mesh, patch_asset = patch, attachment_animation = animation}
    end,
    prepare = function(context, session)
        local owner = assert(session.bindings[context.node.attachment.participant], "Attachment owner is unavailable")
        context.removed_slots = owner.removed_slots
        local hidden, flags = covered(context.node.attachment, owner)
        context.hide_attachment = context.node.attachment.when_undressed and hidden or false
        context.coverage_flags = flags
        return Attachment.prepare(context, owner.actor)
    end,
    enter = Attachment.enter,
    ready = Attachment.ready, sample = Attachment.sample, restore = Attachment.restore, status = Attachment.status,
    guard = Attachment.guard,
    begin_outfit = Attachment.begin_outfit,
}

-- Each adapter context owns one physical attachment; the host owns a named collection.
local function attachments(node, duration, session, present)
    local retained = session and session.retained_subsystems or {}
    local bindings = session and Binding.resolve(session.participants, node)
    local specs, result = {}, {}
    for id, spec in pairs(node.attachments or {}) do specs[id] = spec end
    for _, item in pairs(retained) do
        if item.engine.id == "attachment" and not specs[item.id] then
            local spec = copy(item.context.node.attachment)
            spec.animation = spec.retained_tracks and spec.retained_tracks[node.id]
            assert(spec._condition or spec.animation,"Retained attachment has no animation for the target node")
            spec.participant = nil
            for role, owner in pairs(bindings) do if owner.id == item.owner_id then spec.participant = role end end
            assert(spec.participant, "Retained attachment owner is absent from the target node")
            specs[item.id] = spec
        end
    end
    local ids = {}
    for id in pairs(specs) do ids[#ids+1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local spec, key = specs[id], "attachment:" .. id
        if not (present and present[key]) then
        local previous = retained[key]
        local owner = bindings and bindings[spec.participant]
        local directive = node.outfits and node.outfits[spec.participant]
        local removed = OutfitState.merge(owner and owner.removed_slots, directive and directive.remove_slots)
        local incompatible = not compatible(spec,owner)
        local skip = incompatible or spec.when_undressed and not previous and not OutfitState.undressed(removed) and
            (not owner or covered(spec, owner))
        if not skip then
            if previous then
                assert(owner and owner.id == previous.owner_id, "Attachment owner cannot change during retention")
                for _, field in ipairs({"mesh", "component", "socket", "reference_bone", "body_profile", "material_profile"}) do
                    assert(spec[field] == previous.context.node.attachment[field], "Retained attachment configuration changed: " .. field)
                end
                assert(spec.retain_for_session, "A retained attachment must keep session ownership")
            end
            local effective = copy(node)
            effective.attachment = spec
            result[#result+1] = {id = id, key = key, engine = attachment_engine,
                resources = attachment_engine.load(effective, duration), node = effective,
                retained = previous, owner_id = owner and owner.id}
        end
        end
    end
    return result
end

function M.load(node, duration, session)
    local result = attachments(node, duration, session)
    result[#result+1] = {id="completion_effects",key="completion_effects",engine={id="completion_effects",
        prepare=CompletionEffects.prepare,ready=CompletionEffects.ready,enter=CompletionEffects.enter,
        sample=CompletionEffects.sample,guard=CompletionEffects.guard,leave_node=CompletionEffects.leave_node,
        restore=CompletionEffects.restore,status=CompletionEffects.status},resources={},node=node,retain_for_session=true,
        retained=session and session.retained_subsystems and session.retained_subsystems.completion_effects}
    result[#result+1] = {id="task_actions",key="task_actions",engine={id="task_actions",prepare=TaskActions.prepare,
        ready=TaskActions.ready,enter=TaskActions.enter,sample=TaskActions.sample,guard=TaskActions.guard,
        restore=TaskActions.restore,status=TaskActions.status},resources={},node=node,retain_for_session=true,
        retained=session and session.retained_subsystems and session.retained_subsystems.task_actions}
    result[#result+1] = {id = "gaze", key = "gaze", engine = {id = "gaze", prepare = Gaze.prepare, ready = Gaze.ready,
        enter = Gaze.enter, sample = Gaze.sample, guard = Gaze.guard, leave_node = Gaze.leave_node,
        restore = Gaze.restore, status = Gaze.status}, resources = {}, node = node,
        retain_for_session = true, retained = session and session.retained_subsystems and session.retained_subsystems.gaze}
    result[#result+1] = {id="expressions",key="expressions",engine={id="expressions",prepare=Expressions.prepare,
        ready=Expressions.ready,enter=Expressions.enter,sample=Expressions.sample,guard=Expressions.guard,
        leave_node=Expressions.leave_node,restore=Expressions.restore,status=Expressions.status},resources={},node=node,
        retain_for_session=true,retained=session and session.retained_subsystems and session.retained_subsystems.expressions}
    result[#result+1] = {id="sfx",key="sfx",engine={id="sfx",prepare=Sfx.prepare,ready=Sfx.ready,
        enter=Sfx.enter,sample=Sfx.sample,guard=Sfx.guard,leave_node=Sfx.leave_node,restore=Sfx.restore,status=Sfx.status},
        resources=Sfx.load(node),node=node}
    result[#result+1] = {id="voices",key="voices",engine={id="voices",prepare=Voices.prepare,ready=Voices.ready,
        enter=Voices.enter,sample=Voices.sample,guard=Voices.guard,leave_node=Voices.leave_node,restore=Voices.restore,status=Voices.status},
        resources=Voices.load(node),node=node}
    local Response=require('SceneZOI.VoiceResponses')
    result[#result+1]={id='voice_responses',key='voice_responses',engine={id='voice_responses',prepare=Response.prepare,
        ready=Response.ready,enter=Response.enter,sample=Response.sample,guard=Response.guard,leave_node=Response.leave_node,
        restore=Response.restore,status=Response.status},resources={},node=node,retain_for_session=true,
        retained=session and session.retained_subsystems and session.retained_subsystems.voice_responses}
    return result
end

local function add(host, session, loaded_item)
    local item = loaded_item.retained or {id = loaded_item.id, key = loaded_item.key, engine = loaded_item.engine, context = loaded_item.resources}
    local context = item.context
    for key, value in pairs(loaded_item.resources) do context[key] = value end
    -- An absent optional animation also clears the previous node's track.
    context.attachment_animation = loaded_item.resources.attachment_animation
    context.node, context.participants = loaded_item.node, session.participants
    context.defer_visibility = true
    item.owner_id = loaded_item.owner_id or item.owner_id
    item.retain_for_session = loaded_item.retain_for_session == true or
        (item.engine.id == "attachment" and context.node.attachment.retain_for_session == true)
    if item.retain_for_session then host.retained[item.key] = item end
    host.items[#host.items + 1] = item
end

function M.new(session, loaded)
    session.retained_subsystems = session.retained_subsystems or {}
    local host = setmetatable({items = {}, retained = session.retained_subsystems, session=session}, M)
    for _, loaded_item in ipairs(loaded) do add(host, session, loaded_item) end
    return host
end

function M:prepare(session)
    -- A manual outfit edit can satisfy an optional attachment condition for the
    -- first time. Evaluate after the resolved appearance barrier, using this
    -- node's declared resources; no earlier scene visit or player restart is needed.
    local present = {}
    for _, item in ipairs(self.items) do present[item.key] = true end
    for _, loaded_item in ipairs(attachments(session.node, session.duration, session, present)) do
        if not present[loaded_item.key] then add(self, session, loaded_item) end
    end
    local ready = true
    for _, item in ipairs(self.items) do
        if item.engine.id == "attachment" then
            local owner = session.bindings[item.context.node.attachment.participant]
            item.owner_id = item.owner_id or owner.id
            assert(item.owner_id == owner.id, "Attachment participant changed during the session")
        end
        local prepared = item.engine.prepare(item.context, session)
        -- Preparation can rebuild the body/parent and intentionally leave those
        -- references unavailable for several ticks. Do not inspect them early.
        if prepared == false then ready = false
        elseif not item.engine.ready(item.context) then ready = false end
    end
    return ready
end

function M:sample(position)
    for _, item in ipairs(self.items) do item.engine.sample(item.context, position) end
end

function M:keep_body_unmerged(participant, node, bindings)
    for _, item in ipairs(self.items) do
        if item.owner_id == participant.id and item.context.body_region then return true end
    end
    -- A manual edit may be the first activation. This does not load the optional
    -- assets or alter entry behavior; it only keeps that edit's native body layout.
    for _, spec in pairs(node and node.attachments or {}) do
        if spec.body_profile and bindings[spec.participant] == participant and compatible(spec,participant) then return true end
    end
    return false
end

function M:guard()
    -- A covering outfit deliberately prevents attachment creation. Its native
    -- body mask still needs protection throughout/after appearance handoffs.
    local session=self.session;local seen={};local bindings=session.bindings
    for _,spec in pairs(session.node.attachments or {})do
        bindings=bindings or Binding.resolve(session.participants,session.node)
        local owner=bindings[spec.participant]
        if owner and spec.body_profile and compatible(spec,owner)then
            local key=owner.id..'|'..spec.body_profile
            if not seen[key]then
                seen[key]=true
                owner.clothing_mask_repairs=(owner.clothing_mask_repairs or 0)+Body.guard_clothing(owner.actor,spec.body_profile)
            end
        end
    end
    for _, item in ipairs(self.items) do if item.engine.guard then item.engine.guard(item.context) end end
end

function M:begin_outfit(change)
    for _, item in ipairs(self.items) do
        if item.owner_id == change.participant.id and item.engine.begin_outfit then
            item.engine.begin_outfit(item.context, change.participant, change)
        end
    end
end

function M:enter()
    for _, item in ipairs(self.items) do item.engine.enter(item.context) end
end

local function restore(items)
    local errors = {}
    for index = #items, 1, -1 do
        local item = items[index]
        if not item.restored then
            local ok, err = pcall(item.engine.restore, item.context)
            if ok then item.restored = true else errors[#errors + 1] = tostring(err) end
        end
    end
    if #errors > 0 then error(table.concat(errors, "; ")) end
end

function M:leave_node()
    local temporary = {}
    for _, item in ipairs(self.items) do
        if item.engine.leave_node then item.engine.leave_node(item.context) end
        if not item.retain_for_session then temporary[#temporary + 1] = item end
    end
    restore(temporary)
end

function M:restore()
    local items, seen = {}, {}
    for _, item in ipairs(self.items) do items[#items + 1] = item; seen[item] = true end
    for _, item in pairs(self.retained) do if not seen[item] then items[#items + 1] = item end end
    restore(items)
end

function M:tracks(session)
    local tracks = {}
    for _, item in ipairs(self.items) do
        if item.engine.id == "attachment" and item.context.attachment_animation then
            local role = item.context.node.attachment.participant
            tracks[#tracks + 1] = {id = "attachment." .. item.id, kind = "attachment",
                participant_id = session.bindings[role].id}
        end
    end
    return tracks
end

function M:status()
    local values = {}
    for _, item in ipairs(self.items) do values[#values + 1] = item.engine.status(item.context) end
    return #values == 0 and "optional_engines=none" or table.concat(values, ":")
end

return M
