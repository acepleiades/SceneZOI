package.path="modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;"..package.path
local Clock=require("SceneZOI.Clock")
local c=Clock.new()
local speeds={.50,1,1.50,2.00}
for index,speed in ipairs(speeds) do
    c:select(index);c:reset_node();c:advance(1,1)
    assert(math.abs(c.elapsed-speed)<1e-9)
    c:advance(10,0);assert(math.abs(c.elapsed-speed)<1e-9)
    c:advance(1,3);assert(math.abs(c.elapsed-speed*4)<1e-9)
end
assert(c.game_elapsed==16,"Native-game time was affected by scene speed/pause")
local total=c.session_elapsed;local game_total=c.game_elapsed
c:reset_node();assert(c.elapsed==0 and c.session_elapsed==total and c.game_elapsed==game_total and c.index==4)
assert(not pcall(c.select,c,0) and not pcall(c.select,c,5) and not pcall(c.select,c,1.5))
assert(Clock.delta(0/0)==0 and Clock.delta(-1)==0 and Clock.delta(math.huge)==0)
assert(not pcall(c.advance,c,1,-1))
local scale=0
inzoi={UB1System={Get=function() return {GetTimeManager=function() return {GetTimeScale=function() return scale end} end} end}}
assert(Clock.game_scale()==0);scale=4;assert(Clock.game_scale()==4)
local ticks=1234
inzoi={UB1System={Get=function() return {GetTimeManager=function() return {GetCurrentDateTime=function() return {GetTicks=function() return ticks end} end} end} end}}
assert(Clock.calendar_ticks()==1234 and Clock.TICKS_PER_GAME_MINUTE==600000000)
print("Clock checks passed: all four scene speeds, game pause/multiplication, no catch-up, node reset and invalid values.")
