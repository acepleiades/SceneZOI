local Files=require('SceneZOI.DataFiles')
local Data=require('SceneZOI.ExpressionData')
local M={}
function M.refresh()
 local snapshot=Files.get()
 if M.snapshot==snapshot and M.value then return M.value end
 M.snapshot=snapshot
 M.value=Data.compile(Files.documents('expression_set'))
 for _,warning in ipairs(M.value.warnings)do print('[SceneZOI] Expression data warning: '..warning)end
 for _,warning in ipairs(snapshot.warnings)do M.value.warnings[#M.value.warnings+1]=warning end
 return M.value
end
function M.get()return M.value or M.refresh()end
return M
