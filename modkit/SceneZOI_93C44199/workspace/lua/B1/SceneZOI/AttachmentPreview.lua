local Attachment = require("SceneZOI.Attachment")
local Config = require("SceneZOI.Config")
local Diagnostics = require("SceneZOI.Diagnostics")
local Json = require("SceneZOI.Json")
local Protocol = require("SceneZOI.Protocol")
local V = require("SceneZOI.DataValidation")

local M = {}
local reference_key = "attachment_pose_reference"
local reference_header = "# SceneZOI attachment pose reference. Copy XYZ degrees into attachment_rest_rotations."
local max_reference_bytes = 65536
local last_state

local function collect(session)
    local rows, contexts = Json.array(), {}
    if session.preparing or session.stopping or not session.started then return rows, contexts end
    for _, item in ipairs(session.subsystems.items or {}) do
        if item.engine.id == "attachment" and not item.restored then
            local context = item.context
            local row = Attachment.preview(context, true)
            local role = context.node.attachment.participant
            local owner = session.bindings[role]
            if row and owner then
                row.participant = owner.id
                row.name = (owner.outfit_name and Protocol.decode(owner.outfit_name)) or owner.task_name or role
                row.role, row.attachment = role, item.id
                rows[#rows+1] = row
                contexts[item.id] = context
            end
        end
    end
    return rows, contexts
end

local function export_failed(scene, reason, detail, bytes)
    Diagnostics.record("attachment_pose_export_failed", {
        scene_id = scene.id, reason = reason, detail = Diagnostics.detail(detail),
        attempted_bytes = bytes, limit_bytes = max_reference_bytes,
    })
    return "preview_export_" .. reason
end

local function export(scene, rows)
    local entries = {}
    for _, row in ipairs(rows) do
        for bone, rotation in pairs(row.rotations or {}) do
            entries[#entries+1] = "scene=" .. scene.id .. " " .. Diagnostics.format({
                label = scene.label, role = row.role, attachment = row.attachment, bone = bone,
                x = rotation[1], y = rotation[2], z = rotation[3],
            })
        end
    end
    if #entries == 0 then return export_failed(scene, "empty") end
    table.sort(entries)
    local loaded, previous, read_error = pcall(Diagnostics.load, reference_key)
    if not loaded then return export_failed(scene, "read", previous) end
    if type(previous) ~= "string" then return export_failed(scene, "read", read_error) end
    local lines = {reference_header}
    for line in previous:gmatch("[^\r\n]+") do
        local id = line:match("^scene=([a-z][a-z0-9_.%-]*) ")
        if id and id ~= scene.id then lines[#lines+1] = line end
    end
    for _, entry in ipairs(entries) do lines[#lines+1] = entry end
    local data = table.concat(lines, "\n") .. "\n"
    if #data > max_reference_bytes then return export_failed(scene, "full", nil, #data) end
    local saved, write_error = Diagnostics.save(reference_key, data)
    if not saved then return export_failed(scene, "write", write_error, #data) end
    return "preview_exported"
end

local function rotate(command, rows, contexts)
    V.fields(command, {"action", "participant", "attachment", "bone", "rotation"},
        {"action", "participant", "attachment", "bone", "rotation"})
    V.name(command.bone)
    V.array(command.rotation, 3)
    assert(#command.rotation == 3, "Expected XYZ rotation")
    for _, angle in ipairs(command.rotation) do V.number(angle, -180, 180) end
    for _, row in ipairs(rows) do
        if not row.hidden and row.participant == command.participant and row.attachment == command.attachment then
            local applied = Attachment.preview_rotation(contexts[row.attachment], command.bone, command.rotation)
            return applied and "ok" or "preview_invalid"
        end
    end
    return "preview_invalid"
end

local function apply(session, encoded)
    assert(#encoded <= 4096, "Attachment preview request is too large")
    local command = Json.decode(Protocol.decode(encoded))
    local rows, contexts = collect(session)
    if command.action == "export" then
        V.fields(command, {"action"}, {"action"})
        return export(session.node, rows)
    end
    if command.action == "rotate" then return rotate(command, rows, contexts) end
    return "preview_invalid"
end

function M.request(session, raw)
    if session.stopping then return end
    local fields = Protocol.unpack(raw)
    if not fields or #fields ~= 7 or fields[1] ~= session.client or fields[2] ~= session.sequence or
        fields[3] ~= "attachment_preview" or fields[6] ~= session.token then return end
    local count = tonumber(fields[4])
    if not count or count % 1 ~= 0 or count < 1 or count > 9007199254740991 or count <= (session.attachment_preview_ack or 0) then return end
    session.attachment_preview_ack = count
    if tonumber(fields[5]) ~= session.revision then
        session.attachment_preview_code = "preview_stale"
    elseif not session.started or session.preparing then
        session.attachment_preview_code = "preview_stale"
    else
        local ok, code = pcall(apply, session, fields[7])
        session.attachment_preview_code = ok and code or "preview_invalid"
    end
end

function M.publish(session, dt)
    session.attachment_preview_elapsed = (session.attachment_preview_elapsed or 0.1) + dt
    if session.attachment_preview_elapsed < 0.1 then return end
    session.attachment_preview_elapsed = 0
    local rows = collect(session)
    local code = session.preparing and "busy" or session.attachment_preview_code or "ok"
    local packet = Protocol.pack(session.client, session.sequence, session.revision, session.attachment_preview_ack or 0,
        code, session.token, Protocol.encode(Json.encode(rows)))
    if packet == last_state then return end
    local saved = inzoi.cli.execute("uimod.cfg_save mod_id=" .. Config.mod_id .. " section=" .. Config.section ..
        " key=attachment_preview_state value=" .. packet)
    if saved then last_state = packet end
end

return M
