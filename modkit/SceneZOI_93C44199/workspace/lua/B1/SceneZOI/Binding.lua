-- A session assigns identity to explicit roles once. Nodes may validate, never reassign it.
local M = {}
function M.validate(node, role, body)
    local requirement = assert(node.participants[role], "Participant role is absent from this node")
    assert(not body or requirement.body == body, "Participant body is unsupported by this role")
    return role
end
function M.resolve(participants, node)
    local bindings, count = {}, 0
    for _ in pairs(node.participants) do count = count + 1 end
    assert(count == #participants, "Node participant count does not match this session")
    for _, participant in ipairs(participants) do
        local role = M.validate(node, participant.role, participant.body)
        assert(not bindings[role], "Two participants cannot occupy the same role")
        bindings[role] = participant
    end
    for role in pairs(node.tracks) do assert(bindings[role], "Body track has no participant") end
    assert(bindings[node.anchor_participant], "Scene anchor participant is unavailable")
    return bindings
end
return M
