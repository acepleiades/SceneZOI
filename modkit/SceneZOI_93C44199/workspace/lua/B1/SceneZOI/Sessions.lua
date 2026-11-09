-- Which scene sessions exist and which one the controls show. Sessions are addressed by ID.
local M = {}
local by_token, order, current = {}, {}, nil
-- Who holds what, by session ID or pending-start key. Held until cleanup finishes.
local zois, furniture = {}, {}

function M.reset()
    by_token, order, current = {}, {}, nil
    zois, furniture = {}, {}
end

-- All or nothing: a start owns its whole roster and furniture, or none of it.
function M.reserve(key, ids, furniture_id)
    for _, id in ipairs(ids) do
        if zois[id] and zois[id] ~= key then return false, "participant_busy" end
    end
    if furniture_id and furniture[furniture_id] and furniture[furniture_id] ~= key then
        return false, "furniture_unavailable"
    end
    for _, id in ipairs(ids) do zois[id] = key end
    if furniture_id then furniture[furniture_id] = key end
    return true
end

function M.transfer(from, to)
    for id, key in pairs(zois) do if key == from then zois[id] = to end end
    for id, key in pairs(furniture) do if key == from then furniture[id] = to end end
end

function M.release(key)
    for id, holder in pairs(zois) do if holder == key then zois[id] = nil end end
    for id, holder in pairs(furniture) do if holder == key then furniture[id] = nil end end
end

function M.holder(id) return zois[id] end
function M.furniture_holder(id) return furniture[id] end

function M.add(session)
    assert(not by_token[session.token], "Duplicate scene session")
    by_token[session.token] = session
    order[#order + 1] = session
end

function M.remove(session)
    if by_token[session.token] ~= session then return false end
    by_token[session.token] = nil
    M.release(session.token)
    for index, candidate in ipairs(order) do
        if candidate == session then table.remove(order, index); break end
    end
    if current == session then current = nil end
    return true
end

function M.get(token) return token and by_token[token] or nil end
function M.has(session) return session ~= nil and by_token[session.token] == session end
function M.count() return #order end

-- A copy, so a session can end while callers walk the list.
function M.list()
    local copy = {}
    for index, session in ipairs(order) do copy[index] = session end
    return copy
end

function M.focused() return current end
function M.focus(session) current = session end

return M
