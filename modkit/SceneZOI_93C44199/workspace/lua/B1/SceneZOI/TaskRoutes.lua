-- Scene-local routing from an actual participant/task completion, independent of task semantics.
local V=require('SceneZOI.DataValidation')
local M={}
function M.validate(value,roles)
 if value==nil then return end
 assert(V.object(value),'Expected participant task-completion routes')
 for role,routes in pairs(value)do
  assert(roles[role],'Unbound task-route role');assert(V.object(routes),'Expected task-to-scene map')
  for task,target in pairs(routes)do V.id(task);V.id(target)end
 end
end
function M.link(nodes,warnings)
 for id,node in pairs(nodes)do for role,routes in pairs(node.task_completion_routes or {})do
  for task,target_id in pairs(routes)do
   local target=nodes[target_id]
   if not target or not V.equal(target.participants,node.participants)or not V.equal(target.furniture,node.furniture)then
    warnings[#warnings+1]='Unavailable or incompatible task route from '..id..' for '..role..'/'..task
    routes[task]=nil
   end
  end
 end end
end
function M.candidate(session,payload)
 if session.preparing or session.stopping or session.ended or session.node.kind=='transition'then return nil end
 local task=payload.task;if not task or not task.completed then return nil end
 local role=payload.participant_role
 local routes=(session.node.task_completion_routes or {})[role]
 local target=routes and routes[task.id];if not target then return nil end
 local person=(session.bindings or {})[role]
 if not person or person.id~=payload.participant_id then return nil end
 return {session_id=session.token,source_node_id=session.node.id,source_revision=session.revision,
  participant_id=person.id,participant_role=role,task_id=task.id,completion_index=task.completion_index,target=target}
end
function M.select(session,candidates)
 if session.preparing or session.stopping or session.ended or session.node.kind=='transition'then return nil end
 local valid={}
 for _,route in ipairs(candidates)do
  local maps=session.node.task_completion_routes or {};local person=(session.bindings or {})[route.participant_role]
  if route.session_id==session.token and route.source_node_id==session.node.id and route.source_revision==session.revision and
   person and person.id==route.participant_id and(maps[route.participant_role]or {})[route.task_id]==route.target then
   valid[#valid+1]=route
  end
 end
 table.sort(valid,function(a,b)
  return a.participant_role..'|'..a.task_id..'|'..a.participant_id < b.participant_role..'|'..b.task_id..'|'..b.participant_id
 end)
 return valid[1]
end
return M
