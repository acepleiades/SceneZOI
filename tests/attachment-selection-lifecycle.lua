package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local V=require('SceneZOI.DataValidation')
local loaded,created,restored,entered={}, {}, {}, {}
local unavailable,restore_failure
local function no_operation()end
local noop={load=function()return {}end,prepare=function()return true end,ready=function()return true end,
 enter=no_operation,sample=no_operation,guard=no_operation,restore=no_operation,leave_node=no_operation,status=function()return 'ready'end}
for _,name in ipairs({'Gaze','Expressions','Sfx','Voices','VoiceResponses','CompletionEffects','TaskActions'})do
 package.loaded['SceneZOI.'..name]=noop
end
package.loaded['SceneZOI.Diagnostics']={record=no_operation}
package.loaded['SceneZOI.Traits']={capture=function(actor)return {body=actor.body}end,
 matches=function(requirement,traits)return requirement.body==traits.body end}
package.loaded['SceneZOI.BodyRegion']={covered=function()return false end,guard_clothing=function()return 0 end}
package.loaded['SceneZOI.Attachment']={
 load=function(node,duration)
  local mesh=node.attachment.mesh
  assert(mesh~=unavailable,'Missing selected mesh')
  loaded[#loaded+1]=mesh
  return mesh,nil,nil,duration
 end,
 prepare=function(context,actor)
  assert(context.attachment_duration==3,'Attachment host lost the validated handoff duration')
  if not context.attachment then
   context.attachment={actor=actor,mesh=context.attachment_asset}
   created[#created+1]=context.attachment
  end
  return true
 end,
 ready=function()return true end,enter=function(context)entered[#entered+1]=context.node.attachment.mesh end,sample=no_operation,guard=no_operation,
 restore=function(context)
  local mesh=context.node.attachment.mesh
  if mesh==restore_failure then restore_failure=nil;error('Transient old replacement cleanup failure')end
  if context.attachment then
   context.attachment.destroyed=true
   restored[#restored+1]=mesh
   context.attachment=nil
  end
 end,
 status=function()return 'ready'end,
}
local Host=require('SceneZOI.Subsystems')
local first={id='1',role='first',body='male',actor={body='male'},removed_slots={}}
local second={id='2',role='second',body='male',actor={body='male'},removed_slots={}}
local function spec(role,mesh,region)
 return {participant=role,mesh=mesh,socket='pelvis',reference_bone='pelvis',retain_for_session=true,
  body_profile=region and 'test.region' or nil,_selection_slot=region and 'body_region' or nil}
end
local node={id='test.entry',duration=3,anchor_participant='first',tracks={first='a',second='b'},participants={first={body='male'},second={body='male'}},
 attachments={['test.original.first']=spec('first','original',true),
              ['test.original.second']=spec('second','second',true),
              ['test.prop']=spec('first','prop',false)},
 _attachment_slots={first={body_region='test.original.first'},second={body_region='test.original.second'}}}
local session={node=node,duration=3,participants={first,second},bindings={first=first,second=second},retained_subsystems={}}
local host=Host.new(session,Host.load(node,3));assert(host:prepare(session))
assert(#created==3 and #restored==0)
local original=session.retained_subsystems['attachment:test.original.first']
local other=session.retained_subsystems['attachment:test.original.second']
local prop=session.retained_subsystems['attachment:test.prop']
local next_node=V.copy(node);next_node.id='test.changed';next_node.attachments={['test.large.first']=spec('first','large',true)}
next_node._attachment_slots.first.body_region='test.large.first'
local replacements=Host.load(next_node,3,session)
assert(replacements.retiring['attachment:test.original.first']==original and #restored==0,
 'Preloading a replacement must retain the currently visible provider')
host:leave_node();local next_host=Host.new(session,replacements)
session.node=next_node
assert(original.restored and #restored==1 and restored[1]=='original')
assert(session.retained_subsystems['attachment:test.original.first']==nil)
assert(next_host:prepare(session) and #created==4)
assert(session.retained_subsystems['attachment:test.original.second']==other and
       session.retained_subsystems['attachment:test.prop']==prop,
 'Changing one participant replacement must preserve the other participant and ordinary retained props')
local large=session.retained_subsystems['attachment:test.large.first']

-- Selecting the same provider reuses its component and updates only node resources.
local same_node=V.copy(next_node);same_node.id='test.same'
local same_host=Host.new(session,Host.load(same_node,3,session));session.node=same_node
assert(same_host:prepare(session) and #created==4 and #restored==1)
assert(session.retained_subsystems['attachment:test.large.first']==large)

-- Invalid destinations fail during read-only preload, leaving active resources available.
local missing=V.copy(same_node);missing.id='test.missing';missing.attachments['test.large.first'].mesh='missing'
unavailable='missing'
assert(not pcall(Host.load,missing,3,session) and not large.restored and #restored==1)
unavailable=nil

-- A managed provider can change its asset under a stable attachment ID.
local changed=V.copy(same_node);changed.id='test.revised';changed.attachments['test.large.first'].mesh='revised'
local revision=Host.load(changed,3,session)
assert(revision.retiring[large.key]==large)
restore_failure='large'
assert(not pcall(Host.new,session,revision))
assert(session.retained_subsystems[large.key]==large and not large.restored,
 'A failed outgoing cleanup retains ownership and prevents the new replacement from starting')
local retry=Host.new(session,revision);session.node=changed
assert(large.restored and retry:prepare(session) and #created==5)

-- Explicitly selecting no region replacement must also suppress retained fallbacks.
local disabled=V.copy(changed);disabled.id='test.disabled';disabled.attachments={}
disabled._attachment_slots.first.body_region=false
local disabled_host=Host.new(session,Host.load(disabled,3,session));session.node=disabled
assert(disabled_host:prepare(session) and #created==5)
assert(session.retained_subsystems['attachment:test.large.first']==nil)
assert(session.retained_subsystems[other.key]==other and session.retained_subsystems[prop.key]==prop)

-- Live changes preserve every nonattachment context, including a running completion effect.
local contexts={}
for _,item in ipairs(disabled_host.items)do if item.engine.id~='attachment'then
 contexts[item.key]=item.context;item.context.running_completion=true
end end
local live=V.copy(node);live.id=disabled.id
local live_resources=Host.load(live,3,session)
assert(disabled_host:refresh_appearance(live_resources)==disabled_host);session.node=live
assert(disabled_host:prepare(session)and #created==6)
for _,item in ipairs(disabled_host.items)do if item.engine.id~='attachment'then
 assert(item.context==contexts[item.key]and item.context.running_completion,'Appearance changes restarted a nonattachment engine')
end end
disabled_host:enter_appearance();assert(#entered==3)
local live_original=session.retained_subsystems['attachment:test.original.first']
local revised=V.copy(live);revised.attachments['test.original.first'].mesh='small'
local revised_resources=Host.load(revised,3,session);restore_failure='original'
assert(not pcall(disabled_host.refresh_appearance,disabled_host,revised_resources))
assert(session.retained_subsystems[live_original.key]==live_original and not live_original.restored and #created==6)
disabled_host:refresh_appearance(revised_resources);session.node=revised
assert(disabled_host:prepare(session)and #created==7)
disabled_host:refresh_appearance(Host.load(live,3,session));session.node=live
assert(disabled_host:prepare(session)and #created==8)
assert(session.retained_subsystems[other.key]==other and session.retained_subsystems[prop.key]==prop)
disabled_host:restore();disabled_host:restore()
assert(#restored==#created,'Every created component must be restored exactly once')
print('Attachment selection lifecycle passed: deferred retirement, independent owners, stable reuse, missing assets, retryable replacement cleanup, explicit none, retained props and idempotent Exit.')
