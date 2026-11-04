-- Owned local additive rotations on the native body post-process instance.
-- The game retains its animation graph, body fitting, and every foreign array entry.
local Q=require('SceneZOI.GazeMath')
local M={}
local function same(a,b)
 return math.abs(math.abs(a.X*b.X+a.Y*b.Y+a.Z*b.Z+a.W*b.W)-1)<1e-7
end
local function match(row,bone,q)
 if row.BoneName~=bone or row.Depth~=-1 then return false end
 local t=row.Transform;local p,s=t.Translation,t.Scale3D
 return math.abs(p.X)+math.abs(p.Y)+math.abs(p.Z)+math.abs(s.X)+math.abs(s.Y)+math.abs(s.Z)<1e-8 and same(t.Rotation,q)
end
local function locate(rows,bone,e)
 local function matches(row)return row and(match(row,bone,e.delta)or e.pending and match(row,bone,e.pending))end
 if e.index and matches(rows[e.index])then return e.index end
 local found
 for i,row in ipairs(rows)do if matches(row)then assert(not found,'Ambiguous body correction ownership');found=i end end
 return found
end
local function payload(bone,q)
 local row=inzoi.FB1AdditiveBoneData();row.BoneName,row.Depth=bone,-1
 local t=UE.FTransform();t.Rotation=UE.FQuat(q.X,q.Y,q.Z,q.W)
 t.Translation=UE.FVector(0,0,0);t.Scale3D=UE.FVector(0,0,0);row.Transform=t;return row
end
local function axis(mesh,b)
 assert(mesh:GetBoneIndex(b.bone)>=0 and mesh:GetBoneIndex(b.child)>=0,'Missing oscillation bone: '..b.bone..' / '..b.child)
 assert(tostring(mesh:GetParentBone(b.child))==b.bone,'Oscillation child must be a direct child: '..b.child)
 local a=mesh:GetSocketTransform(b.bone,0);local c=mesh:GetSocketTransform(b.child,0)
 local delta={X=c.Translation.X-a.Translation.X,Y=c.Translation.Y-a.Translation.Y,Z=c.Translation.Z-a.Translation.Z,W=0}
 local p=Q.multiply(Q.multiply(Q.inverse(a.Rotation),delta),a.Rotation)
 local length=math.sqrt(p.X*p.X+p.Y*p.Y+p.Z*p.Z);assert(length>1e-6,'Zero-length oscillation axis')
 return {X=p.X/length,Y=p.Y/length,Z=p.Z/length}
end
function M.apply(owner,spec,angle)
 owner.leases=owner.leases or {}
 local mesh=owner.participant.actor.Mesh
 if not mesh then return false end
 local post=mesh:GetPostProcessInstance()
 if not post then return false end
 local array=assert(post.AdditiveBones,'Body correction array unavailable');local rows=array:ToTable();local lease
 for _,l in ipairs(owner.leases)do if l.post==post and not l.restored then lease=l end end
 if not lease then
  lease={post=post,mesh=mesh,entries={},axes={}};owner.leases[#owner.leases+1]=lease
  -- Appearance rebuilds can copy our corrections. Adopt only recorded signatures.
  for _,old in ipairs(owner.leases)do if old~=lease and not old.restored then
   for bone,e in pairs(old.entries)do local i=locate(rows,bone,e)
    if i then lease.entries[bone]={index=i,delta=e.delta,pending=e.pending}end
   end
  end end
 end
 -- Read every axis before mutating the body array, retaining scalar values only.
 for _,b in ipairs(spec.bones)do if not lease.axes[b.bone]then lease.axes[b.bone]=axis(mesh,b)end end
 for _,b in ipairs(spec.bones)do
  local a=lease.axes[b.bone];local half=math.rad(angle*(b.weight or 1))*.5
  local q={X=a.X*math.sin(half),Y=a.Y*math.sin(half),Z=a.Z*math.sin(half),W=math.cos(half)}
  local e=lease.entries[b.bone];local index=e and locate(rows,b.bone,e)
  if not index then
   e={delta=q,index=array:Num()+1};lease.entries[b.bone]=e
   local row=payload(b.bone,q);array:Add(row);rows[e.index]=row
  else
   e.index=index;e.pending=q;local row=payload(b.bone,q);array:Set(index,row);rows[index]=row;e.delta=q;e.pending=nil
  end
 end
end
function M.restore(owner)
 local errors={}
 for _,lease in ipairs(owner.leases or {})do if not lease.restored then
  local ok,err=pcall(function()
   local valid,alive=pcall(function()return UE.UKismetSystemLibrary.IsValid(lease.post)end)
   if valid and alive==false then return end
   local array=lease.post.AdditiveBones;local rows=array:ToTable();local indices={}
   for bone,e in pairs(lease.entries)do local index=locate(rows,bone,e);if index then indices[#indices+1]={index=index,bone=bone}end end
   table.sort(indices,function(a,b)return a.index>b.index end)
   for _,entry in ipairs(indices)do array:Remove(entry.index);lease.entries[entry.bone]=nil end
  end)
  if ok then lease.restored=true else errors[#errors+1]=tostring(err)end
 end end
 if #errors>0 then error(table.concat(errors,'; '))end
 owner.leases={}
end
return M
