-- Ask B2 to attach the native receiver before delivering the first message.
local Protocol = require("SceneZOI.Protocol")
local Controller = require("SceneZOI.Controller")
local M = {}
local generation, pending, attached
local elapsed, serial = 0, 0

function M.boot()
    generation = ("route.%d.%d"):format(os.time(), math.random(1, 999999999))
    pending, attached = {}, {}
    elapsed, serial = 0, 0
end

function M.forget(id)
    if not generation then return end
    pending[id], attached[id] = nil, nil
end

function M.send(actor, kind, content)
    local native_id = actor:GetEntityId()
    local id = Protocol.id(native_id)
    if not generation or attached[id] == actor then
        inzoi.message.send_to_sim(native_id, kind, content)
        return
    end
    local queue = pending[id]
    if not queue or queue.actor ~= actor then
        serial = serial + 1
        queue = {actor = actor, ticket = id .. ":" .. serial, messages = {}, seen = {}}
        pending[id] = queue
    end
    local key = kind .. "|" .. content
    if queue.seen[key] then return end
    queue.seen[key] = true
    queue.messages[#queue.messages + 1] = {kind, content}
end

function M.discard(kind, content)
    if not generation then return end
    local key = kind .. "|" .. content
    for id, queue in pairs(pending) do
        if queue.seen[key] then
            queue.seen[key] = nil
            for index, row in ipairs(queue.messages) do
                if row[1] == kind and row[2] == content then
                    table.remove(queue.messages, index)
                    break
                end
            end
            if #queue.messages == 0 then pending[id] = nil end
        end
    end
end

function M.tick(dt, actors)
    if not next(pending) then return end
    elapsed = elapsed + dt
    if elapsed < 0.2 then return end
    elapsed = 0
    local relay = actors[Controller.controlled_id(actors)]
    if not relay then return end
    local tickets = {}
    for _, queue in pairs(pending) do tickets[#tickets + 1] = queue.ticket end
    inzoi.message.send_to_sim(relay:GetEntityId(), "SceneZOI.Route",
        Protocol.pack(generation, table.concat(tickets, "+")))
end

function M.ready(content)
    local fields = Protocol.unpack(content)
    if not fields or fields[1] ~= generation or not fields[2] then return end
    for ticket in fields[2]:gmatch("%d+:%d+") do
        local id = ticket:match("^%d+")
        local queue = pending[id]
        if queue and queue.ticket == ticket then
            pending[id] = nil
            local native_id = queue.actor:GetEntityId()
            if Protocol.id(native_id) == id then
                attached[id] = queue.actor
                for _, row in ipairs(queue.messages) do
                    inzoi.message.send_to_sim(native_id, row[1], row[2])
                end
            end
        end
    end
end

return M
