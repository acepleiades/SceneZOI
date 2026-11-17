-- A clothed hub still needs native coverage when its fallback asks for unmerged skin.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;tests/?.lua;'..package.path
local F=require('support.runtime-fixture').new()
local R,P,cfg=F.Runtime,F.Protocol,F.cfg
local J=require('SceneZOI.Json')
local Sessions=require('SceneZOI.Sessions')
local Coverage=require('SceneZOI.ClothingCoverage')
local Subsystems=require('SceneZOI.Subsystems')
local Appearance=require('SceneZOI.Appearance')
local Bodies=require('SceneZOI.TemporaryBody')
local order={}
local coverage_ready,restore_fails=false,false
local guards,restores,appearance_checks,resource_prepares=0,0,0,0
Coverage.guard=function(current)
    assert(not current.node._body_variants,'Reproduce a normal hub without a custom body')
    guards=guards+1;order[#order+1]='clothing'
    return coverage_ready
end
Coverage.status=function()return coverage_ready and 'clothing=ready'or'clothing=native_layout_pending'end
Coverage.restore=function()
    restores=restores+1
    if restore_fails then error('injected coverage cleanup failure')end
end
local create=Subsystems.new
Subsystems.new=function(...)
    local host=create(...)
    host.keep_body_unmerged=function()return true end
    host.guard=function()
        assert(order[#order]=='clothing','Clothing must guard before an attachment adds its mask')
        order[#order+1]='attachment'
    end
    host.prepare=function()resource_prepares=resource_prepares+1;return true end
    return host
end
Appearance.ready=function()appearance_checks=appearance_checks+1;return true end
local body_prepares=0
Bodies.prepare=function()body_prepares=body_prepares+1;return true end
F.add_actor(1);F.add_actor(2);R.boot()
local row={token='start.clothing',has_household=true,lifetime={deadline_seconds=600},
    placement={max_start_distance_cm=1500,exit='restore'},req={addon_id='example.addon',client_id='client',request_id='start'},
    restrictions={},entry={initiator='1',node='test.node',bindings={first='1',second='2'}}}
assert(Sessions.reserve(row.token,{'1','2'}))
local token=R.start_background(row)
local current=R.api_session(token)
assert(not current.node._body_variants and not current.node.attachments,
    'The regression must not rely on an instantiated attachment or custom mesh')
for _,sent in ipairs(F.sent)do
    if sent.kind=='SceneZOI.Prepare'then assert(sent.fields[5]=='1','Covered fallback needs the same unmerge handshake')end
end
local record=P.encode(J.encode({token=token,collision=true}))
for id=1,2 do R.save_reply(F.actors[id],P.pack(token,'snapshot',record))end
local journal=J.decode(P.decode(cfg.save_snapshot));cfg.save_ready=P.pack(journal.host,journal.revision,'ready')
R.tick(.05)
for id=1,2 do F.reply(token,id,'ready','male:npc',1)end
order={};R.tick(.05)
assert(guards>0 and body_prepares>0 and R.snapshot(token).phase=='preparing')
assert(current.preparation_stage=='clothing_coverage'and appearance_checks==0 and resource_prepares==0,
    'Native layout/coverage readiness must gate the first frame even without a selected body')
assert(order[1]=='clothing'and order[2]=='attachment')
coverage_ready=true;order={};R.tick(.05)
assert(R.snapshot(token).phase=='playing'and appearance_checks>0 and resource_prepares>0)
local samples=F.samples[token]or 0
order={};R.tick(.05)
assert(order[1]=='clothing'and order[2]=='attachment'and(F.samples[token]or 0)>samples,
    'Playing scenes must continue clothing coverage guards before sampling')

-- Cleanup failure cannot hold the independent animation/collision restoration hostage.
restore_fails=true;R.stop('ok',token)
for id=1,2 do F.reply(token,id,'released')end
assert(R.snapshot(token).phase=='exiting'and not current.clothing_coverage_restored)
assert(current.participants[1].was_restored and current.participants[2].was_restored,
    'Coverage cleanup failure must not block independent native restoration')
restore_fails=false;R.tick(require('SceneZOI.Config').heartbeat_interval)
assert(restores>=2 and not R.snapshot(token),'Coverage cleanup must retry before session completion')
print('Runtime clothing coverage passed: clothed hub without custom body/attachment, native-layout barrier, guard ordering, playing coverage and independent cleanup retry.')
