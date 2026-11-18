package.path="modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;"..package.path
local D=require("SceneZOI.WardrobeDiagnostics")
local garments={Bottom={GarmentId="None",MeshId="None"},Stockings={GarmentId="new_stockings",MeshId="stockings_mesh"}}
local component={GetName=function()return"Bottom"end,GetSkeletalMeshAsset=function()return{GetName=function()return"old_skirt_mesh"end}end,
    IsVisible=function()return true end,bHiddenInGame=false}
UE={USkeletalMeshComponent={StaticClass=function()return"skeletal"end}}
local participant={id="12",role="receiving",outfit_counter=3,
    outfit_items={piece1={key="Bottom",kind="garment",asset="old_skirt",expected_asset="None",enabled=false}},
    actor={AppearanceComponent={AppearanceSetting={FinalStyle={Outfit={Garments={ToTable=function()return garments end}}}}},
        K2_GetComponentsByClass=function()return{component}end}}
local current={token="session.test",node={id="scene.test"},revision=2}
local sample=D.sample(current,participant,"change")
assert(sample.items[1].captured=="old_skirt"and not sample.items[1].enabled)
assert(sample.client_garments.Bottom=="None"and sample.client_garments.Stockings=="new_stockings")
assert(sample.rendered_garments[1].mesh=="old_skirt_mesh"and sample.rendered_garments[1].visible)
assert(sample.stage=="change"and sample.outfit_counter==3 and sample.revision==2)
participant.actor={}
sample=D.sample(current,participant,"entry")
assert(sample.client_garments_unavailable and sample.rendered_garments_unavailable)
for i=1,40 do participant.outfit_items["piece"..i]={key="slot"..i}end
sample=D.sample(current,participant,"entry")
assert(sample.items_truncated and #sample.items==32)
print("Wardrobe diagnostics passed: captured intent, resolved garments, stale visible component evidence, unavailable reads and bounded snapshots.")
