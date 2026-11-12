-- Session-owned sparse outfit layer. Never overwrite the original base styles.
local State = require("SceneZOI.OutfitState")
local Wardrobe = require("SceneZOI.Wardrobe")
local M = {}
local COSTUME = "SceneZOI_Demo_Outfit"

local function has_scene_layer(appearance)
    -- Several outfits can share Script. A newer layer can hide ours from the reason lookup.
    for _, style in ipairs(appearance:GetAppearanceSetting().Outfit.ActiveStyleList) do
        if style.Reason == inzoi.EB1ChangeOutfitReason.Script and tostring(style.Outfit.CostumeId) == COSTUME then
            return true
        end
    end
    return false
end

-- Preserve the body's section layout at the source of appearance refreshes,
-- instead of sending a merged body to B1 and rebuilding it a second time there.
function M.keep_unmerged(owner, lease)
    local appearance = assert(owner:GetComponent(inzoi.EB2ComponentType.Appearance))
    local setting = appearance:GetAppearanceSetting()
    if not lease.body_merge then
        lease.body_merge = {base = setting.Body.bUseMeshMerge, final = setting.FinalBody.bUseMeshMerge}
    end
    if not setting.Body.bUseMeshMerge and not setting.FinalBody.bUseMeshMerge then return end
    setting.Body.bUseMeshMerge, setting.FinalBody.bUseMeshMerge = false, false
    appearance:SetAppearanceSetting(setting)
end

---@param owner FB2Character
function M.recover(owner, legacy_layers)
    local legacy={};for _,name in ipairs(legacy_layers or {})do legacy[name]=true end
    if not next(legacy)then return end
    local appearance = owner:GetComponent(inzoi.EB2ComponentType.Appearance)
    if not appearance then return end
    -- Earlier live fixtures left a namespaced layer with the default Invalid reason. Remove
    -- only that exact fixture ID; never remove a generic Undressed layer owned by another mod.
    local setting = appearance:GetAppearanceSetting()
    local layers = setting.Outfit.ActiveStyleList
    -- BlueLua's native TArray supports ipairs but not Lua's length operator.
    local stale = {}
    for index, style in ipairs(layers) do
        if legacy[tostring(style.Outfit.CostumeId)] and style.Reason == inzoi.EB1ChangeOutfitReason.Invalid then
            -- Native removal ignores Invalid-reason layers; filter this fixture's stale entries only.
            stale[#stale + 1] = index
        end
    end
    for index = #stale, 1, -1 do layers:Remove(stale[index]) end
    if #stale > 0 then
        appearance:SetAppearanceSetting(setting)
        appearance:RefreshAppearance()
    end
end

local function remove_layer(appearance)
    if not has_scene_layer(appearance) then return end
    appearance:RemoveCostumeByCostumeId(COSTUME, inzoi.EB1ChangeOutfitReason.Script)
    assert(not has_scene_layer(appearance), "The scene outfit layer has not been removed")
end

---@param owner FB2Character
function M.apply(owner, lease, slots)
    local removed = State.merge(lease.removed_slots, slots)
    slots = State.slots(removed)
    local signature = table.concat(slots, ":") .. ":manual" .. (lease.wardrobe and lease.wardrobe.version or 0)
    if signature == (lease.outfit_signature or ":manual0") then return end
    -- Expanding our sparse layer is the only node change that needs an appearance refresh.
    -- Omitted instructions keep the current layer and its already-built body mesh.
    local appearance = assert(owner:GetComponent(inzoi.EB2ComponentType.Appearance),
        "Participant has no appearance component")
    -- Drop only our previous revision or a leftover layer from an earlier scene.
    remove_layer(appearance)
    lease.outfit = false
    lease.removed_slots = removed
    if #slots == 0 and not (lease.wardrobe and lease.wardrobe.version > 0) then return end
    local reason = inzoi.EB1ChangeOutfitReason.Script
    local style = inzoi.FB1StyleSetting()
    -- The game stacks Script layers by costume ID. This sparse layer leaves existing outfits in place.
    -- EmplaceActiveOutfit retains the struct's Reason; its separate argument does not assign it.
    style.Reason, style.Outfit.CostumeId = reason, COSTUME
    for _, kind in ipairs(slots) do
        local garment = inzoi.FB1GarmentDescription()
        garment.GarmentType, garment.GarmentId, garment.MeshId = kind, "None", "None"
        style.Outfit.Garments:Add(kind, garment)
    end
    Wardrobe.apply(lease, style)
    -- Automatic directives still leave hair/accessories alone. Only explicit
    -- manual choices add the captured garment/accessory/printed overrides.
    -- Mark ownership before the native call so a partial failure still gets cleanup.
    lease.outfit = true
    appearance:EmplaceActiveOutfit(style, COSTUME, reason)
    assert(tostring(appearance:GetActiveCostumeIdByReason(reason)) == COSTUME,
        "The game did not accept the prototype outfit layer")
    -- Emplace edits simulation data only; explicitly send the resolved appearance to B1.
    if lease.body_merge then M.keep_unmerged(owner, lease) end
    appearance:RefreshAppearance()
    lease.outfit_signature, lease.removed_slots = signature, removed
end

---@param owner FB2Character
function M.restore(owner, lease)
    local appearance = owner:GetComponent(inzoi.EB2ComponentType.Appearance)
    local script = inzoi.EB1ChangeOutfitReason.Script
    lease.refresh_pending = lease.refresh_pending or lease.outfit or lease.body_merge or lease.lent_costume
    -- Older saves may name a uniform the scene never took: our own layer is the proof it did.
    if lease.lent_costume and lease.recovering and has_scene_layer(appearance) then
        lease.recovery_confirmed = true
    end
    if lease.body_merge then
        local setting = appearance:GetAppearanceSetting()
        setting.Body.bUseMeshMerge, setting.FinalBody.bUseMeshMerge = lease.body_merge.base, lease.body_merge.final
        appearance:SetAppearanceSetting(setting)
    end
    if lease.outfit then
        remove_layer(appearance)
        lease.outfit = false
    end
    if lease.lent_costume then
        local now = tostring(appearance:GetActiveCostumeIdByReason(script))
        -- Something else dressed this Zoi during the scene, or the record was only a claim: leave it alone.
        if (now == "None" or now == "") and (not lease.recovering or lease.recovery_confirmed) then
            appearance:ChangeCostumeByCostumeId(lease.lent_costume, script)
        end
        lease.lent_costume = nil
    end
    if lease.refresh_pending then
        appearance:RefreshAppearance()
        lease.refresh_pending = nil
    end
    lease.body_merge = nil
    lease.outfit, lease.outfit_signature, lease.removed_slots = false, nil, nil
end

return M
