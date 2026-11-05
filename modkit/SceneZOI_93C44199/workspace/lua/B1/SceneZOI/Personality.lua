-- Preferences use canonical data IDs, independent of roles, body repetition and display labels.
local Config=require('SceneZOI.Config')
local Protocol=require('SceneZOI.Protocol')
local Keys=require('SceneZOI.ExpressionKeys')
local Library=require('SceneZOI.ExpressionLibrary')
local M={}
local function command(action,key,value)
 local line='uimod.cfg_'..action..' mod_id='..Config.mod_id..' section=scenezoi_personality key=zoi_'..key
 if value then line=line..' value='..value end
 return inzoi.cli.execute(line)
end
function M.resolve(id,body)
 local data=Library.get();id=Keys.normalize(id);id=id and(data.aliases[id]or id)
 return id and data.sets[id]and data.sets[id].body==body and id or nil
end
function M.valid(id,body)return M.resolve(id,body)~=nil end
function M.load(person,body)
 local ok,_,data=command('load',person.id);local f=ok and Protocol.unpack(data);local selected
 if f and f[1]=='1'then selected=f[2]elseif f and f[1]=='2'then selected=Protocol.decode(f[2])end
 person.expression_set=M.resolve(selected,body)or Library.get().defaults[body]
 person.expression_body=body;person.expression_profile_loaded=true
 person.expression_error=not person.expression_set and('No expression sets installed for the '..body..' body.')or nil
 return person.expression_set
end
function M.request(session,raw)
 if session.stopping or session.ended then return end
 local f=Protocol.unpack(raw)
 if not f or f[1]~=session.client or f[2]~=session.sequence or(f[3]~='personality'and f[3]~='personality2')then return end
 local count,revision=tonumber(f[4]),tonumber(f[7])
 if not count or count%1~=0 or count<=0 or count<=(session.personality_ack or 0)or session.preparing then return end
 session.personality_ack=count;session.personality_code='personality_invalid'
 if revision~=session.revision then session.personality_code='personality_stale';return end
 local requested=f[6];if f[3]=='personality2'then requested=Protocol.decode(f[6])end
 for _,person in ipairs(session.participants)do
  if person.id==f[5]then
   local id=M.resolve(requested,person.expression_body)
   if not id then return end
   local ok=command('save',person.id,Protocol.pack('2',Protocol.encode(id)))
   if ok then person.expression_set=id;person.expression_error=nil;session.personality_code='ok'
   else session.personality_code='personality_storage'end
   return
  end
 end
end
function M.publish(session)
 local rows={}
 for _,person in ipairs(session.participants)do
  if person.expression_body then rows[#rows+1]=table.concat({person.id,person.outfit_name or Protocol.encode(person.id),person.expression_body,Protocol.encode(person.expression_set or ''),Protocol.encode(person.expression_error or '')},':')end
 end
 local ids,available={},{}
 for id in pairs(Library.get().sets)do ids[#ids+1]=id end;table.sort(ids)
 for _,id in ipairs(ids)do local spec=Library.get().sets[id];available[#available+1]=table.concat({Protocol.encode(id),Protocol.encode(require('SceneZOI.Localization').label('expression_set',id,spec.label)),spec.body},':')end
 local packet=Protocol.pack(session.client,session.sequence,session.revision,session.personality_ack or 0,session.preparing and 'busy'or session.personality_code or 'ok',#rows>0 and table.concat(rows,'+')or 'none',#available>0 and table.concat(available,'+')or 'none')
 if packet==session.personality_state then return end
 local ok=inzoi.cli.execute('uimod.cfg_save mod_id='..Config.mod_id..' section='..Config.section..' key=personality_state value='..packet)
 if ok then session.personality_state=packet end
end
return M
