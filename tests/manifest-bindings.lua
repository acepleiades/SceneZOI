-- Native exact-group dispatch can shadow wildcard bindings from other mods.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local Json=require('SceneZOI.Json')
local file=assert(io.open('modkit/SceneZOI_93C44199/workspace/lua/lua_manifest.json','rb'))
local manifest=Json.decode(file:read('*a'));file:close()
-- Verified through ModKit list_lua_binding_keys for B1 and B2 (2026-11-06).
local groups={'CompanyRoleNpc','Crowd','EventCrowd','ResidenceFamily','ServiceNpc','ShopNpc','SiteRoleNpc','StaticNpc'}
local expected={'Zoi.SceneZOI','Zoi.SceneZOIStarter'}
local function dispatch(ours,foreign,key)
    local registry={}
    for _,bindings in ipairs({ours,foreign})do
        for _,binding in ipairs(bindings)do
            if binding.type=='Zoi'then
                local list=registry[binding.key]or{};registry[binding.key]=list
                list[#list+1]=binding.script
            end
        end
    end
    return registry[key]or registry['*']or{}
end
for _,env in ipairs({'B1','B2'})do
    local bindings=assert(manifest.bindings[env]);local seen={}
    for _,binding in ipairs(bindings)do
        local id=binding.type..'/'..binding.key..'/'..binding.script
        assert(not seen[id],'Duplicate native binding: '..env..'/'..id);seen[id]=true
    end
    for _,key in ipairs(groups)do
        for _,foreign in ipairs({{},{{type='Zoi',key=key,script='Independent.GroupHandler'}}})do
            local selected=dispatch(bindings,foreign,key);local counts={}
            for _,script in ipairs(selected)do counts[script]=(counts[script]or 0)+1 end
            for _,script in ipairs(expected)do
                assert(counts[script]==1,env..'/'..key..' lost '..script..' when exact group shadows wildcard')
            end
            if #foreign>0 then assert(counts['Independent.GroupHandler']==1,'Do not displace another mod binding')end
        end
    end
    local fallback=dispatch(bindings,{},'FutureUnlistedGroup')
    for _,script in ipairs(expected)do
        local count=0;for _,name in ipairs(fallback)do if name==script then count=count+1 end end
        assert(count==1,'Retain wildcard fallback for native groups not explicitly declared')
    end
end
assert(manifest.chunkScripts.B2[1]=='Systems.B2ZoiGroupManager')
assert(manifest.chunkScripts.B2[2]=='Components.B2SlotComponent')
print('Manifest dispatch passed: exact/wildcard precedence, all eight groups in B1/B2, independent mod coexistence, single delivery and future-group fallback.')
