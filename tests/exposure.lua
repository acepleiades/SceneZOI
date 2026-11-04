package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local V=require('SceneZOI.DataValidation')
local Profiles=require('SceneZOI.Profiles');Profiles.set({body={['test.region']={section=5,coverage_bit=5}},material={},rules={}})
local captures=0
package.loaded['SceneZOI.Traits']={capture=function(actor)captures=captures+1;return actor.traits end,matches=function(requirement,traits)return requirement.body==traits.body end}
local created,destroyed=0,0
local A={load=function(node)return node.attachment.mesh,nil,nil end,
 prepare=function(ctx,actor)if not ctx.attachment then created=created+1;ctx.attachment={actor=actor}end;ctx.attachment.hidden=ctx.hide_attachment;return true end,
 ready=function()return true end,enter=function()end,sample=function()end,guard=function()end,
 restore=function(ctx)if ctx.attachment then destroyed=destroyed+1;ctx.attachment=nil end end,status=function()return 'test'end}
package.loaded['SceneZOI.Attachment']=A
local noop={prepare=function()return true end,ready=function()return true end,enter=function()end,sample=function()end,guard=function()end,leave_node=function()end,restore=function()end,status=function()return'test'end,load=function()return {}end}
for _,name in ipairs({'Gaze','Expressions','Sfx','Voices'})do package.loaded['SceneZOI.'..name]=noop end
local Host=require('SceneZOI.Subsystems')
local function owner(id,role,body)
 local garments={Top={BodyFlags=1<<5},Bottom={BodyFlags=0}}
 function garments:ToTable()return {Top=self.Top,Bottom=self.Bottom}end
 return {id=id,role=role,body=body,removed_slots={},actor={traits={body=body},AppearanceComponent={AppearanceSetting={FinalStyle={Outfit={Garments=garments}}}}}},garments
end
local first,g1=owner('1','first','male');local second,g2=owner('2','second','male');local third,g3=owner('3','third','female')
local node={id='test.hub',duration=3,anchor_participant='first',participants={first={body='male'},second={body='male'},third={body='female'}},tracks={first='a',second='b',third='c'},attachments={}}
for _,role in ipairs({'first','second','third'})do node.attachments['test.rule.'..role]={participant=role,mesh='/Test/Prop.Prop',socket='root',reference_bone='root',body_profile='test.region',when_undressed=true,retain_for_session=true,_condition={body='male'},retained_tracks={}}end
local session={node=node,duration=3,participants={first,second,third},bindings={first=first,second=second,third=third},retained_subsystems={}}
local host=Host.new(session,Host.load(node,3));assert(created==0,'Conditional rules must wait for actual owner compatibility')
assert(host:prepare(session)and created==0,'Covered regions must not create attachments')
assert(host:keep_body_unmerged(first,node,session.bindings)and not host:keep_body_unmerged(third,node,session.bindings))
g1.Top.BodyFlags=0
assert(host:prepare(session)and created==1,'A manual top edit exposing bit 5 must activate the matching rule without full undressing')
assert(host:prepare(session)and created==1,'Repeated preparation must not duplicate components')
g2.Top.BodyFlags=0;g3.Top.BodyFlags=0
assert(host:prepare(session)and created==2,'Repeated matching bodies need independently owned attachments; incompatible bodies must be excluded')
local a=session.retained_subsystems['attachment:test.rule.first'];local b=session.retained_subsystems['attachment:test.rule.second']
assert(a.owner_id=='1'and b.owner_id=='2'and a.context.attachment~=b.context.attachment)
g1.Top.BodyFlags=1<<5;assert(host:prepare(session));assert(a.context.attachment.hidden and not b.context.attachment.hidden)
local nextnode=V.copy(node);nextnode.id='test.other';nextnode.attachments={}
session.node=nextnode;local nextHost=Host.new(session,Host.load(nextnode,3,session));assert(nextHost:prepare(session)and created==2,'Retained static fallback must preserve both components across unknown nodes')
nextHost:restore();nextHost:restore();assert(destroyed==2 and captures==3,'Independent cleanup and cached compatibility traits must be stable')
print('Exposure rules passed: arbitrary section 5, resolved garment coverage, first manual activation, actual-body filtering, repeated owners, visibility, static retention and idempotent cleanup.')
