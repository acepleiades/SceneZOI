-- Session-owned sparse outfit layer. Never overwrite the original base styles.
local State = require("SceneZOI.OutfitState")
local Wardrobe = require("SceneZOI.Wardrobe")
local M = {}
local COSTUME = "SceneZOI_Demo_Outfit"

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

local function remove_layer(owner, lease)
    if not lease.outfit then return end
    local appearance = assert(owner:GetComponent(inzoi.EB2ComponentType.Appearance))
    appearance:RemoveCostumeByCostumeId(COSTUME, inzoi.EB1ChangeOutfitReason.Script)
    assert(tostring(appearance:GetActiveCostumeIdByReason(inzoi.EB1ChangeOutfitReason.Script)) ~= COSTUME,
        "The scene outfit layer has not been removed")
    lease.outfit = false
end

---@param owner FB2Character
function M.apply(owner, lease, slots)
    local removed = State.merge(lease.removed_slots, slots)
    slots = State.slots(removed)
    local signature = table.concat(slots, ":") .. ":manual" .. (lease.wardrobe and lease.wardrobe.version or 0)
    if signature == (lease.outfit_signature or ":manual0") then return end
    -- Expanding our sparse layer is the only node change that needs an appearance refresh.
    -- Omitted instructions keep the current layer and its already-built body mesh.
    remove_layer(owner, lease)
    lease.removed_slots = removed
    if #slots == 0 and not (lease.wardrobe and lease.wardrobe.version > 0) then return end
    local appearance = owner:GetComponent(inzoi.EB2ComponentType.Appearance)
    assert(appearance, "Participant has no appearance component")
    local reason = inzoi.EB1ChangeOutfitReason.Script
    local previous = tostring(appearance:GetActiveCostumeIdByReason(reason))
    -- A leftover of ours from an earlier scene: this lease has no record of it, and nothing else uses the id.
    if previous == COSTUME then
        appearance:RemoveCostumeByCostumeId(COSTUME, reason)
        previous = tostring(appearance:GetActiveCostumeIdByReason(reason))
    end
    -- Script is a shared game reason. Refuse to replace another system's existing layer.
    assert(previous == "None" or previous == "", "Another script already controls the participant's outfit: " .. previous)
    local style = inzoi.FB1StyleSetting()
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
    local changed = lease.outfit or lease.body_merge
    if lease.body_merge then
        local setting = appearance:GetAppearanceSetting()
        setting.Body.bUseMeshMerge, setting.FinalBody.bUseMeshMerge = lease.body_merge.base, lease.body_merge.final
        appearance:SetAppearanceSetting(setting)
    end
    if lease.outfit then
        remove_layer(owner, lease)
    end
    if changed then appearance:RefreshAppearance() end
    lease.body_merge = nil
    lease.outfit, lease.outfit_signature, lease.removed_slots = false, nil, nil
end

return M
