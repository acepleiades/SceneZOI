-- Optional pack-declared region replacement. Geometry/layout assumptions are data.
local M = {}
local Profiles=require("SceneZOI.Profiles")

local function coverage(flags, profile)
    local SECTION=profile.coverage_bit
    flags = flags & 0xffffffff
    -- Mirror the game's CombineBodyFlags skeleton-preservation exception.
    if profile.full_coverage_exception and flags == 0xffffffff then flags = flags & ~(1 << SECTION) end
    return (flags & (1 << SECTION)) ~= 0, flags
end

-- Resolved coverage bits and render sections are configured independently.
-- Read every resolved garment, including normalized underwear and custom slots;
-- a category name alone does not establish which body sections it hides.
function M.covered(actor, profile)
    profile=Profiles.body(profile)
    local flags = 0
    local garments = actor.AppearanceComponent.AppearanceSetting.FinalStyle.Outfit.Garments
    for _, garment in pairs(garments:ToTable()) do flags = flags | (garment.BodyFlags or 0) end
    return coverage(flags,profile)
end

-- Predict only from the captured starting piece and current resolved garments.
-- Unknown/mismatched metadata returns nil, retaining the conservative hidden path.
function M.after_outfit(owner, change, profile)
    local profile_id=profile
    profile=Profiles.body(profile)
    local piece = change.piece
    if not piece then return nil end
    if piece.kind ~= "garment" then return M.covered(owner.actor, profile_id) end
    local replacement = 0
    if change.enabled == "1" then
        local original = owner.original_outfit_metadata and owner.original_outfit_metadata[piece.key]
        if not original or original.asset ~= piece.asset or type(original.flags) ~= "number" then return nil end
        replacement = original.flags
    end
    local flags = replacement
    local garments = owner.actor.AppearanceComponent.AppearanceSetting.FinalStyle.Outfit.Garments
    for slot, garment in pairs(garments:ToTable()) do
        if tostring(slot) ~= piece.key then flags = flags | (garment.BodyFlags or 0) end
    end
    return coverage(flags,profile)
end

function M.load(profile)
    profile=Profiles.body(profile)
    local asset = UE.UObject.Load(profile.patch_mesh)
    assert(asset, "Stock skin patch is unavailable; install the supplying content pack")
    return asset
end

local function visibility_record(body, mesh)
    local SECTION=body.profile.section
    local asset = mesh:GetSkeletalMeshAsset()
    body.masked = body.masked or {}
    for _, record in ipairs(body.masked) do
        if record.mesh == mesh and record.asset == asset then return record end
    end
    local record = {mesh = mesh, asset = asset, visibility = {}}
    for lod = 0, mesh:GetNumLODs() - 1 do
        record.visibility[#record.visibility + 1] = {lod = lod, shown = mesh:IsMaterialSectionShown(SECTION, lod)}
    end
    body.masked[#body.masked + 1] = record
    return record
end

local function hide_section(body, mesh)
    local SECTION=body.profile.section
    local record = visibility_record(body, mesh)
    for _, state in ipairs(record.visibility) do
        if mesh:IsMaterialSectionShown(SECTION, state.lod) then mesh:ShowMaterialSection(SECTION, SECTION, false, state.lod) end
    end
end

-- Runs every B1 update after coverage is first committed, independently of outfit
-- acknowledgement, material readiness, game pause and the appearance barrier.
function M.guard(session)
    local body = session.body_region
    if not body or not body.coverage_committed then return end
    local profile=body.profile;local SECTION=profile.section
    local mesh = body.actor.Mesh
    local asset = mesh and mesh:GetSkeletalMeshAsset()
    if not asset or mesh:GetNumMaterials() < profile.minimum_materials or asset:GetName() ~= profile.mesh_name or
        mesh:GetMaterialIndex(profile.material_slot) ~= SECTION then return end
    hide_section(body, mesh)
    body.guard_ticks = (body.guard_ticks or 0) + 1
end

-- Clothing owns these hidden regions even when a coverage attachment is skipped.
-- Appearance rebuilds can reset the render mask after manual edits. Reassert only
-- declared, layout-validated regions currently covered by the resolved outfit.
-- Do not force exposed regions visible: replacement/other owners may mask them.
function M.guard_clothing(actor,profile_id)
    if not M.covered(actor,profile_id)then return 0 end
    local profile=Profiles.body(profile_id);local mesh=actor.Mesh
    local asset=mesh and mesh:GetSkeletalMeshAsset()
    if not asset or mesh:GetNumMaterials()<profile.minimum_materials or asset:GetName()~=profile.mesh_name or
        mesh:GetMaterialIndex(profile.material_slot)~=profile.section then return 0 end
    local repairs=0
    for lod=0,mesh:GetNumLODs()-1 do
        if mesh:IsMaterialSectionShown(profile.section,lod)then
            mesh:ShowMaterialSection(profile.section,profile.section,false,lod);repairs=repairs+1
        end
    end
    return repairs
end

local function configure_patch(session, body)
    local profile=body.profile;local SECTION=profile.section
    local actor, parent = body.actor, body.mesh
    local patch = actor:AddComponentByClass(UE.USkeletalMeshComponent:StaticClass(), true, UE.FTransform(), false)
    assert(patch, "Could not create stock skin patch")
    -- Retain partial creation immediately so early Exit or a failed setter still owns cleanup.
    body.patch = patch
    patch:SetHiddenInGame(true, true)
    patch:SetCollisionEnabled(0)
    patch:SetGenerateOverlapEvents(false)
    patch:SetSimulatePhysics(false)
    patch:SetSkeletalMeshAsset(session.patch_asset)
    assert(patch:GetMaterialIndex(profile.patch_material_slot) == SECTION, "Unexpected stock patch section layout")
    assert(patch:K2_AttachToComponent(parent, "None", 0, 0, 0, false), "Could not attach stock skin patch")
    -- This asset retains the full stock body origin. It follows the mesh root, not the pelvis;
    -- a pelvis attachment would apply the body's authored root-to-pelvis offset twice.
    patch:K2_SetRelativeTransform(UE.FTransform(), false, nil, true)
    patch:SetLeaderPoseComponent(parent, true, false)
    patch:AddTickPrerequisiteComponent(parent)
    for slot = 0, patch:GetNumMaterials() - 1 do patch:SetMaterial(slot, body.material) end
    for lod = 0, patch:GetNumLODs() - 1 do
        for slot = 0, patch:GetNumMaterials() - 1 do
            patch:ShowMaterialSection(slot, slot, slot == SECTION, lod)
        end
    end
    -- Pose sharing covers final deformation bones; the one stock muscle morph is separate.
    if profile.morph then patch:SetMorphTarget(profile.morph, parent:GetMorphTarget(profile.morph), true)end
    patch:PrestreamTextures(3, true, 0)
    body.patch_frames = 0
end

function M.prepare(session, actor)
    local profile=Profiles.body(session.node.attachment.body_profile);local SECTION=profile.section
    if not session.body_region then
        local setting = actor.AppearanceComponent.AppearanceSetting
        session.body_region = {actor = actor, profile=profile, base_merge = setting.Body.bUseMeshMerge,
            final_merge = setting.FinalBody.bUseMeshMerge, frames = 0}
        -- Runtime merging collapses all skin sections into one material slot. Ask the game's
        -- appearance builder for its unmerged body before Runtime captures the settled instance.
        setting.Body.bUseMeshMerge = false
        setting.FinalBody.bUseMeshMerge = false
        actor.AppearanceComponent:RefreshAll()
        return false
    end
    local body = session.body_region
    if body.mesh and (actor.Mesh ~= body.mesh or actor.Mesh:GetSkeletalMeshAsset() ~= body.asset) then
        if body.patch then body.patch:K2_DestroyComponent(actor); body.patch = nil end
        -- Keep retired geometry masked until final release. Re-enabling it here
        -- can expose the replacement geometry while the old component still draws.
        body.mesh, body.asset, body.frames = nil, nil, 0
    end
    local setting = actor.AppearanceComponent.AppearanceSetting
    if setting.Body.bUseMeshMerge or setting.FinalBody.bUseMeshMerge then
        -- A B2 outfit refresh sends its body settings back to B1 as well. Keep the
        -- active compatibility profile unmerged after that refresh; do not replace
        -- the session-entry merge snapshot used by restore.
        setting.Body.bUseMeshMerge = false
        setting.FinalBody.bUseMeshMerge = false
        body.frames, body.patch_frames = 0, 0
        body.merge_resets = (body.merge_resets or 0) + 1
        actor.AppearanceComponent:RefreshAll()
        return false
    end
    body.frames = body.frames + 1
    if body.frames < 3 or actor.Mesh:GetNumMaterials() < profile.minimum_materials then return false end
    -- A newly rebuilt mesh can expose its slots before the appearance builder installs
    -- its skin MID. Wait for that actual resource instead of treating three ticks as proof.
    local material = actor.Mesh:GetMaterial(SECTION)
    if not material then return false end
    if not body.patch then
        local mesh = actor.Mesh
        assert(mesh:GetSkeletalMeshAsset():GetName() == profile.mesh_name, "Unexpected mesh for region profile")
        assert(mesh:GetMaterialIndex(profile.material_slot) == SECTION, "Configured region material slot is unavailable")
        body.mesh, body.asset, body.material = mesh, mesh:GetSkeletalMeshAsset(), material
        body.visibility = visibility_record(body, mesh).visibility
        configure_patch(session, body)
    end
    return true
end

function M.ready(session)
    local profile=session.body_region and session.body_region.profile;local SECTION=profile and profile.section
    local body = session.body_region
    if not body or not body.mesh or not body.patch then return false end
    assert(body.actor.Mesh == body.mesh and body.mesh:GetSkeletalMeshAsset() == body.asset,
        "Participant body changed during skin patch preparation")
    local material = body.mesh:GetMaterial(SECTION)
    if not material then body.patch_frames = 0; return false end
    if material ~= body.material then
        body.material, body.patch_frames = material, 0
        for slot = 0, body.patch:GetNumMaterials() - 1 do body.patch:SetMaterial(slot, material) end
    end
    if body.patch:GetNumBones() == 0 or body.patch:GetMaterial(SECTION) ~= body.material then
        body.patch_frames = 0
        return false
    end
    body.patch_frames = body.patch_frames + 1
    if body.patch_frames < 3 then return false end
    if profile.morph then body.patch:SetMorphTarget(profile.morph, body.mesh:GetMorphTarget(profile.morph), true)end
    -- Switch coverage only when the replacement is ready, preventing a temporary visible hole.
    hide_section(body, body.mesh)
    for _, state in ipairs(body.visibility) do
        assert(not body.mesh:IsMaterialSectionShown(SECTION, state.lod), "Configured region did not hide")
    end
    body.patch:SetHiddenInGame(false, true)
    body.coverage_committed = true
    return true
end

function M.status(session)
    local body = session.body_region
    if not body then return "body=waiting" end
    local SECTION=body.profile.section
    if not body.patch then
        local setting = body.actor.AppearanceComponent.AppearanceSetting
        return string.format("body=unmerging:frames=%d:materials=%d:base_merge=%s:final_merge=%s",
            body.frames, body.actor.Mesh:GetNumMaterials(), tostring(setting.Body.bUseMeshMerge),
            tostring(setting.FinalBody.bUseMeshMerge))
    end
    local mathlib, error_max = UE.UKismetMathLibrary, 0
    for _, name in ipairs({"pelvis", "spine_01", "thigh_l", "thigh_r"}) do
        local point = UE.FVector(0, 0, 0)
        local a = mathlib.TransformLocation(body.mesh:GetSocketTransform(name, 0), point)
        local b = mathlib.TransformLocation(body.patch:GetSocketTransform(name, 0), point)
        error_max = math.max(error_max, math.sqrt((a.X-b.X)^2 + (a.Y-b.Y)^2 + (a.Z-b.Z)^2))
    end
    return string.format("patch_frames=%d:patch_pose_error_cm=%.6f:region_shown=%s:merge_resets=%d:guard_ticks=%d", body.patch_frames,
        error_max, tostring(body.mesh:IsMaterialSectionShown(SECTION, 0)), body.merge_resets or 0, body.guard_ticks or 0)
end

function M.restore(session)
    local SECTION=session.body_region and session.body_region.profile.section
    local body = session.body_region
    if not body then return end
    if body.patch then
        body.patch:K2_DestroyComponent(body.actor)
        body.patch = nil
    end
    for _, record in ipairs(body.masked or {}) do
        if record.mesh:GetSkeletalMeshAsset() == record.asset then
            for _, state in ipairs(record.visibility) do record.mesh:ShowMaterialSection(SECTION, SECTION, state.shown, state.lod) end
        end
    end
    local setting = body.actor.AppearanceComponent.AppearanceSetting
    setting.Body.bUseMeshMerge = body.base_merge
    setting.FinalBody.bUseMeshMerge = body.final_merge
    -- B2 outfit removal refreshes appearance after Native.restore stops its montage. Calling
    -- RefreshAll here would replace that instance too early and break retryable cleanup.
    session.body_region = nil
end

return M
