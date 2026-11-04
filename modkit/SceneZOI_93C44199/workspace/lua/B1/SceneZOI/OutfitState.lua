-- Undressing is additive during a session; only final release restores the base outfit.
local M = {}
local SLOTS = {"Top", "Bottom", "Full", "Jacket", "Shoes", "Socks", "InnerTop", "InnerUnder", "Stockings", "Gloves", "Scarf"}

function M.merge(previous, slots)
    local removed = {}
    for slot, value in pairs(previous or {}) do if value then removed[slot] = true end end
    for _, slot in ipairs(slots or {}) do removed[slot] = true end
    return removed
end

function M.slots(removed)
    local slots = {}
    for _, slot in ipairs(SLOTS) do if removed and removed[slot] then slots[#slots + 1] = slot end end
    local extra, known = {}, {}
    for _, slot in ipairs(SLOTS) do known[slot] = true end
    for slot, value in pairs(removed or {}) do if value and not known[slot] then extra[#extra + 1] = slot end end
    table.sort(extra)
    for _, slot in ipairs(extra) do slots[#slots + 1] = slot end
    return slots
end

-- UpdateFinalUnderwear normalizes these slots after the sparse layer is applied.
-- Replacement bodies may use their resulting default garments as body geometry.
function M.base_slot(slot)
    return slot == "InnerTop" or slot == "InnerUnder"
end

function M.undressed(removed)
    for _, slot in ipairs(SLOTS) do if not (removed and removed[slot]) then return false end end
    return true
end

-- Only explicitly conditional lower-body attachments use this visibility rule.
function M.lower_body_covered(original, removed)
    for _, slot in ipairs({"Full", "Bottom", "InnerUnder"}) do
        local id = original and original[slot]
        if id and id ~= "None" and id ~= "" and not (removed and removed[slot]) then return true end
    end
    return false
end

return M
