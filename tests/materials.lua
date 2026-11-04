local root=TEST_ROOT or "modkit/SceneZOI_93C44199/workspace/lua/"
package.path=root.."B1/?.lua;"..package.path
assert(loadfile("tests/support/profiles.lua"))()
local function color(r,g,b) return {R=r,G=g,B=b,A=1} end
local function map(entries)
    entries=entries or {}
    function entries:Find(name) return self[name] end
    function entries:ToTable()
        local result={}
        for k,v in pairs(self) do if type(v)~="function" then result[k]=v end end
        return result
    end
    return entries
end
local reference=color(.3762620091,.1980690062,.1169710010)
local chromophore=color(.3762620091,.2158609927,.1470270008)
local function material(value,is_dynamic)
    local m={value=value,writes=0,dynamic=is_dynamic~=false}
    function m:IsA() return self.dynamic end
    function m:K2_GetVectorParameterValue(name) return self.parameters and self.parameters[name] or self.value end
    function m:SetVectorParameterValue(name,value)
        self.writes=self.writes+1;self[name]=value
    end
    return m
end
UE={FLinearColor=color,UMaterialInstanceDynamic={StaticClass=function() return {} end}}
local real=require("SceneZOI.MaterialMatch")
local Color=setmetatable({ready=function(a,b)return real.ready(a,b,"test.colors")end},{__index=real})
local function fixture()
    local skin=material(reference)
    skin.parameters={["Chromophore Contribution"]=chromophore}
    local body={mesh={GetMaterial=function(_,slot) assert(slot==17);return skin end}}
    local hair={VectorParameters=map({TipColor=color(.1,.2,.3)}),OverrideVectorParameters=map()}
    local actor={AppearanceComponent={AppearanceSetting={FinalHead={Hair=hair}},NamedComponents=map()}}
    local component={created={},slots={MatchedSkin=0,MatchedHair=1},original={material(color(1,1,1)),material(color(0,0,0))}}
    function component:GetMaterialIndex(name) return self.slots[name] or -1 end
    function component:GetMaterial(slot) return self.original[slot+1] end
    function component:CreateDynamicMaterialInstance(slot,source)
        assert(source==self.original[slot+1],"Instantiate the mesh-assigned material without substituting an asset");local mid=material(color(0,0,0))
        self.created[slot+1]=mid;return mid
    end
    return {actor=actor,component=component},body,skin,hair
end
local function close(a,b) assert(math.abs(a-b)<1e-6,tostring(a).." != "..tostring(b)) end
local a,b,source,hair=fixture()
source.value=color(0/0,.1,.2)
assert(not Color.ready(a,b) and not a.color,"Invalid skin input must not create materials")
source.value=reference
source.dynamic=false
assert(not Color.ready(a,b) and not a.color,"An uninstalled skin MID must not create color instances")
source.dynamic=true;hair.VectorParameters.TipColor=nil
assert(not Color.ready(a,b) and not a.color,"Missing hair appearance must block readiness")
hair.VectorParameters.TipColor=color(.1,.2,.3)
hair.OverrideVectorParameters.TipColor=color(0,0,0)
assert(not Color.ready(a,b));assert(Color.ready(a,b))
assert(a.color.hair.HairColor.R==0 and a.color.hair_source=="override","Explicit black must override other colors")
assert(a.color.skin.SkinTint.R==reference.R and source.writes==0,"Pass resolved linear tone without modifying the body")
close(a.color.skin.SkinChromophore.G,chromophore.G)
assert(a.component.original[1].writes==0 and a.component.original[2].writes==0,"Never modify shared attachment materials")
local count=a.color.skin.writes
assert(Color.ready(a,b) and a.color.skin.writes==count,"Stable colors should not create/rewrite instances each frame")
hair.OverrideVectorParameters.TipColor=color(.4,.2,.1)
assert(not Color.ready(a,b),"Color changes during preparation must reset readiness")
assert(Color.ready(a,b));close(a.color.hair.HairColor.R,.4)
source.value=color(reference.R*.5,reference.G*.5,reference.B*.5)
assert(not Color.ready(a,b));assert(Color.ready(a,b));close(a.color.skin.SkinTint.R,reference.R*.5)
local a2,b2=fixture()
assert(not Color.ready(a2,b2));assert(Color.ready(a2,b2))
assert(a2.color.skin~=a.color.skin and a2.color.hair~=a.color.hair,"Sessions need independent instances")
close(a2.color.skin.SkinTint.R,reference.R)
source.parameters["Chromophore Contribution"]=color(.3,.2,.1)
assert(not Color.ready(a,b));assert(Color.ready(a,b));close(a.color.skin.SkinChromophore.R,.3)
assert(Color.status(a):find("hair_source=override",1,true))

-- Reported live case: a retained attachment survives a male outfit rebuild,
-- while BodyRegion has temporarily cleared its mesh and old skin patch.
local held_skin,held_hair=a.color.skin,a.color.hair
local old_mesh=b.mesh
b.mesh=nil
assert(not Color.ready(a,b) and a.color.frames==0,"An unfinished body rebuild must wait without indexing a missing mesh")
assert(a.color.skin==held_skin and a.color.hair==held_hair,"Waiting must preserve the attachment's material instances")
b.mesh=old_mesh
assert(not Color.ready(a,b));assert(Color.ready(a,b),"Matching must warm up again after the body returns")
assert(not Color.ready(a,nil));assert(not Color.ready(a,{}))
assert(a.color.frames==0)
assert(not Color.ready(a,b));assert(Color.ready(a,b))

-- Missing appearance-map defaults can come from the actual applied hair material.
local fallback,fb,_,fh=fixture()
fh.VectorParameters.TipColor=nil
local applied=material(color(.6,.3,.2))
fallback.actor.AppearanceComponent.NamedComponents=map({Hair={GetMaterial=function() return applied end}})
assert(not Color.ready(fallback,fb));assert(Color.ready(fallback,fb))
close(fallback.color.hair.HairColor.R,.6);assert(fallback.color.hair_source=="material")
assert(applied.writes==0)
local invalid,ib=fixture()
invalid.component.slots.MatchedSkin=nil
assert(not pcall(Color.ready,invalid,ib),"A changed material-slot layout must fail explicitly")
local partial,pb=fixture()
function partial.component:CreateDynamicMaterialInstance(slot)
    if slot==0 then return material(color(1,1,1)) end
end
assert(not pcall(Color.ready,partial,pb))
assert(partial.color and partial.color.skin,"Partial creation must remain owned by the attachment for cleanup")
local unsupported,ub,us=fixture()
us.parameters["Chromophore Contribution"]=color(0,0,0)
assert(not pcall(Color.ready,unsupported,ub),"Zero normalization denominators must fail explicitly")
print("Color checks passed: mesh-assigned material instances, direct linear skin/chromophore inputs, delayed sources, overrides/black, hair fallback, isolated MIDs, readiness resets and partial failure.")
