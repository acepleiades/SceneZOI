-- SDK save data is the durable channel. Lua lifecycle save callbacks are not
-- dispatched by the tested retail build, so they are not used as a safety gate.
-- One journal holds every session's original state plus anything still unrecovered.
local C=require('SceneZOI.Config')
local P=require('SceneZOI.Protocol')
local J=require('SceneZOI.Json')
local Diagnostics=require('SceneZOI.Diagnostics')
local V=require('SceneZOI.DataValidation')
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
local function resources(record)
 local people,beds=J.array({}),J.array({})
 for id in pairs(record.people)do people[#people+1]=id end;table.sort(people)
 for _,bed in ipairs(record.beds)do beds[#beds+1]=V.copy(bed)end
 return {session_id=record.token,participants=people,furniture=beds}
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
local function confirm_participant(record,id,source)
 local position=record.positions and record.positions[id]
 if position then
  position.simulation_restored=true
  return false
 end
 record.people[id]=nil
 Diagnostics.record('participant_recovered',{session_id=record.token,participant_id=id,source=source})
 return true
end
local function owns(current,actor,id)
 if not current then return false end
 for _,person in ipairs(current.participants)do
  if person.actor==actor and person.id==id then return true end
 end
 return false
end
local function settled_coordinates(data,token)
 V.fields(data,{'token','checkpoint','location','rotation'},{'token','checkpoint','location','rotation'})
 assert(data.token==token,'Wrong settled snapshot token')
 V.number(data.checkpoint,1,1e9,true)
 for _,key in ipairs({'location','rotation'})do
  V.array(data[key],3);assert(#data[key]==3,'Incomplete settled coordinates')
  for _,value in ipairs(data[key])do V.number(value,-1e12,1e12);assert(math.abs(value)<1e12,'Invalid settled coordinate')end
 end
 return data
end
local function settle(current,actor,id,fields)
 if not current or fields[1]~=current.token or not current.preparing or current.stopping or
  not owns(current,actor,id)or not current.journal_revision then return end
 local record=records[current.token]
 local original=record and not record.deferred and record.people[id]
 if not original or not current.save_records or not current.save_records[id]then return end
 local ok,data=pcall(settled_coordinates,decoded(fields[3]),current.token)
 if not ok then return end
 local changed=not V.equal(original.location,data.location)or not V.equal(original.rotation,data.rotation)
 local published=current.entry_checkpoints and current.entry_checkpoints[id]or 0
 local pending=current.entry_checkpoint_pending and current.entry_checkpoint_pending[id]or 0
 local latest=math.max(published,pending)
 if data.checkpoint<latest or(data.checkpoint==latest and changed)then return end
 if data.checkpoint==latest and not current.journal_update_pending then return end
 if changed then
  -- The private message can update only entry coordinates. Never replace the
  -- original body/clothing/policy/held-object state with post-prepare values.
  local updated=V.copy(original)
  updated.location,updated.rotation=V.copy(data.location),V.copy(data.rotation)
  record.people[id],current.save_records[id]=updated,updated
 end
 -- Clear the old acknowledgement before publishing. Independent participants
 -- may settle in different ticks; the latest combined journal must be cached
 -- by the UI before any anchor or playback can use those entry coordinates.
 current.entry_checkpoint_pending=current.entry_checkpoint_pending or {}
 current.entry_checkpoint_pending[id]=data.checkpoint
 current.save_ready=false;current.journal_update_pending=true
 local written,result=pcall(publish,true)
 if not written then
  if not current.journal_write_failed then print('[SceneZOI] Settled save snapshot could not be written: '..tostring(result))end
  current.journal_write_failed=true
  return
 end
 current.journal_revision=result;current.journal_update_pending=nil
 current.entry_checkpoints=current.entry_checkpoints or {}
 for who,checkpoint in pairs(current.entry_checkpoint_pending)do current.entry_checkpoints[who]=checkpoint end
 current.entry_checkpoint_pending=nil;current.journal_write_failed=nil
end
function M.offer(current,actor,fields)
 local id=P.id(actor:GetEntityId())
 if fields[2]=='settled_snapshot'then settle(current,actor,id,fields);return end
 if fields[2]=='snapshot'then
  if not current or fields[1]~=current.token or not owns(current,actor,id)then return end
  -- Once published, only the explicit settled update can change the journal.
  -- A delayed original offer must not overwrite the newer return coordinates.
  if current.journal_revision then return end
  local data=decoded(fields[3]);if not data or data.token~=current.token then return end
  current.save_records=current.save_records or {};current.save_records[id]=data
  for _,person in ipairs(current.participants)do if not current.save_records[person.id]then return end end
  if current.journal_revision then return end
  local beds={}
  if current.furniture then beds[1]={id=current.furniture.id,owner=current.furniture_owner.id,
   pair_id=current.furniture.selected_pair_id,spots=V.copy(current.furniture.spot_ids),slots=V.copy(current.furniture.slots)}end
  local people={};for key,value in pairs(current.save_records)do people[key]=value end
  serial=serial+1
  records[current.token]={token=current.token,serial=serial,people=people,beds=beds,sent={}}
  -- The save callback can run after the game has serialized some participant
  -- changes. Publish the originals before commit and carry old recovery records
  -- forward when another scene starts.
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
  if fields[2]=='recovered'and record.people[id]then
   if not confirm_participant(record,id)then return end
  elseif fields[2]=='furniture_recovered'then
   local beds={}
   for _,bed in ipairs(record.beds)do
    if bed.owner~=id then beds[#beds+1]=bed
    else Diagnostics.record('furniture_recovered',{session_id=record.token,furniture_id=bed.id,owner_id=id})end
   end
   record.beds=beds
  else return end
  retire_if_empty(record);publish()
 end
end
function M.checkpoint(current,id)return current.entry_checkpoints and current.entry_checkpoints[id]end
function M.ready(current)
 if current.journal_update_pending then return false end
 if current.save_ready then return true end
 if not current.journal_revision then return false end
 local f=P.unpack(read('save_ready'))
 if f and f[1]==host and f[3]=='ready'and tonumber(f[2])and tonumber(f[2])>=current.journal_revision then
  current.save_ready=true;return true
 end
 return false
end
-- Same-world stream-out can leave the replacement client actor at the old animation anchor.
-- These transforms are for the current world only and are never serialized into saves.
function M.defer_position(token,id,anchor,original)
 local record=records[token]
 if not record or not record.people[id]then return end
 record.positions=record.positions or {}
 record.positions[id]={anchor=anchor,original=original}
 return true
end
-- A session ended: keep only what its cleanup could not confirm, to recover later.
function M.finish(token,people,furniture)
 local record=records[token];if not record then return end
 local kept={};for _,id in ipairs(people or {})do kept[id]=record.people[id]end
 for id in pairs(record.positions or {})do kept[id]=record.people[id]end
 record.people=kept
 record.beds=furniture and record.beds or {}
 record.deferred=true
 if next(record.people) or #record.beds>0 then Diagnostics.record('recovery_deferred',resources(record))end
 retire_if_empty(record);publish()
end
-- The simulation side confirmed its release after the client actor was gone.
function M.resolve(token,id)
 local record=records[token];if not record or not record.people[id]then return false end
 if confirm_participant(record,id,'late_release')then retire_if_empty(record);publish()end
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
  if bed.pair_id then
   V.id(bed.pair_id);V.array(bed.spots,2);assert(#bed.spots==2 and bed.spots[1]~=bed.spots[2],'Invalid saved sitting spots')
   for _,spot in ipairs(bed.spots)do V.id(spot)end
   V.array(bed.slots,64);assert(#bed.slots>0,'Missing saved sofa slots')
   for _,slot in ipairs(bed.slots)do V.fields(slot,{'component_name','slot_name'},{'component_name','slot_name'});V.name(slot.component_name);V.name(slot.slot_name)end
  else assert(bed.spots==nil and bed.slots==nil,'Saved sofa slots need a pair ID')end
  record.beds[#record.beds+1]=V.copy(bed)
 end
 return record
end
-- Reads a whole journal. One unreadable record must not lose the others.
local function index_journal(raw)
 local journal=decoded(raw);assert(type(journal)=='table','Invalid saved SceneZOI journal')
 local rows
 -- Backward compatibility with version 1 single-session save journals.
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
function M.boot()
 records,revision,serial={},0,0
 host='host.'..os.time()..'.'..math.random(1,1073741823)
 -- Diagnostics only. The actual recovery source remains the loaded game's save journal.
 pcall(function()
  local previous=read('save_snapshot')
  if not previous then return end
  if previous:sub(1,1)=='{'then previous=J.decode(previous).value end
  local journal=decoded(previous)
  if not journal or type(journal.records)~='table'or #journal.records==0 then return end
  local sessions=J.array({})
  for _,row in ipairs(journal.records)do
   if type(row)=='table'and type(row.token)=='string'then sessions[#sessions+1]=row.token end
  end
  Diagnostics.record('previous_journal_found',{previous_journal=journal.host,sessions=sessions,count=#journal.records})
 end)
 seen=read('save_restore')
 local request,response=P.unpack(seen),P.unpack(read('save_restore_state'))
 if request and request[3]=='restore'and request[1]==read('ui_boot')and
    (not response or response[1]~=request[1]or response[2]~=request[2])then
  seen=nil
 end
 pcall(publish)
end
local function send(actor,kind,record,value)
 pcall(function()require('SceneZOI.SimulationRoute').send(actor,kind,P.pack(record.token,P.encode(J.encode(value))))end)
end
local function restore_position(actor,position)
 local current,anchor,original=actor:K2_GetActorLocation(),position.anchor.Translation,position.original.Translation
 local dx,dy=current.X-anchor.X,current.Y-anchor.Y
 -- A streamed-in Zoi can settle to floor height at the old scene's XY.
 -- Leave horizontal movement and moves to another floor alone.
 if dx*dx+dy*dy>9 or current.Z<math.min(anchor.Z,original.Z)-3 or
     current.Z>math.max(anchor.Z,original.Z)+3 then return 'position_changed' end
 local moved=actor:K2_SetActorTransform(position.original,false,nil,true)
 assert(moved~=false,'Native position update failed')
 return 'restored'
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
    for _,record in ipairs(ordered())do Diagnostics.record('recovery_loaded',resources(record))end
   else
    Diagnostics.record('recovery_rejected',{code='invalid_recovery'})
    write('save_restore_state',P.pack(f[1],f[2],'error','invalid_recovery'))
   end
  end
 end
 -- Each resource recovers when it is loaded, however long that takes.
 local now=os.time()
 local recovered=false
 for _,record in pairs(records)do if record.deferred then
  for id,data in pairs(record.people)do
   local actor=actors[id]
   if actor and now-(record.sent[id]or 0)>=RETRY_SECONDS then
    record.sent[id]=now
    local position=record.positions and record.positions[id]
    if position and position.simulation_restored then
     local ok,result=pcall(restore_position,actor,position)
     if ok then
      record.positions[id],record.people[id]=nil,nil
      recovered=true
      Diagnostics.record('participant_recovered',{session_id=record.token,participant_id=id,presentation_position=result})
     elseif position.last_error~=tostring(result) then
      position.last_error=tostring(result)
      Diagnostics.record('presentation_recovery_wait',{session_id=record.token,participant_id=id,code=position.last_error})
     end
    else send(actor,'SceneZOI.Recover',record,data)end
   end
  end
  local owners={}
   for _,bed in ipairs(record.beds)do owners[bed.owner]=owners[bed.owner]or {};table.insert(owners[bed.owner],bed.pair_id and V.copy(bed)or bed.id)end
  for id,ids in pairs(owners)do
   local actor,key=actors[id],'bed'..id
   if actor and now-(record.sent[key]or 0)>=RETRY_SECONDS then
    record.sent[key]=now;send(actor,'SceneZOI.FurnitureRecover',record,ids)
   end
  end
  retire_if_empty(record)
 end end
 if recovered then publish()end
end
-- A loaded journal that has not been read yet could name anyone.
function M.restore_waiting()
 local raw=read('save_restore')
 if not raw or raw==seen then return false end
 local f=P.unpack(raw)
 return f~=nil and f[3]=='restore'
end
-- A start is refused only when it overlaps something not yet recovered.
function M.overlaps(ids,furniture_id,spot_ids)
 for _,record in pairs(records)do if record.deferred then
  for _,id in ipairs(ids)do if record.people[id]then return true end end
  if furniture_id then for _,bed in ipairs(record.beds)do if bed.id==furniture_id and require('SceneZOI.FurniturePairs').overlap(spot_ids,bed.spots)then return true end end end
 end end
 return false
end
return M
