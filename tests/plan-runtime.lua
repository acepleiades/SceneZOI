-- A plan drives a live session: it can end it, it locks navigation, and the snapshot reports it.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;tests/?.lua;'..package.path
local Search=require('SceneZOI.SceneSearch')
local TaskRoutes=require('SceneZOI.TaskRoutes')
local F=require('support.runtime-fixture').new()
local R,P,cfg=F.Runtime,F.Protocol,F.cfg
local J=require('SceneZOI.Json');local Sessions=require('SceneZOI.Sessions')
local ended={}
F.Events.subscribe('session_ended',function(e)ended[e.id]=e end)
for id=1,4 do F.add_actor(id)end
R.boot()
local function journal_ack()
 local j=J.decode(P.decode(cfg.save_snapshot));cfg.save_ready=P.pack(j.host,j.revision,'ready')
end
local function offer(token,ids)
 local record=P.encode(J.encode({token=token,collision=true}))
 for _,id in ipairs(ids)do R.save_reply(F.actors[id],P.pack(token,'snapshot',record))end
 journal_ack()
end
local function ready(token,ids)
 offer(token,ids);R.tick(.05)
 for _,id in ipairs(ids)do F.reply(token,id,'ready','female:npc',1)end
 R.tick(.05);R.tick(.05)
end
local serial=0
local function plan_row(a,b,policy,household)
 serial=serial+1
 local token='plan.'..serial
 return {token=token,has_household=household,lifetime={deadline_seconds=600},placement={max_start_distance_cm=1500,exit='restore'},
  req={addon_id='test.addon',client_id='test.client',request_id='p'..serial},restrictions={},
  entry={initiator=tostring(a),node='test.node',bindings={first=tostring(a),second=tostring(b)}},
  plan={goals=J.array({}),end_policy=policy,task_progress_multiplier=1}}
end
local function start(a,b,policy,household)
 local row=plan_row(a,b,policy,household)
 assert(Sessions.reserve(row.token,{tostring(a),tostring(b)}))
 return R.start_background(row)
end
local function place(id,x)F.actors[id].K2_GetActorLocation=function()return {X=x,Y=0,Z=0}end end
place(3,1000);place(4,1000)
-- The timer ends the scene through ordinary cleanup, and the result says why.
local token=start(1,2,{type='duration',seconds=2,clock='real'})
ready(token,{1,2})
local snap=R.snapshot(token);assert(snap.phase=='playing'and snap.plan.auto_mode and snap.plan.end_policy.clock=='real')
-- Manual and add-on navigation are refused while it drives.
local ok,err=pcall(R.navigate_to,token,'test.node');assert(not ok and tostring(err):find('navigation_locked',1,true))
for _=1,5 do R.tick(.25)end;assert(R.snapshot(token).phase=='playing','Not yet')
for _=1,5 do R.tick(.25)end
assert(R.snapshot(token).phase=='exiting');F.reply(token,1,'released');F.reply(token,2,'released');R.flush_notifications()
assert(ended[token].code=='ok'and ended[token].plan.outcome=='duration_elapsed')
assert(Sessions.holder('1')==nil,'Its roster is free again')
-- The owner can stop an add-on plan at any time; a plan never blocks that.
local held=start(3,4,{type='addon'},true);ready(held,{3,4})
for _=1,8 do R.tick(.25)end;assert(R.snapshot(held).phase=='playing')
R.stop('addon_requested',held);F.reply(held,3,'released');F.reply(held,4,'released');R.flush_notifications()
assert(ended[held].code=='addon_requested')
-- The panel's Auto-mode toggle reaches the scene it shows, and a stale command does nothing.
F.controlled=1
local shown=start(1,2,{type='addon'});ready(shown,{1,2})
R.tick(.25);R.tick(.25)
assert(cfg.plan_state:find('|1|1|1|1',1,true),'The panel is told about the plan: '..tostring(cfg.plan_state))
local client,sequence=shown:match('^(.-)%.(%d+)%.%d+$')
cfg.request=P.pack(client,sequence,'start','1','test.node','first:1+second:2','none');cfg.heartbeat=P.pack(client,sequence,'heartbeat','b1')
cfg.auto_mode=P.pack(client,sequence,'auto_mode',4,'0',99);R.tick(.25);R.tick(.25);assert(R.snapshot(shown).plan.auto_mode==true,'A command sent before a scene change is stale')
cfg.auto_mode=P.pack(client,sequence,'auto_mode',5,'0',R.snapshot(shown).revision);R.tick(.25);R.tick(.25)
local after=R.snapshot(shown).plan;assert(after.auto_mode==false,'Turned off from the panel')
assert(cfg.plan_state:find('|1|0|1|1',1,true),'The panel hears the change: '..tostring(cfg.plan_state))
ok=pcall(R.navigate_to,shown,'test.node');assert(ok,'Manual navigation is free again')
F.reply(shown,1,'ready','female:npc',2);F.reply(shown,2,'ready','female:npc',2);R.tick(.05);R.tick(.05)
cfg.auto_mode=P.pack(client,sequence,'auto_mode',4,'1');R.tick(.25);R.tick(.25)
assert(R.snapshot(shown).plan.auto_mode==false,'An older command is refused')
cfg.auto_mode=P.pack('other','9','auto_mode',9,'1');R.tick(.25);R.tick(.25)
assert(R.snapshot(shown).plan.auto_mode==false,'A command for another scene is refused')
local result=R.set_auto_mode(shown,true);assert(result.auto_mode==true and R.snapshot(shown).plan.auto_mode)
ok=pcall(R.navigate_to,shown,'test.node');assert(not ok,'Back on, it is locked again')
R.stop('ok',shown);F.reply(shown,1,'released');F.reply(shown,2,'released');R.flush_notifications()
print('Plan runtime passed: a timed plan ends a scene with its outcome, navigation is locked while it drives, and the owner can always stop it.')

-- A blocked automatic redirect can still play its completion effect. Manual
-- navigation keeps the normal catalog rules, including entry into that route.
local catalog=require('SceneZOI.Catalog')
local data=catalog.get_snapshot()
local function route_node(id,kind,rating,destination)
 return {id=id,kind=kind,content_rating=rating,destination=destination,
  participants=F.node.participants,anchor_participant='first',navigation={}}
end
local blocked=route_node('test.blocked','loop','EXPLICIT')
local bridge=route_node('test.bridge','transition','GENERAL',blocked.id)
F.node.content_rating='GENERAL'
F.node.task_completion_routes={first={charge=bridge.id}}
data.nodes={[F.node.id]=F.node,[bridge.id]=bridge,[blocked.id]=blocked}
catalog.get_snapshot=function()return data end
catalog.get=function(id)return assert(data.nodes[id])end
local runtime_search=require('SceneZOI.SceneSearch')
runtime_search.allowed=Search.allowed
runtime_search.matches=Search.matches
local routes=require('SceneZOI.TaskRoutes');routes.candidate=TaskRoutes.candidate;routes.select=TaskRoutes.select
local tasks=require('SceneZOI.Tasks')
tasks.inspect=function()return {}end
tasks.progress=tasks.inspect
tasks.enter_node=function()end
local sent,effects=false,0
tasks.update=function(_,current,_,emit)
 if sent then return end
 sent=true
 emit({participant_id=current.bindings.first.id,participant_role='first',task={id='charge',completed=true,completion_index=1}})
end
require('SceneZOI.CompletionEffects').trigger=function(_,payloads) effects=effects+#payloads end

local restricted=plan_row(3,4,{type='addon'},true)
restricted.plan.auto_restrictions={allowed_content_ratings={'GENERAL'}}
local denied=plan_row(3,4,{type='addon'},true)
denied.plan.auto_restrictions=restricted.plan.auto_restrictions
denied.entry.node=bridge.id
ok,err=pcall(R.start_background,denied)
assert(not ok and tostring(err):find('Scene is restricted in Auto-mode',1,true),'Start rechecks the transition destination')
assert(Sessions.reserve(restricted.token,{'3','4'}))
token=R.start_background(restricted);ready(token,{3,4})
Sessions.get(token).tasks={}
R.tick(.05)
assert(sent and effects==1 and R.snapshot(token).node_id==F.node.id,'A restricted completion redirect falls back to effects')
R.set_auto_mode(token,false)
assert(R.navigate_to(token,bridge.id).accepted,'Manual navigation can enter a transition excluded from Auto-mode')
ok,err=pcall(R.set_auto_mode,token,true)
assert(not ok and tostring(err):find('scene_restricted',1,true) and R.snapshot(token).plan.auto_mode==false,
 'A manual transition can settle before Auto-mode is re-enabled')
R.stop('ok',token);F.reply(token,3,'released');F.reply(token,4,'released');R.flush_notifications()
print('Auto-mode restrictions passed: startup transition closure, completion effects fallback, and manual navigation.')
-- Route planning may skip neutral loops, including the landing loop between two
-- one-shots. The runtime still waits for each one-shot's authored endpoint.
local first_hub=route_node('test.first_hub','loop','GENERAL')
local landing=route_node('test.landing','loop','GENERAL')
local final_hub=route_node('test.final_hub','loop','GENERAL')
local final=route_node('test.activity','loop','SUGGESTIVE')
local second=route_node('test.second','transition','GENERAL',final_hub.id)
local first=route_node('test.first','transition','GENERAL',landing.id)
F.node.navigation={{id='toward_hub',target=first_hub.id}}
first_hub.navigation={{id='toward_first',target=first.id}}
landing.navigation={{id='toward_second',target=second.id}}
final_hub.navigation={{id='toward_activity',target=final.id}}
for _,node in ipairs({first_hub,landing,final_hub,final,first,second})do data.nodes[node.id]=node end
catalog.transition_destination=function(node)return catalog.get(node.destination)end
local loaded={}
catalog.load=function(node)
 loaded[#loaded+1]=node.id
 return {first='a',second='b'}, 1
end
local completed={}
F.Events.subscribe('transition_completed',function(e)completed[#completed+1]=e.node_id end)

local staged=plan_row(3,4,{type='duration',seconds=20,clock='game'},true)
staged.plan.stage_count=2
staged.plan.stage_priorities={{stage=2,matches={{allowed_content_ratings={'SUGGESTIVE'}}}}}
assert(Sessions.reserve(staged.token,{'3','4'}))
token=R.start_background(staged);ready(token,{3,4})
for _=1,40 do R.tick(.25)end
assert(R.snapshot(token).node_id==first.id,'The first transition is selected through the unplayed hub')
local function accept_node(revision)
 F.reply(token,3,'ready','female:npc',revision);F.reply(token,4,'ready','female:npc',revision)
 R.tick(.05);R.tick(.05)
 assert(R.snapshot(token).phase=='playing')
end
accept_node(2)
R.tick(.25);R.flush_notifications()
assert(R.snapshot(token).node_id==first.id and #completed==0,'The first one-shot cannot be cut short')
for _=1,4 do R.tick(.25)end
R.flush_notifications()
assert(R.snapshot(token).node_id==second.id and completed[1]==first.id,'The landing hub supplies the next transition without playing')
accept_node(3)
R.tick(.25);R.flush_notifications()
assert(R.snapshot(token).node_id==second.id and #completed==1,'The second one-shot cannot be cut short')
for _=1,4 do R.tick(.25)end
R.flush_notifications()
assert(R.snapshot(token).node_id==final.id and completed[2]==second.id,'The last bridge hub is skipped')
assert(table.concat(loaded,',')=='test.node,test.first,test.second,test.activity','Only the activity and its one-shots are loaded')
accept_node(4)
R.stop('ok',token);F.reply(token,3,'released');F.reply(token,4,'released');R.flush_notifications()
assert(ended[token].code == 'ok' and Sessions.holder('3') == nil)
print('Automatic transition chain passed: both one-shots finish in order and three intermediate loops are skipped.')
