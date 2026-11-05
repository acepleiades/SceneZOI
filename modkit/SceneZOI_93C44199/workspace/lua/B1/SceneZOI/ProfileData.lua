local V=require('SceneZOI.DataValidation')
local M={}
local function body(v)
 V.fields(v,{'schema_version','id','section','coverage_bit','full_coverage_exception','patch_mesh','patch_material_slot','morph'},{'schema_version','id','section','coverage_bit','patch_mesh','patch_material_slot'})
 assert(v.schema_version==2,'Unsupported body profile version');V.id(v.id)
 V.number(v.section,0,255,true);V.number(v.coverage_bit,0,31,true)
 V.asset(v.patch_mesh);V.name(v.patch_material_slot)
 if v.morph then V.name(v.morph)end
 if v.full_coverage_exception~=nil then V.boolean(v.full_coverage_exception)end
end
local function material(v)
 V.fields(v,{'schema_version','id','source_material','skin_slot','hair_slot','skin_parameter','hair_parameter','chromophore_parameter','source_skin_parameter','source_chromophore_parameter','source_hair_parameter'},{'schema_version','id','source_material','skin_slot','hair_slot','skin_parameter','hair_parameter','chromophore_parameter','source_skin_parameter','source_chromophore_parameter','source_hair_parameter'})
 assert(v.schema_version==1,'Unsupported material profile version');V.id(v.id);V.number(v.source_material,0,255,true)
 for _,key in ipairs({'skin_slot','hair_slot','skin_parameter','hair_parameter','chromophore_parameter','source_skin_parameter','source_chromophore_parameter','source_hair_parameter'})do V.name(v[key])end
 assert(v.skin_slot~=v.hair_slot,'Material targets must be distinct')
end
local function rule(v)
 V.fields(v,{'schema_version','id','body','mesh_name','body_age','growth_steps','section','attachment','node_animations','legacy_layers'},{'schema_version','id','body','section','attachment'})
 assert(v.schema_version==1,'Unsupported exposure rule version');V.id(v.id)
 assert(v.body=='male'or v.body=='female','Unsupported rule body');V.number(v.section,0,255,true)
 if v.mesh_name then V.name(v.mesh_name)end
 if v.body_age then V.name(v.body_age)end
 if v.growth_steps then V.array(v.growth_steps,16);for _,x in ipairs(v.growth_steps)do V.name(x)end end
 local a=v.attachment
 V.fields(a,{'mesh','socket','reference_bone','body_profile','material_profile','retain_for_session'},{'mesh','socket','reference_bone','body_profile'})
 V.asset(a.mesh);V.name(a.socket);V.name(a.reference_bone);V.id(a.body_profile)
 if a.material_profile then V.id(a.material_profile)end
 if a.retain_for_session~=nil then V.boolean(a.retain_for_session)end
 assert(V.object(v.node_animations or {}),'Expected node animation map')
 for id,path in pairs(v.node_animations or {})do V.id(id);V.asset(path)end
 if v.legacy_layers then V.array(v.legacy_layers,16);for _,id in ipairs(v.legacy_layers)do V.name(id)end end
end
function M.compile(snapshot)
 local result={body={},material={},rules={},warnings={}}
 for _,entry in ipairs({{'body_profile','body',body},{'material_profile','material',material},{'coverage_attachment','rules',rule}})do
  for _,doc in ipairs(snapshot.by_kind[entry[1]]or {})do
   local ok,err=pcall(function()
    entry[3](doc.data);local id=doc.data.id;local previous=result[entry[2]][id]
    assert(not previous or V.equal(previous,doc.data),'Conflicting profile ID: '..id)
    result[entry[2]][id]=V.copy(doc.data)
   end)
   if not ok then result.warnings[#result.warnings+1]=doc.source..': '..tostring(err)end
  end
 end
 for id,spec in pairs(result.rules)do
  local profile=result.body[spec.attachment.body_profile]
  if not profile or profile.section~=spec.section or(spec.attachment.material_profile and not result.material[spec.attachment.material_profile])then
   result.warnings[#result.warnings+1]='Unavailable or mismatched exposure profile: '..id;result.rules[id]=nil
  end
 end
 return result
end
M.validate_body=body;M.validate_material=material;M.validate_rule=rule
return M
