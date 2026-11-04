-- Copy this SDK folder into the add-on; it does not require framework internals.
local J=require('SceneZOIAddon.Json')
local M={API_VERSION=1}
local function owner_key(owner)
 local ok,id=pcall(function()
  local value=owner:GetEntityId()
  return tostring(type(value)=='number'and value or value.Value)
 end)
 return ok and id or nil
end
function M.new(addon_id,callbacks)
 assert(type(addon_id)=='string'and addon_id:match('^[a-z][a-z0-9_.%-]*$'),'Invalid add-on ID')
 local client={addon_id=addon_id,client_id='client.'..os.time()..'.'..math.random(1,1073741823),pending={},callbacks=callbacks or {},event_cursor=0,session_indices={},renew_serial=0}
 function client:request(owner,request_id,operation,arguments)
  assert(type(request_id)=='string'and request_id:match('^[a-z][a-z0-9_.%-]*$'),'Invalid request ID')
  assert(not self.pending[request_id],'Request is already pending')
  local raw=J.encode({api_version=1,addon_id=self.addon_id,client_id=self.client_id,request_id=request_id,expected_instance_id=self.instance_id,operation=operation,arguments=arguments or {}})
  assert(#raw<=65536,'Request is too large')
  self.pending[request_id]={owner=owner,owner_id=owner_key(owner),raw=raw,age=0,retry=0}
  pcall(function()inzoi.message.send_to_client(owner:GetEntityId(),'SceneZOI.API.Request',raw)end)
  return request_id
 end
 local function host(instance)
  if client.instance_id and client.instance_id~=instance then
   client.event_cursor=0;client.session_indices={};client.integration=nil
   -- Commit new transport state before callbacks can submit resynchronization requests.
   local previous=client.instance_id;local lost=client.pending
   client.pending={};client.instance_id=instance
   for id in pairs(lost)do if client.callbacks.response then client.callbacks.response({api_version=1,instance_id=instance,addon_id=client.addon_id,client_id=client.client_id,request_id=id,ok=false,code='host_changed'})end end
   if client.callbacks.instance_changed then client.callbacks.instance_changed(previous,instance)end
  end
  client.instance_id=instance
 end
 function client:on_message(kind,content)
  if kind~='SceneZOI.API.Response'and kind~='SceneZOI.API.Event'then return false end
  local ok,value=pcall(J.decode,content,262144)
  if not ok or value.api_version~=1 or value.addon_id~=self.addon_id or value.client_id~=self.client_id then return false end
  if kind=='SceneZOI.API.Response'then
   local request=self.pending[value.request_id];if not request then return true end
   self.pending[value.request_id]=nil;host(value.instance_id)
   if not value.ok and J.decode(request.raw).operation=='renew_integration'then self.integration=nil end
   if value.ok and value.result then
    local result=value.result;local sent=J.decode(request.raw)
    if sent.operation=='register_integration' then self.integration={owner=request.owner,owner_id=request.owner_id,age=0}
    elseif sent.operation=='release_integration'then self.integration=nil end
    if sent.operation=='subscribe'and result.event_cursor then self.event_cursor=math.max(self.event_cursor,result.event_cursor)end
    local snapshot=result.session
    if sent.operation=='subscribe'and snapshot and snapshot~=J.null and snapshot.id then self.session_indices[snapshot.id]=snapshot.event_index or 0 end
   end
   if self.callbacks.response then self.callbacks.response(value)end
  else
   host(value.instance_id);local event=value.event
   if event.event_cursor and event.event_cursor<=self.event_cursor then return true end
   if event.event_cursor then self.event_cursor=event.event_cursor end
   if event.session_id and event.event_index then
    if event.event_index<=(self.session_indices[event.session_id]or -1)then return true end
    self.session_indices[event.session_id]=event.event_index
   end
   if self.callbacks.event then self.callbacks.event(event,value.instance_id)end
  end
  return true
 end
 -- Refresh wrappers only for the same entity. Never move a caller to another Zoi.
 function client:refresh_owner(owner)
  local id=assert(owner_key(owner),'Expected a live native owner')
  if self.integration and self.integration.owner_id==id then self.integration.owner=owner end
  for _,row in pairs(self.pending)do if row.owner_id==id then row.owner=owner end end
 end
 function client:tick(dt,owner)
  if owner then self:refresh_owner(owner)end
  assert(type(dt)=='number'and dt==dt and dt>=0 and dt<math.huge,'Expected real elapsed seconds')
  if self.integration then
   self.integration.age=self.integration.age+dt
   if self.integration.age>=2 then
    self.integration.age=0;self.renew_serial=self.renew_serial+1
    self:request(self.integration.owner,'sdk.renew.'..self.renew_serial,'renew_integration',{})
   end
  end
  for id,row in pairs(self.pending)do
   row.age=row.age+dt;row.retry=row.retry+dt
   if row.age>=12 then
    self.pending[id]=nil
    if self.callbacks.response then self.callbacks.response({api_version=1,addon_id=self.addon_id,client_id=self.client_id,request_id=id,ok=false,code='transport_timeout'})end
   elseif row.retry>=1 then
    row.retry=0
    local ok=pcall(function()inzoi.message.send_to_client(row.owner:GetEntityId(),'SceneZOI.API.Request',row.raw)end)
    if not ok then row.age=12 end
   end
  end
 end
 return client
end
-- Helpers only consume public copied data; roles are not genders or control states.
function M.roles(snapshot)
 local roles={};for _,p in ipairs(snapshot.participants or {})do roles[p.role]=p.id end;return roles
end
function M.actions(snapshot,participant_id)
 local roles=M.roles(snapshot);local out=J.array({})
 for _,a in ipairs(snapshot.actions or {})do
  local row={type=a.type,actor=roles[a.actor],target=roles[a.target],performer=roles[a.performer],addon_data=a.addon_data}
  if not participant_id or row.actor==participant_id or row.target==participant_id or row.performer==participant_id then out[#out+1]=row end
 end;return out
end
function M.partners(snapshot,participant_id,action_type)
 local out,seen=J.array({}),{}
 for _,a in ipairs(M.actions(snapshot,participant_id))do if not action_type or a.type==action_type then
  for _,id in ipairs({a.actor,a.target,a.performer})do if id and id~=participant_id and not seen[id]then seen[id]=true;out[#out+1]=id end end
 end end;table.sort(out);return out
end
function M.task(snapshot,participant_id,task_id)
 for _,row in ipairs(snapshot.task_state or {})do if row.participant_id==participant_id and row.task_id==task_id then return row end end
end
function M.navigation(result)
 -- Consume get_navigation, which has already applied lifetime and technical checks.
 return result.locked and J.array({})or result.navigation
end
function M.data(record,namespace)return (record.addon_data or {})[namespace]end
return M
