-- SDK save data is the durable channel. Lua lifecycle save callbacks are not
-- dispatched by the tested retail build, so they are not used as a safety gate.
local C=require('SceneZOI.Config')
local P=require('SceneZOI.Protocol')
local J=require('SceneZOI.Json')
local M={}
local pending,seen
local function read(key)
 local ok,message,data=inzoi.cli.execute('uimod.cfg_load mod_id='..C.mod_id..' section='..C.section..' key='..key)
 return ok and (data or message)or nil
end
local function write(key,value)
 local ok,message=inzoi.cli.execute('uimod.cfg_save mod_id='..C.mod_id..' section='..C.section..' key='..key..' value='..value)
 assert(ok,message or 'Save bridge write failed')
end
local function decoded(value)
 local text=P.decode(value);if not text then return nil end
 local ok,result=pcall(J.decode,text);if ok then return result end
end
function M.boot()pending=nil;seen=read('save_restore')end
function M.busy()return pending~=nil end
function M.offer(current,actor,fields)
 if fields[2]=='snapshot'and current and fields[1]==current.token then
  local id=P.id(actor:GetEntityId());local owned=false
  for _,person in ipairs(current.participants)do if person.actor==actor then owned=true end end
  if not owned then return end
  local data=decoded(fields[3]);if not data or data.token~=current.token then return end
  current.save_records=current.save_records or {};current.save_records[id]=data
  for _,person in ipairs(current.participants)do if not current.save_records[person.id]then return end end
  local beds={}
  if current.furniture then beds[1]={id=current.furniture.id,owner=current.furniture_owner.id}end
  local packet=P.encode(J.encode({version=1,client=current.client,sequence=current.sequence,token=current.token,
   participants=current.save_records,furniture=J.array(beds)}))
  if current.save_packet~=packet then write('save_snapshot',packet);current.save_packet=packet end
 elseif pending and fields[1]==pending.token then
  local id=P.id(actor:GetEntityId())
  if fields[2]=='recovered'and pending.people[id]then pending.people[id].done=true
  elseif fields[2]=='furniture_recovered'and pending.beds[id]then pending.beds[id].done=true end
 end
end
function M.ready(current)
 if current.save_ready then return true end
 if not current.save_packet then return false end
 local f=P.unpack(read('save_ready'))
 if f and f[1]==current.client and f[2]==current.sequence and f[3]=='ready'and f[4]==current.token then
  current.save_ready=true;return true
 end
 return false
end
local function begin_restore(f)
 local journal=decoded(f[4]);assert(journal and journal.version==1,'Invalid saved SceneZOI journal')
 assert(type(journal.participants)=='table'and type(journal.furniture)=='table','Incomplete saved SceneZOI journal')
 local row={client=f[1],sequence=f[2],token=f[1]..'.'..f[2],people={},beds={}}
 local count=0
 for id,data in pairs(journal.participants)do
  assert(type(id)=='string'and id:match('^%d+$')and type(data)=='table','Invalid saved participant')
  count=count+1;assert(count<=32,'Too many saved participants');row.people[id]={data=data}
 end
 assert(#journal.furniture<=4,'Too much saved furniture')
 for _,bed in ipairs(journal.furniture)do
  assert(type(bed.id)=='string'and bed.id:match('^%d+$')and type(bed.owner)=='string'and bed.owner:match('^%d+$'),'Invalid saved furniture')
  local owner=row.beds[bed.owner]or {ids={}};row.beds[bed.owner]=owner;owner.ids[#owner.ids+1]=bed.id
 end
 return row
end
function M.tick(actors,active)
 local raw=read('save_restore')
 if raw and raw~=seen and not pending then
  local f=P.unpack(raw)
  if f and f[3]=='restore'then
   seen=raw
   local ok,row=pcall(begin_restore,f)
   if ok then pending=row
   else write('save_restore_state',P.pack(f[1],f[2],'error','invalid_recovery'))end
  end
 end
 if not pending or active then return end
 local row=pending
 for id,part in pairs(row.people)do if not part.done then
  local actor=actors[id]
  if actor then pcall(inzoi.message.send_to_sim,actor:GetEntityId(),'SceneZOI.Recover',P.pack(row.token,P.encode(J.encode(part.data))))end
 end end
 for id,bed in pairs(row.beds)do if not bed.done then
  local actor=actors[id]
  if actor then pcall(inzoi.message.send_to_sim,actor:GetEntityId(),'SceneZOI.FurnitureRecover',P.pack(row.token,P.encode(J.encode(bed.ids))))end
 end end
 -- Replies may be synchronous in tests; independently check the complete barrier.
 local complete=true
 for _,part in pairs(row.people)do if not part.done then complete=false end end
 for _,bed in pairs(row.beds)do if not bed.done then complete=false end end
 local status=P.pack(row.client,row.sequence,complete and 'ready'or 'pending','ok')
 if row.status~=status then write('save_restore_state',status);row.status=status end
 if complete then pending=nil end
end
return M
