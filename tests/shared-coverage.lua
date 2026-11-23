-- The neutral region adapter is available with only SceneZOI enabled.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local J=require('SceneZOI.Json')
local f=assert(io.open('packs/scenezoi/profiles/male_crotch.json','rb'))
local raw=f:read('*a');f:close();local profile=J.decode(raw)
assert(not raw:find('HZoi_660649D8',1,true))
local compiled=require('SceneZOI.ProfileData').compile({by_kind={body_profile={{owner='scenezoi',source='male_crotch',data=profile}}}})
assert(#compiled.warnings==0 and compiled.body['scenezoi.male_crotch'])
assert(not next(compiled.rules)and not next(compiled.material),
 'Providing neutral coverage must not add anatomy, material matching or automatic attachment rules')
require('SceneZOI.Profiles').set(compiled)
local stock='/SceneZOI_93C44199/Compatibility/StockCoveragePatch.StockCoveragePatch'
local fitted='/SceneZOI_93C44199/Compatibility/ZoiBitsMaleCoveragePatch.ZoiBitsMaleCoveragePatch'
assert(profile.patch_mesh==stock and profile.section==17 and profile.coverage_bit==17)
local path='/NaturalSkin_B5AE5C0D/Mesh/SKM_Male_Base_NS.SKM_Male_Base_NS'
assert(profile.patch_mesh_overrides[path]==fitted)
local native={GetName=function()return 'SKM_Male_Base'end}
local zoibits={GetName=function()return 'SKM_Male_Base_NS'end}
local assets={[stock]={},[fitted]={},[path]=zoibits}
UE={UObject={Load=function(p)assert(not p:find('HZoi_660649D8',1,true));return assets[p]end}}
local Body=require('SceneZOI.BodyRegion')
local a,selection=Body.load(profile.id,native);assert(a==assets[stock]and selection.reason=='default_unlisted_body')
local b,matched=Body.load(profile.id,zoibits);assert(b==assets[fitted]and matched.reason=='body_mesh_override')
assert(not compiled.body['hzoi.body_layout'],'No old profile alias is retained')
print('Shared coverage passed: framework-only registration, neutral assets, stock/ZoiBits selection and no automatic anatomy.')
