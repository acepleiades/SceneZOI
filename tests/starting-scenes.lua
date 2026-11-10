package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
inzoi={EB1BodyAgeType={Adult=1}}
local V=require('SceneZOI.DataValidation');local Choose=require('SceneZOI.StartingScenes')
local function person(id,body)return {id=id,body=body,body_age=1,growth_step='Youth'}end
local function hub(id,bodies)local roles={};for i,body in ipairs(bodies)do roles['role'..i]={body=body}end;return{id=id,starting_hub=true,participants=roles}end
local all={}
for _,combo in ipairs({'mf','mm','ff','mff','mmf','mmmm'})do
 local bodies={};for c in combo:gmatch('.')do bodies[#bodies+1]=c=='m'and'male'or'female'end
 all[combo]=hub(combo,bodies);local roster={};for i,body in ipairs(bodies)do roster[i]=person(tostring(i),body)end
 local chosen,n=Choose.choose(all,roster,function()return 1 end);assert(chosen and n>=1)
 local used={};for role,id in pairs(chosen.bindings)do assert(not used[id]);used[id]=true;assert(all[chosen.node].participants[role].body==roster[tonumber(id)].body)end
end
local a=hub('a',{'male','female'});local b=V.copy(a);b.id='b'
assert(not Choose.choose({a=a},{person('1','female'),person('2','female')}))
for i=1,2 do local choice,n=Choose.choose({a=a,b=b},{person('2','female'),person('1','male')},function(size)assert(size==2);return i end);assert(choice.node==(i==1 and'a'or'b')and n==2)end
a.participants.role1.growth_steps={'Adult'};assert(not Choose.choose({a=a},{person('1','male'),person('2','female')}))
assert(not pcall(Choose.choose,{a=b},{person('1','male'),person('1','female')}))
local solo=hub('solo',{'female'})
local alone=Choose.choose({a=a,solo=solo},{person('1','female')},function()return 1 end);assert(alone.node=='solo'and alone.bindings.role1=='1','A lone Zoi gets a one-role scene')
assert(not Choose.choose({a=a},{person('1','female')}),'A two-role scene is no solo start')
assert(not Choose.choose({solo=hub('m',{'male'})},{person('1','female')}),'A solo scene is for its own body')
local grown=hub('g',{'female'});grown.participants.role1.growth_steps={'Youth','Adult','Old','Elderly'}
local teen=person('1','female');teen.growth_step='Teen';assert(not Choose.choose({g=grown},{teen}),'A teen never matches an adults-only solo scene')
print('Generic starting scenes passed: repeated bodies, arbitrary roles, complete rosters, eligibility and random scene selection.')
