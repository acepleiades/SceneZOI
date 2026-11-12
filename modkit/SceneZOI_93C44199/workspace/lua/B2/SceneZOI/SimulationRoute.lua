-- Bootstrap one native message receiver on the controlled Zoi. It attaches
-- additional receivers only for participants or furniture owners being addressed.
local Protocol = require("SceneZOI.Protocol")
local M = {}
local receiver = "SceneZOISimulationReceiver"
local elapsed = 0

local function attach(manager, id)
    local actor = manager:FindCharacter(id)
    if not actor then return false end
    if not actor:HasLuaModule(receiver) then actor:AddLuaModule(receiver, "Zoi.SimulationReceiver") end
    return actor:HasLuaModule(receiver)
end

function M.tick(dt)
    elapsed = elapsed + dt
    if elapsed < 0.2 then return end
    elapsed = 0
    local id = inzoi.FB2ControllerSystem.GetPossessEntityId()
    if not id or tonumber(id.Value) == nil or tonumber(id.Value) < 0 then return end
    local manager = inzoi.getB2Manager("FB2EntityManager")
    if manager then attach(manager, id) end
end

function M.receive(owner, content)
    local fields = Protocol.unpack(content)
    if not fields or not fields[2] then return end
    local manager = inzoi.getB2Manager("FB2EntityManager")
    if not manager then return end
    local ready = {}
    for ticket in fields[2]:gmatch("%d+:%d+") do
        local id = inzoi.FB1EntityId()
        id.Value = tonumber(ticket:match("^%d+"))
        if attach(manager, id) then ready[#ready + 1] = ticket end
    end
    if #ready > 0 then
        inzoi.message.send_to_client(owner:GetEntityId(), "SceneZOI.RouteReady",
            Protocol.pack(fields[1], table.concat(ready, "+")))
    end
end

return M
