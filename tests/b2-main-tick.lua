package.path='modkit/SceneZOI_93C44199/workspace/lua/B2/?.lua;'..package.path
local times,routes={},{}
package.loaded['SceneZOIStarter.Selection']={tick=function()end}
package.loaded['SceneZOI.SimulationRoute']={tick=function(dt)routes[#routes+1]=dt end}
package.loaded['SceneZOI.FurnitureLease']={tick=function()end}
package.loaded['SceneZOI.NativeGetUp']={tick=function(dt)times[#times+1]=dt end}
local Main=assert(loadfile('modkit/SceneZOI_93C44199/workspace/lua/B2/Main.lua'))()
Main.on_tick({},.1);Main.on_tick(.2)
assert(#times==2 and times[1]==.1 and times[2]==.2 and routes[1]==.1 and routes[2]==.2,
 'Native GetUp uses one numeric global delta per callback in either supported hook form')
print('B2 global tick passed: native GetUp progresses once per frame with direct or state-prefixed delta.')
