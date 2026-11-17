package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
package.loaded['SceneZOI.ClothingCoverage']={compatible_body=function()return true end}
local V=require('SceneZOI.DataValidation')
local assets={}
local function asset(path,length)
 assets[path]={GetName=function()return path:match('%.(.*)$')end,GetPlayLength=function()return length end};return path
end
UE={UObject={Load=function(path)return assets[path]end}}
inzoi={cli={execute=function()return true end}}
package.loaded['SceneZOI.Diagnostics']={record=function()end,catalog_changed=function()end}
package.loaded['SceneZOI.Traits']={capture=function(actor)return actor.traits end,
 matches=function(value,traits)return not value.body or value.body==traits.body end}
local scene={id='pack.scene',label='Scene',kind='loop',duration=3,fps=60,
 participants={lead={body='male'},other={body='female'}},anchor_participant='lead',
 tracks={lead=asset('/Test/Male.Male',3),other=asset('/Test/Female.Female',3)},navigation={},
 appearance={lead={body_variant='pack.body',attachment_variants={body_region='pack.part'}}}}
local body={schema_version=1,id='pack.body',label='Body',body='male',mesh=asset('/Test/Body.Body')}
local attachment={schema_version=1,id='pack.part',label='Part',body='male',
 attachment={mesh=asset('/Test/Part.Part'),socket='pelvis',reference_bone='pelvis',body_profile='region',retain_for_session=true},
 node_animations={['pack.scene']=asset('/Test/PartTrack.PartTrack',3)}}
local prop={schema_version=1,id='pack.prop',label='Prop',attachment={mesh=asset('/Test/Prop.Prop'),socket='head',reference_bone='root'}}
local profile={schema_version=2,id='region',section=5,coverage_bit=5,patch_mesh=asset('/Test/Patch.Patch'),patch_material_slot='skin'}
local rule={schema_version=1,id='legacy.part',body='male',section=5,
 attachment={mesh=asset('/Test/Legacy.Legacy'),socket='pelvis',reference_bone='pelvis',body_profile='region'},node_animations={}}
local function document(data)return {owner='pack',source=data.id,data=data}end
local source={by_kind={scene_pack={document({schema_version=3,id='pack',nodes={scene},extensions={}})},
 body_variant={document(body)},attachment_variant={document(prop),document(attachment)},
 body_profile={document(profile)},coverage_attachment={document(rule)}}}
package.loaded['SceneZOI.DataFiles']={get=function()return source end}
local Catalog=require('SceneZOI.Catalog')
local snapshot=Catalog.refresh(true)
assert(snapshot.variants.bodies['pack.body']and snapshot.variants.attachments['pack.part'])
local public=Catalog.public_node(snapshot.nodes['pack.scene'])
assert(V.equal(public.appearance,scene.appearance),'Public scene lookup must expose its authored appearance defaults')
public.appearance.lead.body_variant=false
assert(snapshot.nodes['pack.scene'].appearance.lead.body_variant=='pack.body','Public scene data must be a copy')
local preview=Catalog.get('pack.scene')
assert(preview._body_variants.lead.id=='pack.body'and preview._attachment_slots.lead.body_region=='pack.part.lead')
assert(preview.attachments['pack.part.lead'].animation==attachment.node_animations['pack.scene'])
assert(not snapshot.nodes['pack.scene'].attachments and not snapshot.nodes['pack.scene']._attachment_slots,
 'Resolving a scene must not mutate the cached declarations')
local participants={{id='11',role='lead',body='male',traits={body='male'}},{id='22',role='other',body='female',traits={body='female'}}}
local explicit={['11']={body_variant=false,attachment_variants={body_region=false,tongue='pack.prop'}}}
local current={participants=participants,appearance_selections=explicit}
local resolved=Catalog.get('pack.scene',current)
assert(not resolved._body_variants.lead and resolved._attachment_slots.lead.body_region==false)
assert(resolved._attachment_slots.lead.tongue=='pack.prop.lead'and not resolved.attachments['pack.part.lead'])
Catalog.resolve_appearance(preview,participants,explicit)
assert(not preview._body_variants.lead and preview._attachment_slots.lead.body_region==false,
 'The initial pre-roster copy can be resolved again after actual participants are captured')
local all=Catalog.variants()
assert(#all.bodies==1 and #all.attachments==3 and all.attachments[1].id=='legacy.part'and all.attachments[2].id=='pack.part'and all.attachments[3].id=='pack.prop')
assert(all.attachments[1].automatic_fallback and all.attachments[1].provider=='pack')
assert(all.bodies[1].provider=='pack'and not all.bodies[1]._owner)
assert(all.attachments[2].node_animations['pack.scene']==attachment.node_animations['pack.scene'])
all.bodies[1].mesh='changed';all.attachments[2].attachment.mesh='changed'
assert(snapshot.variants.bodies['pack.body'].mesh==body.mesh and snapshot.variants.attachments['pack.part'].attachment.mesh==attachment.attachment.mesh)
assert(#Catalog.variants('female').bodies==0 and #Catalog.variants('female').attachments==1,
 'Body-filtered public arrays preserve generic props and exclude incompatible variants')
assert(not pcall(Catalog.variants,'unknown'))
current.appearance_selections['11'].attachment_variants.body_region='legacy.part'
resolved=Catalog.get('pack.scene',current)
assert(resolved._attachment_slots.lead.body_region=='legacy.part.lead')
source.by_kind.body_variant[#source.by_kind.body_variant+1]=document({schema_version=1,id='bad',body='male',mesh=body.mesh})
source.by_kind.coverage_attachment[#source.by_kind.coverage_attachment+1]=document({schema_version=1,id='z.foreign',body='male',section=5,
 attachment={mesh='/Missing/Foreign.Foreign',socket='pelvis',reference_bone='pelvis',body_profile='region'},
 node_animations={['pack.scene']='/Missing/Clip.Clip'}})
source.by_kind.scene_pack[1].data.nodes[1].hide_if_tracks_missing=true
snapshot=Catalog.refresh(true)
assert(#snapshot.variants.warnings==1 and #snapshot.warnings>=1,'Invalid variants are diagnosed without discarding valid scene data')
assert(snapshot.nodes['pack.scene'],'Unchosen foreign fallback assets cannot prune a scene with valid authored tracks')
assets[attachment.node_animations['pack.scene']]=nil
resolved=Catalog.get('pack.scene')
assert(resolved._attachment_slots.lead.body_region=='pack.part.lead'and not resolved.attachments['pack.part.lead'].animation,
 'The selected provider remains selected when its optional mapped clip is missing')
print('Variant catalog passed: registry compilation, warnings, scene/API resolution, post-capture resolution, public sorted metadata, body filtering and copied declarations.')
