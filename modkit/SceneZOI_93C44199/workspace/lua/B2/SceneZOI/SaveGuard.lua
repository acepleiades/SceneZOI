local P=require('SceneZOI.Protocol')
local J=require('SceneZOI.Json')
local R=require('SceneZOI.SaveRecovery')
local M={}
function M.offer(owner,lease)
 if not lease.save_snapshot then
  local data=R.capture(lease,{})
  local setting=owner:GetComponent(inzoi.EB2ComponentType.Appearance):GetAppearanceSetting()
  data.body_merge={base=setting.Body.bUseMeshMerge,final=setting.FinalBody.bUseMeshMerge}
  data.outfit=true -- Remove only our exact temporary layer, if it was applied later.
  lease.save_snapshot=data
 end
 local kind=lease.save_settled and 'settled_snapshot'or 'snapshot'
 local data=lease.save_settled and {token=lease.token,checkpoint=lease.entry_checkpoint,location=lease.save_snapshot.location,rotation=lease.save_snapshot.rotation}or lease.save_snapshot
 inzoi.message.send_to_client(owner:GetEntityId(),'SceneZOI.Save',P.pack(lease.token,kind,P.encode(J.encode(data))))
 if lease.save_settled then lease.entry_checkpoint_sent_at=os.time()end
end
-- Native GetUp may restore the actor outside the seat after the original
-- journal was captured. Replace only its return coordinates; clothing, body,
-- autonomy, collision and held-object originals must remain the first snapshot.
function M.settled(owner,lease)
 assert(lease.tasks_settled and lease.save_snapshot,'Missing settled save snapshot')
 local coordinates=R.capture(lease,{})
 local original=lease.save_snapshot
 local changed=false
 for _,key in ipairs({'location','rotation'})do for i=1,3 do
  if original[key][i]~=coordinates[key][i]then changed=true end
 end end
 if changed then
  original.location,original.rotation=coordinates.location,coordinates.rotation
  lease.save_settled=true;lease.entry_checkpoint=(lease.entry_checkpoint or 0)+1
  lease.entry_checkpoint_sent_at=nil
 end
 if not lease.save_settled or lease.entry_checkpoint_acked==lease.entry_checkpoint then return true end
 local now,last=os.time(),lease.entry_checkpoint_sent_at
 if not last or now<last or now-last>=1 then M.offer(owner,lease)end
 return false
end
function M.reply(owner,request,kind)
 inzoi.message.send_to_client(owner:GetEntityId(),'SceneZOI.Save',P.pack(request,kind))
end
return M
