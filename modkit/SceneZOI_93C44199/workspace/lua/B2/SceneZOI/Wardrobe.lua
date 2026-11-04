-- Session-entry pieces, copied into native structs so later rebuilds cannot
-- mutate the originals. The script layer never edits the character's base style.
local Protocol = require("SceneZOI.Protocol")
local M = {}

local function values(map) return map and map:ToTable() or {} end
local function valid(id) return id and tostring(id) ~= "None" and tostring(id) ~= "" end
local function identity(value, kind)
    local id = kind == "garment" and value.GarmentId or value.AccessoryId
    if not valid(id) then id = kind == "garment" and value.MeshId or value.AccessoryMeshId end
    return valid(id) and tostring(id) or nil
end

function M.capture(owner, lease)
    if lease.wardrobe then return end
    local appearance = owner:GetComponent(inzoi.EB2ComponentType.Appearance)
    local source = appearance:GetAppearanceSetting().FinalStyle.Outfit
    local snapshot = inzoi.FB1StyleSetting()
    local wardrobe = {snapshot = snapshot, items = {}, by_id = {}, touched = {}, disabled = {}, version = 0}
    local function add(kind, key, label, asset, extra)
        local item = {id = "piece" .. (#wardrobe.items + 1), kind = kind, key = key, label = label, asset = asset, extra = extra}
        wardrobe.items[#wardrobe.items + 1], wardrobe.by_id[item.id] = item, item
    end
    for _, kind in ipairs({"garment", "accessory"}) do
        local map = kind == "garment" and source.Garments or source.Accessories
        local entries, keys = values(map), {}
        for key in pairs(entries) do keys[#keys + 1] = tostring(key) end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local value = entries[key]
            local asset = identity(value, kind)
            if asset then
                local target = kind == "garment" and snapshot.Outfit.Garments or snapshot.Outfit.Accessories
                target:Add(key, value)
                local custom = kind == "garment" and tostring(value.CustomGarmentName or "") or ""
                local label = key .. ": " .. (valid(custom) and custom or asset)
                add(kind, key, label, asset)
            end
        end
    end
    for index, description in ipairs(source.PrintedAccessories) do
        snapshot.Outfit.PrintedAccessories:Add(description)
        local entries, keys = values(description.PrintedAccessoryData), {}
        for key in pairs(entries) do keys[#keys + 1] = tostring(key) end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local value = entries[key]
            if valid(value.PrintedAccessoryId) then
                add("printed", tostring(index) .. "/" .. key, "Accessory: " .. tostring(value.PrintedAccessoryId),
                    tostring(value.PrintedAccessoryId), {index = index, bone = key})
            end
        end
    end
    lease.wardrobe = wardrobe
end

function M.enabled(lease, item)
    if item.kind == "garment" then return not (lease.removed_slots and lease.removed_slots[item.key]) end
    return not lease.wardrobe.disabled[item.id]
end

function M.toggle(lease, item_id, enabled)
    local wardrobe = assert(lease.wardrobe, "Starting outfit is unavailable")
    local item = wardrobe.by_id[item_id]
    if not item then return false end
    if M.enabled(lease, item) == enabled then return true end
    wardrobe.touched[item.id] = true
    if item.kind == "garment" then
        lease.removed_slots = lease.removed_slots or {}
        lease.removed_slots[item.key] = not enabled or nil
    else wardrobe.disabled[item.id] = not enabled or nil end
    wardrobe.version = wardrobe.version + 1
    return true
end

function M.apply(lease, style)
    local wardrobe = lease.wardrobe
    if not wardrobe then return end
    local printed_changed = false
    for _, item in ipairs(wardrobe.items) do
        if wardrobe.touched[item.id] then
            if item.kind == "garment" and M.enabled(lease, item) then
                style.Outfit.Garments:Add(item.key, wardrobe.snapshot.Outfit.Garments:Find(item.key))
            elseif item.kind == "accessory" then
                local description = wardrobe.snapshot.Outfit.Accessories:Find(item.key)
                if not M.enabled(lease, item) then
                    description = inzoi.FB1AccessoryDescription()
                    description.AccessoryType, description.AccessoryId, description.AccessoryMeshId = item.key, "None", "None"
                end
                style.Outfit.Accessories:Add(item.key, description)
            elseif item.kind == "printed" then printed_changed = true end
        end
    end
    if printed_changed then
        for index, original in ipairs(wardrobe.snapshot.Outfit.PrintedAccessories) do
            local description = inzoi.FB1PrintedAccessoryDescription()
            description.PrintedAccessoryName, description.bHasUnlockedItems = original.PrintedAccessoryName, original.bHasUnlockedItems
            local kept = 0
            for key, value in pairs(values(original.PrintedAccessoryData)) do
                local enabled = true
                for _, item in ipairs(wardrobe.items) do
                    if item.kind == "printed" and item.extra.index == index and item.extra.bone == tostring(key) then
                        enabled = M.enabled(lease, item); break
                    end
                end
                if enabled then description.PrintedAccessoryData:Add(key, value); kept = kept + 1 end
            end
            if kept == 0 then description.PrintedAccessoryName = "None" end
            style.Outfit.PrintedAccessories:Add(description)
        end
    end
end

function M.inventory(owner, lease)
    local rows = {}
    for _, item in ipairs(lease.wardrobe.items) do
        rows[#rows + 1] = table.concat({item.id, item.kind, Protocol.encode(item.key), Protocol.encode(item.label),
            M.enabled(lease, item) and "1" or "0", Protocol.encode(item.asset)}, ":")
    end
    local name = tostring(owner:GetFirstName()) .. " " .. tostring(owner:GetLastName())
    local slots = require("SceneZOI.OutfitState").slots(lease.removed_slots)
    for index, slot in ipairs(slots) do slots[index] = Protocol.encode(slot) end
    -- The game resolves underwear, full outfits and accessory conflicts after
    -- applying a layer. B1 must wait for this result, not an unchanged entry
    -- outfit that can no longer be produced by the game's resolver.
    local source = owner:GetComponent(inzoi.EB2ComponentType.Appearance):GetAppearanceSetting().FinalStyle.Outfit
    local expected = {}
    for _, slot in ipairs({"Top", "Bottom", "Full", "Jacket", "Shoes", "Socks", "InnerTop", "InnerUnder", "Stockings", "Gloves", "Scarf"}) do
        local value = source.Garments:Find(slot)
        expected[#expected + 1] = "g." .. Protocol.encode(slot) .. ":" .. Protocol.encode(value and identity(value, "garment") or "None")
    end
    for _, item in ipairs(lease.wardrobe.items) do
        local value
        if item.kind == "garment" then
            local description = source.Garments:Find(item.key)
            value = description and identity(description, "garment")
        elseif item.kind == "accessory" then
            local description = source.Accessories:Find(item.key)
            value = description and identity(description, "accessory")
        elseif item.kind == "printed" then
            local description = source.PrintedAccessories[item.extra.index]
            local data = description and description.PrintedAccessoryData:Find(item.extra.bone)
            value = data and valid(data.PrintedAccessoryId) and tostring(data.PrintedAccessoryId) or nil
        end
        expected[#expected + 1] = "p." .. item.id .. ":" .. Protocol.encode(value or "None")
    end
    return Protocol.pack(lease.token, "outfit", lease.outfit_counter or 0, lease.revision,
        #slots > 0 and table.concat(slots, ":") or "none", Protocol.encode(name), #rows > 0 and table.concat(rows, "+") or "none",
        table.concat(expected, "+"))
end

return M
