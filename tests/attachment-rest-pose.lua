package.path=(TEST_ROOT or "modkit/SceneZOI_93C44199/workspace/lua/").."B1/?.lua;"..package.path
local Math = require("SceneZOI.GazeMath")
local warnings = {}
package.loaded["SceneZOI.Diagnostics"] = {
    record=function(event, fields) assert(event == "attachment_rest_pose_warning"); warnings[#warnings+1] = fields end,
    detail=tostring,
}

local function vector(x,y,z) return {X=x or 0,Y=y or 0,Z=z or 0} end
local function quat(x,y,z,w) return {X=x or 0,Y=y or 0,Z=z or 0,W=w or 1} end
local function transform(q, z) return {Rotation=q or quat(), Translation=vector(0,0,z), Scale3D=vector(1,1,1)} end
local function compose(local_pose, parent)
    return transform(Math.multiply(parent.Rotation, local_pose.Rotation), local_pose.Translation.Z+parent.Translation.Z)
end
local function near(a,b) return math.abs(a-b)<1e-7 end
local function yaw(transform, degrees)
    local half = math.rad(degrees)/2
    return near(transform.Rotation.Z,math.sin(half)) and near(transform.Rotation.W,math.cos(half))
end

local bones = {"root", "Anchor", "base", "tip"}
local parents = {root="None", Anchor="root", base="Anchor", tip="base"}
local function rest(index) return transform(quat(),index) end
local function component_pose(mesh, bone)
    local transform = mesh.locals[bone] or mesh:GetRefPoseTransform(mesh:GetBoneIndex(bone))
    local parent = parents[bone]
    return parent == "None" and transform or compose(transform,component_pose(mesh,parent))
end
local function component(kind)
    local c = {kind=kind, locals={}, bHiddenInGame=true}
    function c:SetHiddenInGame(hidden) self.bHiddenInGame=hidden end
    function c:SetCollisionEnabled(value) assert(value == 0) end
    function c:SetGenerateOverlapEvents(value) assert(not value) end
    function c:SetSimulatePhysics(value) assert(not value) end
    function c:PrestreamTextures() end
    function c:SetSkeletalMeshAsset(asset) assert(self.kind=="skeletal"); self.asset=asset end
    function c:GetSkeletalMeshAsset() assert(self.kind=="skeletal"); return self.asset end
    function c:SetSkinnedAssetAndUpdate(asset,reset) assert(self.kind=="poseable" and reset); self.asset=asset end
    function c:GetSkinnedAsset() assert(self.kind=="poseable"); return self.asset end
    function c:GetBoneIndex(name)
        for index, bone in ipairs(bones) do if name:lower() == bone:lower() then return index-1 end end
        return -1
    end
    function c:GetBoneName(index) return bones[index+1] end
    function c:GetParentBone(name) return parents[name] end
    function c:GetRefPoseTransform(index) return rest(index) end
    function c:GetSocketTransform(name,space) assert(name=="Anchor" and space==2); return component_pose(self,name) end
    function c:GetBoneTransformByName(name,space) assert(self.kind=="poseable" and space==1); return component_pose(self,name) end
    function c:SetBoneTransformByName(name, pose, space)
        assert(self.kind=="poseable" and space==1 and name~="root" and name~="Anchor")
        local parent = component_pose(self,parents[name])
        self.locals[name] = transform(Math.multiply(Math.inverse(parent.Rotation),pose.Rotation), pose.Translation.Z-parent.Translation.Z)
    end
    function c:ResetBoneTransformByName(name) self.locals[name]=nil end
    function c:K2_AttachToComponent(mesh, socket) assert(socket=="Anchor"); self.parent=mesh; return true end
    function c:K2_SetRelativeTransform(offset) self.offset=offset end
    function c:AddTickPrerequisiteComponent() end
    function c:GetNumBones() return #bones end
    function c:GetNumMaterials() return 1 end
    function c:GetMaterial() return {} end
    function c:SetAnimationMode(mode) assert(self.kind=="skeletal" and mode==1) end
    function c:GetAnimationMode() return 1 end
    function c:SetPlayRate(rate) assert(rate==0) end
    function c:SetPosition(position) self.position=position end
    function c:GetAnimInstance() return {} end
    function c:PlayAnimation(animation) self.animation=animation end
    function c:SetAnimation(animation) assert(not animation);self.animation=nil;self.cleared=true end
    function c:K2_DestroyComponent() assert(not self.destroyed);self.destroyed=true end
    return c
end

local function class(kind)
    return {StaticClass=function() return kind end}
end
UE = {USkeletalMeshComponent=class("skeletal"),UPoseableMeshComponent=class("poseable"),
    FTransform=transform, FQuat=quat, UKismetMathLibrary={ComposeTransforms=compose,
        InvertTransform=function(t) return transform(Math.inverse(t.Rotation), -t.Translation.Z) end}}
local actor = {Mesh={GetBoneIndex=function() return 1 end},
    AppearanceComponent={AppearanceSetting={FinalStyle={Outfit={Garments={}}}}}}
function actor:AddComponentByClass(kind)
    return component(kind)
end

local Attachment = require("SceneZOI.Attachment")
local clip = {}
local spec = {mesh="/Test/Attachment.Attachment", socket="Anchor", reference_bone="Anchor", participant="lead"}
local session = {node={id="test.animated", attachment=spec, attachment_id="test.rule.lead"},
    attachment_asset={}, attachment_animation=clip, defer_visibility=true, scene_revision=1}

local function prepare()
    for _ = 1, 8 do
        if Attachment.prepare(session,actor) and Attachment.ready(session) then return end
    end
    error("The attachment did not become ready")
end
local function move(id, animation, rotations)
    session.scene_revision=session.scene_revision+1
    session.node.id, session.attachment_animation = id, animation
    session.node.attachment_rest_rotations = rotations and {lead={["test.rule.lead"]=rotations}}
    prepare()
end

prepare()
Attachment.enter(session)
local animated = session.attachment.component
Attachment.sample(session, .9)
assert(animated.animation == clip and not animated.bHiddenInGame and not Attachment.preview(session))

move("test.preview", nil)
local posed = session.pending_attachment.component
assert(posed.kind=="poseable" and posed.bHiddenInGame and not animated.bHiddenInGame and animated.position==.9)
assert(not Attachment.preview(session), "Preview must wait until entry")
Attachment.enter(session)
assert(animated.destroyed and not posed.bHiddenInGame and next(posed.locals)==nil)
local preview = assert(Attachment.preview(session))
assert(preview.mesh == spec.mesh and #preview.bones==2 and preview.bones[1]=="base" and preview.bones[2]=="tip")
assert(next(preview.rotations)==nil and posed.offset.Translation.Z==-1)

assert(not Attachment.preview_rotation(session,"anchor",{0,0,30}))
assert(not Attachment.preview_rotation(session,"ROOT",{0,0,30}))
assert(not Attachment.preview_rotation(session,"missing",{0,0,30}))
assert(not Attachment.preview_rotation(session,"base",{0,0,181}))
assert(warnings[1].detail:find("move the attachment off its anchor",1,true))
assert(Attachment.preview_rotation(session,"Base",{0,0,30}))
assert(Attachment.preview_rotation(session,"tip",{0,0,20}))
assert(Attachment.preview_rotation(session,"base",{0,0,30}))
assert(yaw(posed.locals.base,30) and yaw(posed.locals.tip,20))
assert(yaw(component_pose(posed,"tip"),50),"Two edited levels must compose once in each bone's local space")
assert(Attachment.preview(session).rotations.base[3]==30)
posed.bHiddenInGame=true
assert(not Attachment.preview(session), "A covered mesh must not be editable")
local hidden = assert(Attachment.preview(session,true))
assert(hidden.hidden and hidden.rotations.base[3]==30 and hidden.rotations.tip[3]==20,
    "Export must still be able to read a covered mesh's committed edits")
assert(not Attachment.preview_rotation(session,"base",{0,0,99}) and yaw(posed.locals.base,30))
posed.bHiddenInGame=false
Attachment.enter(session)
assert(yaw(posed.locals.base,30),"Entering for a same-revision outfit change lost the preview")
assert(Attachment.preview_rotation(session,"tip",nil) and not posed.locals.tip)
assert(Attachment.preview(session).rotations.tip==nil)

move("test.authored", nil, {base={0,0,-28}, Anchor={0,0,65}})
assert(session.attachment.component == posed and yaw(posed.locals.base,30),"Preparing the next scene changed the outgoing pose")
Attachment.enter(session)
assert(yaw(posed.locals.base,-28) and not posed.locals.Anchor and not Attachment.preview(session))
assert(not Attachment.preview_rotation(session,"base",{0,0,60}))

move("test.empty_angles", nil, {})
Attachment.enter(session)
assert(next(posed.locals)==nil and Attachment.preview(session),
    "An empty bone map must leave the mesh at rest and allow preview")

move("test.animated", clip, {tip={0,0,90}})
local again = session.pending_attachment.component
assert(again.bHiddenInGame and not posed.bHiddenInGame)
Attachment.enter(session)
assert(posed.destroyed and again.animation==clip and not Attachment.preview(session))
move("test.rest",nil)
local final = session.pending_attachment.component
Attachment.enter(session)
assert(next(final.locals)==nil and again.destroyed,"Returning to an unposed node carried previous bone offsets")
move("test.pending",clip)
local pending = session.pending_attachment.component
Attachment.restore(session)
assert(final.destroyed and pending.destroyed,"Exit during warm-up must clean up both owned components")

UE.UPoseableMeshComponent = nil
move("test.fallback_clip",clip)
Attachment.enter(session)
local fallback = session.attachment.component
move("test.fallback_rest",nil)
Attachment.enter(session)
assert(session.attachment.component==fallback and fallback.cleared and not fallback.animation and not Attachment.preview(session))
Attachment.restore(session)

UE.UPoseableMeshComponent = class("poseable")
session.node.attachment_id, session.attachment_pose_unavailable = nil, nil
move("test.dynamic_effect",nil)
Attachment.enter(session)
assert(session.attachment.component.kind=="skeletal" and not Attachment.preview(session),
    "A dynamic add-on effect without an authored identity should use ordinary skeletal rest")
Attachment.restore(session)

print("Attachment rest poses passed: staged mode changes, reference anchor, local offsets, preview, authored precedence, reset, fallback and cleanup.")
