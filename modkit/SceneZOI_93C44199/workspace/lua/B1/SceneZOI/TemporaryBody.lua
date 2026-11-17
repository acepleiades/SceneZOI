-- Body variants change only the rendered component. Native appearance data is
-- never rewritten, so a save cannot acquire a reference to the provider's body.
local Diagnostics = require("SceneZOI.Diagnostics")
local ClothingCoverage = require("SceneZOI.ClothingCoverage")
local M = {}

local function path(value)
    if type(value) == "string" then return value end
    local asset = value.AssetPath
    local package = tostring(asset.PackageName)
    return package == "None" and "" or package .. "." .. tostring(asset.AssetName)
end

local function configured(actor)
    local setting = actor.AppearanceComponent.AppearanceSetting
    local override = path(setting.FinalBody.OverrideMesh)
    return override ~= "" and override or path(setting.FinalBody.BodyData.BodyMesh)
end

local function base_path(actor)
    return path(actor.AppearanceComponent.AppearanceSetting.Body.OverrideMesh)
end

local function list(value)
    return value and value:ToTable() or {}
end

local function morphs(mesh, asset)
    local result = {}
    for _, morph in ipairs(list(asset.MorphTargets)) do
        local name = morph:GetName()
        result[name] = mesh:GetMorphTarget(name)
    end
    return result
end

local function capture(current, participant, mesh, asset)
    local original = {asset = asset, slots = {}, morphs = morphs(mesh, asset),
        physics_override = mesh.PhysicsAssetOverride, physics = mesh.PhysicsAssetOverride or asset.PhysicsAsset}
    local subsystem = current.subsystems
    local native_visibility = subsystem and subsystem.body_visibility and
        subsystem:body_visibility(participant, mesh, asset)
    local clothing_visibility = ClothingCoverage.original_visibility(current, participant, mesh, asset)
    for index, name in ipairs(list(mesh:GetMaterialSlotNames())) do
        local slot, visibility = index - 1, {}
        for lod = 0, mesh:GetNumLODs() - 1 do
            visibility[lod] = mesh:IsMaterialSectionShown(slot, lod)
            -- A retained region attachment may currently hide this native body.
            -- Preserve its original visibility, including garment-hidden false.
            local owned = native_visibility and native_visibility[slot]
            if owned and owned[lod] ~= nil then visibility[lod] = owned[lod] end
            -- The clothing mask is another SceneZOI-owned rendering layer. Keep
            -- its native baseline, then reapply both masks to the chosen body.
            owned = clothing_visibility and clothing_visibility[slot]
            if owned and owned[lod] ~= nil then visibility[lod] = owned[lod] end
        end
        original.slots[tostring(name)] = {index = slot, material = mesh:GetMaterial(slot), visibility = visibility}
    end
    return original
end

local function skin(mesh, asset, original, restoring)
    for name, source in pairs(original.slots) do
        local slot = mesh:GetMaterialIndex(name)
        if slot >= 0 then
            mesh:SetMaterial(slot, source.material)
            for lod = 0, mesh:GetNumLODs() - 1 do
                local shown = source.visibility[lod]
                if shown == nil then shown = source.visibility[0] end
                mesh:ShowMaterialSection(slot, slot, shown, lod)
            end
        end
    end
    for _, morph in ipairs(list(asset.MorphTargets)) do
        local name = morph:GetName()
        if original.morphs[name] ~= nil then mesh:SetMorphTarget(name, original.morphs[name], true) end
    end
    -- The chosen geometry must not discard the character's native physics setup.
    -- Restoring nil reinstates the original mesh's own default physics asset.
    local physics = original.physics
    if restoring then physics = original.physics_override end
    mesh:SetPhysicsAsset(physics, false)
end

local function record_for(current, participant)
    current.temporary_bodies = current.temporary_bodies or {}
    local key = participant.id or participant.role
    local record = current.temporary_bodies[key]
    if not record then
        record = {participant = participant, owned = {}, warnings = {}}
        current.temporary_bodies[key] = record
    end
    return record
end

local function warn(current, record, definition, reason)
    local key = tostring(definition and definition.id) .. ":" .. reason
    record.wait = reason
    if record.warnings[key] then return end
    record.warnings[key] = true
    Diagnostics.record("appearance_variant_warning", {scene_id = current.node.id,
        participant_id = record.participant.id, participant_role = record.participant.role,
        slot = "body", variant_id = definition and definition.id, detail = reason})
end

local function loaded(record, definition, actual)
    -- A rendered asset is held by the native component. A Lua userdata cached
    -- across a clothing rebuild is not a GC owner, so reacquire after handoff.
    if record.loaded_path == definition.mesh and record.applied == actual then return actual end
    local ok, asset = pcall(UE.UObject.Load, definition.mesh)
    record.loaded_path = definition.mesh
    return ok and asset or nil
end

local function release_keepers(record, strict)
    local failures = {}
    for index = #(record.keepers or {}), 1, -1 do
        local keeper = record.keepers[index]
        if not record.original or record.original.keeper ~= keeper then
            local ok, failure = pcall(keeper.K2_DestroyComponent, keeper, record.participant.actor)
            if ok then table.remove(record.keepers, index)
            else failures[#failures + 1] = tostring(failure) end
        end
    end
    if strict then assert(#failures == 0, table.concat(failures, "; ")) end
end

local function keep_original(record, original)
    local actor = record.participant.actor
    local keeper = assert(actor:AddComponentByClass(UE.USkeletalMeshComponent:StaticClass(), true, UE.FTransform(), false),
        "Could not retain the native body during a temporary replacement")
    -- Lua userdata does not retain a generated mesh against native GC. This
    -- invisible, actor-owned component holds its asset and dynamic skin materials.
    record.keepers = record.keepers or {}
    record.keepers[#record.keepers + 1] = keeper
    keeper:SetHiddenInGame(true, true)
    keeper:SetCollisionEnabled(0)
    keeper:SetGenerateOverlapEvents(false)
    keeper:SetSimulatePhysics(false)
    if keeper.SetComponentTickEnabled then keeper:SetComponentTickEnabled(false) end
    keeper:SetSkeletalMeshAsset(original.asset)
    for _, slot in pairs(original.slots) do keeper:SetMaterial(slot.index, slot.material) end
    original.keeper = keeper
end

local function native_ready(actor, mesh, record)
    local setting = actor.AppearanceComponent.AppearanceSetting
    if setting.Body.bUseMeshMerge or setting.FinalBody.bUseMeshMerge then
        record.wait = "awaiting_native_unmerge_flags"; return false
    end
    local expected_path = configured(actor)
    local ok, names = pcall(function()
        local source = assert(UE.UObject.Load(expected_path))
        local result = {}
        for _, material in ipairs(list(source.Materials)) do
            assert(material.MaterialSlotName ~= nil)
            result[#result + 1] = tostring(material.MaterialSlotName)
        end
        return result
    end)
    if ok and #names > 0 then
        for _, name in ipairs(names) do
            if mesh:GetMaterialIndex(name) < 0 then
                record.wait = "awaiting_native_section_layout:" .. name; return false
            end
        end
    else
        -- Some native replacement assets do not expose material metadata. Keep
        -- their resolved unmerge flags and stable component/asset barrier visible.
        local asset = mesh:GetSkeletalMeshAsset()
        record.native_stable = record.waiting_mesh == mesh and record.waiting_asset == asset and
            (record.native_stable or 0) + 1 or 0
        record.waiting_mesh, record.waiting_asset = mesh, asset
        if record.native_stable < 3 then record.wait = "awaiting_stable_native_body"; return false end
    end
    return true, expected_path
end

local function restore_one(record)
    if not record.original then release_keepers(record, false); return true end
    local mesh = record.participant.actor.Mesh
    local asset = mesh:GetSkeletalMeshAsset()
    -- Clothing may already have rebuilt a new, valid native body. It takes
    -- precedence over the older snapshot, particularly after leaving a variant.
    if not record.owned[asset] and not record.restore_pending then
        if record.applied_physics and mesh.PhysicsAssetOverride == record.applied_physics then
            mesh:SetPhysicsAsset(record.native_physics_override, false)
        end
        record.applied_physics = nil
        record.applied, record.original = nil, nil
        release_keepers(record, false)
        return true
    end
    record.restore_pending = true
    local original = assert(record.original.keeper:GetSkeletalMeshAsset(), "The retained native body is unavailable during restoration")
    mesh:SetSkeletalMeshAsset(original)
    skin(mesh, original, record.original, true)
    record.restore_pending, record.applied, record.original, record.applied_physics = nil, nil, nil, nil
    release_keepers(record, false)
    return false
end

local function reconcile(current, participant, allow_capture)
    local definition = current.node._body_variants and current.node._body_variants[participant.role]
    local all = current.temporary_bodies
    local existing = all and all[participant.id or participant.role]
    if not definition and not existing then return true end
    local record = existing or record_for(current, participant)
    local mesh = participant.actor.Mesh
    local actual = mesh and mesh:GetSkeletalMeshAsset()
    if not actual then record.wait = "native_mesh_unavailable"; return false end
    if not definition then
        record.definition = nil
        local ready = restore_one(record)
        if not ready then current.appearance_frames = 0; participant.settling_instance = nil end
        return ready
    end
    local chosen = loaded(record, definition, actual)
    local ok, compatible = pcall(function() return chosen and chosen:GetSkeleton() == actual:GetSkeleton() end)
    if not ok or not compatible then
        warn(current, record, definition, chosen and "The body variant has an incompatible skeleton; keeping a valid native body."
            or "The body variant mesh is unavailable; keeping a valid native body.")
        record.definition = nil
        return restore_one(record)
    end
    local layout_ok, reason = ClothingCoverage.compatible_body(participant.actor, chosen)
    if not layout_ok then
        warn(current, record, definition, tostring(reason) .. " Keeping a valid native body.")
        record.definition = nil
        return restore_one(record)
    end
    if not record.original or record.mesh ~= mesh or not record.owned[actual] then
        if not allow_capture then record.wait = "native_body_rebuilt"; return false end
        -- The participant lease requests unmerged rendering. Wait for that native
        -- result before replacing geometry, otherwise garments share this mesh.
        local ready, source_path = native_ready(participant.actor, mesh, record)
        if not ready then return false end
        local original = capture(current, participant, mesh, actual)
        if record.applied_physics and original.physics_override == record.applied_physics then
            -- A native mesh rebuild can retain the component's override that we
            -- supplied. It is still ours, not a new native restoration baseline.
            original.physics_override = record.native_physics_override
            original.physics = original.physics_override or actual.PhysicsAsset
        end
        keep_original(record, original)
        record.original, record.mesh = original, mesh
        release_keepers(record, false)
        record.native_physics_override = original.physics_override
        record.native_path, record.base_path = source_path, base_path(participant.actor)
        record.restore_pending = nil
    end
    record.definition = definition.id
    if record.applied == chosen and actual == chosen then record.wait = "ready"; return true end
    local instance = mesh:GetAnimInstance()
    -- Same skeleton and same component preserve the game's animation instance.
    -- Never set an animation class, switch mode, or construct a new instance.
    record.owned[chosen], record.applied = true, chosen
    mesh:SetSkeletalMeshAsset(chosen)
    skin(mesh, chosen, record.original, false)
    record.applied_physics = record.original.physics
    assert(mesh:GetAnimInstance() == instance, "Body replacement changed the native animation instance")
    record.wait, record.changes = "settling", (record.changes or 0) + 1
    current.appearance_frames, participant.settling_instance = 0, nil
    Diagnostics.record("appearance_body_applied", {scene_id = current.node.id, participant_id = participant.id,
        participant_role = participant.role, variant_id = definition.id, rendered_mesh = chosen:GetName(),
        native_body = record.native_path, base_override_before = record.base_path,
        base_override_after = base_path(participant.actor), native_instance_preserved = true})
    return false
end

function M.prepare(current)
    local ready = true
    for _, participant in ipairs(current.participants) do
        if not reconcile(current, participant, true) then ready = false end
    end
    return ready
end

function M.guard(current)
    local ready = true
    for _, participant in ipairs(current.participants) do
        if not reconcile(current, participant, false) then ready = false end
    end
    return ready
end

function M.restore(current)
    local failures = {}
    for _, record in pairs(current.temporary_bodies or {}) do
        if not record.restored then
            local ok, failure = pcall(restore_one, record)
            if ok then ok, failure = pcall(release_keepers, record, true) end
            record.restored = ok
            if not ok then failures[#failures + 1] = tostring(failure) end
        end
    end
    assert(#failures == 0, table.concat(failures, "; "))
end

function M.status(current)
    local result = {}
    for _, record in pairs(current.temporary_bodies or {}) do
        local ok, actual = pcall(function() return record.participant.actor.Mesh:GetSkeletalMeshAsset():GetName() end)
        local base_ok, base = pcall(base_path, record.participant.actor)
        result[#result + 1] = tostring(record.participant.role) .. "=" .. tostring(record.definition or "native") ..
            ":mesh=" .. (ok and actual or "unavailable") .. ":base_override=" .. (base_ok and base or "unavailable") ..
            ":keepers=" .. tostring(#(record.keepers or {})) .. ":" .. tostring(record.wait or "native")
    end
    table.sort(result)
    return "temporary_body=" .. (#result > 0 and table.concat(result, ",") or "native")
end

return M
