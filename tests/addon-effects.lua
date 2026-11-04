package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local Control=require('SceneZOI.AddonControl')
local calls,failed={},{}
package.loaded['SceneZOI.Attachment']={
 load=function(node)return node.attachment.mesh,nil,node.attachment.animation end,
 prepare=function(ctx,actor)ctx.attachment=ctx.attachment or {component={SetHiddenInGame=function()end}};calls[actor]=(calls[actor]or 0)+1;return true end,
 ready=function()return true end,enter=function()end,sample=function()end,
 restore=function(ctx)if failed[ctx.attachment_asset]then error('injected cleanup failure')end;ctx.attachment=nil end}
local Effects=require('SceneZOI.AddonEffects')
local s={participants={{id='1',role='a',actor='one'},{id='2',role='b',actor='two'}},duration=3,node={kind='loop'},clock={position=function()return 0 end}}
Control.init(s);Control.layer(s,'first');Control.layer(s,'second')
local function attach(key,id,mesh)
 return Effects.attach(s,key,{participant_id=id,effect_id='prop',attachment={mesh=mesh,socket='pelvis',reference_bone='pelvis'}})
end
attach('first','1','/Test/One.One');attach('second','2','/Test/Two.Two')
s.preparing=true;Effects.tick(s,.1);assert(not calls.one)
s.preparing=false;Effects.tick(s,.1);assert(calls.one==1 and calls.two==1)
assert(Effects.snapshot(s,'first').attachments[1].phase=='active')
failed['/Test/One.One']=true;Effects.release(s,'first');assert(Effects.snapshot(s,'first').attachments[1].phase=='releasing')
Effects.release(s,'second');assert(#Effects.snapshot(s,'second').attachments==0,'One cleanup failure cannot block another owner')
assert(not pcall(Effects.restore,s));Effects.retain(s);failed['/Test/One.One']=nil;Effects.idle();assert(next(s.addon_attachments)==nil,'Idle retry retains timed-out cleanup ownership')
Control.layer(s,'first');attach('first','1','/Test/Three.Three');Control.release(s,'first');Effects.tick(s,.1);assert(next(s.addon_attachments)==nil,'Caller expiry retires attachments')
Control.layer(s,'first');Effects.attach(s,'first',{participant_id='1',effect_id='animated',attachment={mesh='/Test/Animated.Animated',socket='pelvis',reference_bone='pelvis',animation='/Test/Clip.Clip'}})
s.duration=4;Effects.tick(s,.1);assert(#Effects.snapshot(s,'first').errors==1,'Incompatible navigation reports a retained diagnostic')
Effects.tick(s,.1);assert(next(s.addon_attachments)==nil)
Control.layer(s,'first');attach('first','1','/Test/Gone.Gone');Effects.tick(s,.1)
UE={UKismetSystemLibrary={IsValid=function()return false end}}
failed['/Test/Gone.Gone']=true;assert(pcall(Effects.restore,s)and next(s.addon_attachments)==nil,'Destroyed native components retire without endless invalid-object retries')
print('Add-on attachment ownership: preparation holds, isolated owners, release failures, timeout orphan retention/idle retry, expiry and incompatible-animation diagnostics passed.')
