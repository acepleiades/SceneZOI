-- Which scene sessions exist and which one the controls show. Sessions are addressed by ID.
local M = {}
local by_token, order, current = {}, {}, nil

function M.reset()
    by_token, order, current = {}, {}, nil
end

function M.add(session)
    assert(not by_token[session.token], "Duplicate scene session")
    by_token[session.token] = session
    order[#order + 1] = session
end

function M.remove(session)
    if by_token[session.token] ~= session then return false end
    by_token[session.token] = nil
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

function M.holding(id)
    for _, session in ipairs(order) do
        for _, participant in ipairs(session.participant_ids) do
            if participant == id then return session end
        end
    end
end

return M
