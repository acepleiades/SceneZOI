-- Bone-local adjustments for an owned, trackless poseable attachment.
local Math = require("SceneZOI.GazeMath")
local M = {}
-- EBoneSpaces::ComponentSpace is separate from ERelativeTransformSpace.
local COMPONENT_SPACE = 1

local function parent_bone(component, name)
    local parent = component:GetParentBone(name)
    parent = parent and tostring(parent)
    if parent and parent ~= "" and parent:lower() ~= "none" then return parent end
end

function M.bind(component, reference)
    local pose = {bones={}, by_name={}, protected={}}
    local ancestor, reference_pose = reference
    -- Native component-space samples can lag the component's first tick.
    -- Derive the bind offset from the mesh's own reference hierarchy.
    while ancestor do
        local key = ancestor:lower()
        assert(not pose.protected[key], "Cyclic attachment reference hierarchy")
        pose.protected[key] = true
        local index = component:GetBoneIndex(ancestor)
        assert(index >= 0, "Missing attachment reference ancestor")
        local rest = component:GetRefPoseTransform(index)
        reference_pose = reference_pose and UE.UKismetMathLibrary.ComposeTransforms(reference_pose, rest) or rest
        ancestor = parent_bone(component, ancestor)
    end
    for index = 0, component:GetNumBones() - 1 do
        local name = tostring(component:GetBoneName(index))
        local key = name:lower()
        if key ~= "none" and not pose.protected[key] then
            pose.bones[#pose.bones+1] = name
            pose.by_name[key] = {name=name, index=index, parent=parent_bone(component, name)}
        end
    end
    table.sort(pose.bones)
    return pose, reference_pose
end

local function rotation_error(rotation)
    if type(rotation) ~= "table" or #rotation ~= 3 then return "invalid_rotation" end
    for index = 1, 3 do
        local value = rotation[index]
        if type(value) ~= "number" or value ~= value or math.abs(value) > 180 then return "invalid_rotation" end
    end
end

function M.apply(attachment, name, rotation)
    local pose, component = attachment.pose, attachment.component
    if type(name) ~= "string" then return false, "unknown_bone" end
    local key = name:lower()
    if pose.protected[key] then return false, "protected_attachment_anchor" end
    local bone = pose.by_name[key]
    if not bone then return false, "unknown_bone" end
    if rotation == nil then
        component:ResetBoneTransformByName(bone.name)
        return true, bone.name
    end
    local invalid = rotation_error(rotation)
    if invalid then return false, invalid end

    local rest = component:GetRefPoseTransform(bone.index)
    local yaw = math.rad(rotation[3]) / 2
    local delta = Math.multiply({X=0,Y=0,Z=math.sin(yaw),W=math.cos(yaw)}, Math.quaternion(rotation[2], rotation[1]))
    local q = Math.multiply(rest.Rotation, delta)
    rest.Rotation = UE.FQuat(q.X, q.Y, q.Z, q.W)
    if bone.parent then
        -- The poseable setter removes the current parent transform. Supply the
        -- same component-space parent here so the stored edit is bone-local,
        -- even when an earlier edit also changes that parent.
        rest = UE.UKismetMathLibrary.ComposeTransforms(rest, component:GetBoneTransformByName(bone.parent, COMPONENT_SPACE))
    end
    component:SetBoneTransformByName(bone.name, rest, COMPONENT_SPACE)
    return true, bone.name
end

return M
