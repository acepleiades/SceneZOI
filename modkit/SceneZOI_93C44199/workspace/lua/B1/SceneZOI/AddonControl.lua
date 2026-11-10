-- Coordination between trusted installed add-ons. Never grants navigation ownership.
local V=require('SceneZOI.DataValidation')
local J=require('SceneZOI.Json')
local M={}
local registrations,results,result_order,serial={},{},{},0
local capabilities={interrupt=true,speed=true,tasks=true,presentation=true,outfits=true,attachments=true}
function M.key(addon,client,entity)return addon..'|'..client..'|'..entity end
function M.validate_capabilities(names)
 V.array(names,6);local granted={}
 for _,name in ipairs(names)do assert(capabilities[name]and not granted[name],'invalid_capability');granted[name]=true end
 return granted
end
function M.register(key,names)
 local granted=M.validate_capabilities(names)
 local n=0;for _ in pairs(registrations)do n=n+1 end;assert(registrations[key]or n<64,'integration_limit')
 registrations[key]={capabilities=granted,age=0}
 return {capabilities=V.copy(granted),lease_seconds=12,renew_after_seconds=2}
end
function M.renew(key)local r=assert(registrations[key],'integration_not_registered');r.age=0;return {lease_seconds=12}end
function M.authorize(current,key,capability,creator)
 local r=registrations[key]
 assert(creator or(r and r.capabilities[capability]),'capability_not_granted')
 -- Creators also register for expiring modifiers; abandoned clients must release them.
 if capability~='interrupt'then assert(r and r.capabilities[capability],'capability_not_granted')end
 return true
end
function M.init(s)
 s.addon_controls={};s.addon_history=J.array({});s.addon_played=J.array({});s.addon_played_ids={}
 s.playing_seconds=0;s.playing_game_seconds=0;s.peak_content_rating=nil
end
function M.layer(s,key)
 s.addon_controls=s.addon_controls or {};local layer=s.addon_controls[key]
 if not layer then serial=serial+1;layer={serial=serial,tasks={},expressions={},voice_mutes={}};s.addon_controls[key]=layer end
 return layer
end
function M.touch(layer)serial=serial+1;layer.serial=serial;return serial end
function M.release(s,key)
 registrations[key]=nil
 if s and s.addon_controls then s.addon_controls[key]=nil end
end
function M.tick(dt,sessions,release)
 local expired={};for key,r in pairs(registrations)do r.age=r.age+dt;if r.age>=12 then expired[#expired+1]=key end end
 table.sort(expired)
 for _,key in ipairs(expired)do
  registrations[key]=nil
  for _,s in ipairs(sessions)do M.release(s,key)end
  if release then release(key)end
 end
end
function M.speed(s)
 local factor=1
 for _,layer in pairs(s.addon_controls or {})do factor=factor*(layer.speed_multiplier or 1)end
 return math.max(.1,math.min(2,factor))
end
function M.task(s,pid,id)
 local rate,hold=1,false
 for _,layer in pairs(s.addon_controls or {})do
  local t=layer.tasks[pid..'|'..id]
  if t then rate=rate*(t.rate_multiplier or 1);hold=hold or t.completion_hold==true end
 end
 return math.max(0,math.min(10,rate)),hold
end
function M.muted(s,id)
 for _,layer in pairs(s and s.addon_controls or {})do if layer.voice_mutes[id]then return true end end
 return false
end
function M.expression(s,id)
 local latest,value=-1,nil
 for _,layer in pairs(s and s.addon_controls or {})do
  local row=layer.expressions[id]
  if row and(row.serial or layer.serial)>latest then latest,value=row.serial or layer.serial,row end
 end
 return value
end
function M.enter(s)
 if not s.addon_history then M.init(s)end
 local row={node_id=s.node.id,revision=s.revision,playing_seconds=0,playing_game_seconds=0}
 s.addon_history[#s.addon_history+1]=row
 if #s.addon_history>128 then table.remove(s.addon_history,1);s.history_truncated=true end
 s.addon_visit=row
end
function M.sample(s,dt,scale)
 if s.preparing or s.stopping or scale<=0 or dt<=0 then return end
 if not s.addon_history then M.init(s)end
 if not s.addon_visit or s.addon_visit.revision~=s.revision then M.enter(s)end
 s.playing_seconds=s.playing_seconds+dt;s.playing_game_seconds=s.playing_game_seconds+dt*scale
 s.addon_visit.playing_seconds=s.addon_visit.playing_seconds+dt
 s.addon_visit.playing_game_seconds=s.addon_visit.playing_game_seconds+dt*scale
 local ratings={GENERAL=1,SUGGESTIVE=2,EXPLICIT=3}
 if (ratings[s.node.content_rating]or 0)>(ratings[s.peak_content_rating]or 0)then s.peak_content_rating=s.node.content_rating end
 if not s.addon_played_ids[s.node.id]then
  s.addon_played_ids[s.node.id]=true
  if #s.addon_played<64 then
   local actions=J.array({});for i,a in ipairs(s.node.actions or {})do if i<=16 then actions[#actions+1]={type=a.type,actor=a.actor,target=a.target,performer=a.performer}else s.history_truncated=true end end
   s.addon_played[#s.addon_played+1]={node_id=s.node.id,content_rating=s.node.content_rating,actions=actions}
  else s.history_truncated=true end
 end
end
function M.facts(s)
 return {playing_seconds=s.playing_seconds or 0,playing_game_seconds=s.playing_game_seconds or 0,
  animation_seconds=s.clock.session_elapsed,peak_content_rating=s.peak_content_rating,
  visited_scenes=V.copy(s.addon_history or J.array({})),played_scenes=V.copy(s.addon_played or J.array({})),
  history_truncated=s.history_truncated==true,stop_reason=s.stop_reason,stop_origin=V.copy(s.stop_origin),cleanup_code=s.cleanup_code,cleanup_complete=s.cleanup_complete}
end
function M.ended(s,snapshot)
 results[s.token]=V.copy(snapshot);result_order[#result_order+1]=s.token
 while #result_order>32 do results[table.remove(result_order,1)]=nil end
end
function M.result(id)return V.copy(results[id])end
-- A confirmation can arrive after the session has ended and its result was kept.
function M.note_restoration(token,id,value)
 local result=results[token];if not result then return end
 for _,person in ipairs(result.participants or {})do if person.id==id then person.restoration=value end end
end
function M.reset()registrations,results,result_order={},{},{} end
return M
