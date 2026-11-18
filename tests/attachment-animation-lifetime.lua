-- Lua can retain a userdata whose native animation was collected during preparation.
package.path = "modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;" .. package.path
local diagnostics, assets, loads = {}, {}, {}
package.loaded["SceneZOI.Diagnostics"] = {detail=tostring, record=function(name, fields)
    assert(name == "attachment_animation_failed")
    diagnostics[#diagnostics + 1] = fields
end}
package.loaded["SceneZOI.BodyRegion"] = {restore=function() end}
package.loaded["SceneZOI.MaterialMatch"] = {}
local animation_class = {}
UE = {UObject={Load=function(path)
    loads[path] = (loads[path] or 0) + 1
    return assets[path]
end}, UAnimationAsset={StaticClass=function() return animation_class end},
    UKismetSystemLibrary={IsValid=function(object) return object ~= nil and object.alive ~= false end}}
local Attachment = require("SceneZOI.Attachment")

local function clip(length)
    local value = {alive=true,length=length}
    function value:IsA(kind) assert(self.alive, "Collected native animation"); return kind == animation_class end
    function value:GetPlayLength() assert(self.alive, "Collected native animation"); return self.length end
    return value
end

local function component(animation, hidden)
    local value = {alive=true,animation=animation,position=.75,hidden=hidden,starts=0}
    function value:PlayAnimation(asset, looping)
        assert(asset.alive and looping, "bad argument #1 to 'PlayAnimation' (object needed but got nil or incompatible value)")
        if self.fail_play then error("Injected native PlayAnimation failure") end
        self.animation, self.starts = asset, self.starts + 1
    end
    function value:SetPlayRate(rate) assert(rate == 0) end
    function value:SetPosition(position, notify) assert(not notify); self.position=position end
    function value:GetAnimInstance() return {} end
    function value:SetHiddenInGame(hidden) self.hidden=hidden end
    function value:K2_DestroyComponent() assert(not self.destroyed); self.destroyed=true end
    return value
end

local mesh_path, animation_path = "/Test/Attachment.Attachment", "/Test/Incoming.Incoming"
assets[mesh_path], assets[animation_path] = {}, clip(2)
local node = {id="test.incoming", attachment_id="test.attachment", attachment={participant="lead",
    mesh=mesh_path,animation=animation_path}}
local mesh, _, stale, duration = Attachment.load(node, 2)
local previous = clip(2)
local outgoing = component(previous, false)
local context = {node=node,attachment_asset=mesh,attachment_animation=stale,attachment_duration=duration,
    participants={{id="40",role="lead"}},scene_revision=2,scene_session={token="test.session"},
    attachment={component=outgoing,actor={},animation=previous,position=.75}}
assert(not node.duration and duration == 2, "Add-on contexts need the validated scalar without a scene duration")

-- The incoming asset has no native owner yet. Its old wrapper stays truthy.
stale.alive = false
local fresh = clip(2)
assets[animation_path] = fresh
Attachment.change_animation(context)
assert(outgoing.animation == fresh and outgoing.starts == 1 and outgoing.position == 0)
assert(context.attachment_animation == fresh and context.attachment.animation == fresh and loads[animation_path] == 2)
Attachment.change_animation(context)
assert(outgoing.starts == 1 and loads[animation_path] == 2, "A held native clip must not restart or reload every update")

local function fail_incoming(replacement, expected_detail, stage)
    local cached = clip(2)
    context.scene_revision = context.scene_revision + 1
    context.attachment_animation = cached
    cached.alive, assets[animation_path] = false, replacement
    outgoing.position, context.attachment.position = .75, .75
    local starts, count = outgoing.starts, #diagnostics
    local ok, err = pcall(Attachment.change_animation, context)
    assert(not ok and tostring(err):find(expected_detail, 1, true), tostring(err))
    assert(outgoing.animation == fresh and outgoing.position == .75 and outgoing.starts == starts,
        "A rejected incoming clip changed the outgoing native pose")
    local report = diagnostics[#diagnostics]
    assert(#diagnostics == count + 1 and report.scene_id == node.id and report.attachment_id == "test.attachment")
    assert(report.session_id == "test.session" and report.participant_role == "lead" and report.participant_id == "40")
    assert(report.animation == animation_path and report.expected_duration == 2 and report.stage == stage)
    assert(report.component_valid == true and report.cached_animation_valid == false and report.revision == context.scene_revision)
    assert(not pcall(Attachment.change_animation, context) and #diagnostics == count + 1,
        "Repeated failure on one handoff must still fail, without duplicate diagnostics")
end

fail_incoming(nil, "Scene attachment animation is unavailable", "resolve_animation")
fail_incoming({IsA=function()return false end}, "Expected an attachment animation asset", "resolve_animation")
fail_incoming(clip(3), "Attachment and participant animation durations differ", "resolve_animation")
outgoing.fail_play = true
fail_incoming(clip(2), "Injected native PlayAnimation failure", "play_animation")
outgoing.fail_play = nil
Attachment.restore(context)
Attachment.restore(context)
assert(outgoing.destroyed, "Failure must retain component ownership for ordinary cleanup")

-- A staged poseable-to-animated handoff keeps the old component visible until
-- the hidden replacement has a verified native-owned clip.
local held = component(nil, false)
local pending = component(nil, true)
context.attachment = {component=held,actor={},poseable=true}
context.pending_attachment = {component=pending,actor={},poseable=false}
context.attachment_animation = clip(2)
context.scene_revision = context.scene_revision + 1
assets[animation_path] = nil
assert(not pcall(Attachment.enter, context))
assert(context.attachment.component == held and not held.hidden and not held.destroyed and pending.hidden,
    "Failed incoming resolution hid or replaced the outgoing component")
fresh = clip(2)
assets[animation_path] = fresh
Attachment.enter(context)
assert(context.attachment.component == pending and pending.animation == fresh and pending.starts == 1)
assert(held.hidden and held.destroyed and not pending.hidden and not context.pending_attachment)
Attachment.restore(context)
assert(pending.destroyed)
print("Attachment animation lifetime passed: fresh native ownership, retained pose, missing/type/duration/native failures, deduplicated provenance and pending-component cleanup.")
