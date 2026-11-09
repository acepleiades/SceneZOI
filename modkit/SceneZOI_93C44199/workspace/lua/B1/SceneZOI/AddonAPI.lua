-- Versioned public B2 -> B1 native message API. This module owns no playback.
local V=require('SceneZOI.DataValidation')
local J=require('SceneZOI.Json')
local P=require('SceneZOI.Protocol')
local C=require('SceneZOI.Config')
local Catalog=require('SceneZOI.Catalog')
local Search=require('SceneZOI.SceneSearch')
local Events=require('SceneZOI.Events')
local Services=require('SceneZOI.AddonServices')
local Control=require('SceneZOI.AddonControl')
local M={version=1}
local cursor=0
local cache,order,subscribers,pending,serial,handle,instance={},{},{},nil,0,nil,nil
local function runtime()return require('SceneZOI.Runtime')end
local function cfg(key,value)
 local ok,message,data=inzoi.cli.execute('uimod.cfg_'..(value and 'save'or 'load')..' mod_id='..C.mod_id..' section='..C.section..' key='..key..(value and ' value='..value or ''))
 if value then assert(ok,message or 'API UI bridge failed')end
 return ok and(data or message)or nil
end
local function deliver(actor,kind,data)
 -- The actor can be released between events; one dead endpoint must not stop the others.
 local ok,err=pcall(function()inzoi.message.send_to_sim(actor:GetEntityId(),kind,J.encode(data))end)
 if not ok then print('[SceneZOI] Add-on delivery failed: '..tostring(err))end
 return ok
end
local function event_to(sub,event)
 if not M.in_scope(sub,event)then return end
 if sub.names['*']or sub.names[event.name]then
  deliver(sub.actor,'SceneZOI.API.Event',{api_version=1,instance_id=instance,addon_id=sub.addon_id,client_id=sub.client_id,event=V.copy(event)})
 end
end
-- An add-on always hears its own sessions. Others see the focused scene unless they opted in.
function M.in_scope(sub,event)
 if event.addon_id==sub.addon_id and event.addon_client_id==sub.client_id then return true end
 if sub.scope=='all'then return true end
 if sub.scope=='owned'then return false end
 return event.focused~=false
end
local function key(req,actor)return req.addon_id..'|'..req.client_id..'|'..P.id(actor:GetEntityId())..'|'..req.request_id end
local function emit_failure(row,code,message)
 row.status={phase='failed',code=code,message=message}
 local event={name='session_start_failed',request_id=row.req.request_id,addon_id=row.req.addon_id,code=code,message=message}
 deliver(row.actor,'SceneZOI.API.Event',{api_version=1,instance_id=instance,addon_id=row.req.addon_id,client_id=row.req.client_id,event=event})
end
function M.fail_start(token,reason)
 if pending and pending.token==token then
  local row=pending;pending=nil;pcall(cfg,'api_start','none');emit_failure(row,'start_failed',tostring(reason))
 end
end
function M.context(token,fields)
 if not token then return nil end
 local row=assert(pending and pending.token==token and pending.stage=='ui'and pending,'Unknown/expired add-on start')
 assert(fields[4]==row.entry.initiator and fields[5]==row.entry.node,'Add-on start identity changed')
 local assignments={};for role,id in pairs(row.entry.bindings)do assignments[#assignments+1]=role..':'..id end;table.sort(assignments)
 assert(fields[6]==table.concat(assignments,'+')and (fields[7]or 'none')==(row.entry.furniture or 'none'),'Add-on start roster/context changed')
 return row
end
function M.created(row,current)
 if not row then return end
 row.status={phase='preparing',session_id=current.token};pending=nil;pcall(cfg,'api_start','none')
end
function M.has_pending()return pending~=nil end
function M.departure_reply(actor,content)
 local f=P.unpack(content);if not pending or not f or f[1]~=pending.token then return end
 local id=P.id(actor:GetEntityId());if pending.departures[id]==nil then return end
 if f[2]=='ok'then pending.departures[id]=true else M.fail_start(pending.token,'Could not leave a gameplay group')end
end
local function owned(req)
 local r=runtime();local s=r.snapshot(req.arguments.session_id)
 assert(s and s.id==req.arguments.session_id,'session_not_found')
 assert(r.is_addon_owner(req.addon_id,req.client_id,s.id),'session_not_owned')
 return s
end
local function roster(args)
 if args.participants==nil then return nil end
 V.array(args.participants,32);assert(#args.participants>=2,'At least two participants are required')
 local rows,seen={},{}
 for _,id in ipairs(args.participants)do
  assert(type(id)=='string'and id:match('^%d+$')and not seen[id],'Invalid/duplicate participant ID');seen[id]=true
  rows[#rows+1]=require('SceneZOI.Traits').capture(assert(runtime().actors[id],'Participant is not loaded'))
 end
 return rows
end
local function refresh()
 if not runtime().snapshot()and not pending then
  require('SceneZOI.DataFiles').refresh();Catalog.refresh()
 end
 return Catalog.get_snapshot()
end
local function profile(args)
 if args.furniture_id then
  assert(type(args.furniture_id)=='string'and args.furniture_id:match('^%d+$'),'Invalid furniture ID')
  return assert(require('SceneZOI.Furniture').available(args.furniture_id),'furniture_unavailable')
 end
end
local function find(args,data)
 local q=Search.criteria(data.metadata,args.search);local people=roster(args);local furniture=profile(args)
 assert(not furniture or people,'Furniture queries require participants')
 return Search.find(data,q,people,furniture,args.bindings),q
end
local function start(actor,req,row,data,preflight)
 local args=req.arguments
 V.fields(args,{'participants','initiator','furniture_id','scene_id','search','session_restrictions','context','bindings','start_mode'},{'participants','initiator'})
 assert(not runtime().snapshot()and not pending,'session_already_running')
 assert(not require('SceneZOI.SaveBridge').busy()and not require('SceneZOI.Autosave').busy(),'restore_pending')
 local controller=UE.UGameplayStatics.GetPlayerController(actor,0)
 assert(controller and P.id(controller:GetCharacterEntityId())==args.initiator,'initiator_not_controlled')
 local people=assert(roster(args));local member=false;for _,person in ipairs(people)do if person.id==args.initiator then member=true end end;assert(member,'Initiator must participate')
 local restrictions=Search.criteria(data.metadata,args.session_restrictions)
 local search=Search.criteria(data.metadata,args.search)
 local mode=preflight and(args.start_mode or(args.scene_id and 'start_scene'or 'start_at_hub'))or req.operation
 assert(mode=='start_at_hub'or mode=='start_scene'or mode=='start_random_scene','Invalid start mode')
 if mode=='start_at_hub'then search.starting_hub_only=true end
 local rows=Search.find(data,search,people,profile(args),args.bindings);local allowed={}
 for _,candidate in ipairs(rows)do
  if Search.allowed(data.nodes,data.nodes[candidate.scene_id],restrictions)and(mode~='start_scene'or candidate.scene_id==args.scene_id)then allowed[#allowed+1]=candidate end
 end
 if mode=='start_scene'then V.id(args.scene_id)end
 local chosen=assert(Search.random(allowed),'no_matching_scenes')
 if args.context then assert(V.object(args.context)and #J.encode(args.context)<=4096,'Invalid/oversized add-on context')end
 if preflight and args.furniture_id then require('SceneZOI.Furniture').prepare(args.furniture_id,data.nodes[chosen.scene_id])end
 if preflight then return {valid=true,scene_id=chosen.scene_id,bindings=V.copy(chosen.bindings),reservation=false,assets_checked=false,startup_rechecks=true}end
 serial=serial+1;row.token='api.'..os.time()..'.'..serial;row.age=0;row.retry=1;row.stage='depart';row.departures={}
 for _,p in ipairs(people)do row.departures[p.id]=false end
 row.entry={initiator=args.initiator,node=chosen.scene_id,bindings=chosen.bindings,furniture=args.furniture_id,api_token=row.token}
 row.restrictions=restrictions;row.context=V.copy(args.context);row.status={phase='accepted',scene_id=chosen.scene_id};pending=row
 -- Ensure the caller receives start failures/end events even without a subscription.
 local sk=req.addon_id..'|'..req.client_id..'|'..P.id(actor:GetEntityId())
 if not subscribers[sk]then subscribers[sk]={addon_id=req.addon_id,client_id=req.client_id,actor=actor,names={['*']=true}}end
 return {accepted=true,scene_id=chosen.scene_id,start_request_id=req.request_id}
end
local function execute(actor,req,row)
 local args=req.arguments;local op=req.operation
 local handled,result=Services.execute(actor,req)
 if handled then
  if runtime().api_control_event and not op:match('^get_')and op~='renew_integration'and op~='register_integration'then runtime().api_control_event(req)end
  return result
 end
 if op=='get_version'then return {api_version=1,runtime_build=C.build,instance_id=instance,maximum_sessions=1,features={session_registry=1,event_scopes=1,scene_metadata=1,scene_search=1,session_restrictions=1,events=2,explicit_bindings=1,preflight=1,furniture_discovery=1,session_results=1,integration_leases=1,live_controls=1,presentation_overrides=1,facial_poses=1,head_attachments=1,addon_data=1}}end
 if op=='subscribe'or op=='unsubscribe'then
  V.fields(args,{'events','scope'});local sk=req.addon_id..'|'..req.client_id..'|'..P.id(actor:GetEntityId())
  if op=='unsubscribe'then subscribers[sk]=nil;return {subscribed=false}end
  V.array(args.events or {'*'},32);local names={};for _,n in ipairs(args.events or {'*'})do if n~='*'then V.id(n)end;names[n]=true end
  local scope=args.scope or 'focused';assert(scope=='focused'or scope=='owned'or scope=='all','Invalid subscription scope')
  subscribers[sk]={addon_id=req.addon_id,client_id=req.client_id,actor=actor,names=names,scope=scope};return {subscribed=true,scope=scope,event_cursor=cursor,session=runtime().snapshot()or J.null}
 end
 if op=='get_session'then
  V.fields(args,{'session_id'});local s=runtime().snapshot(args.session_id);if args.session_id then assert(s and s.id==args.session_id,'session_not_found')end;return {session=s or J.null,event_cursor=cursor}
 end
 if op=='list_sessions'then V.fields(args,{});return {sessions=runtime().snapshots(),event_cursor=cursor}end
 if op=='get_request_status'then
  V.fields(args,{'request_id'},{'request_id'});local k=V.copy(req);k.request_id=args.request_id;local r=assert(cache[key(k,actor)],'request_not_found');return V.copy(r.status or {phase='completed',response=r.response})
 end
 if op=='stop_session'then V.fields(args,{'session_id'},{'session_id'});owned(req);runtime().api_session(args.session_id).stop_origin={addon_id=req.addon_id,client_id=req.client_id,reason='creator_stop'};runtime().stop('ok',args.session_id);return {accepted=true}end
 if op=='navigate_to_scene'then
  V.fields(args,{'session_id','scene_id'},{'session_id','scene_id'});owned(req);V.id(args.scene_id)
  return runtime().navigate_to(args.session_id,args.scene_id)
 end
 if op=='cancel_start'then
  V.fields(args,{'start_request_id'},{'start_request_id'});assert(pending and pending.req.addon_id==req.addon_id and pending.req.client_id==req.client_id and pending.req.request_id==args.start_request_id,'request_not_found')
  M.fail_start(pending.token,'Cancelled by its add-on');return {accepted=true}
 end
 local data=refresh()
 if op=='find_furniture'then
  V.fields(args,{'origin_id','radius_m','scene_id','include_unavailable'},{'origin_id'})
  return require('SceneZOI.Furniture').find(args,runtime().actors,data)
 end
 if op=='validate_start'then
  local ok,value=pcall(start,actor,req,row,data,true)
  if ok then return value end
  local message=tostring(value);local code=message:match('([a-z_]+)$')or 'invalid_request'
  local known={session_already_running=true,restore_pending=true,initiator_not_controlled=true,no_matching_scenes=true,furniture_unavailable=true}
  return {valid=false,code=known[code]and code or 'invalid_request',message=message,reservation=false}
 end
 if op=='get_definitions'then V.fields(args,{});return {tags=V.copy(data.metadata.tags),actions=V.copy(data.metadata.actions),tasks=V.copy((data.tasks or {}).definitions or {}),content_ratings={'GENERAL','SUGGESTIVE','EXPLICIT'}}end
 if op=='get_scene'then V.fields(args,{'scene_id'},{'scene_id'});return Catalog.public_node(Catalog.get(args.scene_id))end
 if op=='find_scenes'or op=='choose_random_scene'then
  V.fields(args,{'participants','furniture_id','search','bindings'});local rows=find(args,data)
  if op=='find_scenes'then return {scenes=rows,count=#rows}end
  return {scene=Search.random(rows)or J.null,count=#rows}
 end
 if op=='start_scene'or op=='start_random_scene'or op=='start_at_hub'then return start(actor,req,row,data)end
 error('unknown_operation')
end
function M.receive(actor,content)
 local ok,req=pcall(J.decode,content,65536);if not ok or type(req)~='table'then return end
 local valid=pcall(function()
  V.fields(req,{'api_version','addon_id','client_id','request_id','operation','arguments','expected_instance_id'},{'api_version','addon_id','client_id','request_id','operation'})
  for _,k in ipairs({'addon_id','client_id','request_id','operation'})do V.id(req[k])end
  assert(V.object(req.arguments or {}),'Invalid arguments')
 end)
 if not valid then return end
 local k=key(req,actor);local old=cache[k]
 if old and old.raw==content then deliver(actor,'SceneZOI.API.Response',old.response);return end
 local response={api_version=1,instance_id=instance,addon_id=req.addon_id,client_id=req.client_id,request_id=req.request_id}
 if old then response.ok=false;response.code='request_id_reused';deliver(actor,'SceneZOI.API.Response',response);return end
 local row={req=req,actor=actor,raw=content};req.arguments=req.arguments or {}
 local success,value=pcall(function()assert(req.api_version==1,'unsupported_api_version');assert(not req.expected_instance_id or req.expected_instance_id==instance,'host_changed');return execute(actor,req,row)end)
 response.ok=success
 if success then response.result=value;response.code='ok'
 else
  local message=tostring(value);response.message=message
  local known={session_not_found=true,session_not_owned=true,session_not_ready=true,session_already_running=true,navigation_locked=true,
   no_matching_scenes=true,initiator_not_controlled=true,furniture_unavailable=true,incompatible_furniture=true,unsupported_api_version=true,
   unknown_operation=true,request_not_found=true,restore_pending=true,capability_not_granted=true,integration_not_registered=true,invalid_capability=true,participant_not_found=true,task_not_found=true,outfit_item_not_found=true,effect_already_exists=true,host_changed=true,integration_limit=true,attachment_limit=true,expression_set_not_found=true,expression_context_not_found=true,incompatible_expression_set=true,facial_pose_not_found=true,incompatible_facial_pose=true}
  local candidate=message:match('([a-z_]+)$')
  response.code=known[candidate]and candidate or 'invalid_request'
  if message:find('Scene is restricted for this session',1,true)then response.code='scene_restricted'end
 end
 row.response=response;cache[k]=row;order[#order+1]=k
 while #order>256 do local oldest=table.remove(order,1);if not pending or pending~=cache[oldest]then cache[oldest]=nil end end
 deliver(actor,'SceneZOI.API.Response',response)
end
function M.boot()
 cache,order,subscribers,pending,serial={},{},{},nil,0;cursor=0
 Control.reset()
 instance='host.'..os.time()..'.'..math.random(1,1073741823)
 cfg('api_start','none');cfg('api_start_result','none')
 if handle then Events.unsubscribe(handle)end
 handle=Events.subscribe('*',function(event)
  cursor=cursor+1;event.event_cursor=cursor
  event.api_version=1;event.instance_id=instance;event.session_id=event.id
  for k,sub in pairs(subscribers)do
   if not pcall(function()return sub.actor:GetEntityId()end)then subscribers[k]=nil else event_to(sub,event)end
  end
  if event.request_id then
   for _,row in pairs(cache)do if row.status and row.status.session_id==event.id then row.status={phase=event.phase,session_id=event.id,event=event.name,code=event.code}end end
  end
 end)
end
local function update(dt)
 if not pending then return end
 local row=pending;row.age=row.age+math.max(tonumber(dt)or 0,0);row.retry=row.retry+math.max(tonumber(dt)or 0,0)
 if row.age>15 then M.fail_start(row.token,'Start bridge timed out');return end
 if runtime().snapshot()then M.fail_start(row.token,'Another session started');return end
 if row.stage=='depart'then
  local all=true;for _,done in pairs(row.departures)do if not done then all=false end end
  if all then row.stage='ui';cfg('api_start',P.encode(J.encode({token=row.token,entry=row.entry})))
  elseif row.retry>=.5 then
   row.retry=0
   for id,done in pairs(row.departures)do if not done then
    local actor=runtime().actors[id];if not actor then M.fail_start(row.token,'Participant unloaded');return end
    inzoi.message.send_to_sim(actor:GetEntityId(),'SceneZOI.API.Depart',P.pack(row.token))
   end end
  end
 elseif row.stage=='ui'then
  local raw=cfg('api_start_result');local encoded=raw and raw:match('([0-9a-f]+)')
  -- cfg_load may return a JSON wrapper; extract only its value.
  if raw and raw:sub(1,1)=='{'then local ok,v=pcall(J.decode,raw);encoded=ok and v.value or nil end
  local text=encoded and P.decode(encoded);local ok,v=pcall(J.decode,text or '')
  if ok and v.token==row.token and v.started==false then M.fail_start(row.token,v.message or 'Controls declined the start')end
 end
end
function M.tick(dt)
 local ok,err=pcall(update,dt)
 if not ok and pending then M.fail_start(pending.token,tostring(err))end
end
return M
