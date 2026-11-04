-- Per-entity preferences outside save files; an explicit silent choice is persistent.
local Config=require('SceneZOI.Config')
local Protocol=require('SceneZOI.Protocol')
local Json=require('SceneZOI.Json')
local V=require('SceneZOI.DataValidation')
local Keys=require('SceneZOI.ExpressionKeys')
local Library=require('SceneZOI.VoiceLibrary')
local M={}
local function command(action,id,value)
 local line='uimod.cfg_'..action..' mod_id='..Config.mod_id..' section=scenezoi_voice key=zoi_'..id
 if value then line=line..' value='..value end
 return inzoi.cli.execute(line)
end
function M.options(data,body,archetype,context)
 local ids={}
 for id,set in pairs(data.sets)do if set.body==body and set.archetype==archetype and set.context==context then ids[#ids+1]=id end end
 table.sort(ids);return ids
end
function M.defaults(data,body,archetype)
 local result={}
 for context in pairs(data.contexts)do local ids=M.options(data,body,archetype,context);result[context]=ids[1]end
 return result
end
function M.normalize(raw,body,data)
 local archetype=Keys.normalize(raw and raw.archetype)
 if not archetype or not data.archetypes[archetype]or data.archetypes[archetype].body~=body then return {schema_version=1,sets={}}end
 local result={schema_version=1,archetype=archetype,sets={}}
 for context,id in pairs(type(raw.sets)=='table'and raw.sets or {})do
  context=Keys.normalize(context);id=Keys.normalize(id)
  local set=id and data.sets[id]
  if context and set and set.context==context and set.archetype==archetype and set.body==body then result.sets[context]=id end
 end
 return result
end
function M.load(person,body)
 local data=Library.get();local ok,_,raw=command('load',person.id)
 local parsed
 if ok and raw and raw~=''then
  local good,value=pcall(function()local f=Protocol.unpack(raw);assert(f and f[1]=='voice1');local decoded=Protocol.decode(f[2]);return Json.decode(decoded)end)
  if good and V.object(value)and value.schema_version==1 and V.object(value.sets)then parsed=value end
 end
 -- An existing profile that loses its package becomes silent, without overwriting
 -- its saved IDs. It recovers naturally when the package returns next session.
 if not parsed then local a=data.defaults[body];parsed={archetype=a,sets=a and M.defaults(data,body,a)or {}}end
 person.voice_profile=M.normalize(parsed,body,data);person.voice_body=body;person.voice_loaded=true
 return person.voice_profile
end
function M.request(session,raw)
 if session.stopping or session.ended then return end
 local f=Protocol.unpack(raw)
 if not f or f[1]~=session.client or f[2]~=session.sequence or f[3]~='voice'then return end
 local count,revision=tonumber(f[4]),tonumber(f[8])
 if not count or count%1~=0 or count<=0 or count<=(session.voice_ack or 0)or session.preparing then return end
 session.voice_ack=count;session.voice_code='voice_invalid'
 if revision~=session.revision then session.voice_code='voice_stale';return end
 local data=Library.get()
 for _,person in ipairs(session.participants)do if person.id==f[5]and person.voice_loaded then
  local next_profile=V.copy(person.voice_profile);local id=Protocol.decode(f[7]);local action=f[6]
  if action=='archetype'then
   if id~=''then
    local a=data.archetypes[id];if not a or a.body~=person.voice_body then return end
    if id==next_profile.archetype then session.voice_code='ok';return end
    next_profile={schema_version=1,archetype=id,sets=M.defaults(data,person.voice_body,id)}
   else next_profile={schema_version=1,sets={}}end
  else
   local context=Keys.normalize(Protocol.decode(action));if not context or not data.contexts[context]then return end
   if id==''then next_profile.sets[context]=nil
   else
    local set=data.sets[id]
    if not set or set.body~=person.voice_body or set.archetype~=next_profile.archetype or set.context~=context then return end
    next_profile.sets[context]=id
   end
  end
  local ok=command('save',person.id,Protocol.pack('voice1',Protocol.encode(Json.encode(next_profile))))
  if ok then person.voice_profile=next_profile;person.voice_error=nil;session.voice_code='ok'
  else session.voice_code='voice_storage'end
  return
 end end
end
function M.publish(session)
 local data=Library.get();local payload={archetypes={},contexts={},sets={},participants={}}
 for id,a in pairs(data.archetypes)do payload.archetypes[id]={label=a.label,body=a.body}end
 for id,c in pairs(data.contexts)do payload.contexts[id]={label=c.label}end
 for id,s in pairs(data.sets)do payload.sets[id]={label=s.label,body=s.body,archetype=s.archetype,context=s.context}end
 for _,p in ipairs(session.participants)do if p.voice_loaded then payload.participants[p.id]={body=p.voice_body,archetype=p.voice_profile.archetype,sets=p.voice_profile.sets,error=p.voice_error}end end
 local packet=Protocol.pack(session.client,session.sequence,session.revision,session.voice_ack or 0,session.preparing and 'busy'or session.voice_code or 'ok',Protocol.encode(Json.encode(payload)))
 if packet==session.voice_state then return end
 local ok=inzoi.cli.execute('uimod.cfg_save mod_id='..Config.mod_id..' section='..Config.section..' key=voice_state value='..packet)
 if ok then session.voice_state=packet end
end
return M
