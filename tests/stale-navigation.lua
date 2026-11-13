-- A click left in the navigation mailbox by an earlier scene is not replayed into a new one with the same client and
-- sequence ("Scene navigation changed. Choose again." flickered over scenes, 2026-11-13).
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;tests/?.lua;'..package.path
local F=require('support.runtime-fixture').new()
local R,P,cfg=F.Runtime,F.Protocol,F.cfg
local J=require('SceneZOI.Json')
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
 for _,id in ipairs(ids)do F.reply(token,id,'ready','female:npc',1)end
 R.tick(.05);R.tick(.05)
end
local function heartbeat(client,sequence)cfg.heartbeat=P.pack(client,sequence,'heartbeat','b'..tostring(sequence))end
-- the mailbox still holds click number 3 of an earlier scene "ui|7"
cfg.navigation=P.pack('ui','7','navigate','3','test.nowhere','4')
cfg.request=P.pack('ui','7','start','1','test.node','first:1+second:2','none')
heartbeat('ui','7');R.tick(.25)
local token=assert(R.snapshot()).id
offer(token,{1,2});R.tick(.05);ready(token,{1,2})
for _=1,8 do R.tick(.25)end
assert(not tostring(cfg.navigation_state):find('stale_navigation',1,true),'A leftover click is not answered "navigation changed": '..tostring(cfg.navigation_state))
print('Stale navigation passed: a click left by an earlier scene is not replayed into a new one.')
