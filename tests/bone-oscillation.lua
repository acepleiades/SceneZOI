package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local V=require('SceneZOI.DataValidation');local Q=require('SceneZOI.GazeMath')
local I={X=0,Y=0,Z=0,W=1}
local function vec(x,y,z)return {X=x,Y=y,Z=z}end
local function transform(q)return {Translation=vec(0,0,0),Scale3D=vec(1,1,1),Rotation=q or V.copy(I)}end
local fail_set,fail_remove=false,false
local function array(rows)
 local a={rows=V.copy(rows or {})}
 function a:Num()return #self.rows end
 function a:ToTable()return V.copy(self.rows)end
 function a:Add(v)self.rows[#self.rows+1]=V.copy(v)end
 function a:Set(i,v)self.rows[i]=V.copy(v);if fail_set then fail_set=false;error('partial native Set')end end
 function a:Remove(i)if fail_remove then fail_remove=false;error('temporary cleanup failure')end;table.remove(self.rows,i)end
 return a
end
UE={FQuat=function(x,y,z,w)return {X=x,Y=y,Z=z,W=w}end,FVector=vec,FTransform=transform,
 UKismetSystemLibrary={IsValid=function(o)return not o.dead end}}
inzoi={FB1AdditiveBoneData=function()return {}end}
local Native=require('SceneZOI.BoneOscillation')
local foreign={{BoneName='joint',Depth=0,Transform=transform()},{BoneName='other_mod',Depth=-1,Transform=transform()}}
foreign[1].Transform.Translation.X=2
local spec={bones={{bone='joint',child='tip',weight=1}}}
local function owner(id)
 local post={AdditiveBones=array(foreign),AdditiveFaceBones=array({{sentinel=true}})}
 local mesh={post=post,q=I}
 function mesh:GetPostProcessInstance()return self.post end
 function mesh:GetBoneIndex(b)return(b=='joint'or b=='tip')and 1 or -1 end
 function mesh:GetParentBone()return 'joint'end
 function mesh:GetSocketTransform(b)
  local t=transform(self.q)
  if b=='tip'then
   local p=Q.multiply(Q.multiply(self.q,{X=10,Y=0,Z=0,W=0}),Q.inverse(self.q))
   t.Translation=vec(p.X,p.Y,p.Z)
  end
  return t
 end
 return {participant={id=id,actor={Mesh=mesh}}},mesh
end
local a,am=owner('1');local b,bm=owner('2')
for i=1,200 do
 am.q=Q.quaternion(i*3,i*2)
 local angle=math.sin(i)*1.25
 Native.apply(a,spec,angle);Native.apply(b,spec,-angle*.8)
 assert(am.post.AdditiveBones:Num()==3 and bm.post.AdditiveBones:Num()==3,'No accumulation; independent same-body owners')
 local q=am.post.AdditiveBones.rows[3].Transform.Rotation
 assert(math.abs(q.X-math.sin(math.rad(angle)/2))<1e-7 and math.abs(q.Y)+math.abs(q.Z)<1e-7,'Local longitudinal axis must not follow world orientation')
 assert(V.equal(am.post.AdditiveBones.rows[1],foreign[1])and V.equal(am.post.AdditiveBones.rows[2],foreign[2]))
 local scale=am.post.AdditiveBones.rows[3].Transform.Scale3D
 assert(scale.X==0 and scale.Y==0 and scale.Z==0,'Correction scale is additive zero')
 assert(am.post.AdditiveFaceBones.rows[1].sentinel,'Facial overlays untouched')
end
local old=am.post;am.post={AdditiveBones=array(old.AdditiveBones.rows)}
Native.apply(a,spec,.7);assert(am.post.AdditiveBones:Num()==3,'Adopt copied own correction on replacement post')
-- Removing a foreign entry shifts our index; locate only the recorded signature.
am.post.AdditiveBones:Remove(1);Native.apply(a,spec,.5);assert(am.post.AdditiveBones:Num()==2)
fail_set=true;assert(not pcall(Native.apply,a,spec,.8))
fail_remove=true;assert(not pcall(Native.restore,a));Native.restore(a)
assert(am.post.AdditiveBones:Num()==1 and am.post.AdditiveBones.rows[1].BoneName=='other_mod')
assert(old.AdditiveBones:Num()==2 and bm.post.AdditiveBones:Num()==3,'Cleanup owns old/new posts and does not affect other participant')
Native.restore(b);Native.restore(b);assert(bm.post.AdditiveBones:Num()==2)
local c,cm=owner('3');Native.apply(c,spec,.3);cm.post.dead=true;Native.restore(c)
local d,dm=owner('4');local bad={bones={{bone='absent',child='tip'}}}
assert(not pcall(Native.apply,d,bad,1));Native.restore(d);assert(dm.post.AdditiveBones:Num()==2)
print('Bone oscillation native adapter passed: local axes under moving poses, weighted independent owners, no accumulation, foreign/facial corrections preserved, copied/rebuilt posts, shifted indices, partial Set and retryable cleanup, dead/missing bones and idempotent release.')
