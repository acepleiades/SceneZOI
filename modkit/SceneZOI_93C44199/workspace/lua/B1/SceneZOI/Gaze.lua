-- Session-owned eye overlays; each node supplies a fresh map of role targets.
-- No assumptions about gender, control status, pair ordering, or participant count.
local Native = require("SceneZOI.GazeNative")
local Math = require("SceneZOI.GazeMath")
local M = {}

function M.prepare(context, session)
    context.session, context.owners = session, context.owners or {}
    local ready = true
    for _, participant in ipairs(session.participants) do
        local owner = context.owners[participant.id]
        if not owner then
            owner = {id = participant.id, actor = participant.actor}
            context.owners[participant.id] = owner
        end
        local record = Native.bind(owner)
        if not record then ready = false
        else
            -- Acquire native entry ownership once for the entire session,
            -- including across copied or rebuilt head instances.
            if not owner.native_state then owner.native_state = Native.capture(owner) end
            owner.record = record
        end
    end
    -- Resolve all declared targets before modifying a single eye.
    for role, spec in pairs(context.node.gaze or {}) do
        assert(session.bindings[role] and session.bindings[spec.participant], "Unbound gaze participant")
        if not Native.target(session.bindings[spec.participant], spec) then ready = false end
    end
    return ready
end

function M.ready(context) return context.session ~= nil end

local function update(context)
    local session = context.session
    if not session or not context.active then return end
    local bindings=context.bindings or session.bindings
    if not bindings then return end
    context.samples, context.clamped = (context.samples or 0)+1, 0
    context.last = {}
    -- Targets are sampled first. Eye translations are not altered, so mutual
    -- eye contact and self-targets introduce no positional feedback.
    local targets = {}
    for role, spec in pairs(context.targets or {}) do
        targets[role] = Native.target(bindings[spec.participant], spec)
    end
    for role, participant in pairs(bindings) do
        local owner = context.owners[participant.id]
        local spec=require('SceneZOI.AddonControl').expression(session,participant.id)or(context.node.expressions and context.node.expressions[role])
        local owns_eyes=spec and spec.facial_pose and require('SceneZOI.FacialPoseLibrary').owns_eyes(spec.facial_pose,participant.expression_body or participant.body)
        local facial=session.expressions and session.expressions.owners[participant.id]
        local active=facial and facial.fixed_targets
        owns_eyes=owns_eyes or(active and(active.FACIAL_L_Eye or active.FACIAL_R_Eye))
        if owns_eyes and owner.changed then
            Native.restore(owner,owner.native_state);owner.native_state=Native.capture(owner);owner.changed=false;owner.restored=nil
        end
        local record = not owns_eyes and Native.bind(owner)
        if record then
            owner.record = record
            local row = {role = role, participant = participant.id, eyes = {}}
            for _, eye in ipairs(Native.eyes) do
                local pitch, roll = 0, 0
                if targets[role] then pitch, roll = Math.angles(Native.direction(record, eye, targets[role]), record.limit) end
                if math.abs(pitch) >= record.limit.Pitch-0.0001 or math.abs(roll) >= record.limit.Roll-0.0001 then
                    context.clamped = context.clamped+1
                end
                local rotation = Native.rotation(record, pitch, roll)
                -- Keep ownership even if the second eye command fails midway.
                owner.changed = true
                Native.apply(owner, eye, rotation)
                row.eyes[#row.eyes+1] = {pitch = pitch, roll = roll}
            end
            context.last[#context.last+1] = row
        end
    end
end

function M.enter(context)
    context.targets, context.bindings, context.active = context.node.gaze or {}, context.session.bindings, true
    update(context)
end

function M.sample(context) update(context) end

function M.leave_node(context)
    -- Keep the outgoing target active through preparation. enter replaces the
    -- entire target map atomically, including deliberate forward defaults.
end

function M.guard(context)
    -- Outfit readiness can take several frames. Keep eyes following the held
    -- pose and reapply after a face rebuild without touching blinking or clocks.
    if context.active and context.session and context.session.preparing then update(context) end
end

function M.restore(context)
    context.active, context.targets, context.bindings = false, {}, nil
    local errors = {}
    for _, owner in pairs(context.owners or {}) do
        if owner.changed and not owner.restored then
            local ok, err = pcall(Native.restore, owner, owner.native_state)
            if ok then owner.restored = true else errors[#errors+1] = tostring(err) end
        end
    end
    if #errors > 0 then error(table.concat(errors, "; ")) end
end

function M.status(context)
    local rows = {}
    for _, row in ipairs(context.last or {}) do
        local eyes = {}
        for _, angle in ipairs(row.eyes) do eyes[#eyes+1] = string.format("%.2f,%.2f",angle.pitch,angle.roll) end
        rows[#rows+1] = row.role .. "=" .. table.concat(eyes,";")
    end
    return "gaze_samples=" .. tostring(context.samples or 0) .. ":gaze_clamped=" .. tostring(context.clamped or 0) ..
        ":gaze_angles=" .. table.concat(rows,"+")
end

return M
