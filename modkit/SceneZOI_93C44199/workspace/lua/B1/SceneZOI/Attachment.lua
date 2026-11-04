-- Optional skinned attachment. Component creation and cleanup retain the tested lifecycle.
local M = {}
local Body = require("SceneZOI.BodyRegion")
local Color = require("SceneZOI.MaterialMatch")
local Config = require("SceneZOI.Config")
local OutfitState = require("SceneZOI.OutfitState")
local COMPONENT_SPACE = 2
local KEEP_RELATIVE = 0
local function attachment_parent(actor,spec)
    if spec.component=="head"then return require("SceneZOI.GazeNative").head(actor)end
    return actor.Mesh
end

function M.load(node, duration)
    local spec = node.attachment
    if not spec then return nil, nil, nil end
    local asset = UE.UObject.Load(spec.mesh)
    assert(asset, "Scene attachment mesh is unavailable")
    local animation
    if spec.animation then
        animation = UE.UObject.Load(spec.animation)
        assert(animation, "Scene attachment animation is unavailable")
        assert(math.abs(animation:GetPlayLength() - duration) <= Config.max_duration_difference,
            "Attachment and participant animation durations differ")
    end
    return asset, spec.body_profile and Body.load(spec.body_profile) or nil, animation
end

local function clothes_removed(actor, context)
    local node = context.node
    local garments = actor.AppearanceComponent.AppearanceSetting.FinalStyle.Outfit.Garments
    local owner = node.attachment.participant
    local slots = context.removed_slots and OutfitState.slots(context.removed_slots)
        or (node.outfits and node.outfits[owner] and node.outfits[owner].remove_slots) or {}
    for _, kind in ipairs(slots) do
        local garment = garments:Find(kind)
        -- Final appearance can normalize both underwear slots; use the same rule
        -- as the participant appearance barrier. Replacement bodies use these slots.
        if garment and not OutfitState.base_slot(kind) then
            local id = tostring(garment.GarmentId)
            if id ~= "None" and id ~= "" then return false, kind .. ":" .. id end
        end
    end
    return true, "clothes_ready"
end

function M.status(session)
    if not session.node.attachment then return "attachment=none" end
    local attachment = session.attachment
    if attachment then
        local parent, component = attachment.parent, attachment.component
        local a, b = parent:GetSocketTransform(session.node.attachment.socket, 0), component:GetSocketTransform(session.node.attachment.reference_bone, 0)
        local mathlib, error_max = UE.UKismetMathLibrary, 0
        for _, point in ipairs({UE.FVector(0,0,0), UE.FVector(1,0,0), UE.FVector(0,1,0), UE.FVector(0,0,1)}) do
            local x, y = mathlib.TransformLocation(a, point), mathlib.TransformLocation(b, point)
            error_max = math.max(error_max, math.sqrt((x.X-y.X)^2 + (x.Y-y.Y)^2 + (x.Z-y.Z)^2))
        end
        local p = attachment.actor:K2_GetActorLocation()
        local origin = mathlib.TransformLocation(a, UE.FVector(0,0,0))
        local playback = "attachment_track=static"
        if attachment.animation then
            local position = component:GetPosition()
            playback = string.format("attachment_time=%.6f:clock_error_s=%.6f", position,
                math.abs(position - (attachment.position or 0)))
        end
        return string.format("frames=%d:bones=%d:materials=%d:pelvis_error_cm=%.6f:actor=%.1f,%.1f,%.1f:pelvis=%.1f,%.1f,%.1f:body_visible=%s:body_hidden=%s:attachment_hidden=%s",
            attachment.ready_frames, component:GetNumBones(), component:GetNumMaterials(), error_max,
            p.X,p.Y,p.Z,origin.X,origin.Y,origin.Z,tostring(parent:IsVisible()),tostring(parent.bHiddenInGame),tostring(component.bHiddenInGame)) .. ":" .. playback .. ":" .. Body.status(session) .. ":" .. Color.status(attachment) .. ":coverage_flags=" .. tostring(session.coverage_flags or 0) ..
            ":kept_visible_edits=" .. (attachment.kept_visible_edits or 0) .. ":visible_outfit_ticks=" .. (attachment.visible_outfit_ticks or 0) .. ":visibility_repairs=" .. (attachment.visibility_repairs or 0)
    end
    for _, participant in ipairs(session.participants) do
        if participant.role == session.node.attachment.participant then
            local _, detail = clothes_removed(participant.actor, session)
            return "waiting_appearance=" .. detail
        end
    end
    return "waiting_participants"
end

function M.prepare(session, actor)
    if not session.node.attachment then return true end
    if not clothes_removed(actor, session) then return false end
    if session.node.attachment.body_profile and not Body.prepare(session, actor) then return false end
    local spec = session.node.attachment
    local parent = attachment_parent(actor,spec)
    if not parent then return false end
    assert(parent and parent:GetBoneIndex(spec.socket) >= 0, "Participant has no configured socket bone")
    if session.attachment then
        local attachment = session.attachment
        if attachment.parent ~= parent then
            if attachment.component.RemoveTickPrerequisiteComponent then attachment.component:RemoveTickPrerequisiteComponent(attachment.parent)end
            assert(attachment.component:K2_AttachToComponent(parent, spec.socket, KEEP_RELATIVE, KEEP_RELATIVE, KEEP_RELATIVE, false))
            attachment.component:K2_SetRelativeTransform(attachment.offset, false, nil, true)
            attachment.component:AddTickPrerequisiteComponent(parent)
            attachment.parent, attachment.ready_frames = parent, 0
        end
        return true
    end
    -- AddComponentByClass with deferred finish=false registers the component with its owner.
    local component = actor:AddComponentByClass(UE.USkeletalMeshComponent:StaticClass(), true, UE.FTransform(), false)
    assert(component, "Could not create the attachment skeletal component")
    session.attachment = {component = component, actor = actor, parent = parent, ready_frames = 0}
    component:SetHiddenInGame(true, true)
    component:SetCollisionEnabled(0)
    component:SetGenerateOverlapEvents(false)
    component:SetSimulatePhysics(false)
    component:SetSkeletalMeshAsset(session.attachment_asset)
    assert(component:GetBoneIndex(spec.reference_bone) >= 0, "Attachment skeleton has no configured reference bone")
    -- This component has an independent skeleton; do not set the Zoi as a LeaderPose component.
    component:SetAnimationMode(1)
    local rest_reference = component:GetSocketTransform(spec.reference_bone, COMPONENT_SPACE)
    local offset = UE.UKismetMathLibrary.InvertTransform(rest_reference)
    session.attachment.offset = offset
    assert(component:K2_AttachToComponent(parent, spec.socket, KEEP_RELATIVE, KEEP_RELATIVE, KEEP_RELATIVE, false),
        "Could not attach attachment to the configured socket")
    -- Inverse bind offset cancels the attachment's own root-to-reference transform; snapping only its
    -- component origin to the target socket would apply the authored reference offset a second time.
    component:K2_SetRelativeTransform(offset, false, nil, true)
    component:AddTickPrerequisiteComponent(parent)
    M.change_animation(session)
    component:PrestreamTextures(3, true, 0)
    return false
end

function M.begin_outfit(session, owner, change)
    local attachment, spec = session.attachment, session.node.attachment
    if not attachment then return end
    local keep = not attachment.component.bHiddenInGame and spec.when_undressed and spec.body_profile and
        not Body.covered(owner.actor, spec.body_profile) and Body.after_outfit(owner, change, spec.body_profile) == false
    session.outfit_visibility_hold = keep and "visible" or "hidden"
    if keep then attachment.kept_visible_edits = (attachment.kept_visible_edits or 0) + 1
    else attachment.component:SetHiddenInGame(true, true) end
end

function M.guard(session)
    local spec = session.node.attachment
    if spec.body_profile then Body.guard(session) end
    local attachment = session.attachment
    if not attachment or not session.outfit_visibility_hold then return end
    local hidden = session.outfit_visibility_hold == "hidden" or Body.covered(attachment.actor, spec.body_profile)
    -- Also respect the actual resolved result if game normalization changes another
    -- slot, and repair child visibility resets without restarting the held track.
    if attachment.component.bHiddenInGame ~= hidden then
        attachment.component:SetHiddenInGame(hidden, true)
        if not hidden then attachment.visibility_repairs = (attachment.visibility_repairs or 0) + 1 end
    end
    if not hidden then attachment.visible_outfit_ticks = (attachment.visible_outfit_ticks or 0) + 1 end
end

-- Switch only the animation on the retained component; preserve bind offset, body patch and colors.
function M.change_animation(session)
    local attachment = assert(session.attachment, "Attachment component is missing")
    local animation = session.attachment_animation
    if attachment.animation == animation then return end
    local component = attachment.component
    component.VisibilityBasedAnimTickOption = 0
    component.bEnableUpdateRateOptimizations = false
    if animation then
        component:PlayAnimation(animation, true)
        component:SetPlayRate(0)
        component:SetPosition(0, false)
        assert(component:GetAnimInstance(), "Attachment animation instance was not initialized")
    else
        -- A static definition holds the previous frame-zero pose without an independent clock.
        component:SetPlayRate(0)
        component:SetPosition(0, false)
    end
    attachment.animation, attachment.position, attachment.ready_frames = animation, 0, 0
end

function M.ready(session)
    if not session.node.attachment then return true end
    local attachment = session.attachment
    if not attachment then return false end
    local component = attachment.component
    assert(attachment_parent(attachment.actor,session.node.attachment) == attachment.parent, "Participant attachment parent changed during preparation")
    assert(component:GetSkeletalMeshAsset() == session.attachment_asset, "Attachment mesh was replaced")
    if component:GetNumBones() == 0 or not clothes_removed(attachment.actor, session) then
        attachment.ready_frames = 0
        return false
    end
    local material_count = component:GetNumMaterials()
    local required_materials = session.node.attachment.material_profile and 2 or 1
    assert(material_count >= required_materials, "Attachment has insufficient material slots")
    for index = 0, material_count - 1 do
        if not component:GetMaterial(index) then attachment.ready_frames = 0; return false end
    end
    -- Apply participant colors while hidden, before switching body coverage or playback.
    if session.node.attachment.material_profile and not Color.ready(attachment, session.body_region, session.node.attachment.material_profile) then attachment.ready_frames = 0; return false end
    if session.node.attachment.body_profile and not Body.ready(session) then return false end
    -- This is a post-load component warm-up, not a guessed delay in place of asset loading.
    -- Framework-managed attachments warm up hidden until the body-track handoff.
    if not session.defer_visibility then component:SetHiddenInGame(false, true) end
    attachment.ready_frames = attachment.ready_frames + 1
    return attachment.ready_frames >= 3
end

-- Commit with the body tracks in one B1 update. A retained component keeps its
-- outgoing pose throughout preparation; a new component warms up while hidden.
function M.enter(session)
    M.change_animation(session)
    session.outfit_visibility_hold = nil
    session.attachment.component:SetHiddenInGame(session.hide_attachment == true, true)
end

function M.sample(session, position)
    if not session.attachment_animation then return end
    local attachment = assert(session.attachment, "Animated attachment component is missing")
    assert(attachment.component:GetAnimationMode() == 1, "Attachment animation mode changed")
    -- No independent playback clock: use precisely the same wrapped time as both montages.
    -- Suppress notifies when seeking, especially when crossing the loop boundary.
    attachment.component:SetPosition(position, false)
    attachment.position = position
end

function M.restore(session)
    Body.restore(session)
    local attachment = session.attachment
    if not attachment then return end
    attachment.component:K2_DestroyComponent(attachment.actor)
    session.attachment = nil
end

return M
