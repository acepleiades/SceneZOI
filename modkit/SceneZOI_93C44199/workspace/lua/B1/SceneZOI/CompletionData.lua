-- Inert scene-local completion response schema. Identifiers and effects belong to packs.
local V=require('SceneZOI.DataValidation')
local M={}
local function optional(v,k,lo,hi,integer)if v[k]~=nil then V.number(v[k],lo,hi,integer)end end
function M.timing(v,duration)
 if v==nil then return end
 V.fields(v,{'cycles_per_second','peak_phase','peak_times'})
 assert((v.cycles_per_second~=nil)~=(v.peak_times~=nil),'Choose frequency or peak_times')
 if v.cycles_per_second~=nil then
  V.number(v.cycles_per_second,.001,60);optional(v,'peak_phase',0,1)
  local count=duration*v.cycles_per_second
  assert(count>=1 and math.abs(count-math.floor(count+.5))<.0001,'Uniform cycles must repeat across the clip seam')
 else
  assert(v.peak_phase==nil,'peak_phase applies only to uniform timing');V.array(v.peak_times,4096)
  assert(#v.peak_times>0,'Empty movement markers')
  local previous=-1
  for _,t in ipairs(v.peak_times)do V.number(t,0,duration);assert(t<duration and t>previous,'Markers must be increasing and exclude the loop endpoint');previous=t end
 end
end
function M.responses(value,roles,kind)
 if value==nil then return end
 assert(V.object(value),'Expected completion responses')
 for role,tasks in pairs(value)do
  assert(roles[role],'Unbound completion response role');assert(V.object(tasks),'Expected response task map')
  for id,spec in pairs(tasks)do
   V.id(id);V.fields(spec,{'enabled','slowdown','shake'},{'enabled'});V.boolean(spec.enabled)
   assert(kind~='transition','Transition nodes cannot start completion responses')
   if spec.slowdown~=nil then
    local s=spec.slowdown;V.fields(s,{'repeats','high_speed','low_speed','recovery','fallback_duration'})
    optional(s,'repeats',1,32,true);optional(s,'high_speed',.001,1);optional(s,'low_speed',.001,1)
    assert((s.low_speed or 1/12)<=(s.high_speed or .5),'Low speed exceeds high speed')
    optional(s,'recovery',.001,30);optional(s,'fallback_duration',.01,300)
   end
   if spec.shake~=nil then
    local s=spec.shake
    V.fields(s,{'delay','duration','bursts','duty_cycle','frequency_hz','amplitude_degrees','bones'},{'bones'})
    optional(s,'delay',0,30);optional(s,'duration',.01,300);optional(s,'bursts',1,64,true)
    optional(s,'duty_cycle',.001,1);optional(s,'frequency_hz',.001,60);optional(s,'amplitude_degrees',0,45)
    V.array(s.bones,64);assert(#s.bones>0,'Empty shake bone list');local seen={}
    for _,b in ipairs(s.bones)do
     V.fields(b,{'bone','child','weight'},{'bone','child'});V.name(b.bone);V.name(b.child)
     assert(b.bone~=b.child and not seen[b.bone],'Duplicate or self-target shake bone');seen[b.bone]=true
     optional(b,'weight',-2,2)
    end
   end
   assert(not spec.enabled or spec.slowdown or spec.shake,'Enabled response has no effects')
  end
 end
end
return M
