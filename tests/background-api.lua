-- The public API starts background scenes without touching the single-session contract add-ons already rely on.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local J=require('SceneZOI.Json');local P=require('SceneZOI.Protocol');local Sessions=require('SceneZOI.Sessions')
local V=require('SceneZOI.DataValidation')
local task_registry=dofile('tests/support/task-registry.lua')
local function actor(id,body)return {id=tostring(id),body=body,GetEntityId=function()return {Value=id}end}end
local a,b,c,d,e,f=actor(1,'male'),actor(2,'female'),actor(3,'male'),actor(4,'female'),actor(5,'male'),actor(6,'female')
local actors={['1']=a,['2']=b,['3']=c,['4']=d,['5']=e,['6']=f}
UE={UGameplayStatics={GetPlayerController=function()return {GetCharacterEntityId=function()return {Value=1}end}end}}
local node={id='test.hub',kind='loop',starting_hub=true,content_rating='GENERAL',
 participants={first={body='male'},second={body='female'}},anchor_participant='first',tracks={},navigation={}}
local data={metadata={tags={},actions={}},nodes={[node.id]=node},tasks=task_registry({})}
local started,stopped,renewed,count,too_far,limit,API=nil,{},{},0,false,false,nil
started={}
package.loaded['SceneZOI.Traits']={capture=function(x)return {id=x.id,body=x.body}end}
package.loaded['SceneZOI.DataFiles']={refresh=function()error('Add-on requests must reuse the startup declarations')end}
package.loaded['SceneZOI.Catalog']={refresh=function()return data end,get_snapshot=function()return data end}
local Search=require('SceneZOI.SceneSearch')
package.loaded['SceneZOI.SceneSearch']={criteria=function(_,v)return v or {}end,allowed=Search.allowed,matches=Search.matches,
 find=function(snapshot,_,people)
  local rows={}
  for id in pairs(snapshot.nodes)do rows[#rows+1]={scene_id=id,bindings={first=people[1].id,second=people[2].id}}end
  return rows
 end,random=function(rows)return rows[1]end}
package.loaded['SceneZOI.Furniture']={}
local player
package.loaded['SceneZOI.Runtime']={actors=actors,
 check_start_distance=function()if too_far then error('participant_too_far')end end,
 snapshot=function(id)if id then return started[id]and {id=id,phase='playing'}or nil end return player end,
 is_addon_owner=function(addon,client,id)return started[id]~=nil and addon=='test.addon'and client=='test.client'end,
 api_session=function(id)return assert(started[id],'session_not_found')end,
 renew_session=function(id)renewed[#renewed+1]=id end,
 set_auto_mode=function(id,enabled)started[id].auto=enabled;return {auto_mode=enabled}end,
 start_background=function(row)
  if limit then error('session_limit')end
  count=count+1;local token='background.'..count;started[token]=row
  API.created(row,{token=token});return token
 end,
 stop=function(code,token)stopped[#stopped+1]={code=code,token=token}end}
local cfg,responses,events,departs={}, {}, {}, {}
inzoi={cli={execute=function(line)
 local key=line:match(' key=([%w_]+)')
 if line:find('cfg_save',1,true)then cfg[key]=line:match(' value="([^"]*)"$') or line:match(' value=(.*)');return true end
 return true,'',cfg[key]
end},message={send_to_sim=function(id,kind,content)
 if kind=='SceneZOI.API.Response'then responses[#responses+1]=J.decode(content)
 elseif kind=='SceneZOI.API.Event'then events[#events+1]=J.decode(content)
 elseif kind=='SceneZOI.API.Depart'then departs[#departs+1]={id=id.Value,token=P.unpack(content)[1]}end
end}}
API=require('SceneZOI.AddonAPI');API.boot()
local serial=0
local function request(op,args,addon,client)
 serial=serial+1
 API.receive(a,J.encode({api_version=1,addon_id=addon or 'test.addon',client_id=client or 'test.client',request_id='r'..serial,operation=op,arguments=args or {}}))
 return responses[#responses],'r'..serial
end
local function depart(kind)
 local rows=departs;departs={}
 for _,row in ipairs(rows)do API.departure_reply(actors[tostring(row.id)],P.pack(row.token,'ok',kind or 'npc'))end
end
local function failure()return events[#events].event end
local NPC={initiator='3',participants={'3','4'},background=true}
local function start(extra)
 local args={};for k,v in pairs(NPC)do args[k]=v end;for k,v in pairs(extra or {})do args[k]=v end
 return request('start_at_hub',args)
end

local r=request('get_version');assert(r.result.maximum_sessions==1 and r.result.maximum_npc_sessions==15 and r.result.features.background_sessions==1)
assert(r.result.features.placement==1 and r.result.features.session_lifetimes==1)

-- The controlled Zoi is 1. Without the flag every old rule still holds.
r=request('start_at_hub',{initiator='3',participants={'3','4'}});assert(not r.ok and r.code=='initiator_not_controlled')
player={id='player.1',phase='playing'}
r=request('start_at_hub',{initiator='1',participants={'1','2'}});assert(not r.ok and r.code=='session_already_running')

-- With it, two NPCs can start while the player's scene plays.
r=start({context={purpose='test'}});assert(r.ok and r.result.accepted)
assert(Sessions.holder('3')and Sessions.holder('4'),'The roster is held from the moment the start is accepted')
assert(not cfg.api_start or cfg.api_start=='none','A background start never goes through the panel')
API.tick(.5)
assert(#departs==2,'Participants first leave their gameplay groups')
depart('npc');API.tick(.05)
local row=started['background.1'];assert(row and row.entry.initiator=='3'and row.entry.node=='test.hub'and row.context.purpose=='test')
assert(not row.has_household,'Two NPCs make an NPC-only scene')
assert(row.default_length==true,'Nobody asked a length: the player default can apply')
assert(row.placement.max_start_distance_cm==1500 and row.placement.exit=='restore'and row.lifetime.deadline_seconds==600,'Unset placement and lifetime take bounded defaults')
assert(Sessions.holder('3')=='background.1','The reservation moves to the session')

-- A Zoi already in a scene is refused, whether its scene is running or still starting.
r=request('start_at_hub',{initiator='5',participants={'5','4'},background=true});assert(not r.ok and r.code=='participant_busy')
r=request('start_at_hub',{initiator='5',participants={'5','6'},background=true});assert(r.ok)
local second_request=responses[#responses].request_id
r=request('start_at_hub',{initiator='5',participants={'5','6'},background=true});assert(not r.ok and r.code=='participant_busy')
-- Cancelling a start frees its roster.
r=request('cancel_start',{start_request_id=second_request});assert(r.ok and Sessions.holder('5')==nil and failure().name=='session_start_failed')
departs={}

-- A household member anywhere in the roster takes the scene out of the NPC-only count.
r=request('start_at_hub',{initiator='5',participants={'5','6'},background=true});assert(r.ok);API.tick(.5);depart('household');API.tick(.05)
assert(started['background.2'].has_household==true)
Sessions.release('background.2');started['background.2']=nil

-- Placement and lifetime are explicit, bounded and validated.
r=request('start_at_hub',{initiator='5',participants={'5','6'},background=true,placement={max_start_distance_m=5,exit='stay'},lifetime={lease_seconds=30}});assert(r.ok);API.tick(.5);depart();API.tick(.05)
assert(started['background.3'].placement.max_start_distance_cm==500 and started['background.3'].placement.exit=='stay'and started['background.3'].lifetime.lease_seconds==30)
Sessions.release('background.3');started['background.3']=nil
local function refused(args)local out=request('start_at_hub',args);assert(not out.ok and out.code=='invalid_request');assert(Sessions.holder('5')==nil,'A refused start holds nothing')end
refused({initiator='5',participants={'5','6'},background='yes'})
refused({initiator='5',participants={'5','6'},background=true,placement={exit='teleport'}})
refused({initiator='5',participants={'5','6'},background=true,placement={max_start_distance_m=500}})
refused({initiator='5',participants={'5','6'},background=true,lifetime={deadline_seconds=99999}})
refused({initiator='5',participants={'5','6'},background=true,lifetime={deadline_seconds=10,lease_seconds=10}})

-- Too far apart is refused before anything is held.
too_far=true;r=request('start_at_hub',{initiator='5',participants={'5','6'},background=true});assert(not r.ok and r.code=='participant_too_far'and Sessions.holder('5')==nil);too_far=false

-- The NPC-only cap is found once the roster is known: reported as a failed start, with the roster freed.
limit=true
r=request('start_at_hub',{initiator='5',participants={'5','6'},background=true});assert(r.ok);API.tick(.5);depart();API.tick(.05)
assert(failure().name=='session_start_failed'and failure().code=='session_limit'and Sessions.holder('5')==nil)
limit=false

-- A Zoi that never answers does not hold its roster forever.
r=request('start_at_hub',{initiator='5',participants={'5','6'},background=true});assert(r.ok);API.tick(16);assert(failure().code=='start_failed'and Sessions.holder('5')==nil)
departs={}

-- A Zoi that left mid-start fails the start rather than wedging it.
r=request('start_at_hub',{initiator='5',participants={'5','6'},background=true});assert(r.ok)
actors['6']=nil;API.tick(.5);actors['6']=f
assert(failure().code=='start_failed'and Sessions.holder('5')==nil)
departs={}

-- Sessions are addressed by id, and only their owner steers them.
r=request('get_session',{session_id='background.1'});assert(r.ok and r.result.session.id=='background.1')
r=request('get_session');assert(r.result.session.id=='player.1','No id still means the focused scene')
r=request('renew_session',{session_id='background.1'},'other.addon');assert(not r.ok and r.code=='session_not_owned'and #renewed==0)
r=request('renew_session',{session_id='background.1'});assert(r.ok and renewed[1]=='background.1')
r=request('stop_session',{session_id='background.1'},'other.addon');assert(not r.ok and r.code=='session_not_owned')
r=request('stop_session',{session_id='background.1'});assert(r.ok and stopped[#stopped].token=='background.1')
-- Autonomous plans use the same start path, and plan fields need the new operation.
local goal={{participant_id='5',task_id='charge'}}
data.tasks=task_registry({charge={maximum=100}});node.tasks={first={charge={rate=1}}}
r=request('start_at_hub',{initiator='5',participants={'5','6'},background=true,goals=goal});assert(not r.ok and r.code=='invalid_request'and Sessions.holder('5')==nil)
r=request('start_at_hub',{initiator='5',participants={'5','6'},background=true,auto_restrictions={}})
assert(not r.ok and r.code=='invalid_request'and Sessions.holder('5')==nil)
r=request('start_autonomous_scene',{initiator='5',participants={'5','6'}});assert(not r.ok and r.code=='invalid_request','A plan needs goals or an end policy')
r=request('start_autonomous_scene',{initiator='5',participants={'5','6'},goals={{participant_id='6',task_id='charge'}}});assert(not r.ok and r.code=='goal_unreachable','The data shows no scene can finish it')
r=request('start_autonomous_scene',{initiator='5',participants={'5','6'},goals={{participant_id='5',task_id='nope'}}});assert(not r.ok and r.code=='task_not_found')
r=request('start_autonomous_scene',{initiator='5',participants={'5','6'},goals={{participant_id='9',task_id='charge'}}});assert(not r.ok and r.code=='participant_not_found')
assert(Sessions.holder('5')==nil,'A refused plan holds nothing')
r=request('validate_start',{initiator='5',participants={'5','6'},start_mode='start_autonomous_scene',goals=goal,auto_restrictions={allowed_content_ratings={'EXPLICIT'}}})
assert(r.ok and not r.result.valid and r.result.code=='no_matching_scenes'and Sessions.holder('5')==nil)
r=request('start_autonomous_scene',{initiator='5',participants={'5','6'},goals=goal,stages=4,stage_progress='fastest',
 restrictions={allowed_content_ratings={'GENERAL'}},auto_restrictions={allowed_content_ratings={'GENERAL','SUGGESTIVE'}},
 stage_priorities={{stage=1,matches={{allowed_content_ratings={'GENERAL'}}}}},variety_groups={['test.hub']='test.rest'},
 post_completion_stay_seconds=6,skip_post_completion_stay_after_manual=true,context={purpose='test'}})
assert(r.ok and r.result.autonomous==true and r.result.stages==4 and r.result.scene_id=='test.hub')
API.tick(.5);depart();API.tick(.05)
local planned=started['background.'..count];assert(planned.plan.goals[1].task_id=='charge'and planned.plan.end_policy.type=='goals'and planned.context.purpose=='test')
assert(planned.plan.stage_progress=='fastest')
assert(planned.plan.stage_priorities[1].matches[1].allowed_content_ratings[1]=='GENERAL')
assert(planned.plan.variety_groups['test.hub']=='test.rest'and planned.plan.skip_post_completion_stay_after_manual==true)
assert(planned.restrictions.allowed_content_ratings[1]=='GENERAL','Named restrictions become the session restrictions')
assert(planned.plan.auto_restrictions.allowed_content_ratings[2]=='SUGGESTIVE'and not planned.restrictions.allowed_content_ratings[2],'Auto-only restrictions are plan state')
assert(planned.default_length==false,'A plan has its own end')
Sessions.release('background.'..count);started['background.'..count]=nil
-- A timed plan is not cut short by the default deadline, and the deadline still has a ceiling.
r=request('start_autonomous_scene',{initiator='5',participants={'5','6'},end_policy={type='duration',seconds=6000}});assert(r.ok);API.tick(.5);depart();API.tick(.05)
assert(started['background.'..count].lifetime.deadline_seconds==7200)
Sessions.release('background.'..count);started['background.'..count]=nil
-- A requested length keeps its own limit, whatever the player's default is.
r=request('start_scene',{initiator='5',participants={'5','6'},background=true,scene_id='test.hub',lifetime={deadline_seconds=900}});assert(r.ok);API.tick(.5);depart();API.tick(.05)
assert(started['background.'..count].lifetime.deadline_seconds==900 and started['background.'..count].default_length==false)
Sessions.release('background.'..count);started['background.'..count]=nil
-- The picker's NPC-only start takes the same path and the player's default length.
local picked=API.start_from_picker({GetEntityId=function()return {Value=5}end},{'5','6'},{node='test.hub'},nil);assert(picked.accepted);API.tick(.5);depart();API.tick(.05)
assert(started['background.'..count].default_length==true and started['background.'..count].placement.max_start_distance_cm==10000)
Sessions.release('background.'..count);started['background.'..count]=nil
local distance_check={initiator='5',participants={'5','6'},start_mode='start_autonomous_scene',goals=goal}
too_far=true
r=request('validate_start',distance_check);assert(r.ok and not r.result.valid and r.result.code=='participant_too_far')
distance_check.check_start_distance=false
r=request('validate_start',distance_check)
assert(r.ok and r.result.valid and r.result.anchor_participant_id=='5' and Sessions.holder('5')==nil)
local actual_start=V.copy(distance_check);actual_start.start_mode=nil
r=request('start_autonomous_scene',actual_start);assert(not r.ok and r.code=='invalid_request')
actual_start.check_start_distance=nil
r=request('start_autonomous_scene',actual_start);assert(not r.ok and r.code=='participant_too_far')
too_far=false
distance_check.check_start_distance=nil
r=request('validate_start',distance_check);assert(r.ok and r.result.valid and Sessions.holder('5')==nil)
r=request('validate_start',{initiator='5',participants={'5','6'},start_mode='start_autonomous_scene',goals={{participant_id='6',task_id='charge'}}});assert(r.ok and r.result.valid==false and r.result.code=='goal_unreachable')
local conditional=V.copy(node)
conditional.id='test.conditional'
conditional.tasks={second={charge={rate=1}}}
conditional.task_completion_routes={second={charge=node.id}}
conditional.navigation={}
data.nodes[conditional.id]=conditional
r=request('validate_start',{initiator='5',participants={'5','6'},start_mode='start_autonomous_scene',scene_id=conditional.id,
 goals={goal[1],{participant_id='6',task_id='charge'}}})
assert(r.ok and r.result.valid and r.result.route_uncertain and Sessions.holder('5')==nil,'Conditional routes are disclosed in preflight')
data.nodes[conditional.id]=nil
-- Only the owner can switch a scene between automatic and manual.
started['background.1']=started['background.1']or {}
r=request('set_auto_mode',{session_id='background.1',enabled=false},'other.addon');assert(not r.ok and r.code=='session_not_owned')
r=request('set_auto_mode',{session_id='background.1',enabled='no'});assert(not r.ok and r.code=='invalid_request')
r=request('set_auto_mode',{session_id='background.1',enabled=false});assert(r.ok and r.result.auto_mode==false and started['background.1'].auto==false)
assert(request('get_version').result.features.autonomous_stages==1)
assert(request('get_version').result.features.autonomous_stage_progress==1)
local planner_features=request('get_version').result.features
assert(planner_features.autonomous_stage_priorities==1 and planner_features.autonomous_auto_restrictions==1)
assert(planner_features.autonomous_joint_goal_routes==1 and planner_features.autonomous_manual_completion_exit==1)
-- An add-on that comes back through another Zoi can still ask about its own request.
local _,asked=request('list_sessions',{})
serial=serial+1
API.receive(b,J.encode({api_version=1,addon_id='test.addon',client_id='test.client',request_id='r'..serial,operation='get_request_status',arguments={request_id=asked}}))
assert(responses[#responses].ok,'A request is found whichever Zoi asks')
-- Read the same plain-text diagnostics that are included in a player's runtime ZIP.
local Diagnostics=require('SceneZOI.Diagnostics')
local function read_trace(skip)
 local rows={}
 for line in (cfg.api_trace or ''):gmatch('[^\n]+')do
  if skip==0 then rows[#rows+1]=line else skip=skip-1 end
 end
 return rows
end
local function includes(row,...)
 for _,field in ipairs({...})do assert(row:find(field,1,true),field)end
end
local function trace_sequence(row)return tonumber(row:match(' sequence=(%d+)'))end
Diagnostics.flush()
local skip=#read_trace(0)
assert(request('get_session',{}).ok and #read_trace(skip)==0,'Calls queue writes outside the API handler')
Diagnostics.tick(1)
local traces=read_trace(skip)
assert(#traces==1)
includes(traces[1],'addon_id=test.addon','operation=get_session','endpoint_id=1')
assert(request('get_version',{},'other.addon').ok)
local reply=request('validate_start',{initiator='5',participants={'5','6'},start_mode='start_autonomous_scene',
 context={note='private-note'},end_policy={type='duration',clock='game',seconds=2700}})
assert(reply.ok and reply.result.valid)
assert(not request('get_session',{session_id='missing'}).ok)
local retry={api_version=1,addon_id='test.addon',client_id='test.client',request_id='trace.retry',operation='get_version'}
local raw=J.encode(retry)
API.receive(a,raw);API.receive(a,raw)
retry.operation='get_session';API.receive(a,J.encode(retry))
API.receive(a,'invalid-private-payload')
API.receive(a,J.encode({addon_id='broken.addon',operation='get_version',private='private-note'}))
local Events=require('SceneZOI.Events')
Events.emit('playback_speed_changed',{id='test.session',addon_id='test.addon',addon_client_id='test.client',
 request_id=reply.request_id,speed_index=3,effective_speed=1.5,plan={stage=2,auto_mode=true},
 addon_context={note='private-note'}})
Events.flush()
local native_execute=inzoi.cli.execute
inzoi.cli.execute=function(line)
 if line:find('cfg_save',1,true)and line:find(' key=api_trace ',1,true)then return false end
 return native_execute(line)
end
Diagnostics.flush()
assert(#read_trace(skip)==1,'A storage failure leaves the previous trace intact')
inzoi.cli.execute=native_execute
Diagnostics.flush()
traces=read_trace(skip)
assert(#traces==9,'Pending calls survive a storage failure')
includes(traces[2],'addon_id=other.addon')
assert(trace_sequence(traces[2])==trace_sequence(traces[1])+1)
assert(traces[2]:match('timestamp=%d+') and traces[2]:match('time_utc=[^ ]+Z'))
includes(traces[3],'request_id='..reply.request_id,'valid=true','dispatched=true','seconds=2700')
assert(not traces[3]:find('private-note',1,true))
includes(traces[4],'code=session_not_found')
assert(not traces[4]:find('message=',1,true))
includes(traces[5],'replayed=false','request_id=trace.retry')
includes(traces[6],'replayed=true','request_id=trace.retry')
includes(traces[7],'code=request_id_reused','replayed=false')
includes(traces[8],'kind=rejected','code=invalid_json','payload_bytes=23')
includes(traces[9],'code=invalid_envelope','addon_id=broken.addon')
assert(not traces[9]:find('private-note',1,true))
Diagnostics.flush()
includes(cfg.scene_history,'event=playback_speed_changed','session_id=test.session','stage=2','effective_speed=1.5')
assert(not cfg.scene_history:find('private-note',1,true))
for _=1,302 do assert(request('get_session',{},'other.addon').ok)end
Diagnostics.flush()
traces=read_trace(0)
assert(#traces>0 and #traces<=512 and #cfg.api_trace<=131072)
includes(traces[#traces],'addon_id=other.addon','operation=get_session','request_id=r'..serial..' ')
for index=2,#traces do assert(trace_sequence(traces[index])==trace_sequence(traces[index-1])+1)end
for key in pairs(cfg)do assert(not key:match('^api_trace_'),'API traces must not create page files')end

print('Background API passed: opt-in flag, old contract unchanged, reservations, departures, household detection, placement and lifetime validation, distance, cap, timeouts and addressing by id.')
