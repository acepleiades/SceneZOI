package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;tests/?.lua;'..package.path
local Catalog=require('SceneZOI.Catalog')
local Search=require('SceneZOI.SceneSearch')
local Json=require('SceneZOI.Json')
local F=require('support.runtime-fixture').new()
local R,P,cfg=F.Runtime,F.Protocol,F.cfg

local nodes={}
local function scene(id,rating,destination)
    nodes[id]={id=id,content_rating=rating,kind=destination and 'transition' or 'loop',
        destination=destination,participants={first={}},anchor_participant='first',navigation={}}
    return nodes[id]
end
local idle=scene('test.solo','GENERAL')
local general=scene('test.general','GENERAL')
local suggestive=scene('test.suggestive','SUGGESTIVE')
local explicit=scene('test.explicit','EXPLICIT')
local unrated=scene('test.unrated')
local bridge=scene('test.transition','GENERAL',explicit.id)
for _,node in ipairs({general,suggestive,explicit,unrated,bridge})do
    idle.navigation[#idle.navigation+1]={id=node.id,target=node.id}
end

local fakeCatalog=require('SceneZOI.Catalog')
local catalogSnapshot=fakeCatalog.get_snapshot()
catalogSnapshot.nodes=nodes
fakeCatalog.get_snapshot=function()return catalogSnapshot end
Catalog.get_snapshot=fakeCatalog.get_snapshot
Catalog.resolve_appearance=fakeCatalog.resolve_appearance
fakeCatalog.get=Catalog.get
fakeCatalog.destination=Catalog.destination
F.scene_allowed=Search.allowed

F.add_actor(1)
R.boot()
local function start(sequence,node,mode)
    cfg.request=P.pack('ui',sequence,'start','1',node.id,'first:1','none','none','none',mode or 'none')
    cfg.heartbeat=P.pack('ui',sequence,'heartbeat','b'..sequence)
    R.tick(.25)
end
start('1',explicit,'solo')
assert(not R.any_active(),'The solo launcher validates the initial scene before acquiring a session')
start('2',idle,'solo')
local snapshot=assert(R.snapshot(),'A GENERAL solo scene can open Settings')
assert(snapshot.session_restrictions and table.concat(snapshot.session_restrictions.allowed_content_ratings)== 'GENERAL')
local token=snapshot.id
local snapshotRecord=P.encode(Json.encode({token=token,collision=true}))
R.save_reply(F.actors[1],P.pack(token,'snapshot',snapshotRecord))
local journal=Json.decode(P.decode(cfg.save_snapshot))
cfg.save_ready=P.pack(journal.host,journal.revision,'ready')
R.tick(.05)
F.reply(token,1,'ready','female:npc',1)
R.tick(.05);R.tick(.05)
local current=assert(R.api_session(token))
assert(current.started and not current.preparing)

-- The settings toggle may be used from within this session.
require('SceneZOI.Settings').debug_start_enabled=function()return true end
local options=R.api_navigation(current).navigation
assert(#options==1 and options[1].target==general.id,'Solo offers only GENERAL routes, including transition destinations')
for index,blocked in ipairs({suggestive,explicit,unrated,bridge})do
    cfg.navigation=P.pack('ui','2','navigate',index,blocked.id,current.revision,token)
    R.tick(.25)
    assert(current.node.id==idle.id and current.navigation_code=='navigation_error','Reject a direct request for '..blocked.id)
end
cfg.navigation=P.pack('ui','2','navigate',5,general.id,current.revision,token)
R.tick(.25)
assert(current.node.id==general.id,'GENERAL navigation still works')

R.stop('ok',token)
F.reply(token,1,'released')
R.flush_notifications()
assert(not R.any_active())
start('3',explicit)
snapshot=assert(R.snapshot(),'A separate debug picker session can still start compatible non-GENERAL solo content')
assert(snapshot.content_rating=='EXPLICIT' and not snapshot.session_restrictions)

print('Solo launcher passed: GENERAL-only start and navigation, transition closure, and separate debug entry.')
