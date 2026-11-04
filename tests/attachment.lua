local root=TEST_ROOT or "modkit/SceneZOI_93C44199/workspace/lua/"
package.path=root.."B1/?.lua;"..package.path
assert(loadfile("tests/support/profiles.lua"))()
local asset, material1, material2 = {}, {}, {}
local animation={GetPlayLength=function() return 2 end}
local idle_animation={GetPlayLength=function() return 3 end}
local animation_available, animation_length = true, 2
animation.GetPlayLength=function() return animation_length end
local animation_starts, seeks = 0, 0
local hidden, destroyed, attached, created = true, false, false, 0
local materials_ready = false
local function transform(x,y,z,yaw) return {x=x,y=y,z=z,yaw=yaw} end
local function compose(a,b)
    local c,s=math.cos(math.rad(b.yaw)),math.sin(math.rad(b.yaw))
    return transform(c*a.x-s*a.y+b.x,s*a.x+c*a.y+b.y,a.z+b.z,a.yaw+b.yaw)
end
local rest=transform(3,7,100,90)
local target=transform(20,-50,110,-45)
local component={}
function component:SetHiddenInGame(value) hidden=value;self.bHiddenInGame=value end
function component:SetCollisionEnabled(value) assert(value==0) end
function component:SetGenerateOverlapEvents(value) assert(not value) end
function component:SetSimulatePhysics(value) assert(not value) end
function component:SetSkeletalMeshAsset(value) self.asset=value end
function component:GetSkeletalMeshAsset() return self.asset end
function component:GetBoneIndex(name) assert(name=="pelvis");return 1 end
function component:SetAnimationMode(value) assert(value==1) end
function component:GetAnimationMode() return 1 end
function component:PlayAnimation(value,looping)
    assert((value==animation or value==idle_animation) and looping)
    if animation_starts==0 then assert(hidden,"Initialize the first animation before revealing the component") end
    self.animation=value;animation_starts=animation_starts+1
end
function component:SetPlayRate(value) assert(value==0);self.rate=value end
function component:SetPosition(value,notifies)
    assert(not notifies and self.rate==0,"Seeking must not run an independent clock or fire notifies")
    self.position=value;seeks=seeks+1
end
function component:GetPosition() return self.position end
function component:GetAnimInstance() return {} end
function component:GetSocketTransform(name,space)
    assert(name=="pelvis")
    if space==2 then return rest end
    return compose(compose(rest,self.relative),target)
end
function component:K2_AttachToComponent(parent,bone,location,rotation,scale,weld)
    assert(parent==self.expected_parent and bone=="pelvis")
    assert(location==0 and rotation==0 and scale==0 and not weld)
    attached=true;return true
end
function component:K2_SetRelativeTransform(value) self.relative=value end
function component:AddTickPrerequisiteComponent(parent) assert(parent==self.expected_parent) end
function component:PrestreamTextures() end
function component:GetNumBones() return 8 end
function component:GetNumMaterials() return 2 end
function component:GetMaterial(index) if not materials_ready then return nil end;return index==0 and material1 or material2 end
function component:K2_DestroyComponent() destroyed=true end
local parent={GetBoneIndex=function() return 1 end}
component.expected_parent=parent
-- A default underwear entry may actually be nude-body geometry; it must not block readiness.
local garments={Top={GarmentId="shirt"},InnerUnder={GarmentId="M_InnUnder02_001"}}
function garments:Find(kind) return self[kind] end
local actor={Mesh=parent,AppearanceComponent={AppearanceSetting={FinalStyle={Outfit={Garments=garments}}}}}
function actor:AddComponentByClass(_,manual,_,deferred)
    assert(manual and not deferred);created=created+1;return component
end
UE={
    UObject={Load=function(path)
        if path:find("inZOI_paired_motion_test_Anatomy",1,true) then return animation_available and animation or nil end
        return asset
    end},
    USkeletalMeshComponent={StaticClass=function() return {} end},
    FTransform=function() return transform(0,0,0,0) end,
    UKismetMathLibrary={InvertTransform=function(t)
        local c,s=math.cos(math.rad(-t.yaw)),math.sin(math.rad(-t.yaw))
        return transform(c*-t.x-s*-t.y,s*-t.x+c*-t.y,-t.z,-t.yaw)
    end},
}
local patch_ready=false
local color_ready=false
local current_covered,predicted_covered=false,false
package.loaded["SceneZOI.MaterialMatch"]={ready=function() return color_ready end,status=function() return "color_mock" end}
package.loaded["SceneZOI.BodyRegion"]={load=function() return {} end,prepare=function() return true end,guard=function() end,
    covered=function() return current_covered end,after_outfit=function() return predicted_covered end,
    ready=function() return patch_ready end,restore=function() end,status=function() return "patch_mock" end}
local anatomy=require("SceneZOI.Attachment")
local node={attachment={mesh="test_mesh",animation="inZOI_paired_motion_test_Anatomy",
    participant="male",socket="pelvis",reference_bone="pelvis",body_profile="test.region",
    material_profile="test.colors"},outfits={male={remove_slots={"Top","InnerUnder"}}}}
local loaded,patch,track=anatomy.load(node,2)
local session={node=node,attachment_asset=loaded,attachment_animation=track}
anatomy.prepare(session,actor)
assert(created==0,"Do not prepare against the old clothed appearance")
garments.Top.GarmentId="None"
anatomy.prepare(session,actor)
assert(created==1 and attached and hidden)
assert(animation_starts==1 and component.position==0)
assert(component.VisibilityBasedAnimTickOption==0 and not component.bEnableUpdateRateOptimizations)
assert(not anatomy.ready(session),"Missing materials must block readiness")
materials_ready=true
assert(not anatomy.ready(session),"Skin patch readiness must also block the pair")
patch_ready=true
assert(not anatomy.ready(session) and hidden,"Colors must be applied before revealing the attachment")
color_ready=true
assert(not anatomy.ready(session) and not hidden)
assert(not anatomy.ready(session))
assert(anatomy.ready(session))
for _,position in ipairs({0.1,1.9,0.02,1.5,0}) do
    anatomy.sample(session,position)
    assert(component.position==position and session.attachment.position==position)
end
for index=1,20 do
    target=transform(index*3,index*-7,110+index,index*13)
    local actual=component:GetSocketTransform("pelvis",0)
    assert(math.abs(actual.x-target.x)<1e-8 and math.abs(actual.y-target.y)<1e-8 and
        math.abs(actual.z-target.z)<1e-8 and math.abs(actual.yaw-target.yaw)<1e-8,
        "Anatomy pelvis did not cancel its authored bind offset")
end
local original_component=session.attachment.component
local original_offset=component.relative
session.attachment_animation=idle_animation
anatomy.change_animation(session)
assert(created==1 and not destroyed and session.attachment.component==original_component)
assert(component.relative==original_offset and component.animation==idle_animation)
assert(component.position==0 and session.attachment.ready_frames==0)
anatomy.change_animation(session)
assert(animation_starts==2,"Reapplying the current animation must be a no-op")
anatomy.sample(session,2.8);assert(component.position==2.8)
local refreshed_parent={GetBoneIndex=function() return 1 end}
actor.Mesh=refreshed_parent;component.expected_parent=refreshed_parent
assert(anatomy.prepare(session,actor))
assert(session.attachment.component==original_component and session.attachment.parent==refreshed_parent and component.relative==original_offset)
assert(component.position==2.8,"Reparenting must preserve the held attachment pose")
anatomy.restore(session)
anatomy.restore(session)
assert(destroyed and not session.attachment)
animation_available=false
assert(not pcall(anatomy.load,node,2),"A requested missing animation must fail before changing the Zois")
animation_available=true;animation_length=3
assert(not pcall(anatomy.load,node,2),"A mismatched anatomy duration must fail")
animation_length=2
local config=require("SceneZOI.Config")
node.attachment.animation=nil
loaded,patch,track=anatomy.load(node,2)
assert(not track,"An absent animation path should permit a static attachment")
session={node=node,attachment_asset=loaded}
anatomy.prepare(session,actor)
local before_seeks=seeks
anatomy.sample(session,0.5)
assert(seeks==before_seeks and animation_starts==2,"A static attachment must not initialize or seek an animation")
anatomy.restore(session)
print("Anatomy checks passed: frozen shared-time animation including wrap, hidden initialization, optional static track, missing/mismatched clips, readiness, inverse pelvis bind and cleanup.")

local neutral={node={},participants={}}
local mesh,patch,track=anatomy.load(neutral.node,3)
assert(not mesh and not patch and not track)
assert(anatomy.prepare(neutral,nil) and anatomy.ready(neutral))
anatomy.sample(neutral,1);anatomy.restore(neutral)
print("Optional attachment tests passed: neutral node creates/loads no attachment; animated and static tracks retain tested setup.")

-- Framework warm-up must not expose an incoming attachment before both bodies.
-- Retained animation stays at the outgoing pose until that same handoff.
node.attachment.animation="inZOI_paired_motion_test_Anatomy"
loaded,patch,track=anatomy.load(node,2)
session={node=node,attachment_asset=loaded,attachment_animation=track,defer_visibility=true}
hidden=true
anatomy.prepare(session,actor)
assert(not anatomy.ready(session) and hidden)
assert(not anatomy.ready(session) and hidden)
assert(anatomy.ready(session) and hidden,"A ready incoming attachment must remain hidden until the bodies switch")
anatomy.enter(session)
assert(not hidden and component.animation==animation and component.position==0)
anatomy.sample(session,1.8)
local old_starts=animation_starts
session.attachment_animation=idle_animation
assert(anatomy.ready(session) and component.animation==animation and component.position==1.8)
assert(animation_starts==old_starts,"Target readiness restarted the retained outgoing attachment")
anatomy.enter(session)
assert(component.animation==idle_animation and component.position==0 and animation_starts==old_starts+1)
anatomy.restore(session)
print("Attachment handoff passed: hidden first warm-up and retained outgoing pose until the coordinated body switch.")

node.attachment.when_undressed=true
session={node=node,attachment_asset=loaded,attachment_animation=track,defer_visibility=true}
anatomy.prepare(session,actor);anatomy.ready(session);anatomy.ready(session);anatomy.ready(session);anatomy.enter(session)
anatomy.sample(session,.75)
local before_starts,before_seeks=animation_starts,seeks
anatomy.begin_outfit(session,{actor=actor},{})
assert(not hidden and session.outfit_visibility_hold=="visible" and session.attachment.kept_visible_edits==1)
-- Simulate a native parent-visibility reset while the retained pose is held.
component:SetHiddenInGame(true)
anatomy.guard(session)
assert(not hidden and session.attachment.visibility_repairs==1 and component.position==.75)
current_covered=true;anatomy.guard(session);assert(hidden,"Unexpected resolved coverage must win over prediction")
current_covered=false;anatomy.guard(session);assert(not hidden)
assert(animation_starts==before_starts and seeks==before_seeks,"Visibility repair restarted playback")
anatomy.enter(session);assert(not session.outfit_visibility_hold)
predicted_covered=true
anatomy.begin_outfit(session,{actor=actor},{})
assert(hidden and session.outfit_visibility_hold=="hidden")
anatomy.guard(session);assert(hidden,"A covering edit must stay hidden even before its resolved appearance arrives")
session.hide_attachment=true;anatomy.enter(session);assert(hidden)
predicted_covered=false
anatomy.begin_outfit(session,{actor=actor},{})
assert(hidden,"An already hidden component must wait for the normal reveal barrier")
session.hide_attachment=false;anatomy.enter(session);assert(not hidden)
predicted_covered=nil
anatomy.begin_outfit(session,{actor=actor},{})
assert(hidden,"Unknown coverage must keep the conservative handoff")
anatomy.restore(session)
print("Selective outfit visibility passed: preserved exposure, native visibility repair, actual-coverage fallback, covering/unknown concealment and unchanged held playback.")

-- The same adapter can bind a separate skeleton to a current head component.
local head1={GetBoneIndex=function()return 1 end}
local head2={GetBoneIndex=function()return 1 end}
package.loaded['SceneZOI.GazeNative']={head=function()return actor.head end}
actor.head=head1;component.expected_parent=head1
node.attachment={participant='lead',component='head',socket='pelvis',reference_bone='pelvis',mesh='/Example/Tongue.Tongue'}
session={node=node,attachment_asset=asset,defer_visibility=true}
assert(anatomy.prepare(session,actor)==false and session.attachment.parent==head1)
local removed_parent
function component:RemoveTickPrerequisiteComponent(previous)removed_parent=previous end
actor.head=head2;component.expected_parent=head2
assert(anatomy.prepare(session,actor)and session.attachment.parent==head2 and removed_parent==head1,'Head replacement did not detach the old tick prerequisite')
anatomy.restore(session)
print('Head-component attachment: independent skeleton, replacement-head rebind and cleanup passed.')
