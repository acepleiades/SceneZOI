-- Play through the existing game animation instance; keep its graph and references alive.
local Config = require("SceneZOI.Config")
local M = {}
-- EAnimationMode::AnimationBlueprint; this enum is not exposed by the Lua binding.
local ANIMATION_BLUEPRINT = 0

---@param actor AB1Character
function M.capture(actor)
    local mesh = actor.Mesh
    assert(mesh and mesh:GetAnimationMode() == ANIMATION_BLUEPRINT, "Participant has no active animation blueprint")
    local instance = mesh:GetAnimInstance()
    assert(instance, "Character has no animation instance")
    local movement = actor.CharacterMovement
    return {
        actor = actor, mesh = mesh, instance = instance, transform = actor:GetTransform(),
        collision = actor:GetActorEnableCollision(), movement = movement,
        movement_mode = movement.MovementMode, custom_movement_mode = movement.CustomMovementMode,
    }
end

function M.desired_transform(record, anchor)
    -- The shared animation root is the mesh origin, not the actor/capsule origin.
    local mathlib = UE.UKismetMathLibrary
    return mathlib.ComposeTransforms(mathlib.InvertTransform(record.mesh:GetRelativeTransform()), anchor)
end

function M.enter(record, asset, transform, position)
    assert(record.mesh:GetAnimInstance() == record.instance, "Animation instance changed during task teardown")
    -- Task teardown can change position/movement after capture; restore this settled state.
    if not record.changed then
        record.transform = record.actor:GetTransform()
        record.movement_mode, record.custom_movement_mode = record.movement.MovementMode, record.movement.CustomMovementMode
    end
    record.changed, record.desired = true, transform
    record.between_nodes = false
    record.actor:SetActorEnableCollision(false)
    record.movement:StopMovementImmediately()
    record.movement:DisableMovement()
    record.actor:K2_SetActorTransform(transform, false, nil, true)
    -- SingleNode playback/recreating the instance left later movement and furniture tasks stuck.
    -- Use the existing graph slot with zero blends for the requested immediate transition.
    position = position or 0
    local previous, previous_instance = record.montage, record.montage_instance or record.instance
    local montage = record.instance:PlaySlotAnimationAsDynamicMontage(asset, Config.slot, 0, 0, 1, 1, -1, position)
    assert(montage, "The game animation slot rejected the scene track")
    record.montage, record.montage_instance = montage, record.instance
    record.asset, record.position = asset, position
    -- Install the replacement first, then retire only our outgoing track. Never
    -- leave an empty slot across preparation ticks or stop the game's other slots.
    if previous and previous ~= montage then previous_instance:Montage_Stop(0, previous) end
    -- Freeze its independent clock: Runtime samples both tracks from one looping time.
    record.instance:Montage_SetPlayRate(record.montage, 0)
    record.instance:Montage_SetPosition(record.montage, position)
end

-- Retire only the scene-owned track, retaining the session restoration snapshot.
function M.stop_track(record)
    if record.montage then
        (record.montage_instance or record.instance):Montage_Stop(0, record.montage)
        record.montage, record.montage_instance = nil, nil
    end
    record.between_nodes = true
end

function M.rebind(record)
    local fresh = M.capture(record.actor)
    record.mesh, record.instance = fresh.mesh, fresh.instance
end

-- Nothing in the game outranks a running scene: its tasks are already being cancelled and the
-- player's input is captured. So whatever took the slot, or left it empty, gives it back. The
-- limit below is what ends a scene the game will not let go of.
local function recoverable_clip(record)
    local incoming = record.instance:GetCurrentActiveMontage()
    return incoming and incoming:GetName() or "none"
end

local function take_back_track(record, position)
    local ok, incoming = pcall(recoverable_clip, record)
    if not ok or not incoming then return false end

    local now = UE.UGameplayStatics.GetRealTimeSeconds(record.actor)
    if not record.recovery_window or now - record.recovery_window >= 2 then
        record.recovery_window, record.recovery_attempts = now, 0
    end
    -- Bound recovery if the game repeatedly replaces our track.
    if record.recovery_attempts >= 3 then return false end
    record.recovery_attempts = record.recovery_attempts + 1
    M.enter(record, record.asset, record.desired, position)
    print("[SceneZOI] Scene track taken back on " .. tostring(record.id) .. " from " .. incoming)
    pcall(inzoi.cli.execute, "uimod.cfg_save mod_id=" .. Config.mod_id ..
        " section=" .. Config.section .. " key=montage_recovery value=" ..
        tostring(record.id) .. "|" .. incoming .. "|" .. tostring(position))
    return true
end

local function incoming_name(instance)
    local ok, name = pcall(function() return instance:GetCurrentActiveMontage():GetName() end)
    return ok and name or "none"
end

function M.sample(record, position)
    assert(record.mesh:GetAnimationMode() == ANIMATION_BLUEPRINT and record.mesh:GetAnimInstance() == record.instance,
        "The game replaced the participant's animation instance")
    if not record.instance:Montage_IsActive(record.montage) then
        if take_back_track(record, position) then return end
        error('Scene montage stopped unexpectedly: participant='..tostring(record.id)..' role='..tostring(record.role)..
            ' sample='..tostring(position)..' previous='..tostring(record.position)..' clip='..tostring(record.asset)..
            ' incoming='..incoming_name(record.instance))
    end
    -- Keep the shared anchor without repeatedly teleporting an already aligned
    -- mesh. A teleport can disturb dynamics in the native post-process graph.
    if not UE.UKismetMathLibrary.NearlyEqual_TransformTransform(record.actor:GetTransform(), record.desired,
        0.01, 0.0001, 0.0001) then
        record.actor:K2_SetActorTransform(record.desired, false, nil, true)
    end
    record.instance:Montage_SetPosition(record.montage, position)
    record.position = position
end

-- Hold the last shared sample while the next node prepares. Outfit/body rebuilds
-- may replace the game-owned instance; reapply our old clip to that instance,
-- without replacing it ourselves or recapturing the session restoration state.
function M.hold(record, anchor)
    record.between_nodes = true
    local mesh = record.actor.Mesh
    if not mesh or mesh:GetAnimationMode() ~= ANIMATION_BLUEPRINT or not mesh:GetAnimInstance() then return false end
    if mesh ~= record.mesh or mesh:GetAnimInstance() ~= record.instance or
        not record.montage or not record.instance:Montage_IsActive(record.montage) then
        local position = record.position or 0
        M.rebind(record)
        M.enter(record, assert(record.asset, "Outgoing scene clip is missing"), M.desired_transform(record, anchor), position)
    else M.sample(record, record.position or 0) end
    record.between_nodes = true
    return true
end

-- The simulation refused to leave this Zoi where the scene put it, so the client follows it back.
function M.restore_position(record)
    record.actor:K2_SetActorTransform(record.transform, false, nil, true)
end

function M.restore(record)
    if not record.changed then return end
    local failures = {}
    -- Retry only failed steps; successful restoration must not be applied again.
    record.restored = record.restored or {}
    local function attempt(key, fn)
        if record.restored[key] then return end
        local ok, err = pcall(fn)
        if ok then record.restored[key] = true else failures[#failures + 1] = tostring(err) end
    end
    attempt("animation", function()
        -- An outfit rebuild between nodes may legitimately replace the game-owned
        -- instance before the next hold tick. Retire the track on its actual owner,
        -- then validate the currently attached game-owned instance.
        -- Stop only our montage; keep the game graph and its other animation state intact.
        local between_nodes = record.between_nodes
        M.stop_track(record)
        if between_nodes then M.rebind(record) end
        assert(record.mesh:GetAnimationMode() == ANIMATION_BLUEPRINT and record.mesh:GetAnimInstance() == record.instance,
            "The original game animation instance is no longer attached")
    end)
    attempt("position", function()
        if not record.keep_position then record.actor:K2_SetActorTransform(record.transform, false, nil, true) end
    end)
    attempt("movement", function() record.movement:SetMovementMode(record.movement_mode, record.custom_movement_mode) end)
    attempt("collision", function() record.actor:SetActorEnableCollision(record.collision) end)
    if #failures > 0 then error(table.concat(failures, "; ")) end
    record.changed = false
end

---@param actor AB1Character
function M.release_input(actor)
    local controller = UE.UGameplayStatics.GetPlayerController(actor, 0)
    if not controller then return end
    -- Use the game's own cursor/input routing after the panel has closed.
    controller:ChangeUIInputMode(inzoi.EB1UIInputMode.CursorMode, true)
    UE.UWidgetBlueprintLibrary.SetFocusToGameViewport()
end

return M
