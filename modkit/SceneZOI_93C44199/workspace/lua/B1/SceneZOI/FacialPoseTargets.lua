-- Resolve a declared pose against each participant's current head and rig.
local Library=require('SceneZOI.FacialPoseLibrary')
local Head=require('SceneZOI.GazeNative')
local M={}
function M.prepare(o,id)
 local h=Head.head(o.actor);local mesh=h and h:GetSkeletalMeshAsset()
 if not mesh then return false end
 local definition=Library.get().poses[id]
 local old=o.facial_preparation
 if old and old.head==h and old.mesh==mesh and old.body==o.person.expression_body and old.id==id and old.definition==definition then
  if old.error then o.person.facial_pose_error=old.error end
  return true
 end
 local state={head=h,mesh=mesh,body=o.person.expression_body,id=id,source=id,definition=definition};o.facial_preparation=state
 local ok,data=pcall(function()
  assert(definition,'Facial pose is not installed: '..tostring(id))
  local rows=assert(definition.poses[state.body],'No body-compatible facial pose: '..id)
  local result={targets={},order={}}
  for _,row in ipairs(rows)do
   assert(h:GetBoneIndex(row.bone)>=0 and tostring(h:GetParentBone(row.bone))==row.parent,'Unsupported facial bone: '..row.bone)
   local p,q=row.position,row.rotation
   result.targets[row.bone]={p={X=p[1],Y=p[2],Z=p[3]},q={X=q[1],Y=q[2],Z=q[3],W=q[4]}}
   result.order[#result.order+1]=row.bone
  end
  table.sort(result.order,function(a,b)return h:GetBoneIndex(a)<h:GetBoneIndex(b)end)
  return result
 end)
 if ok then state.data=data;o.person.facial_pose_error=nil else state.error=tostring(data);o.person.facial_pose_error=state.error end
 -- An unsupported optional pose reports its error without blocking scene entry.
 return true
end
return M
