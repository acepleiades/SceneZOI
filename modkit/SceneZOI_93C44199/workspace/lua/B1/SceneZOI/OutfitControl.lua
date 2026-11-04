local Protocol = require("SceneZOI.Protocol")
local Config = require("SceneZOI.Config")
local M = {}

function M.receive(current, actor, fields)
    local counter, revision = tonumber(fields[3]), tonumber(fields[4])
    if revision ~= current.revision or not counter or counter < 0 then return end
    for _, participant in ipairs(current.participants) do
        if participant.actor == actor then
            if counter < (participant.outfit_counter or 0) then return end
            participant.outfit_counter = counter
            participant.outfit_name, participant.outfit_rows = fields[6], fields[7]
            participant.outfit_items = {}
            for row in (fields[7] or ""):gmatch("[^+]+") do
                local id, kind, key, label, enabled, asset = row:match("^([%w]+):([%w]+):(%x+):(%x+):([01]):(%x+)$")
                if id then participant.outfit_items[id] = {id=id, kind=kind, key=Protocol.decode(key), label=Protocol.decode(label),
                    enabled=enabled == "1", asset=Protocol.decode(asset)} end
            end
            local removed = {}
            if fields[5] ~= "none" then
                for slot in (fields[5] or ""):gmatch("[^:]+") do
                    local decoded = Protocol.decode(slot)
                    if decoded then removed[decoded] = true end
                end
            end
            participant.removed_slots = removed
            participant.expected_garments = nil
            participant.outfit_revision = nil
            if fields[8] then
                participant.expected_garments = {}
                participant.outfit_revision = revision
                for entry in fields[8]:gmatch("[^+]+") do
                    local key, encoded = entry:match("^([%w.]+):(%x+)$")
                    local value = encoded and Protocol.decode(encoded)
                    if key and value then
                        if key:sub(1, 2) == "g." then
                            local slot = Protocol.decode(key:sub(3))
                            if slot then participant.expected_garments[slot] = value end
                        elseif key:sub(1, 2) == "p." then
                            local item = participant.outfit_items[key:sub(3)]
                            if item then item.expected_asset = value end
                        end
                    end
                end
            end
            if current.outfit_change and current.outfit_change.participant == participant and counter == current.outfit_change.counter then
                current.outfit_change.acknowledged = true
            end
        end
    end
end

function M.request(current, raw)
    local fields = Protocol.unpack(raw)
    if not fields or fields[1] ~= current.client or fields[2] ~= current.sequence or fields[3] ~= "outfit" then return end
    local count, revision = tonumber(fields[4]), tonumber(fields[8])
    if not count or count % 1 ~= 0 or count <= 0 then return end
    if count <= (current.last_outfit_command or 0) or current.preparing then return end
    current.last_outfit_command = count
    if revision ~= current.revision then return {counter=count, error="outfit_stale"} end
    if fields[7] ~= "0" and fields[7] ~= "1" then return {counter=count, error="outfit_invalid"} end
    for _, participant in ipairs(current.participants) do
        if participant.id == fields[5] and participant.outfit_items and participant.outfit_items[fields[6]] then
            return {counter=count, participant=participant, item=fields[6], piece=participant.outfit_items[fields[6]],
                enabled=fields[7], acknowledged=false}
        end
    end
    return {counter=count, error="outfit_invalid"}
end

function M.publish(current)
    local participants = {}
    for _, participant in ipairs(current.participants) do
        if participant.outfit_name and participant.outfit_rows then
            participants[#participants + 1] = participant.id .. ":" .. participant.outfit_name .. ":" .. Protocol.encode(participant.outfit_rows)
        end
    end
    local packet = Protocol.pack(current.client, current.sequence, current.revision, current.acknowledged_outfit or 0,
        current.preparing and "busy" or current.outfit_code or "ok", #participants > 0 and table.concat(participants, "+") or "none")
    if packet == current.outfit_state then return end
    local ok = inzoi.cli.execute("uimod.cfg_save mod_id=" .. Config.mod_id .. " section=" .. Config.section .. " key=outfit_state value=" .. packet)
    if ok then current.outfit_state = packet end
end

return M
