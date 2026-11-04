-- Facial montage ownership on the existing game head graph. No native state replacement.
local Head=require("SceneZOI.GazeNative")
local M={}
local function usable(object)
    local ok,value=pcall(function()return UE.UKismetSystemLibrary.IsValid(object) end)
    -- A failed bridge query is unknown, not evidence that a native owner died.
    if ok and type(value)=="boolean" then return value end
end
local function blend_time(owner)
    local ok,value=pcall(function()return UE.UGameplayStatics.GetTimeSeconds(owner.actor) end)
    if ok and type(value)=="number" and value==value and value~=math.huge then return value end
end
-- The Lua bridge keeps a userdata tombstone after a transient montage is GC'd.
-- Its typed-argument rejection is distinct from a failed playback/bridge query.
local function expired(err,method,arg)
    local text=tostring(err)
    return text:find("bad argument #"..arg.." to '"..method.."'",1,true)
        and text:find("(object needed but got nil or incompatible value)",1,true)
end
function M.body(person)
    -- Prefer resolved skeletal assets. Generated/merged meshes can have anonymous
    -- names; their appearance-body binding is already validated by B2.
    local head=Head.head(person.actor)
    for _,mesh in ipairs({head or false,person.actor.Mesh or false}) do
        if mesh then
            local asset=mesh:GetSkeletalMeshAsset()
            local name=asset and asset:GetName():lower() or ""
            if name:find("female",1,true) or name:match("[/_]f[_/]") then return "female" end
            if name:find("male",1,true) or name:match("[/_]m[_/]") then return "male" end
        end
    end
    return assert(person.body,"The participant has no resolved appearance body")
end
function M.bind(owner)
    local head=Head.head(owner.actor)
    if not head then return false end
    local instance=head:GetAnimInstance()
    if not instance or usable(instance)==false then return false end
    if owner.instance~=instance then
        owner.head,owner.instance=head,instance
        owner.rebind=true
    end
    return true
end
function M.stop(owner)
    local errors={}
    for _,lease in ipairs(owner.leases or {}) do
        if not lease.released then
            if usable(lease.instance)==false or usable(lease.montage)==false then lease.released=true
            else
                local ok,err=pcall(function()lease.instance:Montage_Stop(0,lease.montage) end)
                if ok or expired(err,"Montage_Stop",2) then lease.released=true else errors[#errors+1]=tostring(err) end
            end
        end
    end
    if #errors>0 then error(table.concat(errors,"; ")) end
    owner.montage=nil;owner.clip=nil;owner.current_lease=nil
end
function M.play(owner,option,transition,now)
    if not M.bind(owner) then return false end
    local old=owner.current_lease
    local montage=owner.instance:PlaySlotAnimationAsDynamicMontage(option.asset,"DefaultSlot",transition,transition,1,1,-1,option.sample)
    assert(montage,"Native head slot rejected an expression")
    -- Record ownership before any subsequent native call can fail.
    local lease={instance=owner.instance,montage=montage}
    owner.leases=owner.leases or {};owner.leases[#owner.leases+1]=lease;owner.current_lease=lease
    owner.montage,owner.clip,owner.position=montage,option,option.sample
    owner.animation_time=now
    owner.instance:Montage_SetPlayRate(montage,0)
    owner.instance:Montage_SetPosition(montage,option.sample)
    if old and not old.released then
        -- Montage_IsActive becomes false as soon as blend-out starts. Retain
        -- ownership through the native blend interval, including game pause.
        local blend_now=blend_time(owner)
        old.retire_at=blend_now and blend_now+transition+0.1
        if usable(old.instance)==false or usable(old.montage)==false then old.released=true
        else
            local ok,err=pcall(function()old.instance:Montage_Stop(transition,old.montage) end)
            if not ok then
                if expired(err,"Montage_Stop",2) then old.released=true else error(err) end
            end
        end
    end
    owner.rebind=false
    return true
end
function M.replay(owner,now)
    local position=owner.position
    local result=M.play(owner,owner.clip,0,now)
    if result then owner.position=position;owner.instance:Montage_SetPosition(owner.montage,position)end
    return result
end
function M.hold(owner,now)
    -- Prune only confirmed completed/invalid leases. Failed queries remain
    -- retryable and an inactive montage may still be blending out visibly.
    local live,blend_now={},blend_time(owner)
    for _,lease in ipairs(owner.leases or {}) do
        if not lease.released and (usable(lease.instance)==false or usable(lease.montage)==false) then lease.released=true end
        if not lease.released and lease~=owner.current_lease and lease.retire_at and blend_now and blend_now>=lease.retire_at then
            local ok,active=pcall(function()return lease.instance:Montage_IsActive(lease.montage) end)
            if (ok and not active) or (not ok and expired(active,"Montage_IsActive",1)) then lease.released=true end
        end
        if not lease.released then live[#live+1]=lease end
    end
    owner.leases=live
    if not owner.clip then return end
    -- Facial sequences contain native blinks. Advance their sampled pose rather
    -- than repeatedly evaluating frame zero. Explicit authored samples stay held.
    -- Guard calls omit time and hold outgoing poses throughout preparation.
    if now then
        if owner.clip.animated and owner.animation_time then
            owner.position=(owner.position+math.max(0,now-owner.animation_time))%owner.clip.duration
        end
        owner.animation_time=now
    end
    if not M.bind(owner) then return end
    local ok,active=pcall(function()return owner.instance:Montage_IsActive(owner.montage) end)
    if not ok then
        if expired(active,"Montage_IsActive",1) then
            if owner.current_lease then owner.current_lease.released=true end
            return M.replay(owner,now)
        end
        return false
    end
    if owner.rebind or not active then return M.replay(owner,now) end
    owner.instance:Montage_SetPosition(owner.montage,owner.position)
    return true
end
return M
