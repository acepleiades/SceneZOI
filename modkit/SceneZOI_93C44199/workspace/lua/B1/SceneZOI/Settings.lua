-- Persistent player settings; groups save independently without replacing other preferences.
local Config=require('SceneZOI.Config')
local Protocol=require('SceneZOI.Protocol')
local M={}
local order={'task_rates','audio','npc_scene'}
local groups={task_rates={values={100,100},min=10,max=500},audio={values={100,100,100},min=0,max=200},npc_scene={values={15},min=5,max=120,default=15}}
local function decode(f,offset,size,spec,loading)
 if not f then return nil end
 local result={}
 for i=1,size do
  local value=tonumber(f[offset+i])
  if not value or value~=value or value%1~=0 or value<0 or value>spec.max then return nil end
  if value<spec.min then if loading then value=spec.min else return nil end end
  result[i]=value
 end
 return result
end
local function apply(group,values)
 groups[group].values=values
 if group=='audio'then require('SceneZOI.SoundNative').set_gains({sfx=values[1]/100,female_voice=values[2]/100,male_voice=values[3]/100})end
end
local function command(action,group,value)
 return inzoi.cli.execute('uimod.cfg_'..action..' mod_id='..Config.mod_id..' section=scenezoi_settings key='..group..(value and ' value='..value or ''))
end
local function state(session,group)
 session.player_settings=session.player_settings or {}
 session.player_settings[group]=session.player_settings[group]or {ack=0,code='ok'}
 return session.player_settings[group]
end
function M.boot()
 for _,group in ipairs(order)do
  local size=#groups[group].values
  local ok,_,raw=command('load',group);local f=ok and Protocol.unpack(raw)
  local values=f and #f==size+1 and f[1]=='1'and decode(f,1,size,groups[group],true)
  if not values then values={};for i=1,size do values[i]=groups[group].default or 100 end end
  apply(group,values)
 end
end
function M.task_multiplier(body)
 local index=body=='female'and 1 or body=='male'and 2
 return index and groups.task_rates.values[index]/100 or 1
end
function M.npc_scene_minutes()return groups.npc_scene.values[1]end
function M.request(session,group,raw)
 if session.stopping or session.ended or not groups[group]then return end
 local size=#groups[group].values;local f=Protocol.unpack(raw)
 if not f or #f~=5+size or f[1]~=session.client or f[2]~=session.sequence or f[3]~='settings_'..group then return end
 local count=tonumber(f[4]);local s=state(session,group)
 if not count or count%1~=0 or count<=0 or count<=s.ack or session.preparing then return end
 s.ack=count;s.code='settings_invalid'
 if tonumber(f[5])~=session.revision then s.code='settings_stale';return end
 local values=decode(f,5,size,groups[group]);if not values then return end
 local ok=command('save',group,Protocol.pack('1',table.unpack(values)))
 if not ok then s.code='settings_storage';return end
 apply(group,values);s.code='ok'
end
-- The controls were rebound to this session: everything has to be sent again.
function M.forget(session)
 for _,group in ipairs(order)do state(session,group).published=nil end
end
function M.publish(session)
 for _,group in ipairs(order)do
  local s=state(session,group)
  local packet=Protocol.pack(session.client,session.sequence,session.revision,s.ack,
   session.preparing and 'busy'or s.code,table.unpack(groups[group].values))
  if packet~=s.published then
   local ok=inzoi.cli.execute('uimod.cfg_save mod_id='..Config.mod_id..' section='..Config.section..' key=settings_'..group..'_state value='..packet)
   if ok then s.published=packet end
  end
 end
end
return M
