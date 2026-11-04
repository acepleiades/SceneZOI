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
 inzoi.message.send_to_client(owner:GetEntityId(),'SceneZOI.Save',P.pack(lease.token,'snapshot',P.encode(J.encode(lease.save_snapshot))))
end
function M.reply(owner,request,kind)
 inzoi.message.send_to_client(owner:GetEntityId(),'SceneZOI.Save',P.pack(request,kind))
end
return M
