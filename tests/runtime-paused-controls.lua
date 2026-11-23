-- The UI clock packet can lag behind native pause. Retained player mailboxes
-- must be acknowledged without applying pose changes later on resume.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;tests/?.lua;'..package.path
local F=require('support.runtime-fixture').new()
local R,P,cfg=F.Runtime,F.Protocol,F.cfg
local J=require('SceneZOI.Json')
local Sessions=require('SceneZOI.Sessions')
F.add_actor(1);F.add_actor(2);R.boot()
local row={token='qa.paused',has_household=true,lifetime={deadline_seconds=600},
 placement={max_start_distance_cm=1500,exit='restore'},req={addon_id='test.addon',client_id='client',request_id='start'},
 restrictions={},entry={initiator='1',node='test.node',bindings={first='1',second='2'}},
 plan={goals=J.array({}),end_policy={type='addon'},task_progress_multiplier=1}}
assert(Sessions.reserve(row.token,{'1','2'}))
local token=R.start_background(row)
local record=P.encode(J.encode({token=token,collision=true}))
for id=1,2 do R.save_reply(F.actors[id],P.pack(token,'snapshot',record))end
local journal=J.decode(P.decode(cfg.save_snapshot));cfg.save_ready=P.pack(journal.host,journal.revision,'ready')
R.tick(.05);for id=1,2 do F.reply(token,id,'ready','female:npc',1)end
R.tick(.05);R.tick(.05)
local current=R.api_session(token)
assert(current.started and not current.preparing)
local client,sequence=current.client,current.sequence
cfg.request=P.pack(client,sequence,'start','1','test.node','first:1+second:2','none')
cfg.heartbeat=P.pack(client,sequence,'heartbeat','paused-test')
F.time_scale=0
-- The clock cached on the session is deliberately still running here.
assert(current.clock.scale>0)
cfg.playback=P.pack(client,sequence,'speed',1,4)
cfg.navigation=P.pack(client,sequence,'navigate',1,'back',current.revision,token)
cfg.auto_mode=P.pack(client,sequence,'auto_mode',1,'0',current.revision)
local outfit=require('SceneZOI.OutfitControl');local requests=0
outfit.request=function()
 requests=requests+1
 if requests==1 then return {counter=1,participant=current.participants[1],item='piece1',enabled='0'}end
end
R.tick(.25);R.tick(.25)
assert(current.clock.index==2 and current.clock.scale==0)
assert(current.last_speed_command==1 and current.last_navigation==1 and current.last_auto_mode==1)
assert(current.navigation_code=='navigation_locked'and current.outfit_code=='game_paused')
assert(current.acknowledged_outfit==1 and not current.outfit_change and not current.preparing)
assert(current.plan.auto_mode,'Pause must not turn Auto-mode off')
F.time_scale=1;for _=1,3 do R.tick(.25)end
assert(current.clock.index==2 and current.plan.auto_mode and current.revision==1,
 'Commands refused during pause must not replay from disk on resume')
cfg.playback=P.pack(client,sequence,'speed',2,4)
R.set_auto_mode(token,false);R.tick(.25);R.tick(.25)
assert(current.clock.index==4,'A fresh player command works after resume')
-- System cleanup and the public owner API remain available while paused.
F.time_scale=0;R.stop('ok',token)
for id=1,2 do F.reply(token,id,'released')end
R.flush_notifications();assert(not R.snapshot(token))
print('Paused controls passed: native-clock race, consumed mailboxes, resume, independent Auto-mode and paused cleanup.')
