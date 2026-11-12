package.path='modkit/SceneZOI_93C44199/workspace/lua/B2/?.lua;'..package.path
local shown,cleared={},{}
inzoi={EB1BaseObject={Self=1,Target=2},FB2Script_SpeechBubble={
 Execute_AddSpeechBubble=function(context,execute)shown[#shown+1]={'speech',context,execute}end,
 Execute_AddInnerThoughtIcon=function(context,execute)shown[#shown+1]={'thought',context,execute}end,
 Execute_RemoveInnerThoughtIcon=function(context)cleared[#cleared+1]={'thought',context.SelfEntityId.Value}end,
 Execute_RemoveSpeechBubble=function(context,execute)cleared[#cleared+1]={'speech',context.SelfEntityId.Value,execute.S1}end,
},FB2ScriptContext=function(self,target)return {SelfEntityId=self,TargetEntityId=target}end,FB1Execute=function()return {}end,EB1ScriptReason={Interaction=1}}
local Members=require('SceneZOI.SceneMembers')
local hook=require('Scripts.B2Script_SpeechBubble')
local function id(value)return {Value=value}end
local function context(self,target)return {SelfEntityId=id(self),TargetEntityId=id(target)}end
local self_bubble,target_bubble={BaseObject=1,S1='Bubble'},{BaseObject=2,S1='Bubble'}
local function count(run)local before=#shown;run();return #shown-before end
-- Nobody in a scene: every bubble passes through with its original arguments.
local ctx=context(10,20)
assert(count(function()hook.Override_Execute_AddSpeechBubble(ctx,self_bubble)end)==1)
assert(shown[#shown][1]=='speech'and shown[#shown][2]==ctx and shown[#shown][3]==self_bubble,'The original call keeps its arguments')
assert(count(function()hook.Override_Execute_AddInnerThoughtIcon(ctx,self_bubble)end)==1)
assert(shown[#shown][1]=='thought')
-- Joining a scene takes down what was already showing: the thought icon, and the last speech bubble by name.
hook.Override_Execute_AddSpeechBubble(ctx,{BaseObject=1,S1='Earlier'})
Members.add(id(10))
assert(#cleared==2 and cleared[1][1]=='thought'and cleared[1][2]==10,'A thought icon is cleared on joining')
assert(cleared[2][1]=='speech'and cleared[2][2]==10 and cleared[2][3]=='Earlier','The last speech bubble is cleared by name')
Members.remove(id(10));Members.add(id(10))
assert(#cleared==3,'A speech bubble is only cleared once')
-- A scene participant goes without, for both kinds.
assert(count(function()hook.Override_Execute_AddSpeechBubble(ctx,self_bubble)end)==0,'Participant speech bubble')
assert(count(function()hook.Override_Execute_AddInnerThoughtIcon(ctx,self_bubble)end)==0,'Participant thought icon')
-- The owner is whichever Zoi the command names: a bystander addressing a participant keeps theirs.
assert(count(function()hook.Override_Execute_AddSpeechBubble(context(20,10),self_bubble)end)==1,'Bystander speaks to a participant')
assert(count(function()hook.Override_Execute_AddSpeechBubble(context(20,10),target_bubble)end)==0,'Bubble placed on the participant target')
assert(count(function()hook.Override_Execute_AddSpeechBubble(ctx,target_bubble)end)==1,'Bubble placed on the bystander target')
-- Several scenes at once, and ids given in any form.
Members.add('30');assert(Members.has(30)and Members.has(id(30)))
assert(count(function()hook.Override_Execute_AddInnerThoughtIcon(context(30,0),self_bubble)end)==0,'Participant of another scene')
-- Leaving the scene brings them back.
Members.remove(id(10))
assert(count(function()hook.Override_Execute_AddSpeechBubble(ctx,self_bubble)end)==1,'Released participant')
-- A malformed context must not cost the game its bubble.
assert(count(function()hook.Override_Execute_AddSpeechBubble({},self_bubble)end)==1,'Failed lookup passes through')

-- The participant lease is what fills the list.
package.loaded['SceneZOI.Config']={lease_timeout=6}
for _,name in ipairs{'SceneZOI.Outfit','SceneZOI.Wardrobe','SceneZOI.SaveGuard','SceneZOI.SaveRecovery','SceneZOI.Binding'}do
 package.loaded[name]=setmetatable({},{__index=function()return function()end end})
end
package.loaded['SceneZOI.Json']={decode=function()return {id='node',participants={female={}}}end}
package.loaded['SceneZOI.SceneData']={simulation=function(node)return node end}
UE={FVector=function(x,y,z)return {X=x,Y=y,Z=z}end,FRotator=function(p,y,r)return {Pitch=p,Yaw=y,Roll=r}end}
inzoi.EB2ComponentType={Appearance=1,Autonomy=2,Interaction=3,Posture=4}
inzoi.EB1GenderType={Male=1,Female=2}
inzoi.cli={execute=function()return true,'',''end}
inzoi.message={send_to_client=function()end}
local moved=false
local owner={}
local option={Value=true,bFollowParent=false}
function owner:GetEntityId()return id(77)end
function owner:GetComponent(kind)
 if kind==inzoi.EB2ComponentType.Appearance then return {GetAppearanceSetting=function()return {Gender=2}end}end
 if kind==inzoi.EB2ComponentType.Posture then return nil end
 return {OnAutonomyOptionChanged=function()end,SendAutonomyEnablePacket=function()end}
end
function owner:GetAutonomyOption()return {AutonomyEnable=option}end
owner.AutonomyOption={AutonomyEnable=option}
function owner:RefreshAutonomyOptionCache()end
function owner:IsAutonomyEnable()return true end
function owner:GetLocation()return {X=1,Y=2,Z=3}end
function owner:GetRotation()return {Pitch=0,Yaw=0,Roll=0}end
function owner:IsCollisionEnabled()return true end
function owner:SetCollisionEnabled()end
function owner:SetLocationAndRotationOnlySimul()moved=true end
local Character=require('Zoi.SceneZOI')
local Protocol=require('SceneZOI.Protocol')
local script={}
Character.on_begin(script,owner)
assert(not Members.has(77))
Character.on_lua_message(script,owner,'SceneZOI.Prepare',Protocol.pack('t1','77','node',1,'0','female',Protocol.encode('{}')))
assert(script.lease and Members.has(77),'A held Zoi is listed from preparation')
Character.on_lua_message(script,owner,'SceneZOI.Release',Protocol.pack('t1','restore'))
assert(not script.lease and not Members.has(77),'A released Zoi is removed')
assert(moved,'Release ran')
print('Speech bubbles passed: participants withheld across scenes, bystanders untouched, per-owner targeting and lease membership.')
