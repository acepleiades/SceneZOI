package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local P=require('SceneZOI.Protocol')
inzoi={cli={execute=function()return true end}}
local Settings=require('SceneZOI.Settings');local Tasks=require('SceneZOI.Tasks');local Controls=require('SceneZOI.AddonControl')
local people={{id='1',role='male_role',body='female',expression_body='male',bio_gender='male'},
 {id='2',role='female_role',body='male',bio_gender='female'}, {id='3',role='third',body='female'}}
local s={client='test',sequence='1',revision=1,participants=people,node={kind='loop',id='test.scene',participants={},tasks={}}}
local defs={charge={id='charge',label='Charge',maximum=100,initial=0,decay=3}}
local function rates(female,male,count)Settings.request(s,'task_rates',P.pack('test','1','settings_task_rates',count,1,female,male))end
local function fresh(rate)
 for _,p in ipairs(people)do s.node.tasks[p.role]={charge={rate=rate}}end
 return Tasks.new(defs,people)
end
local events={};local function tick(t,dt)Tasks.update(t,s,dt,function(e)events[#events+1]=e end)end
rates(50,200,1);local t=fresh(10);tick(t,1)
assert(t.participants['1'].charge.value==5 and t.participants['2'].charge.value==20 and t.participants['3'].charge.value==5,'Appearance body must override role names, biological gender and conflicting expression fixtures; repeated bodies stay independent')
local rows=Tasks.inspect(t,s);assert(rows[1].player_rate_multiplier==.5 and rows[1].rate_multiplier==.5 and rows[1].effective_rate==5)
Controls.register('helper',{'tasks'});local layer=Controls.layer(s,'helper');layer.tasks['1|charge']={rate_multiplier=3}
tick(t,1);assert(t.participants['1'].charge.value==20 and t.participants['2'].charge.value==40,'Player gain must multiply independent add-on factors')
rows=Tasks.inspect(t,s);assert(rows[1].addon_rate_multiplier==3 and rows[1].rate_multiplier==1.5)
layer.tasks['1|charge']=nil
rates(10,100,2);tick(t,1);assert(t.participants['1'].charge.value==21 and t.participants['2'].charge.value==50,'Minimum setting advances only the selected body at one tenth speed')
s.node.tasks.male_role.charge.rate=-2;tick(t,1);assert(t.participants['1'].charge.value==19,'Player minimum must not disable authored negative rates')
s.node.tasks.male_role=nil;tick(t,1);assert(t.participants['1'].charge.value==16,'Automatic decay must remain authored')
rates(200,50,3);t=fresh(10);s.node.tasks.male_role.charge.cap_percent=15;tick(t,1);assert(t.participants['1'].charge.value==15,'Faster progress must respect scene cap')
s.node.tasks.male_role.charge.cap_percent=5;tick(t,1);assert(t.participants['1'].charge.value==15,'Lower caps must preserve accumulated values')
s.node.tasks.male_role.charge.cap_percent=100;s.preparing=true;tick(t,10);s.preparing=false;assert(t.participants['1'].charge.value==15)
s.node.kind='transition';tick(t,10);s.node.kind='loop';tick(t,0);assert(t.participants['1'].charge.value==15,'Held ticks never accrue')
t=fresh(10);tick(t,5);assert(t.participants['1'].charge.completions==1 and t.participants['3'].charge.completions==1 and t.participants['2'].charge.value==25,'Normal completion/reset remains participant-owned')
layer.tasks['1|charge']={completion_hold=true};tick(t,5);assert(t.participants['1'].charge.value==100 and t.participants['1'].charge.completions==1,'Player rate must respect add-on completion holds')
rates(10,100,4);layer.tasks['1|charge']=nil;tick(t,1);assert(t.participants['1'].charge.value==0 and t.participants['1'].charge.completions==2,'Already-ready completion is not cancelled by minimum future accumulation')
rates(500,10,5);t=fresh(10);tick(t,1);assert(t.participants['1'].charge.value==50 and t.participants['2'].charge.value==1,'500% and 10% apply as 5x and 0.1x')
print('Player task rates passed: body identity, repeated owners, 10/50/100/200/500%, live changes, add-on multiplication/holds, decay/negative/zero rates, caps, preparation/transition/pause and completion/reset.')
