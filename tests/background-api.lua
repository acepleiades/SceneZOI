-- The public API starts background scenes without touching the single-session contract add-ons already rely on.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local J=require('SceneZOI.Json');local P=require('SceneZOI.Protocol');local Sessions=require('SceneZOI.Sessions')
local function actor(id,body)return {id=tostring(id),body=body,GetEntityId=function()return {Value=id}end}end
local a,b,c,d,e,f=actor(1,'male'),actor(2,'female'),actor(3,'male'),actor(4,'female'),actor(5,'male'),actor(6,'female')
local actors={['1']=a,['2']=b,['3']=c,['4']=d,['5']=e,['6']=f}
UE={UGameplayStatics={GetPlayerController=function()return {GetCharacterEntityId=function()return {Value=1}end}end}}
local node={id='test.hub',kind='loop',starting_hub=true,participants={first={body='male'},second={body='female'}},navigation={}}
local data={metadata={tags={},actions={}},nodes={[node.id]=node}}
local started,stopped,renewed,count,too_far,limit,API=nil,{},{},0,false,false,nil
started={}
package.loaded['SceneZOI.Traits']={capture=function(x)return {id=x.id,body=x.body}end}
package.loaded['SceneZOI.DataFiles']={refresh=function()end}
package.loaded['SceneZOI.Catalog']={refresh=function()return data end,get_snapshot=function()return data end}
package.loaded['SceneZOI.SceneSearch']={criteria=function(_,v)return v or {}end,allowed=function()return true end,
 find=function(_,_,people)return {{scene_id='test.hub',bindings={first=people[1].id,second=people[2].id}}}end,random=function(rows)return rows[1]end}
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
 if line:find('cfg_save',1,true)then cfg[key]=line:match(' value=(.*)');return true end
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

local r=request('get_version');assert(r.result.maximum_sessions==1 and r.result.maximum_npc_sessions==2 and r.result.features.background_sessions==1)
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
data.tasks={definitions={charge={maximum=100}}};node.tasks={first={charge={rate=1}}}
r=request('start_at_hub',{initiator='5',participants={'5','6'},background=true,goals=goal});assert(not r.ok and r.code=='invalid_request'and Sessions.holder('5')==nil)
r=request('start_autonomous_scene',{initiator='5',participants={'5','6'}});assert(not r.ok and r.code=='invalid_request','A plan needs goals or an end policy')
r=request('start_autonomous_scene',{initiator='5',participants={'5','6'},goals={{participant_id='6',task_id='charge'}}});assert(not r.ok and r.code=='goal_unreachable','The data shows no scene can finish it')
r=request('start_autonomous_scene',{initiator='5',participants={'5','6'},goals={{participant_id='5',task_id='nope'}}});assert(not r.ok and r.code=='task_not_found')
r=request('start_autonomous_scene',{initiator='5',participants={'5','6'},goals={{participant_id='9',task_id='charge'}}});assert(not r.ok and r.code=='participant_not_found')
assert(Sessions.holder('5')==nil,'A refused plan holds nothing')
r=request('start_autonomous_scene',{initiator='5',participants={'5','6'},goals=goal,restrictions={allowed_content_ratings={'GENERAL'}},context={purpose='test'}})
assert(r.ok and r.result.autonomous==true and r.result.stages==1 and r.result.scene_id=='test.hub')
API.tick(.5);depart();API.tick(.05)
local planned=started['background.'..count];assert(planned.plan.goals[1].task_id=='charge'and planned.plan.end_policy.type=='goals'and planned.context.purpose=='test')
assert(planned.restrictions.allowed_content_ratings[1]=='GENERAL','Named restrictions become the session restrictions')
Sessions.release('background.'..count);started['background.'..count]=nil
-- A timed plan is not cut short by the default deadline, and the deadline still has a ceiling.
r=request('start_autonomous_scene',{initiator='5',participants={'5','6'},end_policy={type='duration',seconds=1200}});assert(r.ok);API.tick(.5);depart();API.tick(.05)
assert(started['background.'..count].lifetime.deadline_seconds==1800)
Sessions.release('background.'..count);started['background.'..count]=nil
r=request('validate_start',{initiator='5',participants={'5','6'},start_mode='start_autonomous_scene',goals=goal});assert(r.ok and r.result.valid and Sessions.holder('5')==nil)
r=request('validate_start',{initiator='5',participants={'5','6'},start_mode='start_autonomous_scene',goals={{participant_id='6',task_id='charge'}}});assert(r.ok and r.result.valid==false and r.result.code=='goal_unreachable')
-- Only the owner can switch a scene between automatic and manual.
started['background.1']=started['background.1']or {}
r=request('set_auto_mode',{session_id='background.1',enabled=false},'other.addon');assert(not r.ok and r.code=='session_not_owned')
r=request('set_auto_mode',{session_id='background.1',enabled='no'});assert(not r.ok and r.code=='invalid_request')
r=request('set_auto_mode',{session_id='background.1',enabled=false});assert(r.ok and r.result.auto_mode==false and started['background.1'].auto==false)
assert(request('get_version').result.features.autonomous_stages==1)
-- An add-on that comes back through another Zoi can still ask about its own request.
local _,asked=request('list_sessions',{})
serial=serial+1
API.receive(b,J.encode({api_version=1,addon_id='test.addon',client_id='test.client',request_id='r'..serial,operation='get_request_status',arguments={request_id=asked}}))
assert(responses[#responses].ok,'A request is found whichever Zoi asks')
print('Background API passed: opt-in flag, old contract unchanged, reservations, departures, household detection, placement and lifetime validation, distance, cap, timeouts and addressing by id.')
