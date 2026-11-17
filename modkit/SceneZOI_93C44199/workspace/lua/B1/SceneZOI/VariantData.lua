-- Registered appearance assets and selections contain inert data only.
local V = require("SceneZOI.DataValidation")
local M = {}

local function identity(value, owner)
    V.id(value.id)
    if owner then
        V.id(owner)
        assert(#value.id > #owner + 1 and value.id:sub(1, #owner + 1) == owner .. ".",
            "Variant ID must use its pack namespace")
    end
    assert(value.schema_version == 1, "Unsupported appearance variant schema")
    if value.label ~= nil then V.name(value.label) end
end

local function traits(value, required)
    if required or value.body ~= nil then
        assert(value.body == "male" or value.body == "female", "Invalid appearance variant body")
    end
    if value.body_age ~= nil then V.name(value.body_age) end
    if value.growth_steps ~= nil then
        V.array(value.growth_steps, 16)
        assert(#value.growth_steps > 0, "Empty appearance variant life stages")
        local seen = {}
        for _, step in ipairs(value.growth_steps) do
            V.name(step)
            assert(not seen[step], "Duplicate appearance variant life stage")
            seen[step] = true
        end
    end
end

function M.validate_body(value, owner)
    V.fields(value, {"schema_version", "id", "label", "body", "mesh", "body_age", "growth_steps"},
        {"schema_version", "id", "body", "mesh"})
    identity(value, owner)
    traits(value, true)
    V.asset(value.mesh)
    return V.copy(value)
end

function M.validate_attachment(value, owner)
    V.fields(value, {"schema_version", "id", "label", "body", "body_age", "growth_steps", "attachment", "node_animations"},
        {"schema_version", "id", "attachment"})
    identity(value, owner)
    traits(value, false)
    local attachment = value.attachment
    V.fields(attachment, {"mesh", "component", "socket", "reference_bone", "body_profile", "material_profile", "retain_for_session"},
        {"mesh", "socket", "reference_bone"})
    V.asset(attachment.mesh)
    V.name(attachment.socket)
    V.name(attachment.reference_bone)
    if attachment.component ~= nil then
        assert(attachment.component == "body" or attachment.component == "head", "Invalid attachment variant component")
    end
    if attachment.body_profile ~= nil then
        V.id(attachment.body_profile)
        assert(attachment.component ~= "head", "A body-region variant requires the body component")
    end
    if attachment.material_profile ~= nil then
        V.id(attachment.material_profile)
        assert(attachment.body_profile, "An attachment material profile requires a body profile")
    end
    if attachment.retain_for_session ~= nil then V.boolean(attachment.retain_for_session) end
    local animations = value.node_animations == nil and {} or value.node_animations
    assert(V.object(animations), "Expected attachment variant scene animation map")
    local count = 0
    for id, path in pairs(animations) do
        count = count + 1
        V.id(id)
        V.asset(path)
    end
    assert(count <= 512, "Too many attachment variant scene animations")
    return V.copy(value)
end

function M.validate_selection(value)
    V.fields(value, {"body_variant", "attachment_variants"})
    if value.body_variant ~= nil and value.body_variant ~= false then V.id(value.body_variant) end
    if value.attachment_variants ~= nil then
        assert(V.object(value.attachment_variants), "Expected attachment variant slots")
        local count = 0
        for slot, id in pairs(value.attachment_variants) do
            count = count + 1
            V.id(slot)
            if id ~= false then V.id(id) end
        end
        assert(count <= 16, "Too many attachment variant slots")
    end
    return V.copy(value)
end

function M.validate_scene(value, roles)
    if value == nil then return end
    assert(V.object(value), "Expected appearance selections by role")
    for role, selection in pairs(value) do
        assert(roles[role], "Unbound appearance selection role")
        M.validate_selection(selection)
    end
end

function M.compile(snapshot)
    local result = {bodies = {}, attachments = {}, warnings = {}}
    local kinds = {
        {name = "body_variant", target = result.bodies, validate = M.validate_body},
        {name = "attachment_variant", target = result.attachments, validate = M.validate_attachment},
    }
    for _, kind in ipairs(kinds) do
        local rows = {}
        for _, document in ipairs((snapshot.by_kind or {})[kind.name] or {}) do rows[#rows + 1] = document end
        table.sort(rows, function(a, b)
            if tostring(a.owner) ~= tostring(b.owner) then return tostring(a.owner) < tostring(b.owner) end
            local aid = type(a.data) == "table" and a.data.id or nil
            local bid = type(b.data) == "table" and b.data.id or nil
            if tostring(aid) ~= tostring(bid) then
                return tostring(aid) < tostring(bid)
            end
            return tostring(a.source) < tostring(b.source)
        end)
        local declarations = {}
        for _, document in ipairs(rows) do
            local ok, value = pcall(kind.validate, document.data, document.owner)
            if not ok then
                result.warnings[#result.warnings + 1] = tostring(document.source) .. ": " .. tostring(value)
            else
                local previous = declarations[value.id]
                if previous and not V.equal(previous.data, value) then
                    result.warnings[#result.warnings + 1] = "Conflicting " .. kind.name .. " " .. value.id ..
                        ": kept " .. tostring(previous.source) .. "; ignored " .. tostring(document.source)
                elseif not previous then
                    declarations[value.id] = {data = value, source = document.source}
                    local registered = V.copy(value)
                    registered._owner = document.owner
                    kind.target[value.id] = registered
                end
            end
        end
    end
    table.sort(result.warnings)
    return result
end

return M
