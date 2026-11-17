-- A selection changes runtime components, never the saved appearance setting.
local V = require("SceneZOI.DataValidation")
local Traits = require("SceneZOI.Traits")
local Diagnostics = require("SceneZOI.Diagnostics")
local Config = require("SceneZOI.Config")
local ClothingCoverage = require("SceneZOI.ClothingCoverage")
local M = {}
local recent_warnings = {}

local function sorted(value)
    local keys = {}
    for key in pairs(value or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

local function warning(node, owner, role, slot, id, reason)
    local fields = {scene_id=node.id, participant_id=owner and owner.id,
        participant_role=role, slot=slot, variant_id=id, detail=reason}
    for _, previous in ipairs(recent_warnings) do if V.equal(previous, fields) then return end end
    recent_warnings[#recent_warnings + 1] = fields
    if #recent_warnings > 256 then table.remove(recent_warnings, 1) end
    Diagnostics.record("appearance_variant_warning", V.copy(fields))
end

local function asset(path)
    local ok, value = pcall(function()return UE.UObject.Load(path)end)
    return ok and value ~= nil and value ~= false, value
end

local function condition(value)
    return {body=value.body, mesh_name=value.mesh_name, body_age=value.body_age,
        growth_steps=V.copy(value.growth_steps)}
end

local function owner_traits(owner, requirement)
    if owner and owner.traits then return V.copy(owner.traits) end
    if owner and owner.actor then
        local ok, traits = pcall(Traits.capture, owner.actor)
        if ok then owner.traits = traits; return V.copy(traits) end
    end
    return {body=owner and owner.body or requirement.body}
end

local function compatible(value, traits)
    return Traits.matches(condition(value), traits)
end

local function attachment_valid(value, slot, traits, profiles, node)
    if not compatible(value, traits) then return false, "The variant does not support this participant's body or life stage." end
    local spec = value.attachment
    if (spec.body_profile ~= nil) ~= (slot == "body_region") then
        return false, "Body-region replacements must use the body_region slot; other slots are ordinary attachments."
    end
    if spec.body_profile then
        local profile = profiles.body[spec.body_profile]
        if not profile then return false, "The variant's body profile is unavailable." end
        if spec.material_profile and not profiles.material[spec.material_profile] then
            return false, "The variant's material profile is unavailable."
        end
        if not asset(profile.patch_mesh) then return false, "The body profile's skin patch mesh is unavailable." end
    end
    if not asset(spec.mesh) then return false, "The selected attachment mesh is unavailable." end
    return true
end

function M.animation(node, tracks, role, slot, id, owner)
    local path = (tracks or {})[node.id]
    if not path then return nil end
    local ok, animation = asset(path)
    if not ok then
        warning(node, owner, role, slot, id, "The selected attachment's mapped animation is unavailable; keeping this mesh in its rest pose for this scene.")
        return nil
    end
    local read, length = pcall(function()return animation:GetPlayLength()end)
    if not read or type(length) ~= "number" or length <= 0 or
        math.abs(length - node.duration) > Config.max_duration_difference then
        warning(node, owner, role, slot, id, "The selected attachment's mapped animation duration does not match this scene; keeping this mesh in its rest pose.")
        return nil
    end
    return path
end

local function selected_body(node, owner, role, explicit, scene, variants, traits)
    for _, selection in ipairs({explicit or {}, scene or {}}) do
        local id = selection.body_variant
        if id == false then return nil end
        if id ~= nil then
            local value = variants.bodies[id]
            if not value then
                warning(node, owner, role, "body", id, "The requested body variant is not registered; keeping a valid default body.")
            elseif not compatible(value, traits) then
                warning(node, owner, role, "body", id, "The requested body variant does not support this participant's body or life stage.")
            else
                local available, mesh = asset(value.mesh)
                if not available then
                    warning(node, owner, role, "body", id, "The requested body mesh is unavailable; keeping a valid default body.")
                else
                    local compatible_skeleton = true
                    if owner and owner.actor then
                        local ok, native, replacement = pcall(function()
                            return owner.actor.Mesh:GetSkeletalMeshAsset():GetSkeleton(), mesh:GetSkeleton()
                        end)
                        compatible_skeleton = ok and native ~= nil and replacement ~= nil and native == replacement
                    end
                    if compatible_skeleton then
                        local compatible_layout, reason = true, nil
                        if owner and owner.actor then compatible_layout, reason = ClothingCoverage.compatible_body(owner.actor, mesh) end
                        if compatible_layout then return V.copy(value), mesh end
                        warning(node, owner, role, "body", id, tostring(reason) .. " Keeping a valid default body.")
                    else
                        warning(node, owner, role, "body", id, "The requested body mesh does not have the participant's native skeleton, or compatibility could not be verified; keeping a valid default body.")
                    end
                end
            end
        end
    end
end

local function inject(node, role, id, value, slot, owner)
    local attachment_id = id .. "." .. role
    if node.attachments[attachment_id] then return nil, "The generated attachment ID conflicts with a scene attachment." end
    local spec = V.copy(value.attachment)
    spec.participant, spec._selection_slot, spec._variant_generated = role, slot, true
    spec.when_undressed = spec.body_profile ~= nil
    spec.animation = M.animation(node, value.node_animations, role, slot, id, owner)
    spec.retained_tracks = V.copy(value.node_animations or {})
    spec._condition = condition(value)
    spec._cleanup_layers = V.copy(value.legacy_layers)
    node.attachments[attachment_id] = spec
    return attachment_id
end

local function scene_inline(node, role)
    for _, id in ipairs(sorted(node.attachments)) do
        local spec = node.attachments[id]
        if spec.participant == role and spec.body_profile then return id end
    end
end

local function select_attachment(node, owner, role, slot, explicit, scene, profiles, variants, traits)
    local requested = false
    for _, selection in ipairs({explicit or {}, scene or {}}) do
        local id = (selection.attachment_variants or {})[slot]
        if id ~= nil then
            requested = true
            if id == false then return false, true end
            local value = variants.attachments[id] or profiles.rules[id]
            local ok, reason
            if value then ok, reason = attachment_valid(value, slot, traits, profiles, node)
            else reason = "The requested attachment variant is not registered." end
            if ok then
                local attachment_id, collision = inject(node, role, id, value, slot, owner)
                if attachment_id then return attachment_id, true end
                reason = collision
            end
            warning(node, owner, role, slot, id, reason .. " Keeping a valid scene or coverage default when available.")
        end
    end
    return nil, requested
end

function M.resolve(node, participants, explicit, profiles, variants)
    profiles = profiles or {body={}, material={}, rules={}}
    variants = variants or {bodies={}, attachments={}}
    -- A catalog preview can be resolved again once actual actors are captured.
    -- Keep the authored declarations so that a provisional winner cannot erase them.
    node._variant_source_attachments = node._variant_source_attachments or V.copy(node.attachments or {})
    node.attachments = V.copy(node._variant_source_attachments)
    node._body_variants, node._attachment_slots, node._appearance_fallbacks = {}, {}, {}
    local owners = {}
    for _, owner in ipairs(participants or {}) do owners[owner.role] = owner end
    for _, role in ipairs(sorted(node.participants)) do
        local owner, requirement = owners[role], node.participants[role]
        local chosen = owner and (explicit or {})[tostring(owner.id)] or nil
        local scene = (node.appearance or {})[role]
        local traits = owner_traits(owner, requirement)
        local body, body_asset = selected_body(node, owner, role, chosen, scene, variants, traits)
        node._body_variants[role] = body
        local body_mesh_name
        if body_asset and body_asset.GetName then
            local ok, name = pcall(body_asset.GetName, body_asset)
            if ok then body_mesh_name = name end
        end
        local slots = {body_region=false}
        for slot in pairs(scene and scene.attachment_variants or {}) do slots[slot] = false end
        for slot in pairs(chosen and chosen.attachment_variants or {}) do slots[slot] = false end
        node._attachment_slots[role] = slots
        for _, slot in ipairs(sorted(slots)) do
            local selected, requested = select_attachment(node, owner, role, slot, chosen, scene, profiles, variants, traits)
            if selected ~= nil then slots[slot] = selected end
            if slot == "body_region" then
                local inline = scene_inline(node, role)
                if selected ~= nil then
                    -- Exactly one context owns masking and skin restoration for a body region.
                    for id, spec in pairs(node.attachments) do
                        if spec.participant == role and spec.body_profile and id ~= selected then node.attachments[id] = nil end
                    end
                elseif inline then
                    slots[slot] = inline
                    node.attachments[inline]._selection_slot = slot
                else
                    local candidates = {}
                    for _, id in ipairs(sorted(profiles.rules)) do
                        local rule = profiles.rules[id]
                        if compatible(rule, traits) and (not body or not rule.mesh_name or rule.mesh_name == body_mesh_name) then
                            candidates[#candidates + 1] = id
                        elseif body and rule.mesh_name and compatible(rule, traits) then
                            warning(node, owner, role, slot, id, "This coverage default targets a different body mesh; keeping the selected body without forcing an incompatible replacement.")
                        end
                    end
                    for _, id in ipairs(candidates) do
                        local rule = profiles.rules[id]
                        local ok, reason = attachment_valid(rule, slot, traits, profiles, node)
                        if ok then
                            local attachment_id, collision = inject(node, role, id, rule, slot, owner)
                            if attachment_id then
                                slots[slot] = attachment_id
                                node._appearance_fallbacks[role] = {winner=id, compatible_declarations=candidates}
                                break
                            end
                            reason = collision
                        end
                        warning(node, owner, role, slot, id, reason .. " Trying the next compatible coverage default.")
                    end
                end
            elseif selected == nil and requested then
                slots[slot] = false
            end
        end
    end
    return node
end

function M.report(current)
    local node = current.node
    if not node then return end
    current.appearance_diagnostics = current.appearance_diagnostics or {}
    for _, owner in ipairs(current.participants or {}) do
        local role = owner.role
        local body = (node._body_variants or {})[role]
        local fields = {scene_id=node.id, session_id=current.token, revision=current.revision,
            participant_id=owner.id, participant_role=role, body_variant=body and body.id or false,
            body_mesh=body and body.mesh, attachments={}}
        fields.fallback = V.copy((node._appearance_fallbacks or {})[role])
        for _, slot in ipairs(sorted((node._attachment_slots or {})[role])) do
            local id = node._attachment_slots[role][slot]
            local spec = id and (node.attachments or {})[id]
            fields.attachments[#fields.attachments + 1] = {slot=slot, attachment_id=id,
                mesh=spec and spec.mesh, body_profile=spec and spec.body_profile,
                material_profile=spec and spec.material_profile, animation=spec and spec.animation}
        end
        local key = tostring(owner.id or role)
        if not V.equal(current.appearance_diagnostics[key], fields) then
            current.appearance_diagnostics[key] = V.copy(fields)
            Diagnostics.record("appearance_resolved", V.copy(fields))
            if fields.fallback and #fields.fallback.compatible_declarations > 1 then
                Diagnostics.record("appearance_fallback_conflict", {scene_id=node.id, session_id=current.token,
                    revision=current.revision, participant_id=owner.id, participant_role=role,
                    winner=fields.fallback.winner, compatible_declarations=V.copy(fields.fallback.compatible_declarations),
                    detail="Used the first available compatible coverage declaration by ID alphabetically; unchosen declarations were not loaded."})
            end
        end
    end
end

return M
