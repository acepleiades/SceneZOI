package.path="modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;"..package.path
local instance={}
local Container=assert(loadfile("tests/support/containers.lua"))()
local map=Container.map({Top={GarmentId="original_shirt",BodyFlags=0},InnerUnder={GarmentId="base_body"}})
function map:Find(key) return self[key] end
local actor={Mesh={GetAnimInstance=function() return instance end},
    AppearanceComponent={AppearanceSetting={FinalStyle={Outfit={Garments=map}}}}}
local Appearance=require("SceneZOI.Appearance")
local participant={actor=actor,role="male"}
Appearance.capture(participant)
map.Top.BodyFlags=1 << 17
assert(participant.original_outfit_metadata.Top.flags==0 and participant.original_outfit_metadata.Top.asset=="original_shirt",
    "Outfit coverage metadata must be a plain-value snapshot")
map.Top.BodyFlags=0
local session={participants={participant},node={}}
assert(not Appearance.ready(session));assert(not Appearance.ready(session));assert(not Appearance.ready(session))
assert(Appearance.ready(session))
session.node={outfits={male={remove_slots={"Top","InnerUnder"}}}}
session.appearance_frames=0
assert(not Appearance.ready(session),"Old clothes cannot satisfy an undressing request")
map.Top.GarmentId="None"
assert(not Appearance.ready(session));assert(not Appearance.ready(session));assert(Appearance.ready(session))
session.node={};session.appearance_frames=0
assert(not Appearance.ready(session));assert(not Appearance.ready(session));assert(Appearance.ready(session))
assert(participant.removed_slots.Top,"Returning to a hub must preserve session undressing")
map.Top.GarmentId="original_shirt"
assert(not Appearance.ready(session),"Unexpected redressing must not open the scene readiness barrier")
map.Top.GarmentId="None"
instance={}
assert(not Appearance.ready(session));assert(not Appearance.ready(session));assert(not Appearance.ready(session))
assert(Appearance.ready(session))
print("Appearance tests passed: cumulative clothing state across hubs, base-body fallback and stable animation-instance barrier.")

-- The rear scene is the first node that undresses the female. The game's final
-- style restores default InnerTop/InnerUnder even after our layer clears them.
local female_instance={}
local female_garments=Container.map({Top={GarmentId="dress_top"},InnerTop={GarmentId="original_bra"},
    InnerUnder={GarmentId="original_underwear"}})
function female_garments:Find(slot) return self[slot] end
local female={id="npc_female",body="female",role="female",actor={
    Mesh={GetAnimInstance=function() return female_instance end},
    AppearanceComponent={AppearanceSetting={FinalStyle={Outfit={Garments=female_garments}}}}}}
Appearance.capture(female)
session={participants={female},node={outfits={female={remove_slots={"Top","InnerTop","InnerUnder"}}}}}
female_garments.Top.GarmentId="None"
female_garments.InnerTop.GarmentId="W_InnTop01_001"
female_garments.InnerUnder.GarmentId="W_InnUnder01_001"
for _=1,3 do assert(not Appearance.ready(session)) end
assert(Appearance.ready(session),"Normalized female underwear must not block rear-scene preparation")
session.node={};session.appearance_frames=0
for _=1,2 do assert(not Appearance.ready(session)) end
assert(Appearance.ready(session),"Female undressing must remain ready at a hub")
female_garments.Top.GarmentId="still_dressed"
assert(not Appearance.ready(session),"An actual outer garment must still block preparation")
assert(Appearance.status(session):find("Top=still_dressed",1,true),"Diagnostic must name the blocking garment")
female_garments.Top.GarmentId="None"
female_instance=nil
assert(not Appearance.ready(session),"Underwear normalization must not bypass animation-instance readiness")
assert(Appearance.status(session):find("animation_instance",1,true))
print("Female appearance regression passed: normalized underwear accepted, outerwear and missing animation instance still block readiness.")

-- Reported live case: no InnerTop existed at entry. Removing outerwear causes
-- the game's resolver to introduce W_InnTop03_001 even though that slot was not
-- explicitly removed. Readiness must use the acknowledged result, not entry None.
female_instance={};female_garments.Top.GarmentId="original_top"
female_garments.InnerTop=nil;female_garments.InnerUnder.GarmentId="original_underwear"
female.outfit_items=nil;Appearance.capture(female)
session={participants={female},revision=1,require_resolved_outfit=true,node={},outfit_change={}}
female.removed_slots={Top=true}
female_garments.Top.GarmentId="None";female_garments.InnerTop={GarmentId="W_InnTop03_001"}
assert(not Appearance.ready(session))
assert(Appearance.status(session):find("outfit_result_unacknowledged",1,true))
female.outfit_revision=1
female.expected_garments={Top="None",InnerTop="W_InnTop03_001",InnerUnder="original_underwear"}
female.outfit_items={piece1={kind="garment",key="Top",enabled=false,asset="original_top",expected_asset="None"}}
for _=1,2 do assert(not Appearance.ready(session)) end
assert(Appearance.ready(session),"Game-added underwear must not cause outfit timeout")
assert(female.original_garments.InnerTop=="None","Resolved state overwrote the original snapshot")
female_garments.Top.GarmentId="still_loading"
assert(not Appearance.ready(session),"The new rule must still wait for the target outerwear result")
assert(Appearance.status(session):find("expected_resolved",1,true))
female_garments.Top.GarmentId="None";session.revision=2
assert(not Appearance.ready(session),"A previous node's resolved metadata must not satisfy a new node")
print("Resolved outfit regression passed: game-added underwear, strict target/instance checks, unchanged entry snapshot and revision-gated acknowledgements.")
