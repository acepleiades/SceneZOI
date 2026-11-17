local TaskData=require('SceneZOI.TaskData')
local V=require('SceneZOI.DataValidation')

return function(definitions)
 local documents={}
 for id,definition in pairs(definitions)do
  local data=V.copy(definition)
  data.schema_version,data.id,data.label=1,id,data.label or id
  documents[#documents+1]={source=id,owner='test',data=data}
 end
 return TaskData.compile({by_kind={scene_task=documents}})
end
