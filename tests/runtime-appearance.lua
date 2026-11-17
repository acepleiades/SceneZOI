-- Same-scene appearance changes use readiness without becoming a new scene visit.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;tests/?.lua;'..package.path
local F=require('support.runtime-fixture').new()
local R,P,cfg=F.Runtime,F.Protocol,F.cfg
local V=require('SceneZOI.DataValidation')
local J=require('SceneZOI.Json')
local Sessions=require('SceneZOI.Sessions')
local Catalog=require('SceneZOI.Catalog')
local Subsystems=require('SceneZOI.Subsystems')
local Bodies=require('SceneZOI.TemporaryBody')
local node=V.copy(F.node)
node.participants={first={body='male'},second={body='female'}}
node.appearance={second={body_variant='example.default'}}
Catalog.get=function()return V.copy(node)end
local resolve_calls=0
Catalog.resolve_appearance=function(target,people,selections)
    resolve_calls=resolve_calls+1
    target._body_variants,target._attachment_slots,target.attachments={},{},{}
    for _,person in ipairs(people)do
        assert(person.id,'Resolve appearance must see stable IDs before Session.new')
        local requested=selections[person.id]or{}
        local id=requested.body_variant
        if id==nil then id=(target.appearance[person.role]or{}).body_variant end
        if id then target._body_variants[person.role]={id=id,mesh='/Example/Body.Body',_owner='example'}end
        local slots={}
        for slot,variant in pairs(requested.attachment_variants or{})do
            slots[slot]=variant~=false and variant..'.'..person.role or false
        end
        target._attachment_slots[person.role]=slots
    end
    return target
end
local bodies_ready,body_rebuild,restore_fail=true,false,false
local restores,prepared,enters,attachment_enters,refreshes,leaves=0,0,0,0,0,0
local newly_visible,post_body_guards=false,0
Bodies.prepare=function()
    prepared=prepared+1
    -- Swapping the body installs native visibility before region guards hide it.
    if not bodies_ready then newly_visible=true end
    return bodies_ready
end
Bodies.guard=function()if body_rebuild then body_rebuild=false;return false end return true end
Bodies.restore=function()restores=restores+1;if restore_fail then error('injected body restore failure')end end
Bodies.status=function()return 'temporary_body=test'end
local load=Subsystems.load
Subsystems.load=function(target,...)
    local body=target._body_variants.second
    assert(not body or body.id~='example.load_failure','injected preflight failure')
    return load(target,...)
end
local make=Subsystems.new
Subsystems.new=function(...)
    local host=make(...)
    host.enter=function()enters=enters+1 end
    host.enter_appearance=function()attachment_enters=attachment_enters+1 end
    host.refresh_appearance=function()refreshes=refreshes+1;return host end
    host.leave_node=function()leaves=leaves+1 end
    local guard=host.guard
    host.guard=function(...)
        if newly_visible then newly_visible=false;post_body_guards=post_body_guards+1 end
        return guard(...)
    end
    return host
end
require('SceneZOI.Playback').enter=function(current)current.subsystems:enter()end
local entered,changed=0,0
F.Events.subscribe('node_entered',function()entered=entered+1 end)
F.Events.subscribe('appearance_changed',function()changed=changed+1 end)
F.add_actor(1);F.add_actor(2);R.boot()
local row={token='start.appearance',has_household=true,lifetime={deadline_seconds=600},
    placement={max_start_distance_cm=1500,exit='restore'},req={addon_id='example.addon',client_id='client',request_id='start'},
    restrictions={},appearance={['2']={body_variant='example.body_a'}},
    entry={initiator='1',node='test.node',bindings={first='1',second='2'}}}
assert(Sessions.reserve(row.token,{'1','2'}))
local token=R.start_background(row)
local current=R.api_session(token)
assert(resolve_calls==1 and current.appearance_selections['2'].body_variant=='example.body_a')
assert(current.appearance_selections~=row.appearance)
for _,sent in ipairs(F.sent)do
    if sent.kind=='SceneZOI.Prepare'and sent.id==2 then assert(sent.fields[5]=='1','A selected whole body must remain unmerged')end
end
local record=P.encode(J.encode({token=token,collision=true}))
for id=1,2 do R.save_reply(F.actors[id],P.pack(token,'snapshot',record))end
local journal=J.decode(P.decode(cfg.save_snapshot));cfg.save_ready=P.pack(journal.host,journal.revision,'ready')
R.tick(.05)
bodies_ready=false
for id=1,2 do F.reply(token,id,'ready','female:npc',1)end
R.tick(.05)
assert(R.snapshot(token).phase=='preparing'and prepared>0,'Body readiness must precede playback')
assert(not newly_visible and post_body_guards==1,
    'Attachment masking must run after a body mutation and before this frame is presented')
bodies_ready=true;R.tick(.05)
assert(R.snapshot(token).phase=='playing'and entered==1 and enters==1)

local tasks={sentinel=37}
current.tasks=tasks
local T=require('SceneZOI.Tasks')
T.inspect=function()return{}end;T.progress=function()return{}end;T.snapshot=function()return{}end;T.update=function()end
T.enter_node=function()error('Same-scene refresh must not reenter tasks')end
current.completion_effects={phase='ongoing'}
local effects=current.completion_effects
current.clock.elapsed,current.clock.session_elapsed=1.75,9.75
local original_revision=current.revision
assert(not pcall(R.api_set_appearance,current,{['3']={}}))
assert(not pcall(R.api_set_appearance,current,{['2']={body_variant=true}}))
assert(not pcall(R.api_set_appearance,current,{['2']={body_variant='example.load_failure'}}))
assert(current.revision==original_revision and current.clock.elapsed==1.75 and refreshes==0)
assert(current.appearance_selections['2'].body_variant=='example.body_a','Preflight failure must preserve current selection')

local result=R.api_set_appearance(current,{['2']={attachment_variants={body_region=false,tongue='example.tongue'}}})
assert(result.accepted and current.preparing and refreshes==1)
assert(current.appearance_selections['2'].body_variant=='example.body_a','Omitted fields preserve explicit choices')
assert(current.clock.elapsed==1.75 and current.clock.session_elapsed==9.75 and current.tasks==tasks and current.completion_effects==effects)
assert(leaves==0,'An appearance refresh must not leave completion/voice engines')
local view=R.api_get_appearance(current)
assert(view.appearance['2'].attachment_variants.body_region==false and view.resolved['2'].body_variant=='example.body_a')
assert(view.resolved['2'].attachment_variants.tongue.attachment_id=='example.tongue.second')
view.appearance['2'].body_variant=false
assert(current.appearance_selections['2'].body_variant=='example.body_a','Inspection must return copied selections')
for id=1,2 do F.reply(token,id,'ready','female:npc',current.revision)end
R.tick(.05)
assert(not current.preparing and current.clock.elapsed>=1.75 and current.tasks==tasks and current.completion_effects==effects)
assert(entered==1 and enters==1 and changed==1 and attachment_enters==1,'Resume must enter only attachment engines')

local held,revision=current.clock.elapsed,current.revision
body_rebuild,bodies_ready=true,false
R.tick(.05)
assert(current.preparing and current.clock.elapsed==held,'A spontaneous native rebuild must hold the existing sample')
bodies_ready=true;R.tick(.05)
assert(not current.preparing and current.revision==revision and current.clock.elapsed>=held and entered==1,
    'Spontaneous refresh resume: '..tostring(current.preparing)..'/'..tostring(current.revision)..'/'..tostring(revision)..
    '/'..tostring(current.clock.elapsed)..'/'..tostring(held)..'/'..tostring(entered)..'/'..tostring(current.preparation_stage))

assert(R.api_clear_appearance(current,'2').cleared)
assert(next(current.appearance_selections)==nil and current.node._body_variants.second.id=='example.default')
for id=1,2 do F.reply(token,id,'ready','female:npc',current.revision)end
R.tick(.05)
assert(not current.preparing and current.tasks==tasks and current.completion_effects==effects)
assert(R.api_clear_appearance(current,'2').unchanged,'Clearing an absent override must not prepare again')

restore_fail=true
R.stop('ok',token)
for id=1,2 do F.reply(token,id,'released')end
assert(R.snapshot(token).phase=='exiting'and not current.temporary_bodies_restored)
assert(current.participants[1].was_restored and current.participants[2].was_restored,'Body cleanup failure must not block independent native restoration')
restore_fail=false;R.tick(require('SceneZOI.Config').heartbeat_interval)
assert(restores>=2 and not R.snapshot(token),'Body cleanup must retry before declaring complete')
print('Runtime appearance passed: stable startup IDs, unmerged flags, native barrier, atomic preflight, patch/clear, held clocks/tasks/effects, spontaneous rebuild and independent retryable cleanup.')
