local Files=require('SceneZOI.DataFiles')
local Data=require('SceneZOI.VoiceData')
local M={}
function M.refresh()
 local source=Files.get()
 if M.source==source and M.value then return M.value end
 M.source,M.value=source,Data.compile(source)
 for _,warning in ipairs(M.value.warnings)do print('[SceneZOI] Voice data warning: '..warning)end
 return M.value
end
function M.get()return M.value or M.refresh()end
return M
