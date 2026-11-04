package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local Q=require('SceneZOI.GazeMath')
local I={X=0,Y=0,Z=0,W=1}
local function vec(x,y,z)return {X=x or 0,Y=y or 0,Z=z or 0}end
local function copy(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do if type(v)~='function'then r[k]=copy(v)end end;return r end
local function add(a,b)return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
local function sub(a,b)return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
local function rot(q,p)local r=Q.multiply(Q.multiply(q,{X=p.X,Y=p.Y,Z=p.Z,W=0}),Q.inverse(q));return vec(r.X,r.Y,r.Z)end
local function tf(q,p)return {Translation=p or vec(),Rotation=q or copy(I),Scale3D=vec(1,1,1)}end
local function array(rows)
    local a={rows=copy(rows or {})}
    function a:ToTable()return copy(self.rows)end
    function a:Add(v)self.rows[#self.rows+1]=copy(v)end
    function a:Set(i,v)self.rows[i]=copy(v)end
    function a:Remove(i)if self.fail then self.fail=false;error('temporary removal failure')end;table.remove(self.rows,i)end
    return a
end
UE={FTransform=tf,FVector=vec,FQuat=function(x,y,z,w)return {X=x,Y=y,Z=z,W=w}end,
    UAnimSequence={StaticClass=function()return 'sequence'end},UObject={Load=function()return {IsA=function()return true end}end},UKismetSystemLibrary={IsValid=function(v)return not v.dead end}}
inzoi={FB1AdditiveBoneData=function()return {}end}
package.loaded['SceneZOI.GazeNative']={head=function(actor)return actor.head end}
package.loaded['SceneZOI.ExpressionNative']={play=function(o,clip)o.clip=clip;o.instance.clip=clip;return true end}

local function targets(body)
    local rows={
        {'FACIAL_C_Jaw','FACIAL_C_FacialRoot',0,0,0},
        {'FACIAL_C_LowerLipRotation','FACIAL_C_FacialRoot',0,0,0},
        {'FACIAL_C_MouthUpper','FACIAL_C_FacialRoot',0,4,.4},
        {'FACIAL_C_LipUpper','FACIAL_C_MouthUpper',0,1,.7},
        {'FACIAL_C_MouthLower','FACIAL_C_LowerLipRotation',0,4,-.4},
        {'FACIAL_C_LipLower','FACIAL_C_MouthLower',0,1,-.7},
        {'FACIAL_L_LipCorner','FACIAL_C_FacialRoot',-1.5,5,0},
        {'FACIAL_R_LipCorner','FACIAL_C_FacialRoot',1.5,5,0}}
    local result={}
    for _,row in ipairs(rows)do result[#result+1]={bone=row[1],parent=row[2],position={row[3],row[4],row[5]+(body=='male' and .05 or 0)},rotation={0,0,0,1}}end
    return result
end
local definitions={['scenezoi.open_o']={poses={female=targets('female'),male=targets('male')}}}
package.loaded['SceneZOI.FacialPoseLibrary']={get=function()return {poses=definitions}end}
local played=0
package.loaded['SceneZOI.ExpressionNative'].play=function()played=played+1;error('Visible reference playback is forbidden')end
UE.UObject.Load=function()error('Instant mouth targets must not load a reference animation')end
local Mouth=require('SceneZOI.FacialPose')

local function fixture(id,body,width)
    local h={lod=0,VisibilityBasedAnimTickOption=2,post={AdditiveFaceBones=array()},family=0,origin=vec(id*100,0,150),turn=copy(I)}
    local bones={
      {'FACIAL_C_FacialRoot',nil,vec()},
      {'FACIAL_L_Eye','FACIAL_C_FacialRoot',vec(-3*width,3,6)},
      {'FACIAL_R_Eye','FACIAL_C_FacialRoot',vec(3*width,3,6)},
      {'FACIAL_C_Jaw','FACIAL_C_FacialRoot',vec()},
      {'FACIAL_C_LowerLipRotation','FACIAL_C_FacialRoot',vec()},
      {'FACIAL_C_MouthUpper','FACIAL_C_FacialRoot',vec(0,4,.4)},
      {'FACIAL_C_LipUpper','FACIAL_C_MouthUpper',vec(0,1,.4)},
      {'FACIAL_C_MouthLower','FACIAL_C_LowerLipRotation',vec(0,4,-.4)},
      {'FACIAL_C_LipLower','FACIAL_C_MouthLower',vec(0,1,-.4)},
      {'FACIAL_L_LipCorner','FACIAL_C_FacialRoot',vec(-2*width,5,0)},
      {'FACIAL_R_LipCorner','FACIAL_C_FacialRoot',vec(2*width,5,0)},
      {'FACIAL_L_Brow','FACIAL_C_FacialRoot',vec(-2,3,8)},
      {'FACIAL_L_LipUpper1','FACIAL_C_FacialRoot',vec(0,0,-150)}}
    local by={};for _,row in ipairs(bones)do by[row[1]]=row end
    local mesh={GetName=function()return body..'_'..tostring(width)end}
    function h:GetSkeletalMeshAsset()return mesh end
    function h:GetNumBones()return #bones end
    function h:GetBoneName(i)return bones[i+1][1]end
    function h:GetBoneIndex(n)for i,row in ipairs(bones)do if row[1]==n then return i-1 end end;return -1 end
    function h:GetParentBone(n)return by[n] and by[n][2] or 'Root'end
    function h:GetForcedLOD()return self.lod end
    function h:SetForcedLOD(v)self.lod=v end
    function h:GetPostProcessInstance()return self.post end
    function h:GetSocketTransform(n,space)
        if n=='Root'then return tf(self.turn,self.origin)end
        local row=assert(by[n],n);local p=copy(row[3]);local q=copy(I)
        local f=self.clip and self.clip.label=='Mouth reference' and 0 or self.family
        if n=='FACIAL_C_LipUpper'then p.X=p.X+f*.08;p.Z=p.Z+f*.10 end
        if n=='FACIAL_C_LipLower'then p.Y=p.Y+f*.05;p.Z=p.Z-f*.10 end
        if n=='FACIAL_L_Brow'then p.Z=p.Z+f*.4 end
        for _,entry in ipairs(self.post.AdditiveFaceBones.rows)do if entry.BoneName==n then
            p=add(p,entry.Transform.Translation);q=Q.multiply(q,entry.Transform.Rotation)
        end end
        local parent=self:GetSocketTransform(row[2] or 'Root',0)
        return tf(Q.multiply(parent.Rotation,q),add(parent.Translation,rot(parent.Rotation,p)))
    end
    local foreign={BoneName='FACIAL_L_Eye',Depth=-1,Transform=tf()};foreign.Transform.Scale3D=vec()
    h.post.AdditiveFaceBones:Add(foreign)
    local clip={label='Current'};h.clip=clip
    local o={id=tostring(id),actor={head=h},instance=h,person={expression_body=body},clip=clip,next=10}
    return o,h,foreign
end
local a,ha,foreign=fixture(1,'female',1)
local b,hb=fixture(2,'female',1.15)
local c,hc=fixture(3,'male',1.1)
for _,o in ipairs({a,b,c})do assert(Mouth.prepare(o,'scenezoi.open_o'));Mouth.sample(o,'scenezoi.open_o',0)end
assert(played==0 and a.fixed_stage=='locked' and b.fixed_stage=='locked' and c.fixed_stage=='locked','All participants must acquire the O in the first sample')
assert(a.fixed_targets and b.fixed_targets and c.fixed_targets,'All independent participants must calibrate')
-- Native transforms can round/renormalize a quaternion during a round trip.
-- Rotation ownership must not require its original quaternion magnitude.
local initialCount=#ha.post.AdditiveFaceBones.rows
for _,row in ipairs(ha.post.AdditiveFaceBones.rows)do
    if row.BoneName~='FACIAL_L_Eye'then
        for _,key in ipairs({'X','Y','Z','W'})do row.Transform.Rotation[key]=row.Transform.Rotation[key]*1.00002 end
    end
end
Mouth.guard(a)
assert(#ha.post.AdditiveFaceBones.rows==initialCount,'Quaternion round trips duplicated owned mouth corrections')

assert(a.fixed_targets~=b.fixed_targets and a.fixed_targets~=c.fixed_targets)
assert(not a.fixed_targets.FACIAL_L_LipUpper1,'Unevaluated detail bones must be excluded')
assert(not a.fixed_targets.FACIAL_L_Eye and not a.fixed_targets.FACIAL_L_Brow,'Upper face must remain native')
assert(ha.lod==1 and hb.lod==1 and hc.lod==1)
local function relative(h,n)
    local t=h:GetSocketTransform(n,0);local p=h:GetSocketTransform(h:GetParentBone(n),0)
    return rot(Q.inverse(p.Rotation),sub(t.Translation,p.Translation))
end
for i=1,30 do
    ha.family=(i%7)-3;hb.family=(i%5)-2;hc.family=(i%3)-1
    ha.origin=vec(100+i,0,150);ha.turn=Q.quaternion(i*.3,i*.2)
    for _,o in ipairs({a,b,c})do Mouth.sample(o,'scenezoi.open_o',1+i*.1);Mouth.guard(o)end
    for _,o in ipairs({a,b,c})do
        local h=o.actor.head
        for n,target in pairs(o.fixed_targets)do
            local p=relative(h,n);local d=sub(p,target.p)
            assert(math.abs(d.X)+math.abs(d.Y)+math.abs(d.Z)<.00001,'Underlying expression changed the fixed mouth: '..n)
        end
    end
end
local brow=ha:GetSocketTransform('FACIAL_L_Brow',0).Translation;ha.family=ha.family+2
assert(ha:GetSocketTransform('FACIAL_L_Brow',0).Translation.Z~=brow.Z,'Upper-face motion must remain available')
-- Another owner may insert face-shaping entries and shift our array indices.
local foreignMouth={BoneName='FACIAL_C_Jaw',Depth=-1,Transform=tf()}
foreignMouth.Transform.Scale3D=vec(.1,0,0)
table.insert(ha.post.AdditiveFaceBones.rows,1,copy(foreignMouth));Mouth.guard(a)
local count=#ha.post.AdditiveFaceBones.rows
ha.post={AdditiveFaceBones=array(ha.post.AdditiveFaceBones.rows)};Mouth.guard(a)
assert(#ha.post.AdditiveFaceBones.rows==count,'Copied-head adoption duplicated mouth controls')
ha.post.AdditiveFaceBones.fail=true
assert(not pcall(Mouth.restore,a),'Failed cleanup must remain retryable')
Mouth.restore(a)
assert(#ha.post.AdditiveFaceBones.rows==2 and ha.post.AdditiveFaceBones.rows[1].Transform.Scale3D.X==.1 and ha.post.AdditiveFaceBones.rows[2].BoneName==foreign.BoneName,'Foreign shape and eye entries must survive index shifts and cleanup')
assert(ha.lod==0 and ha.VisibilityBasedAnimTickOption==2 and hb.lod==1 and hb.VisibilityBasedAnimTickOption==0,'Restoration must be participant-owned')
Mouth.sample(b,nil,9);Mouth.restore(c)
assert(#hb.post.AdditiveFaceBones.rows==1 and #hc.post.AdditiveFaceBones.rows==1)
assert(hb.lod==0 and hc.lod==0)
Mouth.sample(a,'scenezoi.open_o',10)
assert(a.fixed_targets,'A restored participant must support repeat calibration')
Mouth.restore(a)
print('Fixed mouth passed: deterministic reference, three independent roles, repeated bodies, head motion, underlying facial changes, copied head, native upper face, cleanup retries and LOD restoration.')


Mouth.sample(a,'scenezoi.open_o',10)
local savedAsset,savedTransform=ha.GetSkeletalMeshAsset,ha.GetSocketTransform
ha.GetSkeletalMeshAsset=function()return nil end
ha.GetSocketTransform=function()error('Read a temporarily unavailable head')end
assert(pcall(Mouth.guard,a),'Temporary mesh unavailability must retain the owned pose without reading missing bones')
ha.GetSkeletalMeshAsset=savedAsset;ha.GetSocketTransform=savedTransform;Mouth.restore(a)
local replacement,hr=fixture(4,'female',1)
local old=hr.GetParentBone
hr.GetParentBone=function(self,n)if n=='FACIAL_C_LipUpper'then return 'OtherRig'end;return old(self,n)end
assert(Mouth.prepare(replacement,'scenezoi.open_o') and replacement.person.facial_pose_error,'An unsupported optional head must report its incompatibility without blocking entry')
Mouth.sample(replacement,'scenezoi.open_o',0)
assert(not replacement.fixed_stage and hr.lod==0 and #hr.post.AdditiveFaceBones.rows==1,'Unsupported heads must not acquire mouth entries')
local changed,hchanged=fixture(5,'female',1)
a.actor.head=hchanged;Mouth.sample(a,'scenezoi.open_o',0)
assert(a.fixed_stage=='locked' and a.facial_preparation.head==hchanged,'A head rebuild must bind its targets immediately')
Mouth.restore(a)
assert(ha.lod==0 and hchanged.lod==0 and played==0,'Head rebuild cleanup or reference-free playback regressed')
print('Instant mouth presets passed: first-sample acquisition, no reference assets/playback, three independent owners, repeated bodies, expression invariance, head rebuilds, unsupported rigs and retryable cleanup.')

-- Different joint subsets must remove the old owned footprint before acquisition.
definitions['example.brow']={poses={female={{bone='FACIAL_L_Brow',parent='FACIAL_C_FacialRoot',position={-2,3,9},rotation={0,0,0,1}}}}}
Mouth.sample(a,'scenezoi.open_o',0)
Mouth.sample(a,'example.brow',0)
assert(a.fixed_count==1 and a.fixed_targets.FACIAL_L_Brow and not a.fixed_targets.FACIAL_C_Jaw,'Switching poses retained old bones')
Mouth.sample(a,'example.missing',0)
assert(not a.fixed_stage and a.person.facial_pose_error,'Missing pose retained the preceding override')
Mouth.sample(a,'example.brow',0);assert(a.fixed_stage=='locked'and not a.person.facial_pose_error)
Mouth.restore(a)
print('Generic facial poses: disjoint bone switching, missing declarations, recovery and no stale footprint passed.')
