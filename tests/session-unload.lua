-- A participant unloading is reported for what it is, and cleanup does not wait for a Zoi that cannot answer.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;tests/?.lua;'..package.path
local F=require('support.runtime-fixture').new()
local R,P,cfg=F.Runtime,F.Protocol,F.cfg
local ended={}
F.Events.subscribe('session_ended',function(e)ended[e.id]=e end)
for id=1,4 do F.add_actor(id)end
R.boot()
local J=require('SceneZOI.Json')
local function start(sequence,a,b)
 F.controlled=a -- A manual start's initiator is the Zoi the player controls.
 cfg.request=P.pack('ui',sequence,'start',tostring(a),'test.node','first:'..a..'+second:'..b,'none')
 cfg.heartbeat=P.pack('ui',sequence,'heartbeat','beat'..sequence)
 R.tick(.25)
 local token=assert(R.snapshot()).id
 local record=P.encode(J.encode({token=token,collision=true}))
 for _,id in ipairs({a,b})do R.save_reply(F.actors[id],P.pack(token,'snapshot',record))end
 local journal=J.decode(P.decode(cfg.save_snapshot))
 cfg.save_ready=P.pack(journal.host,journal.revision,'ready')
 R.tick(.05)
 return token
end
local function journal_people(token)
 for _,record in ipairs(J.decode(P.decode(cfg.save_snapshot)).records)do if record.token==token then return record.participants end end
end
local function row(event,id)for _,person in ipairs(event.participants)do if person.id==id then return person end end end
-- Both answer: ordinary cleanup.
local first=start(1,1,2)
R.stop('ok');F.reply(first,1,'released');F.reply(first,2,'released');R.flush_notifications()
assert(ended[first].code=='ok'and ended[first].result_facts~=nil and row(ended[first],'1').restoration=='restored')
assert(journal_people(first)==nil,'A clean finish leaves nothing to recover')
assert(ended[first].focused==true,'The end of the scene on screen reaches whoever saw it start')
-- One unloads: the rest clean up at once, and it is not called a timeout.
local second=start(2,3,4)
R.unregister(F.actors[3])
assert(R.snapshot(second).phase=='exiting')
F.reply(second,4,'released');R.flush_notifications()
assert(ended[second].code=='participant_unloaded','A missing actor must end the scene as unloaded, not as a cleanup timeout')
assert(row(ended[second],'3').restoration=='deferred_recovery'and row(ended[second],'4').restoration=='restored')
assert(journal_people(second)['3']and not journal_people(second)['4'],'Only the unconfirmed Zoi is kept for later')
-- The simulation side confirms it through another Zoi: nothing left to recover.
R.reply(F.actors[1],P.pack(second,'released_unloaded','3'));assert(journal_people(second)==nil)
-- Reservations last until cleanup finishes.
local Sessions=require('SceneZOI.Sessions')
F.add_actor(3)
local third=start(3,3,4)
R.stop('ok');assert(Sessions.holder('3')==third,'A Zoi stays reserved during cleanup')
F.reply(third,3,'released');F.reply(third,4,'released');assert(Sessions.holder('3')==nil)
-- A genuine timeout is still reported as one, and keeps what it could not confirm.
local fourth=start(4,3,4)
R.stop('ok');F.reply(fourth,3,'released')
for _=1,200 do R.tick(.05)end
R.flush_notifications()
assert(ended[fourth].code=='restore_timeout'and journal_people(fourth)['4']and not journal_people(fourth)['3'])
print('Unload outcomes passed: missing actors end as unloaded, cleanup does not wait for them, per-participant results, deferred recovery and real timeouts.')
