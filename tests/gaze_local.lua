local root=TEST_ROOT or "modkit/SceneZOI_93C44199/workspace/lua/"
package.path=root.."B1/?.lua;"..package.path
local Math=require("SceneZOI.GazeMath")
local function copy(v)
    if type(v)~="table" then return v end
    local result={};for k,x in pairs(v) do if type(x)~="function" then result[k]=copy(x) end end;return result
end
local function transform(q)
    return {Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1},Rotation=q or {X=0,Y=0,Z=0,W=1}}
end
local fail_remove=false
local function array(rows)
    local a={rows=copy(rows)}
    function a:Num()return #self.rows end
    function a:ToTable()return self.rows end
    function a:Get(i)assert(i>=1 and i<=#self.rows);return self.rows[i]end
    function a:Set(i,v)self:Get(i);self.rows[i]=copy(v)end
    function a:Add(v)self.rows[#self.rows+1]=copy(v)end
    function a:Remove(i)
        if fail_remove and self:Get(i).BoneName=="FACIAL_L_Eye" then fail_remove=false;error("cleanup retry") end
        table.remove(self.rows,i)
    end
    return a
end
local original={}
for _,bone in ipairs({"Head","FACIAL_L_Eye","FACIAL_R_Eye"}) do
    local t=transform();t.Translation.X=2
    original[#original+1]={BoneName=bone,Depth=0,Transform=t}
end
local post={AdditiveFaceBones=array(original)}
local headq=Math.quaternion(0,0)
local bases={FACIAL_L_Eye=Math.quaternion(1,2),FACIAL_R_Eye=Math.quaternion(-1,2)}
local function rotate(q,v)
    local r=Math.multiply(Math.multiply(q,{X=v.X,Y=v.Y,Z=v.Z,W=0}),Math.inverse(q))
    return {X=r.X,Y=r.Y,Z=r.Z}
end
local function actual(eye)
    local is_child=eye:find("Parallel",1,true)~=nil
    local source=eye:gsub("Parallel","")
    local delta=Math.quaternion(0,0)
    for _,v in ipairs(post.AdditiveFaceBones.rows) do
        if v.BoneName==source and v.Transform.Translation.X==0 and (not is_child or v.Depth<0 or v.Depth>=1) then delta=v.Transform.Rotation end
    end
    return Math.multiply(headq,Math.multiply(bases[source],delta))
end
local instance={EyeLookAtLimit={Pitch=17,Yaw=0,Roll=5}}
local child={GetName=function()return "Head"end,GetAnimInstance=function()return instance end,
    GetPostProcessInstance=function()return post end,GetParentBone=function()return "FACIAL_C_FacialRoot"end,
    GetBoneIndex=function(_,bone)return bone=="missing" and -1 or 1 end}
child.GetSocketTransform=function(_,eye)
    return transform(eye=="FACIAL_C_FacialRoot" and headq or actual(eye))
end
UE={USkeletalMeshComponent={StaticClass=function()return {}end},FTransform=transform,
    FQuat=function(x,y,z,w)return {X=x,Y=y,Z=z,W=w}end,
    FVector=function(x,y,z)return {X=x,Y=y,Z=z}end,
    UKismetMathLibrary={InverseTransformDirection=function(t,v)return rotate(Math.inverse(t.Rotation),v)end}}
inzoi={FB1AdditiveBoneData=function()return {}end,
    cli={execute=function()error("Local eye updates must not issue CLI commands")end}}
local actor={K2_GetComponentsByClass=function()return {child}end,Mesh=child}
local owner={id="9",actor=actor}
local Native=require("SceneZOI.GazeNative")
Native.capture(owner)
for frame=1,50 do
    headq=Math.quaternion(frame*3,frame*2)
    local record=assert(Native.bind(owner))
    for _,eye in ipairs(Native.eyes) do
        local target=rotate(Math.multiply(headq,bases[eye]),{X=.12,Y=.02,Z=1})
        local direction=Native.direction(record,eye,target)
        local p,r=Math.angles(direction,record.limit)
        assert(math.abs(p-math.deg(-math.atan(.12,1)))<.00001,"Eye correction fed back or used the head's previous orientation")
        Native.apply(owner,eye,Native.rotation(record,p,r))
    end
    assert(post.AdditiveFaceBones:Num()==#original+2,"Eye entries accumulated per sample")
    for _,eye in ipairs(Native.eyes) do
        local value=post.AdditiveFaceBones:Get(eye=="FACIAL_L_Eye" and #original+1 or #original+2)
        local scale=value.Transform.Scale3D
        -- Mirror the native facial scale-delta rule, rather than treating the
        -- entry as a normal multiplicative FTransform. This catches tier3-1's
        -- actual doubled-eye bug even though its rotation/cleanup tests passed.
        for _,axis in ipairs({"X","Y","Z"}) do
            assert(math.abs(.98813*(1+scale[axis])-.98813)<.000001,"Gaze enlarged the visible eye")
        end
        local parent,child_pose=actual(eye),actual(eye.."Parallel")
        local dot=math.abs(parent.X*child_pose.X+parent.Y*child_pose.Y+parent.Z*child_pose.Z+parent.W*child_pose.W)
        assert(math.abs(dot-1)<.000001,"Parent eye changed but the male's visible child eye did not")
    end
end
local first=post
post={AdditiveFaceBones=array(first.AdditiveFaceBones.rows)}
for _,eye in ipairs(Native.eyes) do
    local record=Native.bind(owner)
    Native.apply(owner,eye,Native.rotation(record,0,0))
end
assert(post.AdditiveFaceBones:Num()==#original+2,"Copied corrections were stacked")
post.AdditiveFaceBones=array(original)
for _,eye in ipairs(Native.eyes) do
    local record=Native.bind(owner)
    Native.apply(owner,eye,Native.rotation(record,0,0))
end
assert(post.AdditiveFaceBones:Num()==#original+2)
local other={BoneName="other_mod",Depth=3,Transform=transform()}
post.AdditiveFaceBones:Add(other)
fail_remove=true
assert(not pcall(Native.restore,owner));Native.restore(owner)
assert(first.AdditiveFaceBones:Num()==#original and post.AdditiveFaceBones:Num()==#original+1)
for index,v in ipairs(original) do
    assert(first.AdditiveFaceBones:Get(index).BoneName==v.BoneName and first.AdditiveFaceBones:Get(index).Transform.Translation.X==2)
    assert(post.AdditiveFaceBones:Get(index).BoneName==v.BoneName and post.AdditiveFaceBones:Get(index).Transform.Translation.X==2)
end
assert(post.AdditiveFaceBones:Get(#original+1).BoneName=="other_mod","Cleanup removed another owner's entry")
print("Gaze native adapter: local rotation under fast head motion, no feedback/growth, copied/reset heads, isolated cleanup and retries passed")
