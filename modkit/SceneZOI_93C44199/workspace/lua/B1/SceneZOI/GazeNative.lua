-- Eyes-only local facial corrections on the existing game post-process instance.
-- Retain the native facial-shape array; own and remove only our two appended entries.
local M = {}
M.eyes = {"FACIAL_L_Eye", "FACIAL_R_Eye"}
local PARENT = "FACIAL_C_FacialRoot"

local Math=require("SceneZOI.GazeMath")
local IDENTITY={X=0,Y=0,Z=0,W=1}

function M.head(actor)
    for _, component in ipairs(actor:K2_GetComponentsByClass(UE.USkeletalMeshComponent:StaticClass())) do
        if component:GetName() == "Head" then return component end
    end
end

function M.capture(owner)
    owner.eye_leases={}
    return {}
end

function M.bind(owner)
    local head = M.head(owner.actor)
    if not head or not head:GetAnimInstance() or not head:GetPostProcessInstance() then return nil end
    for _, name in ipairs(M.eyes) do
        assert(head:GetBoneIndex(name) >= 0 and head:GetParentBone(name) == PARENT,
            "Unsupported facial eye layout: " .. name)
    end
    local limit = head:GetAnimInstance().EyeLookAtLimit
    assert(limit and limit.Pitch and limit.Roll, "The game did not provide eye rotation limits")
    return {head = head, post = head:GetPostProcessInstance(), owner=owner,
        limit = {Pitch = math.abs(limit.Pitch), Roll = math.abs(limit.Roll)}}
end

function M.target(binding, spec)
    local mesh
    if spec.component == "head" then mesh = M.head(binding.actor) else mesh = binding.actor.Mesh end
    if not mesh then return nil end
    local x, y, z = 0, 0, 0
    for _, bone in ipairs(spec.bones) do
        assert(mesh:GetBoneIndex(bone) >= 0, "Gaze target bone is missing: " .. bone)
        local point = mesh:GetSocketTransform(bone, 0).Translation
        x, y, z = x+point.X, y+point.Y, z+point.Z
    end
    local count = #spec.bones
    return UE.FVector(x/count, y/count, z/count)
end


function M.rotation(record, pitch, roll)
    return {Pitch=pitch,Yaw=0,Roll=roll,record=record}
end

local function equal(q,r)
    local dot=math.abs(q.X*r.X+q.Y*r.Y+q.Z*r.Z+q.W*r.W)
    return math.abs(dot-1)<0.000001
end

local function owned(value,eye,entry)
    if not value or value.BoneName~=eye or value.Depth~=-1 then return false end
    local t=value.Transform
    local p,s=t.Translation,t.Scale3D
    return math.abs(p.X)+math.abs(p.Y)+math.abs(p.Z)<0.000001 and
        math.abs(s.X)+math.abs(s.Y)+math.abs(s.Z)<0.000001 and equal(t.Rotation,entry.delta)
end

local function find(array,eye,entry)
    if entry.index and entry.index<=array:Num() and owned(array:Get(entry.index),eye,entry) then return entry.index end
    for index,value in ipairs(array:ToTable()) do if owned(value,eye,entry) then return index end end
end

function M.direction(record,eye,target)
    local neutral=record.head:GetSocketTransform(eye,0)
    local previous=IDENTITY
    -- Read the game pose without our preceding correction. This retains native
    -- facial shaping/blink motion and avoids feeding our own eye rotation back.
    for _,lease in ipairs(record.owner.eye_leases or {}) do
        if lease.post==record.post then
            local entry=lease.entries[eye]
            if entry and find(record.post.AdditiveFaceBones,eye,entry) then previous=entry.delta end
        end
    end
    local q=Math.multiply(neutral.Rotation,Math.inverse(previous))
    neutral.Rotation=UE.FQuat(q.X,q.Y,q.Z,q.W)
    local origin=neutral.Translation
    return UE.UKismetMathLibrary.InverseTransformDirection(neutral,
        UE.FVector(target.X-origin.X,target.Y-origin.Y,target.Z-origin.Z))
end


local function payload(eye,q)
    local value=inzoi.FB1AdditiveBoneData()
    -- Negative depth propagates the correction to the eye's descendants,
    -- including EyeParallel, which the tested male's visible eyes follow.
    value.BoneName,value.Depth=eye,-1
    local transform=UE.FTransform()
    transform.Rotation=UE.FQuat(q.X,q.Y,q.Z,q.W)
    -- These facial transforms store additive SCALE DELTAS. Zero preserves
    -- native size; FTransform's usual identity scale (1,1,1) doubles the eyes.
    transform.Scale3D=UE.FVector(0,0,0)
    value.Transform=transform
    return value
end

function M.apply(owner,eye,rotation)
    local record=rotation.record
    assert(eye==M.eyes[1] or eye==M.eyes[2],"Only eye bones may be changed")
    local lease
    for _,value in ipairs(owner.eye_leases) do if value.post==record.post then lease=value end end
    if not lease then
        lease={post=record.post,entries={}}
        -- Appearance may copy the old post-process data to a replacement head.
        -- Adopt our copied entries instead of stacking a second correction.
        for _,previous in ipairs(owner.eye_leases) do
            for name,entry in pairs(previous.entries) do
                local index=find(record.post.AdditiveFaceBones,name,entry)
                if index then lease.entries[name]={index=index,delta=entry.delta} end
            end
        end
        owner.eye_leases[#owner.eye_leases+1]=lease
    end
    local array=record.post.AdditiveFaceBones
    local entry=lease.entries[eye]
    local index=entry and find(array,eye,entry)
    if not index then
        entry={delta=IDENTITY}
        array:Add(payload(eye,IDENTITY))
        entry.index=array:Num()
        lease.entries[eye]=entry
    else entry.index=index end
    -- Native facial adjustments compose locally with the animated eye. Only
    -- this correction is scene-owned; the underlying face/eyelids stay native.
    local delta=Math.quaternion(rotation.Pitch,rotation.Roll)
    array:Set(entry.index,payload(eye,delta))
    entry.delta=delta
end

function M.restore(owner)
    local errors={}
    for _,lease in ipairs(owner.eye_leases or {}) do
        if not lease.restored then
            local ok,err=pcall(function()
                -- A retired UObject may already have been destroyed by an
                -- appearance refresh. It cannot retain a visible correction.
                local alive,array=pcall(function()return lease.post.AdditiveFaceBones end)
                if alive and array then
                    local indices={}
                    for eye,entry in pairs(lease.entries) do
                        if not entry.removed then
                            local index=find(array,eye,entry)
                            if index then indices[#indices+1]={index=index,entry=entry}
                            else entry.removed=true end
                        end
                    end
                    table.sort(indices,function(a,b)return a.index>b.index end)
                    for _,value in ipairs(indices) do
                        array:Remove(value.index)
                        value.entry.removed=true
                    end
                end
            end)
            if ok then lease.restored=true else errors[#errors+1]=tostring(err) end
        end
    end
    if #errors>0 then error(table.concat(errors,"; ")) end
end

return M
