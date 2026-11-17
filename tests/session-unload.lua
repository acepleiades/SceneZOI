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

local diagnostics = require("SceneZOI.Diagnostics")
local record = diagnostics.record
local releases = {}
function diagnostics.record(name, fields)
    if name == "participant_release" then releases[#releases + 1] = fields end
    record(name, fields)
end
for id = 5, 10 do F.add_actor(id) end

local normal = start(5, 5, 6)
F.reply(normal, 7, "released")
assert(R.snapshot(normal).phase == "preparing" and #releases == 0,
    "A reply from outside the roster cannot interrupt a scene")
R.stop("ok")
F.reply(normal, 7, "released", "restore_error")
R.reply(F.actors[5], P.pack(normal, "released", "ok", 0, "host_request"))
F.reply(normal, 6, "released")
R.flush_notifications()
assert(ended[normal].code == "ok" and #releases == 0,
    "Only roster members may acknowledge cleanup or report restoration failure")

local interrupted = start(6, 5, 6)
R.reply(F.actors[6], P.pack(interrupted, "released", "ok", 0, "participant_update_error", "Queue_clear_failed"))
assert(R.snapshot(interrupted).phase == "exiting")
local release = assert(releases[1])
assert(release.session_id == interrupted and release.scene_id == F.node.id)
assert(release.participant_id == "6" and release.role == "second" and release.revision == 1)
assert(release.phase == "preparing" and release.transport == "direct" and
    release.cause == "participant_update_error" and release.simulation_diagnostic == "Queue_clear_failed")
R.reply(F.actors[5], P.pack(interrupted, "released_unloaded", "6", "participant_update_error"))
assert(#releases == 1, "The controlled Zoi's relay does not duplicate the direct diagnostic")
F.reply(interrupted, 6, "released")
F.reply(interrupted, 5, "released")
R.flush_notifications()
assert(ended[interrupted].code == "interrupted")

local unknown = start(7, 5, 6)
F.reply(unknown, 6, "released")
assert(releases[2].cause == "unreported" and releases[2].simulation_diagnostic == nil)
F.reply(unknown, 6, "released")
F.reply(unknown, 5, "released")
R.flush_notifications()
assert(ended[unknown].code == "interrupted")

local relay = start(8, 8, 9)
R.unregister(F.actors[9])
R.reply(F.actors[8], P.pack(relay, "released_unloaded", "10", "simulation_end"))
assert(#releases == 2, "A relayed release for an unrelated Zoi has no diagnostic authority")
R.reply(F.actors[8], P.pack(relay, "released_unloaded", "9", "simulation_end"))
assert(releases[3].transport == "relay" and releases[3].cause == "simulation_end" and
    releases[3].phase == "exiting" and releases[3].participant_id == "9")
F.reply(relay, 8, "released")
R.flush_notifications()
assert(ended[relay].code == "participant_unloaded")
print("Participant release causes passed: sender ownership, missing cause, direct report, relay, and public stop codes.")
