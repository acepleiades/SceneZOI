-- Deterministic partial facial pose, independent of the current expression family.
local Head=require('SceneZOI.GazeNative')
local Q=require('SceneZOI.GazeMath')
local M={}
local FORCED_LOD=1
local Targets=require('SceneZOI.FacialPoseTargets')
local I={X=0,Y=0,Z=0,W=1}
local function v(x,y,z)return {X=x,Y=y,Z=z}end
local function sub(a,b)return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
local function rotate(q,p)local result=Q.multiply(Q.multiply(q,{X=p.X,Y=p.Y,Z=p.Z,W=0}),Q.inverse(q));return v(result.X,result.Y,result.Z)end
local function quat(q)
    local length=math.sqrt(q.X*q.X+q.Y*q.Y+q.Z*q.Z+q.W*q.W)
    assert(length>.000001,'Invalid facial quaternion')
    return {X=q.X/length,Y=q.Y/length,Z=q.Z/length,W=q.W/length}
end
local function pose(h,n)
    local parentName=tostring(h:GetParentBone(n));local t=h:GetSocketTransform(n,0);local parent=h:GetSocketTransform(parentName,0)
    local delta=rotate(Q.inverse(quat(parent.Rotation)),sub(t.Translation,parent.Translation));local scale=parent.Scale3D
    return {p=v(delta.X/scale.X,delta.Y/scale.Y,delta.Z/scale.Z),q=quat(Q.multiply(Q.inverse(quat(parent.Rotation)),quat(t.Rotation)))}
end
local function payload(n,d)
    local row=inzoi.FB1AdditiveBoneData();row.BoneName=n;row.Depth=-1
    local t=UE.FTransform();t.Translation=UE.FVector(d.p.X,d.p.Y,d.p.Z);t.Rotation=UE.FQuat(d.q.X,d.q.Y,d.q.Z,d.q.W);t.Scale3D=UE.FVector(0,0,0);row.Transform=t;return row
end
local function matches(row,n,d)
    if row.BoneName~=n or row.Depth~=-1 then return false end
    local t=row.Transform;local p=t.Translation;local q=t.Rotation;local scale=t.Scale3D
    if math.abs(scale.X)+math.abs(scale.Y)+math.abs(scale.Z)>.000001 then return false end
    local actual,expected=quat(q),quat(d.q)
    local sign=actual.X*expected.X+actual.Y*expected.Y+actual.Z*expected.Z+actual.W*expected.W<0 and -1 or 1
    return math.abs(p.X-d.p.X)+math.abs(p.Y-d.p.Y)+math.abs(p.Z-d.p.Z)<.00001 and
        math.max(math.abs(actual.X-sign*expected.X),math.abs(actual.Y-sign*expected.Y),math.abs(actual.Z-sign*expected.Z),math.abs(actual.W-sign*expected.W))<.000001
end
local function locate(rows,n,e)
    if e.index and rows[e.index] and matches(rows[e.index],n,e.delta)then return e.index end
    local found
    for i,row in ipairs(rows)do if matches(row,n,e.delta)then assert(not found,'Ambiguous facial-pose ownership for '..n);found=i end end
    return found
end
local function hold_head(o,h,copied)
    o.fixed_heads=o.fixed_heads or {};local lease
    for _,value in ipairs(o.fixed_heads)do if value.head==h and not value.restored then lease=value end end
    if not lease then
        lease={head=h,lod=h:GetForcedLOD(),tick=h.VisibilityBasedAnimTickOption}
        if copied and o.fixed_head_settings then
            if lease.lod==FORCED_LOD then lease.lod=o.fixed_head_settings.lod end
            if lease.tick==0 then lease.tick=o.fixed_head_settings.tick end
        end
        o.fixed_heads[#o.fixed_heads+1]=lease
    end
    o.fixed_head_settings=lease
    if h:GetForcedLOD()~=FORCED_LOD then h:SetForcedLOD(FORCED_LOD)end
    h.VisibilityBasedAnimTickOption=0
end
local function apply(o,h)
    local post=h:GetPostProcessInstance();if not post then return end
    o.fixed_leases=o.fixed_leases or {};local lease
    for _,l in ipairs(o.fixed_leases)do if l.post==post and not l.restored then lease=l end end
    local a=post.AdditiveFaceBones;local rows=a:ToTable()
    if not lease then
        lease={post=post,entries={}};o.fixed_leases[#o.fixed_leases+1]=lease
        for _,old in ipairs(o.fixed_leases)do if old~=lease and not old.restored then
            for n,e in pairs(old.entries)do local idx=locate(rows,n,e);if idx then lease.entries[n]={index=idx,delta=e.delta}end end
        end end
    end
    hold_head(o,h,next(lease.entries)~=nil)
    local updates={};local maxerror=0;local count=0
    local seen={};local changed=not o.fixed_observation or o.fixed_observation.post~=post
    -- Read every pose before any array mutation; keep only Lua number values.
    for _,n in ipairs(o.fixed_order)do
        local target=o.fixed_targets[n]
        local actual=pose(h,n);local e=lease.entries[n];local index=e and locate(rows,n,e)
        seen[n]=actual
        local old=o.fixed_observation and o.fixed_observation[n]
        if not old or actual.p.X~=old.p.X or actual.p.Y~=old.p.Y or actual.p.Z~=old.p.Z or actual.q.X~=old.q.X or actual.q.Y~=old.q.Y or actual.q.Z~=old.q.Z or actual.q.W~=old.q.W then changed=true end
        if not index then changed=true end
        local previous=index and e.delta or {p=v(0,0,0),q=I}
        if not index and e and old and actual.p.X==old.p.X and actual.p.Y==old.p.Y and actual.p.Z==old.p.Z and actual.q.X==old.q.X and actual.q.Y==old.q.Y and actual.q.Z==old.q.Z and actual.q.W==old.q.W then previous=e.delta end
        local bq=Q.multiply(actual.q,Q.inverse(previous.q));local bp=sub(actual.p,previous.p)
        local tp=target.p;local tq=quat(target.q)
        local error=sub(actual.p,tp);local distance=math.sqrt(error.X^2+error.Y^2+error.Z^2)
        if distance>maxerror then maxerror=distance end
        count=count+1
        updates[#updates+1]={n=n,index=index,delta={p=sub(tp,bp),q=quat(Q.multiply(Q.inverse(bq),tq))}}
    end
    if not changed then return end
    seen.post=post;o.fixed_observation=seen
    local size=#rows
    for _,u in ipairs(updates)do
        if u.index then a:Set(u.index,payload(u.n,u.delta))else a:Add(payload(u.n,u.delta));size=size+1;u.index=size end
        lease.entries[u.n]={index=u.index,delta=u.delta}
    end
    o.fixed_error=maxerror;o.fixed_count=count
end
function M.prepare(o,id) assert(type(id)=='string','Facial pose requires an ID');return Targets.prepare(o,id) end
function M.sample(o,id,now)
    if not id then M.restore(o);o.person.facial_pose_error=nil;return end
    o.facial_pose_id=id
    o.fixed_now=now
    local h=Head.head(o.actor);if not h or not h:GetPostProcessInstance()then return end
    if M.prepare(o,id)==false then return end
    local prepared=o.facial_preparation
    if o.fixed_data and (not prepared.data or o.fixed_data~=prepared.data)then M.restore(o)end
    if prepared and prepared.data and o.fixed_data~=prepared.data then
        o.fixed_data=prepared.data;o.fixed_targets=prepared.data.targets;o.fixed_order=prepared.data.order;o.fixed_stage='locked'
    end
    if not prepared or not prepared.data then if o.fixed_stage then M.restore(o)end;o.person.facial_pose_error=prepared and prepared.error;return end
    apply(o,h)
end
function M.guard(o)
    if o.fixed_stage=='locked'then M.sample(o,o.facial_pose_id,o.fixed_now or 0)end
end
local function dead(object)
    local ok,value=pcall(function()return UE.UKismetSystemLibrary.IsValid(object) end)
    return ok and value==false
end
function M.restore(o)
    local errors={}
    for _,l in ipairs(o.fixed_leases or {})do if not l.restored then
        local good,message=pcall(function()
            if dead(l.post)then return end
            local a=l.post.AdditiveFaceBones;local rows=a:ToTable();local indices={}
            for n,e in pairs(l.entries)do local i=locate(rows,n,e);if i then indices[#indices+1]={index=i,bone=n}end end
            table.sort(indices,function(first,second)return first.index>second.index end)
            for _,i in ipairs(indices)do
                a:Remove(i.index)
                l.entries[i.bone]=nil
            end
        end)
        if good then l.restored=true else errors[#errors+1]=tostring(message)end
    end end
    for _,lease in ipairs(o.fixed_heads or {})do if not lease.restored then
        local good,message=pcall(function()
            if dead(lease.head)then return end
            if lease.head:GetForcedLOD()==FORCED_LOD then lease.head:SetForcedLOD(lease.lod)end
            if lease.head.VisibilityBasedAnimTickOption==0 then lease.head.VisibilityBasedAnimTickOption=lease.tick end
        end)
        if good then lease.restored=true else errors[#errors+1]=tostring(message)end
    end end
    if #errors>0 then error(table.concat(errors,'; '))end
    o.person.facial_pose_error=nil
    o.fixed_heads=nil;o.fixed_head_settings=nil;o.fixed_stage=nil;o.fixed_data=nil;o.fixed_targets=nil;o.fixed_leases=nil;o.fixed_observation=nil
end
function M.status(o)
    return (o.fixed_stage or 'off')..':'..tostring(o.fixed_count or 0)..':'..string.format('%.6f',o.fixed_error or 0)..':'..(o.facial_preparation and o.facial_preparation.source or 'none')..(o.facial_preparation and o.facial_preparation.error and ':'..o.facial_preparation.error or '')
end
return M
