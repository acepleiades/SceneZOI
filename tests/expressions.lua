package.path="modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;"..package.path
local P=require("SceneZOI.Protocol")
local store,writes,fail_save={},0,false
inzoi={cli={execute=function(line)
    local key=line:match("key=([^ ]+)")
    if line:find("cfg_save",1,true) then
        if fail_save then return false,"disk unavailable" end
        writes=writes+1;store[key]=line:match("value=(.+)$");return true,"ok"
    end
    return store[key]~=nil,"ok",store[key]
end}}
local calls,stops={},{}
package.loaded["SceneZOI.ExpressionNative"]={
    bind=function(o)return o.actor.available end,body=function(p)return p.body end,
    play=function(o,clip,transition)calls[o.id]=(calls[o.id] or 0)+1;o.clip=clip;return true end,
    hold=function()end,stop=function(o)stops[o.id]=(stops[o.id] or 0)+1;o.clip=nil end}
local mouth={}
package.loaded["SceneZOI.FacialPose"]={prepare=function()return true end,sample=function(o,on)mouth[o.id]=on end,guard=function()end,restore=function(o)mouth[o.id]=false end}
local unavailable=false
local bad_asset=false
local throw_load=false
local loads=0
UE={UAnimSequence={StaticClass=function()return "sequence"end},UObject={Load=function(path)
    loads=loads+1
    if throw_load then error("native asset load failed")end
    if bad_asset then return {}end
    if unavailable then return nil end
    return {IsA=function()return true end,GetPlayLength=function()return 10 end}
end}}
local docs={}
for _,name in ipairs({'confident','downer','grinning_face','pleasure_face','troubled_face'})do
 local function context(hold)return {hold=hold,transition=0.25,options={{animation='/Test/FaceA.FaceA'},{animation='/Test/FaceB.FaceB'}}}end
 local spec={schema_version=2,id='example.'..name,label=name,body=name=='confident'and'male'or'female',
  default=name=='confident'or name=='pleasure_face',contexts={Idle=context({5,11}),Pleasure=context({2.4,7}),Kiss=context({6,6})}}
 if name=='downer'then spec.aliases={'example.legacy_downer'}end
 docs[#docs+1]={source=name,data=spec}
end
local library=require('SceneZOI.ExpressionData').compile(docs);assert(#library.warnings==0)
package.loaded['SceneZOI.ExpressionLibrary']={get=function()return library end}
local E=require("SceneZOI.Expressions")
local Profiles=require("SceneZOI.Personality")
local function person(id,role,body)return {id=id,role=role,body=body,actor={available=true},outfit_name=P.encode(role)}end
local a,b,c=person("1","lead","female"),person("2","other","female"),person("3","third","male")
local session={client="test",sequence="1",revision=1,clock={session_elapsed=0},participants={a,b,c}}
local ctx={node={expressions={lead={context="Pleasure"},other={context="Idle",facial_pose='scenezoi.open_o'},third={context="Idle"}}}}
assert(E.prepare(ctx,session));E.enter(ctx)
assert(a.expression_set=="example.pleasure_face" and b.expression_set==a.expression_set and c.expression_set=="example.confident")
assert(calls["1"]==1 and calls["2"]==1 and calls["3"]==1 and mouth["2"] and not mouth["1"])
E.prepare(ctx,session);E.enter(ctx)
assert(calls["1"]==1 and calls["2"]==1,"An outfit handoff reset expression selection")
-- Pause means unchanged shared time, regardless of the number of real callbacks.
for _=1,100 do E.sample(ctx);E.guard(ctx) end
assert(calls["1"]==1 and calls["2"]==1 and calls["3"]==1)
session.clock.session_elapsed=12;E.sample(ctx);assert(calls["1"]==2 and calls["2"]==2)
local before=writes
Profiles.request(session,P.pack("test",1,"personality",1,"2","example.downer",1));assert(writes==before+1)
assert(b.expression_set=="example.downer" and a.expression_set=="example.pleasure_face")
E.sample(ctx);assert(calls["2"]==3 and calls["1"]==2)
Profiles.request(session,P.pack("test",1,"personality",1,"2","example.downer",1));assert(writes==before+1)
Profiles.request(session,P.pack("test",1,"personality",2,"3","example.pleasure_face",1));assert(session.personality_code=="personality_invalid")
Profiles.request(session,P.pack("test",1,"personality",3,"1","example.downer",0));assert(session.personality_code=="personality_stale")
fail_save=true
Profiles.request(session,P.pack("test",1,"personality",4,"1","example.downer",1))
assert(session.personality_code=="personality_storage" and a.expression_set=="example.pleasure_face");fail_save=false
session.stopping=true;local previous_ack=session.personality_ack
Profiles.request(session,P.pack("test",1,"personality",5,"1","example.downer",1))
assert(a.expression_set=="example.pleasure_face" and session.personality_ack==previous_ack,"An exiting session persisted a queued personality edit")
session.stopping=false
local replacement=person("2","new_role","female")
assert(Profiles.load(replacement,"female")=="example.downer","Preference must survive a new session and role")
store.zoi_2=P.pack("1","removed.pack");assert(Profiles.load(replacement,"female")=="example.pleasure_face")
store.zoi_2="malformed";assert(Profiles.load(replacement,"female")=="example.pleasure_face")
E.leave_node(ctx);session.clock.session_elapsed=20;E.sample(ctx);assert(calls["1"]==2)
ctx.node={expressions={lead={context="Kiss"}}};E.prepare(ctx,session);E.enter(ctx)
assert(calls["1"]==3 and not ctx.owners["2"].clip and not mouth["2"])
E.restore(ctx);assert(not ctx.owners["1"].clip and not ctx.owners["3"].clip)
local count=calls["1"];E.sample(ctx);assert(calls["1"]==count)
unavailable=true
local missing={node={expressions={lead={context="Idle"}}}}
assert(E.prepare(missing,session));E.enter(missing)
assert(a.expression_error and not missing.owners["1"].clip,"Missing optional assets must not mutate the face or stop the scene")
local loaded=loads;for _=1,100 do E.sample(missing) end;assert(loads==loaded,"Missing assets retried on every frame")
E.restore(missing)
throw_load=true
local broken={node={expressions={lead={context="Idle"}}}}
assert(pcall(E.prepare,broken,session),"Optional native loader exceptions must not abort a scene")
E.enter(broken);assert(a.expression_error);E.restore(broken)
throw_load=false;bad_asset=true
local wrong_type={node={expressions={lead={context="Idle"}}}}
assert(pcall(E.prepare,wrong_type,session),"A non-animation asset must be rejected without aborting the scene")
E.enter(wrong_type);assert(a.expression_error);E.restore(wrong_type)
print("Expressions passed: three roles, repeated bodies, independent defaults/selection, shared pause/timing, persistent identity, stale/duplicate/invalid/storage guards, missing assets, omitted contexts and cleanup.")

-- Legacy/case-insensitive IDs migrate through data aliases, without engine names.
store.zoi_2=P.pack('1','EXAMPLE.LEGACY_DOWNER');assert(Profiles.load(replacement,'female')=='example.downer')
unavailable=false;bad_asset=false
local absent={node={expressions={lead={context='Tongue Out',facial_pose='scenezoi.open_o'},other={context='pLeAsUrE'}}}}
assert(E.prepare(absent,session));E.enter(absent)
assert(a.expression_error:find('Tongue Out',1,true)and not absent.owners['1'].clip and mouth['1'])
assert(absent.owners['2'].clip,'A missing context affected another participant')
E.restore(absent)
local previous=library;library={sets={},aliases={},defaults={}}
for _,p in ipairs(session.participants)do p.expression_profile_loaded=nil end
local empty={node={expressions={lead={context='idle'},third={context='pleasure'}}}}
local before_loads=loads;assert(E.prepare(empty,session));E.enter(empty);Profiles.publish(session)
assert(loads==before_loads and not a.expression_set and not c.expression_set and a.expression_error)
assert(store.personality_state:match('|none$'),'Empty installed library did not publish valid UI state')
E.restore(empty);library=previous

-- A pose-only override on a node without expressions must release without a clip.
local Control=require('SceneZOI.AddonControl')
local pose_only={node={}}
session.addon_controls={};session.revision=session.revision+1
assert(E.prepare(pose_only,session));E.enter(pose_only)
Control.layer(session,'observer').expressions[a.id]={facial_pose='example.brow'}
local clips=calls[a.id]
E.sample(pose_only);assert(mouth[a.id]=='example.brow'and not pose_only.owners[a.id].face_active and calls[a.id]==clips)
session.addon_controls={};E.sample(pose_only)
assert(not mouth[a.id],'Cleared/expired pose-only override leaked without facial clip ownership')
E.restore(pose_only)
print('Pose-only expression release passed without installed facial clips or node expressions.')
