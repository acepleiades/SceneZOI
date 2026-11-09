-- Owns scene body tracks. Native retains the tested game-animation-instance adapter.
local Native = require("SceneZOI.Native")
local M = {}

function M.refresh_subsystem_tracks(current)
    local tracks = {}
    for _, track in ipairs(current.tracks or {}) do
        if track.kind == "body" then tracks[#tracks + 1] = track end
    end
    for _, track in ipairs(current.subsystems:tracks(current)) do tracks[#tracks + 1] = track end
    current.tracks = tracks
end

function M.enter(current)
    for _, participant in ipairs(current.participants) do Native.rebind(participant) end
    local anchor_owner = assert(current.bindings[current.node.anchor_participant])
    if not current.anchor then
        current.anchor = anchor_owner.mesh:K2_GetComponentToWorld()
        if current.spot then
            local height = current.anchor.Translation.Z
            current.anchor.Translation = UE.FVector(current.spot.X, current.spot.Y, height)
        end
    end
    current.tracks = {}
    for _, participant in ipairs(current.participants) do
        local asset = assert(current.assets[participant.role], "Participant has no animation track")
        local track = {id = participant.role .. ".body", kind = "body", participant_id = participant.id,
            participant = participant, asset = asset}
        current.tracks[#current.tracks + 1] = track
        Native.enter(participant, asset, Native.desired_transform(participant, current.anchor))
    end
    current.subsystems:enter()
    M.refresh_subsystem_tracks(current)
end

function M.sample(current, position)
    for _, track in ipairs(current.tracks) do
        if track.kind == "body" then Native.sample(track.participant, position) end
    end
    current.subsystems:sample(position)
end

function M.leave_node(current)
    -- Keep the paused outgoing montages in their slots until the handoff. Their
    -- last sampled pose stays paired while appearance and resources prepare.
    for _, participant in ipairs(current.participants) do participant.between_nodes = true end
    current.subsystems:leave_node()
end

function M.hold(current)
    local ready = true
    for _, participant in ipairs(current.participants) do
        if not Native.hold(participant, current.anchor) then ready = false end
    end
    return ready
end

return M
