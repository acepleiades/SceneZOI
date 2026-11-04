local Files=require('SceneZOI.DataFiles')
local Data=require('SceneZOI.FacialPoseData')
local M={}
function M.refresh()
 local snapshot=Files.get()
 if M.snapshot==snapshot and M.value then return M.value end
 M.snapshot=snapshot;M.value=Data.compile(Files.documents('facial_pose'))
 for _,warning in ipairs(M.value.warnings)do print('[SceneZOI] Facial pose warning: '..warning)end
 return M.value
end
function M.get()return M.value or M.refresh()end
function M.owns_eyes(id,body)
 local pose=id and M.get().poses[id];local rows=pose and pose.poses[body]
 for _,row in ipairs(rows or {})do if row.bone=='FACIAL_L_Eye'or row.bone=='FACIAL_R_Eye'then return true end end
 return false
end
return M
