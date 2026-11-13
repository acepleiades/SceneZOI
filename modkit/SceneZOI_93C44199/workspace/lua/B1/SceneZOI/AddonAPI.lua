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
local Plan=require('SceneZOI.Plan')
local M={version=1}
local cursor=0
local cache,order,subscribers,pending,serial,handle,instance={},{},{},nil,0,nil,nil
local background_starts={}
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
local function alive(actor)return actor~=nil and pcall(function()return actor:GetEntityId()end)end
-- The Zoi an add-on asked through can stream out mid-scene; the controlled Zoi is always loaded.
local function stable_endpoint()
 local actors=runtime().actors
 local ok,id=pcall(require('SceneZOI.Controller').controlled_id,actors)
 return ok and id and actors[id]or nil
end
local function subscriber_key(sub,actor)return sub.addon_id..'|'..sub.client_id..'|'..P.id(actor:GetEntityId())end
-- One subscription per add-on client survives; the rest of a dead endpoint's duplicates are retired.
local function revive_subscribers()
 local dead={}
 for k,sub in pairs(subscribers)do if not alive(sub.actor)then dead[#dead+1]={key=k,sub=sub}end end
 for _,row in ipairs(dead)do
  subscribers[row.key]=nil
  local covered=false
  for _,other in pairs(subscribers)do if other.addon_id==row.sub.addon_id and other.client_id==row.sub.client_id then covered=true end end
  local actor=not covered and stable_endpoint()
  if actor then row.sub.actor=actor;subscribers[subscriber_key(row.sub,actor)]=row.sub end
 end
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
-- An add-on that reconnects through another Zoi can still ask about its own request.
local latest={}
local function request_key(req)return req.addon_id..'|'..req.client_id..'|'..req.request_id end
local function emit_failure(row,code,message)
 row.status={phase='failed',code=code,message=message}
 local event={name='session_start_failed',request_id=row.req.request_id,addon_id=row.req.addon_id,code=code,message=message}
 local endpoint=alive(row.actor)and row.actor or stable_endpoint()or row.actor
 deliver(endpoint,'SceneZOI.API.Event',{api_version=1,instance_id=instance,addon_id=row.req.addon_id,client_id=row.req.client_id,event=event})
end
function M.fail_start(token,reason)
 require('SceneZOI.SimulationRoute').discard('SceneZOI.API.Depart',P.pack(token))
 local Sessions=require('SceneZOI.Sessions')
 if pending and pending.token==token then
  local row=pending;pending=nil;Sessions.release(token);pcall(cfg,'api_start','none');emit_failure(row,'start_failed',tostring(reason))
 elseif background_starts[token] then
  local row=background_starts[token];background_starts[token]=nil;Sessions.release(token)
  local code=tostring(reason):match('([a-z_]+)$')
  local known={session_limit=true,participant_too_far=true}
  emit_failure(row,known[code]and code or 'start_failed',tostring(reason))
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
 require('SceneZOI.Sessions').transfer(row.token,current.token)
 row.status={phase='preparing',session_id=current.token}
 background_starts[row.token]=nil
 if pending==row then pending=nil;pcall(cfg,'api_start','none')end
end
function M.has_pending()return pending~=nil end
function M.departure_reply(actor,content)
 local f=P.unpack(content);if not f then return end
 local row=pending and pending.token==f[1]and pending or background_starts[f[1]];if not row then return end
 local id=P.id(actor:GetEntityId());if row.departures[id]==nil then return end
 if f[2]~='ok'then M.fail_start(row.token,'Could not leave a gameplay group');return end
 row.departures[id]=true
 if f[3]=='household'then row.has_household=true end
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
local refreshed_at=nil
local function refresh()
 -- Every running scene keeps the catalog it started with. Main rescans the packs every 2 s while nothing runs, so a
 -- request re-reads the whole declaration table (about 45 ms) at most once per REFRESH_SEC, not once per request.
 local now=os.time()
 if require('SceneZOI.Sessions').count()==0 and not pending and next(background_starts)==nil
  and (not refreshed_at or now-refreshed_at>=5 or not Catalog.get_snapshot()) then
  refreshed_at=now
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
 V.fields(args,{'participants','initiator','furniture_id','scene_id','search','session_restrictions','context','bindings','start_mode','background','placement','lifetime','goals','restrictions','end_policy','task_progress_multiplier','stages','required_stages','stage_preferences','auto_speed'},{'participants','initiator'})
 if args.background~=nil then V.boolean(args.background)end
 local autonomous=req.operation=='start_autonomous_scene'or preflight and args.start_mode=='start_autonomous_scene'
 if not autonomous then for _,field in ipairs(Plan.fields)do assert(args[field]==nil,'Plan fields require start_autonomous_scene')end end
 local background=args.background==true or autonomous
 if not background then
  assert(not runtime().snapshot()and not pending,'session_already_running')
  assert(not require('SceneZOI.Autosave').restoring(),'restore_pending')
  local controller=UE.UGameplayStatics.GetPlayerController(actor,0)
  assert(controller and P.id(controller:GetCharacterEntityId())==args.initiator,'initiator_not_controlled')
 end
 local placement=M.placement(args.placement)
 local people=assert(roster(args));local member=false;for _,person in ipairs(people)do if person.id==args.initiator then member=true end end;assert(member,'Initiator must participate')
 local ids={};for _,person in ipairs(people)do ids[#ids+1]=person.id end
 assert(not require('SceneZOI.SaveBridge').restore_waiting(),'restore_pending')
 assert(not require('SceneZOI.SaveBridge').overlaps(ids,args.furniture_id),'restore_pending')
 local Sessions=require('SceneZOI.Sessions')
 for _,id in ipairs(ids)do assert(not Sessions.holder(id),'participant_busy')end
 local restrictions=Search.criteria(data.metadata,args.restrictions or args.session_restrictions)
 local search=Search.criteria(data.metadata,args.search)
 local spec=autonomous and Plan.parse(args,(data.tasks or {}).definitions or {},ids,data.metadata)or nil
 local lifetime=M.lifetime(args.lifetime,spec)
 local mode=preflight and(args.start_mode or(args.scene_id and 'start_scene'or 'start_at_hub'))or req.operation
 assert(mode=='start_at_hub'or mode=='start_scene'or mode=='start_random_scene'or mode=='start_autonomous_scene','Invalid start mode')
 if mode=='start_at_hub'then search.starting_hub_only=true end
 local rows=Search.find(data,search,people,profile(args),args.bindings);local allowed={}
 for _,candidate in ipairs(rows)do
  local named=mode=='start_scene'or autonomous and args.scene_id~=nil
  if Search.allowed(data.nodes,data.nodes[candidate.scene_id],restrictions)and(not named or candidate.scene_id==args.scene_id)then allowed[#allowed+1]=candidate end
 end
 if mode=='start_scene'or autonomous and args.scene_id~=nil then V.id(args.scene_id)end
 local chosen
 if autonomous then chosen=Plan.pick_entry(data,spec,allowed,people,restrictions)
 else chosen=assert(Search.random(allowed),'no_matching_scenes')end
 if args.context then assert(V.object(args.context)and #J.encode(args.context)<=4096,'Invalid/oversized add-on context')end
 if preflight and args.furniture_id then require('SceneZOI.Furniture').prepare(args.furniture_id,data.nodes[chosen.scene_id])end
 if background then runtime().check_start_distance(data.nodes[chosen.scene_id],chosen.bindings,placement.max_start_distance_cm,args.furniture_id)end
 if preflight then return {valid=true,scene_id=chosen.scene_id,bindings=V.copy(chosen.bindings),reservation=false,assets_checked=false,startup_rechecks=true}end
 serial=serial+1;row.token='api.'..os.time()..'.'..serial;row.age=0;row.retry=1;row.stage='depart';row.departures={}
 local reserved,reason=Sessions.reserve(row.token,ids,args.furniture_id);assert(reserved,reason)
 for _,p in ipairs(people)do row.departures[p.id]=false end
 row.entry={initiator=args.initiator,node=chosen.scene_id,bindings=chosen.bindings,furniture=args.furniture_id,api_token=row.token}
 row.restrictions=restrictions;row.context=V.copy(args.context);row.status={phase='accepted',scene_id=chosen.scene_id}
 row.placement,row.lifetime,row.plan=placement,lifetime,spec
 -- Without a length or a plan the runtime applies the player's NPC default once it knows nobody is household.
 row.default_length=args.lifetime==nil and not spec
 if background then background_starts[row.token]=row else pending=row end
 -- Ensure the caller receives start failures/end events even without a subscription.
 local sk=req.addon_id..'|'..req.client_id..'|'..P.id(actor:GetEntityId())
 if not subscribers[sk]then subscribers[sk]={addon_id=req.addon_id,client_id=req.client_id,actor=actor,names={['*']=true}}end
 return {accepted=true,scene_id=chosen.scene_id,start_request_id=req.request_id,autonomous=autonomous or nil,
  stages=spec and spec.stage_count or nil,route_uncertain=spec and spec.route_uncertain or nil}
end
local function execute(actor,req,row)
 local args=req.arguments;local op=req.operation
 local handled,result=Services.execute(actor,req)
 if handled then
  if runtime().api_control_event and not op:match('^get_')and op~='renew_integration'and op~='register_integration'then runtime().api_control_event(req)end
  return result
 end
 if op=='get_version'then return {api_version=1,runtime_build=C.build,instance_id=instance,maximum_sessions=1,maximum_npc_sessions=C.max_npc_sessions,features={autonomous_scenes=1,autonomous_stages=1,session_registry=1,event_scopes=1,background_sessions=1,placement=1,session_lifetimes=1,scene_metadata=1,scene_search=1,session_restrictions=1,events=2,explicit_bindings=1,preflight=1,furniture_discovery=1,session_results=1,integration_leases=1,live_controls=1,presentation_overrides=1,facial_poses=1,head_attachments=1,addon_data=1}}end
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
 if op=='set_auto_mode'then
  V.fields(args,{'session_id','enabled'},{'session_id','enabled'});V.boolean(args.enabled);owned(req)
  return runtime().set_auto_mode(args.session_id,args.enabled)
 end
 if op=='renew_session'then
  V.fields(args,{'session_id'},{'session_id'});owned(req);runtime().renew_session(args.session_id);return {renewed=true}
 end
 if op=='get_request_status'then
  V.fields(args,{'request_id'},{'request_id'});local k=V.copy(req);k.request_id=args.request_id;local r=assert(cache[key(k,actor)]or latest[request_key(k)],'request_not_found');return V.copy(r.status or {phase='completed',response=r.response})
 end
 if op=='stop_session'then V.fields(args,{'session_id'},{'session_id'});owned(req);runtime().api_session(args.session_id).stop_origin={addon_id=req.addon_id,client_id=req.client_id,reason='creator_stop'};runtime().stop('ok',args.session_id);return {accepted=true}end
 if op=='navigate_to_scene'then
  V.fields(args,{'session_id','scene_id'},{'session_id','scene_id'});owned(req);V.id(args.scene_id)
  return runtime().navigate_to(args.session_id,args.scene_id)
 end
 if op=='cancel_start'then
  V.fields(args,{'start_request_id'},{'start_request_id'})
  local target
  local function mine(row)return row and row.req.addon_id==req.addon_id and row.req.client_id==req.client_id and row.req.request_id==args.start_request_id end
  if mine(pending)then target=pending end
  for _,row in pairs(background_starts)do if mine(row)then target=row end end
  assert(target,'request_not_found')
  M.fail_start(target.token,'Cancelled by its add-on');return {accepted=true}
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
  local known={session_already_running=true,restore_pending=true,initiator_not_controlled=true,no_matching_scenes=true,furniture_unavailable=true,participant_busy=true,participant_too_far=true,goal_unreachable=true,required_stage_unavailable=true,participant_not_found=true,task_not_found=true}
  return {valid=false,code=known[code]and code or 'invalid_request',message=message,reservation=false}
 end
 if op=='get_definitions'then V.fields(args,{});return {tags=V.copy(data.metadata.tags),actions=V.copy(data.metadata.actions),tasks=V.copy((data.tasks or {}).definitions or {}),content_ratings={'GENERAL','SUGGESTIVE','EXPLICIT'}}end
 if op=='get_scene'then V.fields(args,{'scene_id'},{'scene_id'});return Catalog.public_node(Catalog.get(args.scene_id))end
 if op=='find_scenes'or op=='choose_random_scene'then
  V.fields(args,{'participants','furniture_id','search','bindings'});local rows=find(args,data)
  if op=='find_scenes'then return {scenes=rows,count=#rows}end
  return {scene=Search.random(rows)or J.null,count=#rows}
 end
 if op=='start_scene'or op=='start_random_scene'or op=='start_at_hub'or op=='start_autonomous_scene'then return start(actor,req,row,data)end
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
  local known={session_not_found=true,session_not_owned=true,session_not_ready=true,session_already_running=true,navigation_locked=true,participant_busy=true,session_limit=true,participant_too_far=true,goal_unreachable=true,required_stage_unavailable=true,session_has_no_plan=true,
   no_matching_scenes=true,initiator_not_controlled=true,furniture_unavailable=true,incompatible_furniture=true,unsupported_api_version=true,
   unknown_operation=true,request_not_found=true,restore_pending=true,capability_not_granted=true,integration_not_registered=true,invalid_capability=true,participant_not_found=true,task_not_found=true,outfit_item_not_found=true,effect_already_exists=true,host_changed=true,integration_limit=true,attachment_limit=true,expression_set_not_found=true,expression_context_not_found=true,incompatible_expression_set=true,facial_pose_not_found=true,incompatible_facial_pose=true}
  local candidate=message:match('([a-z_]+)$')
  response.code=known[candidate]and candidate or 'invalid_request'
  if message:find('Scene is restricted for this session',1,true)then response.code='scene_restricted'end
 end
 row.response=response;cache[k]=row;order[#order+1]=k;latest[request_key(req)]=row
 while #order>256 do
  local oldest=table.remove(order,1);local gone=cache[oldest]
  if gone and(not pending or pending~=gone)then
   cache[oldest]=nil
   if latest[request_key(gone.req)]==gone then latest[request_key(gone.req)]=nil end
  end
 end
 deliver(actor,'SceneZOI.API.Response',response)
end
-- Bounded on purpose: anything without a player panel needs a finite life.
-- The picker with the controlled Zoi unselected: the background path an add-on uses, nobody to answer to.
function M.start_from_picker(actor,ids,chosen,furniture)
 local req={api_version=1,addon_id='scenezoi.picker',client_id='picker',request_id='picker.'..os.time()..'.'..math.random(1,1073741823),operation='start_scene',
  arguments={participants=J.array(ids),initiator=ids[1],background=true,scene_id=chosen.node,furniture_id=furniture,placement={max_start_distance_m=100}}}
 return start(actor,req,{req=req,actor=actor,origin_id=ids[1]},refresh())
end
function M.placement(value)
 local out={max_start_distance_cm=C.background_max_start_distance_cm,exit='restore'}
 if value==nil then return out end
 V.fields(value,{'max_start_distance_m','exit'})
 if value.max_start_distance_m~=nil then V.number(value.max_start_distance_m,0,100);out.max_start_distance_cm=value.max_start_distance_m*100 end
 if value.exit~=nil then assert(value.exit=='restore'or value.exit=='stay','Invalid exit position policy');out.exit=value.exit end
 return out
end
function M.lifetime(value,spec)
 if value==nil then
  local seconds=C.background_default_seconds
  -- A plan asked to run longer than the default must not be cut short by it. Pauses count against this.
  if spec and spec.end_policy.type=='duration'then seconds=math.max(seconds,math.min(C.background_max_seconds,spec.end_policy.seconds*1.5+60))end
  return {deadline_seconds=seconds}
 end
 V.fields(value,{'deadline_seconds','lease_seconds'})
 assert((value.deadline_seconds==nil)~=(value.lease_seconds==nil),'Choose a deadline or an owner lease')
 if value.deadline_seconds then V.number(value.deadline_seconds,1,C.background_max_seconds);return {deadline_seconds=value.deadline_seconds}end
 V.number(value.lease_seconds,1,C.background_max_seconds);return {lease_seconds=value.lease_seconds}
end
function M.boot()
 cache,order,subscribers,pending,serial={},{},{},nil,0;cursor=0
 background_starts={}
 Control.reset()
 instance='host.'..os.time()..'.'..math.random(1,1073741823)
 cfg('api_start','none');cfg('api_start_result','none')
 if handle then Events.unsubscribe(handle)end
 handle=Events.subscribe('*',function(event)
  cursor=cursor+1;event.event_cursor=cursor
  event.api_version=1;event.instance_id=instance;event.session_id=event.id
  revive_subscribers()
  for _,sub in pairs(subscribers)do event_to(sub,event)end
  if event.request_id then
   for _,row in pairs(cache)do if row.status and row.status.session_id==event.id then row.status={phase=event.phase,session_id=event.id,event=event.name,code=event.code}end end
  end
 end)
end
local function depart(row)
 for id,done in pairs(row.departures)do if not done then
  local actor=runtime().actors[id];if not actor then M.fail_start(row.token,'Participant unloaded');return false end
  require('SceneZOI.SimulationRoute').send(actor,'SceneZOI.API.Depart',P.pack(row.token))
 end end
 return true
end
local function update_background(dt)
 local rows={};for _,row in pairs(background_starts)do rows[#rows+1]=row end
 for _,row in ipairs(rows)do
  row.age=row.age+dt;row.retry=row.retry+dt
  if row.age>15 then M.fail_start(row.token,'Start bridge timed out')
  else
   local all=true;for _,done in pairs(row.departures)do if not done then all=false end end
   if all then
    local ok,err=pcall(runtime().start_background,row)
    if not ok then M.fail_start(row.token,err)end
   elseif row.retry>=.5 then row.retry=0;depart(row)end
  end
 end
end
local function update(dt)
 update_background(math.max(tonumber(dt)or 0,0))
 if not pending then return end
 local row=pending;row.age=row.age+math.max(tonumber(dt)or 0,0);row.retry=row.retry+math.max(tonumber(dt)or 0,0)
 if row.age>15 then M.fail_start(row.token,'Start bridge timed out');return end
 if runtime().snapshot()then M.fail_start(row.token,'Another session started');return end
 if row.stage=='depart'then
  local all=true;for _,done in pairs(row.departures)do if not done then all=false end end
  if all then row.stage='ui';cfg('api_start',P.encode(J.encode({token=row.token,entry=row.entry})))
  elseif row.retry>=.5 then
   row.retry=0
   depart(row)
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
