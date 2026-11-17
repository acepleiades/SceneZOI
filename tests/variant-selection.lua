package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local V=require('SceneZOI.DataValidation')
package.loaded['SceneZOI.ClothingCoverage']={compatible_body=function()return true end}
local warnings,events={},{}
package.loaded['SceneZOI.Diagnostics']={record=function(name,fields)
 if name=='appearance_variant_warning'then warnings[#warnings+1]=fields else events[#events+1]={name=name,fields=fields}end
 fields.event=name -- The real diagnostic writer stamps its supplied table.
end}
package.loaded['SceneZOI.Traits']={capture=function(actor)return V.copy(actor.traits)end,
 matches=function(spec,traits)
  for _,key in ipairs({'body','mesh_name','body_age'})do if spec[key]and spec[key]~=traits[key]then return false end end
  if spec.growth_steps then
   local found=false;for _,step in ipairs(spec.growth_steps)do if step==traits.growth_step then found=true end end
   if not found then return false end
  end
  return true
 end}
local assets={}
local skeleton={}
UE={UObject={Load=function(path)return assets[path]end}}
local function mesh(path,name)assets[path]={GetName=function()return name or path end,GetSkeleton=function()return skeleton end};return path end
local function track(path,length)assets[path]={GetPlayLength=function()return length end};return path end
local patch=mesh('/Test/Patch.Patch')
local profiles={body={region={section=5,patch_mesh=patch}},material={matched={}},rules={}}
local function attachment(path,body,region)
 return {id=path,body=body,attachment={mesh=mesh(path),socket='pelvis',reference_bone='pelvis',
  body_profile=region and 'region' or nil,material_profile=region and 'matched' or nil,retain_for_session=true},
  node_animations={}}
end
profiles.rules['z.rule']=attachment('z.rule','male',true)
profiles.rules['a.rule']=attachment('a.rule','male',true)
local variants={bodies={['pack.body']={id='pack.body',body='male',mesh=mesh('/Test/Body.Body','base')},
 ['pack.female']={id='pack.female',body='female',mesh=mesh('/Test/Female.Female')}},attachments={}}
variants.attachments['pack.large']=attachment('pack.large','male',true)
variants.attachments['pack.small']=attachment('pack.small','male',true)
variants.attachments['pack.prop']=attachment('pack.prop',nil,false)
variants.attachments['pack.missing']=attachment('pack.missing','male',true);assets['pack.missing']=nil
variants.attachments['pack.teen']=attachment('pack.teen','male',true);variants.attachments['pack.teen'].growth_steps={'Teen'}
local clip=track('/Test/Clip.Clip',3)
variants.attachments['pack.large'].node_animations['test.scene']=clip
local function scene()
 return {id='test.scene',duration=3,participants={lead={body='male'},other={body='male'}},
  attachments={keep={participant='lead',mesh=mesh('/Test/Keep.Keep'),socket='hand_l',reference_bone='root'}}}
end
local actors={
 {id='11',role='lead',body='male',actor={traits={body='male',mesh_name='base',growth_step='Adult'},saved_body='native'}},
 {id='22',role='other',body='male',actor={traits={body='male',mesh_name='base',growth_step='Adult'},saved_body='native'}},
}
for _,owner in ipairs(actors)do owner.actor.Mesh={GetSkeletalMeshAsset=function()return {GetSkeleton=function()return skeleton end}end}end
local Selection=require('SceneZOI.VariantSelection')
local default=Selection.resolve(scene(),actors,nil,profiles,variants)
assert(default._attachment_slots.lead.body_region=='a.rule.lead'and
 default._attachment_slots.other.body_region=='a.rule.other','Coverage fallback must pick one deterministic provider per owner')
assert(default.attachments['a.rule.lead']and not default.attachments['z.rule.lead']and default.attachments.keep)
assert(default.attachments['a.rule.lead']._selection_slot=='body_region'and default.attachments['a.rule.lead'].when_undressed)

local node=scene();node.appearance={lead={body_variant='pack.body',attachment_variants={body_region='pack.small',prop='pack.prop'}}}
Selection.resolve(node,actors,{['11']={attachment_variants={body_region='pack.large'}}},profiles,variants)
assert(node._body_variants.lead.id=='pack.body'and node._attachment_slots.lead.body_region=='pack.large.lead')
assert(node.attachments['pack.large.lead'].animation==clip and node.attachments['pack.large.lead'].retained_tracks[node.id]==clip)
assert(node._attachment_slots.lead.prop=='pack.prop.lead'and not node.attachments['pack.prop.lead'].when_undressed)
assert(node._attachment_slots.other.body_region=='a.rule.other'and not node.attachments['pack.small.lead'])
assert(actors[1].actor.saved_body=='native','Resolving selection must not edit the appearance saved by the game')

Selection.resolve(node,actors,{['11']={body_variant=false,attachment_variants={body_region=false,prop=false}}},profiles,variants)
assert(not node._body_variants.lead and node._attachment_slots.lead.body_region==false and node._attachment_slots.lead.prop==false)
assert(not node.attachments['pack.large.lead']and not node.attachments['a.rule.lead']and node.attachments.keep)

Selection.resolve(node,actors,{['11']={body_variant='pack.female',attachment_variants={body_region='pack.missing'}}},profiles,variants)
assert(node._body_variants.lead.id=='pack.body'and node._attachment_slots.lead.body_region=='pack.small.lead',
 'Invalid explicit choices must preserve valid scene defaults')
assert(#warnings==2 and warnings[1].participant_id=='11'and warnings[2].variant_id=='pack.missing')

local inline=scene();inline.attachments.old={participant='lead',mesh=mesh('/Test/Old.Old'),socket='pelvis',reference_bone='pelvis',body_profile='region'}
inline.appearance={lead={attachment_variants={body_region='pack.teen'}}}
Selection.resolve(inline,actors,nil,profiles,variants)
assert(inline._attachment_slots.lead.body_region=='old'and not inline.attachments['a.rule.lead'],
 'Scene inline replacement remains above the legacy fallback when a named selection is unavailable')
Selection.resolve(inline,actors,{['11']={attachment_variants={body_region='pack.large'}}},profiles,variants)
assert(not inline.attachments.old and inline.attachments.keep and inline.attachments['pack.large.lead'])
Selection.resolve(inline,actors,{['11']={attachment_variants={body_region=false}}},profiles,variants)
assert(not inline.attachments.old and inline._attachment_slots.lead.body_region==false)
Selection.resolve(inline,actors,nil,profiles,variants)
assert(inline.attachments.old and inline._attachment_slots.lead.body_region=='old',
 'Resolving again for actual actors must restore original declarations before choosing')

local invalid=scene();invalid.appearance={lead={attachment_variants={body_region='pack.prop',tongue='pack.large'}}}
Selection.resolve(invalid,actors,nil,profiles,variants)
assert(invalid._attachment_slots.lead.body_region=='a.rule.lead'and invalid._attachment_slots.lead.tongue==false,
 'Body masking ownership cannot silently move into an unrelated prop slot')
local missing_profile=attachment('pack.profile','male',true);missing_profile.attachment.body_profile='missing'
variants.attachments['pack.profile']=missing_profile
invalid.appearance.lead.attachment_variants.body_region='pack.profile'
Selection.resolve(invalid,actors,nil,profiles,variants)
assert(invalid._attachment_slots.lead.body_region=='a.rule.lead')
variants.attachments['pack.large'].node_animations['test.scene']=track('/Test/Wrong.Wrong',7)
invalid.appearance.lead.attachment_variants.body_region='pack.large'
Selection.resolve(invalid,actors,nil,profiles,variants)
assert(invalid._attachment_slots.lead.body_region=='pack.large.lead'and not invalid.attachments['pack.large.lead'].animation,
 'An invalid optional track keeps the selected mesh at rest instead of choosing a different provider')

-- A mesh-specific legacy default is safe only for the captured and selected body.
local restricted_profiles=V.copy(profiles);restricted_profiles.rules['a.rule'].mesh_name='base'
local custom=scene();custom.appearance={lead={body_variant='pack.body'}}
assets['/Test/Body.Body'].GetName=function()return 'custom'end
Selection.resolve(custom,actors,nil,restricted_profiles,variants)
assert(custom._attachment_slots.lead.body_region=='z.rule.lead',
 'A native-mesh-specific default cannot be forced onto a different temporary body')
assert(custom._attachment_slots.other.body_region=='a.rule.other')
local alien=V.copy(variants.bodies['pack.body']);alien.id='pack.alien';alien.mesh=mesh('/Test/Alien.Alien')
assets[alien.mesh].GetSkeleton=function()return {}end;variants.bodies[alien.id]=alien
Selection.resolve(custom,actors,{['11']={body_variant='pack.alien'}},restricted_profiles,variants)
assert(custom._body_variants.lead.id=='pack.body','An incompatible selected skeleton must preserve the valid scene body')
local warned=#warnings
Selection.resolve(custom,actors,{['11']={body_variant='pack.alien'}},restricted_profiles,variants)
assert(#warnings==warned,'Repeated catalog resolution must not flood identical warnings')
Selection.resolve(default,actors,nil,profiles,variants)
local current={token='test.session',node=default,revision=1,participants=actors}
Selection.report(current);assert(#events==4 and events[1].name=='appearance_resolved'and events[2].name=='appearance_fallback_conflict')
assert(events[2].fields.winner=='a.rule'and #events[2].fields.compatible_declarations==2)
Selection.report(current);assert(#events==4,'Stable selection reporting must be idempotent')
current.revision=2;Selection.report(current);assert(#events==8,'New scene revision must retain its own resolved-selection diagnostic')
local implicit=scene();Selection.resolve(implicit,actors,{['11']={attachment_variants={body_region='z.rule'}}},profiles,variants)
assert(implicit._attachment_slots.lead.body_region=='z.rule.lead','Current coverage declarations are selectable by their registered ID')
-- Layout compatibility is independent of the Skeleton asset: preserving native
-- clothing coverage must be possible before a preferred replacement is chosen.
local Coverage=package.loaded['SceneZOI.ClothingCoverage']
local old_compatible=Coverage.compatible_body
local unsupported_path=mesh('/Test/UnsupportedBody.UnsupportedBody')
variants.bodies['pack.unsupported']={id='pack.unsupported',body='male',mesh=unsupported_path}
Coverage.compatible_body=function(actor,body)
    assert(actor==actors[1].actor)
    if body==assets[unsupported_path]then return false,'Unsupported native clothing region layout.'end
    return true
end
local layout_scene=scene();layout_scene.appearance={lead={body_variant='pack.body'}}
Selection.resolve(layout_scene,actors,{['11']={body_variant='pack.unsupported'}},profiles,variants)
assert(layout_scene._body_variants.lead.id=='pack.body',
    'An unsupported preferred body layout must fall through to the compatible scene body')
assert(warnings[#warnings].variant_id=='pack.unsupported'and warnings[#warnings].detail:find('clothing region layout',1,true))
layout_scene.appearance=nil
Selection.resolve(layout_scene,actors,{['11']={body_variant='pack.unsupported'}},profiles,variants)
assert(not layout_scene._body_variants.lead and actors[1].actor.saved_body=='native',
    'An unsupported optional layout with no scene body must preserve the native body')
Coverage.compatible_body=old_compatible
print('Appearance selection passed: API/scene/fallback order, independent owners, native/none choices, inline defaults, optional missing assets, life stages, supported clothing layouts, stable IDs, tracks, reserved mask ownership, repeat resolution and warnings.')
