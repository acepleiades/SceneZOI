-- Merge data contributions transactionally. Names are opaque case-insensitive keys.
local Keys=require('SceneZOI.ExpressionKeys')
local M={}
local function clone(v)
 if type(v)~='table'then return v end
 local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out
end
local function fields(v,allowed,required)
 assert(type(v)=='table'and(not getmetatable(v)or getmetatable(v).__jsonkind=='object'),'Expected expression object')
 for k in pairs(v)do assert(allowed[k],'Unknown expression field: '..tostring(k))end
 for _,k in ipairs(required or {})do assert(v[k]~=nil,'Missing expression field: '..k)end
end
local function array(v,minimum,maximum)
 assert(type(v)=='table'and(not getmetatable(v)or getmetatable(v).__jsonkind=='array')and #v>=minimum and #v<=maximum,'Invalid expression array')
 for k in pairs(v)do assert(type(k)=='number'and k%1==0 and k>=1 and k<=#v,'Expected expression array')end
end
local function number(v,low,high)assert(type(v)=='number'and v==v and v>=low and v<=high,'Invalid expression number')end
local function label(v)assert(type(v)=='string'and #v>0 and #v<=400 and select(2,v:gsub('[^\128-\191]',''))<=100 and v:find('%S')and not v:find('[%z\1-\31]'),'Invalid expression label')end
local function same(a,b)
 if type(a)~='table'then return a==b end
 if type(b)~='table'then return false end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function add(state,data)
 fields(data,{schema_version=true,id=true,label=true,body=true,default=true,contexts=true,aliases=true},{'schema_version','id','body','contexts'})
 assert(data.schema_version==2,'Unsupported expression schema')
 local id=Keys.required(data.id);local body=data.body;assert(body=='female'or body=='male','Invalid expression body')
 assert(data.default==nil or type(data.default)=='boolean','Invalid expression default')
 assert(type(data.contexts)=='table'and(not getmetatable(data.contexts)or getmetatable(data.contexts).__jsonkind=='object'),'Expected expression contexts')
 assert(not state.aliases[id]or state.aliases[id]==id,'Set ID conflicts with an alias')
 local target=state.sets[id]or {id=id,body=body,contexts={},default=false}
 assert(target.body==body,'Conflicting expression body');state.sets[id]=target
 if data.label~=nil then label(data.label);assert(not target.label or target.label==data.label,'Conflicting expression label');target.label=data.label end
 if data.default then
  assert(not state.explicit_defaults[body]or state.explicit_defaults[body]==id,'Conflicting expression default')
  target.default=true;state.explicit_defaults[body]=id
 end
 local aliases=data.aliases;if aliases==nil then aliases={}end;array(aliases,0,64)
 for _,alias in ipairs(aliases)do
  alias=Keys.required(alias)
  assert(not state.sets[alias]or alias==id,'Alias conflicts with a set')
  assert(not state.aliases[alias]or state.aliases[alias]==id,'Conflicting expression alias')
  if alias~=id then state.aliases[alias]=id end
 end
 local seen={};local count=0
 for name,spec in pairs(data.contexts)do
  count=count+1;assert(count<=256,'Too many contexts');name=Keys.required(name);assert(not seen[name],'Duplicate case-insensitive context');seen[name]=true
  fields(spec,{hold=true,transition=true,options=true},{'options'})
  local group=target.contexts[name]or {options={}};target.contexts[name]=group
  if spec.hold~=nil then array(spec.hold,2,2);number(spec.hold[1],.1,120);number(spec.hold[2],spec.hold[1],120)end
  if spec.transition~=nil then number(spec.transition,0,10)end
  for _,setting in ipairs({'hold','transition'})do
   if spec[setting]~=nil then assert(group[setting]==nil or same(group[setting],spec[setting]),'Conflicting context '..setting);group[setting]=clone(spec[setting])end
  end
  array(spec.options,1,256)
  for _,option in ipairs(spec.options)do
   fields(option,{animation=true,label=true,weight=true,sample=true},{'animation'})
   assert(type(option.animation)=='string'and option.animation:match('^/[A-Za-z0-9_/]+%.[A-Za-z0-9_]+$'),'Invalid expression asset path')
   local weight=option.weight;if weight==nil then weight=1 end;local sample=option.sample;if sample==nil then sample=0 end
   local caption=option.label;if caption==nil then caption=option.animation:match('%.([^%.]+)$')end
   local item={animation=option.animation,label=caption,weight=weight,sample=sample,animated=option.sample==nil}
   label(item.label);number(item.weight,0,100);assert(item.weight>0,'Invalid expression weight');number(item.sample,0,120)
   local found
   for _,old in ipairs(group.options)do if old.animation==item.animation and old.sample==item.sample then assert(same(old,item),'Conflicting duplicate expression clip');found=true end end
   if not found then group.options[#group.options+1]=item end
  end
  assert(#group.options<=256,'Too many merged expression options')
 end
end
function M.compile(documents)
 local state={sets={},aliases={},explicit_defaults={}};local warnings={}
 local sorted={};for i,entry in ipairs(documents)do sorted[i]=entry end
 table.sort(sorted,function(a,b)if a.source:lower()==b.source:lower()then return a.source<b.source end;return a.source:lower()<b.source:lower()end)
 for _,entry in ipairs(sorted)do
  local pending=clone(state);local ok,err=pcall(add,pending,entry.data)
  if ok then state=pending else warnings[#warnings+1]=entry.source..': '..tostring(err)end
 end
 local defaults=clone(state.explicit_defaults);local contexts,ids={},{}
 for id in pairs(state.sets)do ids[#ids+1]=id end;table.sort(ids)
 for _,id in ipairs(ids)do
  local set=state.sets[id];set.label=set.label or id;defaults[set.body]=defaults[set.body]or id
  for name,group in pairs(set.contexts)do
   contexts[name]=true;group.hold=group.hold or {5,11};group.transition=group.transition or .35
   table.sort(group.options,function(a,b)if a.animation~=b.animation then return a.animation<b.animation end;if a.sample~=b.sample then return a.sample<b.sample end;return a.label<b.label end)
  end
 end
 local names={};for name in pairs(contexts)do names[#names+1]=name end;table.sort(names)
 return {schema_version=2,sets=state.sets,aliases=state.aliases,defaults=defaults,contexts=names,warnings=warnings}
end
return M
