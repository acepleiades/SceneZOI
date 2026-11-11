-- Session tokens key the save journal's recovery records, which outlive a launch. The session counters restart with
-- every launch, so the first background scene of a new launch must not get the token of an earlier launch's record.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;tests/?.lua;'..package.path
local function launch()
 for name in pairs(package.loaded)do if name:find('^SceneZOI%.')then package.loaded[name]=nil end end
 local F=require('support.runtime-fixture').new()
 for id=1,2 do F.add_actor(id)end
 F.Runtime.boot()
 local Sessions=require('SceneZOI.Sessions')
 local start={token='start.1',has_household=false,lifetime={deadline_seconds=600},
  placement={max_start_distance_cm=1500,exit='restore'},req={addon_id='test.addon',client_id='test.client',request_id='r1'},
  restrictions={},entry={initiator='1',node='test.node',bindings={first='1',second='2'}}}
 assert(Sessions.reserve(start.token,{'1','2'}))
 return F.Runtime.start_background(start)
end
local first=launch()
local second=launch()
assert(type(first)=='string'and type(second)=='string','Both launches start a background scene')
assert(first~=second,'The first background scene of a new launch reuses an earlier launch\'s token: '..first)
assert(first:match('^host%.%d+%.%d+$')and second:match('^host%.%d+%.%d+$'),'The token keeps its client.sequence.serial shape')
print('Session tokens passed: unique across launches, same client.sequence.serial shape.')
