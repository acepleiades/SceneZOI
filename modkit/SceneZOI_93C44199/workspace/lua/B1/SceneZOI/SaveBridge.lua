-- SDK save data is the durable channel. Lua lifecycle save callbacks are not
-- dispatched by the tested retail build, so they are not used as a safety gate.
-- One journal holds every session's original state plus anything still unrecovered.
local C=require('SceneZOI.Config')
local P=require('SceneZOI.Protocol')
local J=require('SceneZOI.Json')
local M={}
local RETRY_SECONDS=1
local records,revision,serial,host,seen={},0,0,nil,nil
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
local function ordered()
 local rows={}
 for _,record in pairs(records)do rows[#rows+1]=record end
 table.sort(rows,function(a,b)return a.serial<b.serial end)
 return rows
end
local function publish(check_readable)
 local next_revision=revision+1
 local rows=J.array({})
 for _,record in ipairs(ordered())do
  rows[#rows+1]={token=record.token,serial=record.serial,participants=record.people,furniture=J.array(record.beds)}
 end
 local text=J.encode({version=2,host=host,revision=next_revision,records=rows})
 if check_readable then J.decode(text)end
 write('save_snapshot',P.encode(text))
 revision=next_revision
 return revision
end
local function retire_if_empty(record)
 if next(record.people)==nil and #record.beds==0 then records[record.token]=nil end
end
function M.boot()
 records,revision,serial={},0,0
 host='host.'..os.time()..'.'..math.random(1,1073741823)
 seen=read('save_restore')
 pcall(publish)
end
function M.offer(current,actor,fields)
 local id=P.id(actor:GetEntityId())
 if fields[2]=='snapshot'then
  if not current or fields[1]~=current.token then return end
  local owned=false
  for _,person in ipairs(current.participants)do if person.actor==actor then owned=true end end
  if not owned then return end
  local data=decoded(fields[3]);if not data or data.token~=current.token then return end
  current.save_records=current.save_records or {};current.save_records[id]=data
  for _,person in ipairs(current.participants)do if not current.save_records[person.id]then return end end
  if current.journal_revision then return end
  local beds={}
  if current.furniture then beds[1]={id=current.furniture.id,owner=current.furniture_owner.id}end
  local people={};for key,value in pairs(current.save_records)do people[key]=value end
  serial=serial+1
  records[current.token]={token=current.token,serial=serial,people=people,beds=beds,sent={}}
  -- A new scene needs a journal that the save reader can load. Keep all older records if it cannot be written.
  local ok,result=pcall(publish,true)
  if not ok then
   records[current.token]=nil
   if not current.journal_write_failed then print('[SceneZOI] Save snapshot could not be written: '..tostring(result))end
   current.journal_write_failed=true
   return
  end
  current.journal_revision=result
 else
  local record=records[fields[1]];if not record then return end
  if fields[2]=='lent'and record.people[id]then record.people[id].lent_costume=fields[3]
  elseif fields[2]=='recovered'and record.people[id]then record.people[id]=nil
  elseif fields[2]=='furniture_recovered'then
   local beds={};for _,bed in ipairs(record.beds)do if bed.owner~=id then beds[#beds+1]=bed end end
   record.beds=beds
  else return end
  retire_if_empty(record);publish()
 end
end
function M.ready(current)
 if current.save_ready then return true end
 if not current.journal_revision then return false end
 local f=P.unpack(read('save_ready'))
 if f and f[1]==host and f[3]=='ready'and tonumber(f[2])and tonumber(f[2])>=current.journal_revision then
  current.save_ready=true;return true
 end
 return false
end
-- A session ended: keep only what its cleanup could not confirm, to recover later.
function M.finish(token,people,furniture)
 local record=records[token];if not record then return end
 local kept={};for _,id in ipairs(people or {})do kept[id]=record.people[id]end
 record.people=kept
 record.beds=furniture and record.beds or {}
 record.deferred=true
 retire_if_empty(record);publish()
end
-- The simulation side confirmed its release after the client actor was gone.
function M.resolve(token,id)
 local record=records[token];if not record or not record.people[id]then return false end
 record.people[id]=nil
 retire_if_empty(record);publish()
 return true
end
local function parse(row)
 assert(type(row)=='table'and type(row.token)=='string'and #row.token<=256,'Invalid saved record')
 assert(type(row.participants)=='table'and type(row.furniture)=='table','Incomplete saved record')
 local record={token=row.token,people={},beds={},sent={},deferred=true}
 local count=0
 for id,data in pairs(row.participants)do
  assert(type(id)=='string'and id:match('^%d+$')and type(data)=='table','Invalid saved participant')
  count=count+1;assert(count<=32,'Too many saved participants');record.people[id]=data
 end
 assert(#row.furniture<=4,'Too much saved furniture')
 for _,bed in ipairs(row.furniture)do
  assert(type(bed.id)=='string'and bed.id:match('^%d+$')and type(bed.owner)=='string'and bed.owner:match('^%d+$'),'Invalid saved furniture')
  record.beds[#record.beds+1]={id=bed.id,owner=bed.owner}
 end
 return record
end
-- Reads a whole journal. One unreadable record must not lose the others.
local function index_journal(raw)
 local journal=decoded(raw);assert(type(journal)=='table','Invalid saved SceneZOI journal')
 local rows
 if journal.version==1 then
  assert(type(journal.participants)=='table'and type(journal.furniture)=='table','Incomplete saved SceneZOI journal')
  rows={{token=journal.token,participants=journal.participants,furniture=journal.furniture}}
 else
  assert(journal.version==2 and type(journal.records)=='table','Invalid saved SceneZOI journal')
  rows=journal.records
 end
 local result={}
 for _,row in ipairs(rows)do
  local ok,record=pcall(parse,row)
  if ok then serial=serial+1;record.serial=serial;result[record.token]=record
  else print('[SceneZOI] Skipped an unreadable saved record: '..tostring(record))end
 end
 return result
end
local function send(actor,kind,record,value)
 pcall(function()require('SceneZOI.SimulationRoute').send(actor,kind,P.pack(record.token,P.encode(J.encode(value))))end)
end
function M.tick(actors)
 local raw=read('save_restore')
 if raw and raw~=seen then
  local f=P.unpack(raw)
  if f and f[3]=='restore'then
   seen=raw
   local ok,result=pcall(index_journal,f[4])
   if ok then
    records=result;publish()
    write('save_restore_state',P.pack(f[1],f[2],'ready','ok'))
   else write('save_restore_state',P.pack(f[1],f[2],'error','invalid_recovery'))end
  end
 end
 -- Each resource recovers when it is loaded, however long that takes.
 local now=os.time()
 for _,record in pairs(records)do if record.deferred then
  for id,data in pairs(record.people)do
   local actor=actors[id]
   if actor and now-(record.sent[id]or 0)>=RETRY_SECONDS then
    record.sent[id]=now;send(actor,'SceneZOI.Recover',record,data)
   end
  end
  local owners={}
  for _,bed in ipairs(record.beds)do owners[bed.owner]=owners[bed.owner]or {};table.insert(owners[bed.owner],bed.id)end
  for id,ids in pairs(owners)do
   local actor,key=actors[id],'bed'..id
   if actor and now-(record.sent[key]or 0)>=RETRY_SECONDS then
    record.sent[key]=now;send(actor,'SceneZOI.FurnitureRecover',record,ids)
   end
  end
 end end
end
-- A loaded journal that has not been read yet could name anyone.
function M.restore_waiting()
 local raw=read('save_restore')
 if not raw or raw==seen then return false end
 local f=P.unpack(raw)
 return f~=nil and f[3]=='restore'
end
-- A start is refused only when it overlaps something not yet recovered.
function M.overlaps(ids,furniture_id)
 for _,record in pairs(records)do if record.deferred then
  for _,id in ipairs(ids)do if record.people[id]then return true end end
  if furniture_id then for _,bed in ipairs(record.beds)do if bed.id==furniture_id then return true end end end
 end end
 return false
end
return M
