local root=TEST_ROOT or "modkit/SceneZOI_93C44199/workspace/lua/"
package.path=root.."B1/?.lua;"..package.path
local Math=require("SceneZOI.GazeMath")
local function near(a,b) assert(math.abs(a-b)<0.00001,tostring(a).." vs "..tostring(b)) end
local limit={Pitch=17,Roll=5}
local p,r=Math.angles({X=0,Y=0,Z=1},limit);near(p,0);near(r,0)
p,r=Math.angles({X=1,Y=0,Z=1},limit);near(p,-17);near(r,0)
p,r=Math.angles({X=-1,Y=-1,Z=1},limit);near(p,17);near(r,-5)
p,r=Math.angles({X=1,Y=1,Z=-1},limit);near(p,-17);near(r,5)
p,r=Math.angles({X=0,Y=0,Z=0},limit);near(p,0);near(r,0)

local created,restored,fail_restore,unavailable,samples=0,{},false,false,{}
local Native={eyes={"L","R"}}
function Native.bind(owner) return not unavailable and {head=owner.actor,limit=limit} or nil end
function Native.capture(owner) created=created+1;return {entry=owner.id} end
function Native.target(binding,spec)
    assert(binding and spec.bones[1]~="missing","Missing target bone")
    return binding.actor.target
end
function Native.direction(record,eye,target) return target end
function Native.rotation(_,pitch,roll) return {Pitch=pitch,Roll=roll,Yaw=0} end
function Native.apply(owner,eye,rotation) samples[owner.id]=rotation end
function Native.restore(owner,original)
    assert(original.entry==owner.id,"Captured an intermediate snapshot")
    if owner.id=="2" and fail_restore then fail_restore=false;error("retry cleanup") end
    restored[owner.id]=(restored[owner.id] or 0)+1
end
package.loaded["SceneZOI.GazeNative"]=Native
local Gaze=require("SceneZOI.Gaze")
local people={}
for i=1,3 do people[i]={id=tostring(i),actor={target={X=i,Y=1,Z=1}}} end
local session={participants=people,bindings={a=people[1],b=people[2],c=people[3]}}
local ctx={node={gaze={a={participant="b",bones={"eyes"}},b={participant="a",bones={"eyes"}},c={participant="c",bones={"shoulder"}}}}}
assert(Gaze.prepare(ctx,session));Gaze.enter(ctx)
assert(created==3 and samples["1"].Pitch==-17 and samples["3"].Roll==5)
people[2].actor.target={X=-0.01,Y=0,Z=1};Gaze.sample(ctx)
assert(samples["1"].Pitch>0 and samples["1"].Pitch<1,"Target must follow the moving bone")
local outgoing=samples["1"].Pitch
Gaze.leave_node(ctx)
assert(samples["1"].Pitch==outgoing,"Leaving a node must retain its outgoing gaze")
local outgoingBindings=session.bindings;session.bindings=nil
session.preparing=true;ctx.node={};assert(Gaze.prepare(ctx,session));Gaze.guard(ctx)
assert(samples["1"].Pitch==outgoing,"Preparation must not insert a forward gaze")
people[2].actor.target={X=-.02,Y=0,Z=1};Gaze.guard(ctx)
assert(samples["1"].Pitch>outgoing,"Outgoing gaze must keep following its target while preparing")
session.bindings=outgoingBindings;Gaze.enter(ctx);session.preparing=false
assert(created==3,"Node change recaptured original eye state")
for _,v in pairs(samples) do assert(v.Pitch==0 and v.Roll==0,"Missing gaze must look forward") end
ctx.node={gaze={c={participant="c",bones={"shoulder"}}}};Gaze.leave_node(ctx);Gaze.prepare(ctx,session);Gaze.enter(ctx)
assert(samples["3"].Pitch==-17 and samples["1"].Pitch==0,"Self target must not leak to another participant")
package.loaded['SceneZOI.FacialPoseLibrary']={owns_eyes=function(id)return id=='example.eyes'end}
ctx.node.expressions={a={facial_pose='example.eyes'}}
local before_eye_restore=restored['1']or 0
Gaze.sample(ctx);assert(restored['1']==before_eye_restore+1,'Fixed eyes did not release procedural gaze')
local previous=samples['1'];Gaze.sample(ctx);assert(samples['1']==previous,'Suppressed gaze continued writing')
ctx.node.expressions=nil;session.expressions={owners={['1']={fixed_targets={FACIAL_L_Eye={}}}}}
Gaze.sample(ctx);assert(samples['1']==previous,'Gaze resumed before old fixed eye entries were released')
session.expressions=nil;Gaze.sample(ctx);assert(samples['1']~=previous,'Released fixed pose did not restore gaze')
restored['1']=nil
unavailable=true;assert(Gaze.prepare(ctx,session)==false);unavailable=false
session.preparing=true;Gaze.guard(ctx);assert(created==4,"Appearance recovery changed entry snapshot")
fail_restore=true;assert(not pcall(Gaze.restore,ctx));Gaze.restore(ctx)
for i=1,3 do assert(restored[tostring(i)]==1,"Cleanup must retry only failed participants") end
local count=ctx.samples;Gaze.sample(ctx);Gaze.guard(ctx);assert(ctx.samples==count,"Exit retained gaze control")
print("Gaze: multi-participant/self targets, moving targets, limits, forward defaults, refresh and retryable exit passed")
