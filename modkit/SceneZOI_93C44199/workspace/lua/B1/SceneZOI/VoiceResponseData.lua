local V=require('SceneZOI.DataValidation')
local Keys=require('SceneZOI.ExpressionKeys')
local M={}
function M.validate(value,roles)
 assert(V.object(value or {}),'Expected task voice response map')
 for role,tasks in pairs(value or {})do
  assert(roles[role],'Unbound completing voice role');assert(V.object(tasks),'Expected task voice map')
  for task,rules in pairs(tasks)do
   V.id(task);V.array(rules,32)
   for _,rule in ipairs(rules)do
    V.fields(rule,{'participant','context','response','fade_out','priority'},{'participant','context','response'})
    assert(roles[rule.participant],'Unbound response speaker')
    Keys.required(rule.context);Keys.required(rule.response)
    if rule.fade_out~=nil then V.number(rule.fade_out,0,5)end
    if rule.priority~=nil then V.number(rule.priority,-1000,1000,true)end
   end
  end
 end
end
return M
