-- Scenes run beside each other with their own roster, panel binding, lifetime and failure.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;tests/?.lua;'..package.path
local F=require('support.runtime-fixture').new()
local R,P,cfg=F.Runtime,F.Protocol,F.cfg
local J=require('SceneZOI.Json');local Sessions=require('SceneZOI.Sessions')
local ended={}
F.Events.subscribe('session_ended',function(e)ended[e.id]=e end)
for id=1,10 do F.add_actor(id)end
R.boot()
local function journal_ack()
 local j=J.decode(P.decode(cfg.save_snapshot));cfg.save_ready=P.pack(j.host,j.revision,'ready')
end
local function offer(token,ids)
 local record=P.encode(J.encode({token=token,collision=true}))
 for _,id in ipairs(ids)do R.save_reply(F.actors[id],P.pack(token,'snapshot',record))end
 journal_ack()
end
local function ready(token,ids,revision)
 for _,id in ipairs(ids)do F.reply(token,id,'ready','female:npc',revision or 1)end
 R.tick(.05);R.tick(.05)
end
local beat=0
local function heartbeat(client,sequence)beat=beat+1;cfg.heartbeat=P.pack(client,sequence,'heartbeat','b'..beat)end
local function release(token,ids)for _,id in ipairs(ids)do F.reply(token,id,'released')end;R.flush_notifications()end
local function player_scene(sequence,a,b)
 cfg.request=P.pack('ui',sequence,'start',tostring(a),'test.node','first:'..a..'+second:'..b,'none')
 heartbeat('ui',sequence);R.tick(.25)
 local token=assert(R.snapshot()).id
 offer(token,{a,b});R.tick(.05);ready(token,{a,b})
 return token
end
local serial=0
local function row(a,b,household,options)
 serial=serial+1;options=options or {}
 return {token='start.'..serial,has_household=household,lifetime=options.lifetime or {deadline_seconds=600},
  placement={max_start_distance_cm=1500,exit=options.exit or 'restore'},req={addon_id='test.addon',client_id='test.client',request_id='r'..serial},
  restrictions={},entry={initiator=tostring(a),node='test.node',bindings={first=tostring(a),second=tostring(b)}}}
end
local function background(a,b,household,options)
 local start=row(a,b,household,options)
 -- The API reserves the roster when it accepts a start.
 local reserved,why=Sessions.reserve(start.token,{tostring(a),tostring(b)})
 if not reserved then error('A participant is already in a scene: '..why)end
 local ok,result=pcall(R.start_background,start)
 if not ok then Sessions.release(start.token);error(result)end
 return result
end
local function playing(token,ids)offer(token,ids);R.tick(.05);ready(token,ids);assert(R.snapshot(token).phase=='playing')end
local function place(id,x)F.actors[id].K2_GetActorLocation=function()return {X=x,Y=0,Z=0}end end
for id,x in pairs({[3]=1000,[4]=1000,[5]=2000,[6]=2000,[7]=3000,[8]=3000,[9]=5000,[10]=5000})do place(id,x)end
-- The player's own scene.
local player=player_scene(1,1,2)
assert(R.snapshot().id==player and F.autosave.enabled==false,'The controlled Zoi\'s scene holds the autosave suspension')
assert(cfg.focus_session:find(player,1,true),'The panel is told which scene it shows')
-- A background scene beside it.
F.clear_sent()
local npc=background(3,4,false)
assert(npc~=player and Sessions.count()==2 and R.snapshot().id==player,'The default snapshot stays the focused scene')
for _,row_ in ipairs(F.sent)do assert(row_.id==3 or row_.id==4,'A scene only talks to its own participants')end
playing(npc,{3,4})
local before=F.samples[player];R.tick(.05);assert(F.samples[player]==before+1 and F.samples[npc]>=1,'Both scenes advance')
assert(not cfg.state:find('host',1,true),'A scene without the panel never writes the panel state')
-- A reply for an unknown session changes nothing.
F.reply('nothing',3,'rejected','busy');assert(R.snapshot(npc).phase=='playing'and R.snapshot().phase=='playing')
-- Nobody is in two scenes at once.
local ok,err=pcall(background,3,5,false);assert(not ok and tostring(err):find('already in a scene',1,true))
-- NPC-only scenes are capped; scenes with household Zois do not count.
local second=background(5,6,false);assert(R.npc_only_count()==2)
ok,err=pcall(background,7,8,false);assert(not ok and tostring(err):find('session_limit',1,true),'The NPC-only cap applies')
local family=background(7,8,true);assert(Sessions.count()==4 and R.npc_only_count()==2,'A household scene does not use an NPC slot')
playing(second,{5,6})
-- A player's own start is never refused because of NPC scenes: it is limited only by its own roster.
R.stop('ok',family);release(family,{7,8})
-- The panel and autosave follow the controlled Zoi.
F.controlled=3;heartbeat('host','1');R.tick(.25)
assert(R.snapshot().id==npc and cfg.focus_session:find(npc,1,true),'Controlling a participant shows that scene')
assert(cfg.state:find('|host|',1,true)or cfg.state:find('host',1,true),'The panel state now belongs to that scene')
assert(F.autosave.enabled==false and require('SceneZOI.Autosave').owner()==npc,'The suspension moves with the controlled Zoi')
F.controlled=10;R.tick(.25)
assert(R.snapshot()==nil and cfg.focus_session:find('none',1,true),'A free Zoi shows no scene')
assert(F.autosave.enabled==true,'With no eligible owner the autosave setting is restored')
assert(R.snapshot(player).phase=='playing'and R.snapshot(npc).phase=='playing','Scenes keep playing without the panel')
-- A manual scene that lost its panel has a short life; an add-on's scene its own.
for _=1,240 do R.tick(.25)end
R.flush_notifications()
assert(R.snapshot(player).phase=='exiting'and R.snapshot(npc).phase=='playing','A manual scene gets a bounded background interval')
release(player,{1,2});assert(ended[player].code=='lifetime_expired')
assert(Sessions.holder('1')==nil,'Its roster is free again')
-- Returning to a scene before its limit resets it.
F.controlled=5;R.tick(.25);assert(R.snapshot().id==second)
F.controlled=10;R.tick(.25)
for _=1,8 do R.tick(.25)end
-- An owner lease has to be renewed.
local leased=background(7,8,true,{lifetime={lease_seconds=4}})
playing(leased,{7,8})
for _=1,10 do R.tick(.25)end;assert(R.snapshot(leased).phase=='playing')
R.renew_session(leased)
for _=1,10 do R.tick(.25)end;assert(R.snapshot(leased).phase=='playing','A renewal extends the lease')
for _=1,10 do R.tick(.25)end;assert(R.snapshot(leased).phase=='exiting');release(leased,{7,8});assert(ended[leased].code=='owner_expired')
-- A failure stays in its own scene.
F.sample_error=second;R.tick(.25);F.sample_error=nil
assert(R.snapshot(second).phase=='exiting'and R.snapshot(npc).phase=='playing','One scene failing must not end another')
release(second,{5,6});assert(ended[second].code=='runtime_error')
-- Crowded floor: the second standing scene asks for a nearby safe spot.
F.clear_sent()
local near=background(5,6,false)
local placement
for _,sent in ipairs(F.sent)do if sent.kind=='SceneZOI.Placement'then placement=sent end end
assert(not placement,'Enough room needs no placement')
place(7,2010);place(8,2010)
local crowded=background(7,8,true,{exit='stay'})
for _,sent in ipairs(F.sent)do if sent.kind=='SceneZOI.Placement'then placement=sent end end
assert(placement and placement.id==7,'The anchor Zoi looks for floor')
offer(crowded,{7,8});R.tick(.05)
for _,id in ipairs({7,8})do F.reply(crowded,id,'ready','female:npc',1)end;R.tick(.05);R.tick(.05)
assert(R.snapshot(crowded).phase=='preparing','Playback waits for a spot')
R.reply(F.actors[7],P.pack(crowded,'placement','2300.0','0.0','0.0'));R.tick(.05);R.tick(.05)
assert(R.snapshot(crowded).phase=='playing')
-- Exit: an ordinary end may stay in place, anything else goes back.
F.clear_sent();R.stop('ok',crowded)
for _,sent in ipairs(F.sent)do if sent.kind=='SceneZOI.Release'then assert(sent.fields[2]=='stay')end end
release(crowded,{7,8})
-- No floor at all: a background scene gives up, cleanly.
place(9,2005);place(10,2005)
local nowhere=background(9,10,true)
R.reply(F.actors[9],P.pack(nowhere,'placement','none','0'))
assert(R.snapshot(nowhere).phase=='exiting');release(nowhere,{9,10});assert(ended[nowhere].code=='placement_unavailable')
-- Too far apart when playback would begin: refused rather than snapping across the street.
place(9,5000);place(10,5000)
local far_start=background(9,10,true)
offer(far_start,{9,10});R.tick(.05)
place(10,9000)
for _,id in ipairs({9,10})do F.reply(far_start,id,'ready','female:npc',1)end;R.tick(.05);R.tick(.05)
assert(R.snapshot(far_start).phase=='exiting');release(far_start,{9,10});assert(ended[far_start].code=='participant_too_far')
-- A save ends every scene; those with a panel and those without.
cfg.save_request='save.1';R.tick(.25)
assert(R.snapshot(near).phase=='exiting'and R.snapshot(npc).phase=='exiting')
release(near,{5,6});release(npc,{3,4});assert(ended[npc].code=='saving')
assert(not R.any_active())
print('Concurrent sessions passed: independent rosters and failures, panel and autosave following the controlled Zoi, bounded background life, owner leases, NPC-only cap, placement and save.')
