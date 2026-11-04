package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
inzoi={EB1GenderType={Male=1,Female=2},EB1BodyAgeType={Adult=1},EB1GrowthStep={Youth=32,Adult=64},cli={execute=function()error('B1 traits must never call a B2-authority CLI command')end}}
package.loaded['SceneZOI.ExpressionNative']={body=function(person)return person.actor.mesh_body or person.body end}
local T=require('SceneZOI.Traits')
local actor={GetEntityId=function()return{Value=7}end,Mesh={GetSkeletalMeshAsset=function()return{GetName=function()return 'BodyAsset'end}end},AppearanceComponent={AppearanceSetting={Gender=1,BodyAgeType=1,GrowthStep=32}}}
local traits=T.capture(actor);assert(traits.id=='7'and traits.body=='male'and traits.mesh_name=='BodyAsset')
assert(T.matches({body='male',body_age='Adult',growth_steps={'Youth'}},traits))
assert(not T.matches({body='female'},traits)and not T.matches({growth_steps={'Adult'}},traits))
actor.mesh_body='female';assert(T.capture(actor).body=='female','Resolved skeletal body wins over fallback gender')
assert(T.matches({body_age='Adult',growth_steps={'Youth'}},{body_age='EB1BodyAgeType::Adult',growth_step='EB1GrowthStep::Youth'}))
print('B1 traits passed: direct appearance fields, native/string enums, skeletal-body preference, no B2 commands and declarative compatibility.')
