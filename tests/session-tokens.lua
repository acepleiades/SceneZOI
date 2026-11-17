-- Recovery records and UI mailboxes survive a Lua host. A new background session must not inherit either.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;tests/?.lua;'..package.path
local function launch(previous_cfg)
 for name in pairs(package.loaded)do if name:find('^SceneZOI%.')then package.loaded[name]=nil end end
 local F=require('support.runtime-fixture').new()
 local R,P,cfg=F.Runtime,F.Protocol,F.cfg
 local J=require('SceneZOI.Json')
 for id=1,2 do F.add_actor(id)end
 if previous_cfg then cfg.auto_mode=previous_cfg.auto_mode;cfg.playback=previous_cfg.playback end
 R.boot()
 local Sessions=require('SceneZOI.Sessions')
 local start={token='start.1',has_household=true,lifetime={deadline_seconds=600},
  placement={max_start_distance_cm=1500,exit='restore'},req={addon_id='test.addon',client_id='test.client',request_id='r1'},
  restrictions={},entry={initiator='1',node='test.node',bindings={first='1',second='2'}},
  plan={goals=J.array({}),end_policy={type='addon'},task_progress_multiplier=1}}
 assert(Sessions.reserve(start.token,{'1','2'}))
 local token=R.start_background(start)
 local record=P.encode(J.encode({token=token,collision=true}))
 for id=1,2 do R.save_reply(F.actors[id],P.pack(token,'snapshot',record))end
 local journal=J.decode(P.decode(cfg.save_snapshot))
 cfg.save_ready=P.pack(journal.host,journal.revision,'ready')
 R.tick(.05)
 for id=1,2 do F.reply(token,id,'ready','female:npc',1)end
 R.tick(.05);R.tick(.05);R.tick(.25);R.tick(.25)
 local focus=P.unpack(cfg.focus_session)
 assert(focus[2]==token and R.snapshot(token).phase=='playing','The first background scene is playing and focused')
 local client,sequence,serial=token:match('^(.+)%.(%d+)%.(%d+)$')
 assert(client==focus[3] and sequence==focus[4] and serial,'Session token uses the published client and numeric sequence')
 return F,token,focus
end

local function change_controls(F,focus)
 local P,cfg=F.Protocol,F.cfg
 cfg.auto_mode=P.pack(focus[3],focus[4],'auto_mode',23,'0',focus[5])
 cfg.playback=P.pack(focus[3],focus[4],'speed',23,4)
 F.Runtime.tick(.25)
 local snapshot=F.Runtime.snapshot(focus[2])
 assert(snapshot.plan.auto_mode==false and snapshot.speed_index==4,'Fresh panel commands control the current session')
end

local first,first_token,first_focus=launch()
change_controls(first,first_focus)
local second,second_token,second_focus=launch(first.cfg)
assert(first_token~=second_token,'A new launch must not reuse deferred recovery records')
assert(first_focus[4]==second_focus[4] and first_focus[5]==second_focus[5],
 'The fixture must reuse the same sequence and revision across hosts')
local snapshot=second.Runtime.snapshot(second_token)
assert(snapshot.plan.auto_mode and snapshot.speed_index==2,'A new host must ignore persisted Auto-mode and speed commands')
change_controls(second,second_focus)
print('Session tokens passed: cross-host recovery identity, stale panel commands, and fresh controls.')
