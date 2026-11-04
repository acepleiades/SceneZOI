local Face=require('SceneZOI.ExpressionNative')
local Protocol=require('SceneZOI.Protocol')
local M={}
local function short(value)return tostring(value or ''):match('([^:]+)$')end
function M.capture(actor)
 local setting=assert(actor.AppearanceComponent and actor.AppearanceComponent.AppearanceSetting,'Missing participant appearance')
 local gender=setting.Gender
 local fallback=gender==inzoi.EB1GenderType.Male and'male'or gender==inzoi.EB1GenderType.Female and'female'or nil
 local body=Face.body({actor=actor,body=fallback})
 local asset=actor.Mesh and actor.Mesh:GetSkeletalMeshAsset()
 return {body=body,growth_step=setting.GrowthStep,body_age=setting and setting.BodyAgeType,
  mesh_name=asset and asset:GetName(),id=Protocol.id(actor:GetEntityId())}
end
function M.matches(requirement,traits)
 if requirement.body and requirement.body~=traits.body then return false end
 if requirement.mesh_name and requirement.mesh_name~=traits.mesh_name then return false end
 if requirement.body_age then
  local equal=short(traits.body_age)==requirement.body_age
  if not equal and inzoi.EB1BodyAgeType then equal=traits.body_age==inzoi.EB1BodyAgeType[requirement.body_age]end
  if not equal then return false end
 end
 if requirement.growth_steps then
  local found=false;for _,name in ipairs(requirement.growth_steps)do if name==short(traits.growth_step)or(inzoi.EB1GrowthStep and traits.growth_step==inzoi.EB1GrowthStep[name])then found=true end end
  if not found then return false end
 end
 return true
end
return M
