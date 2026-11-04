-- Wait for the actual resolved clothing and a stable game-owned animation instance.
-- Scene changes preserve removed slots; the session release restores the original layer.
local State = require("SceneZOI.OutfitState")
local M = {}
local SLOTS = {"Top", "Bottom", "Full", "Jacket", "Shoes", "Socks", "InnerTop", "InnerUnder", "Stockings", "Gloves", "Scarf"}

local function garments(actor)
    return actor.AppearanceComponent.AppearanceSetting.FinalStyle.Outfit.Garments
end

local function id(map, slot)
    local garment = map:Find(slot)
    if not garment then return "None" end
    local value = tostring(garment.GarmentId or "None")
    if value == "None" or value == "" then value = tostring(garment.MeshId or "None") end
    return value == "" and "None" or value
end

function M.capture(participant)
    local map, original = garments(participant.actor), {}
    for _, slot in ipairs(SLOTS) do original[slot] = id(map, slot) end
    participant.original_garments, participant.removed_slots = original, {}
    participant.original_outfit_metadata = {}
    for slot, garment in pairs(map:ToTable()) do
        slot = tostring(slot)
        -- Plain values only; never retain native appearance structs across refreshes.
        participant.original_outfit_metadata[slot] = {asset = id(map, slot), flags = garment.BodyFlags}
    end
end

function M.ready(session)
    local settled, waiting = true, {}
    for _, participant in ipairs(session.participants) do
        if session.require_resolved_outfit and participant.outfit_revision ~= session.revision then
            settled = false
            waiting[#waiting + 1] = (participant.id or participant.role) .. ".outfit_result_unacknowledged"
        end
        local map = garments(participant.actor)
        local directive = session.node.outfits and session.node.outfits[participant.role]
        local removed = session.outfit_change and participant.removed_slots or
            State.merge(participant.removed_slots, directive and directive.remove_slots)
        participant.removed_slots = removed
        for _, slot in ipairs(SLOTS) do
            local value = id(map, slot)
            local expected = participant.expected_garments and participant.expected_garments[slot]
            if expected then
                -- Explicitly removed base underwear may still provide normalized
                -- replacement-body geometry. Keep that established exception.
                if not (State.base_slot(slot) and removed[slot]) and value ~= expected then
                    settled = false
                    waiting[#waiting + 1] = (participant.id or participant.role) .. "." .. slot .. "=" .. value .. ":expected_resolved=" .. expected
                end
            elseif removed[slot] then
                if not State.base_slot(slot) and value ~= "None" and value ~= "" then
                    settled = false
                    waiting[#waiting + 1] = (participant.id or participant.role) .. "." .. slot .. "=" .. value
                end
            elseif value ~= participant.original_garments[slot] then
                settled = false
                waiting[#waiting + 1] = (participant.id or participant.role) .. "." .. slot .. "=" .. value .. ":expected_original"
            end
        end
        -- Extra garment slots and both accessory kinds use the captured inventory.
        -- Normalized base underwear follows the existing replacement-body policy.
        local outfit = participant.actor.AppearanceComponent.AppearanceSetting.FinalStyle.Outfit
        for _, item in pairs(participant.outfit_items or {}) do
            local value
            if item.kind == "garment" then
                local description = outfit.Garments:Find(item.key)
                value = description and tostring(description.GarmentId)
                if description and (value == "None" or value == "") then value = tostring(description.MeshId or "None") end
            elseif item.kind == "accessory" then
                local description = outfit.Accessories:Find(item.key)
                value = description and tostring(description.AccessoryId)
                if description and (value == "None" or value == "") then value = tostring(description.AccessoryMeshId or "None") end
            elseif item.kind == "printed" then
                local index, bone = item.key:match("^(%d+)/(.*)$")
                local description = index and outfit.PrintedAccessories[tonumber(index)]
                local data = description and description.PrintedAccessoryData:Find(bone)
                value = data and tostring(data.PrintedAccessoryId)
            end
            local base_removed = item.kind == "garment" and State.base_slot(item.key) and not item.enabled
            local actual = value and value ~= "" and value or "None"
            local mismatch = item.expected_asset and actual ~= item.expected_asset or
                not item.expected_asset and ((item.enabled and actual ~= item.asset) or (not item.enabled and actual ~= "None"))
            if not base_removed and mismatch then
                settled = false
                waiting[#waiting + 1] = participant.id .. "." .. item.kind .. "." .. item.key .. "=" .. tostring(value)
            end
        end
        local instance = participant.actor.Mesh:GetAnimInstance()
        if not instance or instance ~= participant.settling_instance then
            settled = false
            waiting[#waiting + 1] = (participant.id or participant.role) .. ".animation_instance_unsettled"
        end
        participant.settling_instance = instance
    end
    session.appearance_frames = settled and (session.appearance_frames or 0) + 1 or 0
    session.appearance_wait = #waiting > 0 and table.concat(waiting, ",")
        or session.appearance_frames >= 3 and "ready" or "settling"
    return session.appearance_frames >= 3
end

function M.status(session)
    return "appearance=" .. (session.appearance_wait or "not_checked")
end

return M
