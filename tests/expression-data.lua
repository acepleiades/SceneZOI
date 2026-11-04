package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local J=require('SceneZOI.Json');local D=require('SceneZOI.ExpressionData');local K=require('SceneZOI.ExpressionKeys')
assert(K.normalize(' Tongue Out ')=='tongue out'and not K.normalize('')and not K.normalize('bad\nkey'))
assert(J.decode(' { "a": [true, false, null, -1.25e2, "\\u30c8\\uD83D\\uDE00"] } ').a[4]==-125)
for byte=0,31 do assert(not pcall(J.decode,'"ordinary'..string.char(byte)..'span"'),'Unescaped control accepted')end
assert(J.decode('"ordinary\\nspan\\\\tail\\"end"')=='ordinary\nspan\\tail"end')
assert(J.decode('"'..string.rep('ordinary span ',10000)..'"')==string.rep('ordinary span ',10000))
for _,bad in ipairs({'{"a":1,"a":2}','[1,]','{"a":}','01','1e','"\\uD800"','true false','return os.execute("bad")',string.rep('[',50)..string.rep(']',50)})do assert(not pcall(J.decode,bad),bad)end
local function doc(source,id,context,clip,extra)
 return {source=source,data={schema_version=2,id=id,body='female',label=extra and extra.label,contexts={[context]={options={{animation='/Test/'..clip..'.'..clip}}}}}}
end
local first=doc('/ModA/a','Designer Set','Idle','A',{label='A display name'})
first.data.aliases={'Old.Name'};first.data.contexts.Idle.hold={2,7}
local second=doc('/ModB/b','DESIGNER SET','iDLe','B')
local third=doc('/ModC/c','designer set','Tongue Out','C')
local docs={third,second,first};local data=D.compile(docs)
assert(docs[1]==third,'Compiler mutated caller ordering')
assert(#data.warnings==0 and data.defaults.female=='designer set'and not data.defaults.male)
assert(data.aliases['old.name']=='designer set'and #data.sets['designer set'].contexts.idle.options==2)
assert(data.sets['designer set'].contexts.idle.hold[2]==7 and data.sets['designer set'].contexts['tongue out'])
assert(#D.compile({first,first}).sets['designer set'].contexts.idle.options==1,'Duplicate clip was duplicated')
-- A conflicting file must leave none of its earlier additions behind.
local broken=doc('/ModZ/z','designer set','New Context','D');broken.data.aliases={'discard me'};broken.data.contexts.Idle={hold={1,3},options={{animation='/Test/E.E'}}}
local result=D.compile({first,broken});assert(#result.warnings==1 and not result.aliases['discard me']and not result.sets['designer set'].contexts['new context'])
for _,field in ipairs({'contexts','aliases'})do
 local raw='{"schema_version":2,"id":"bad","body":"male","contexts":{},"'..field..'":null}'
 if field=='contexts'then raw='{"schema_version":2,"id":"bad","body":"male","contexts":null}'end
 assert(not pcall(J.decode,raw)or #D.compile({{source='bad',data=J.decode(raw)}}).warnings==1)
end
local empty=D.compile({});assert(not next(empty.sets)and not next(empty.defaults))
-- Native data rows contributed by separate packs; ordinary game rows are ignored.
local function quote(value)return '"'..value:gsub('\\','\\\\'):gsub('"','\\"')..'"'end
local function envelope(kind,owner,data)return '{"schema_version":1,"kind":"'..kind..'","owner":"'..owner..'","data":'..data..'}'end
local shared='{"schema_version":2,"id":"Shared Set","body":"female","contexts":{"Idle":{"options":[{"animation":"/Test/A.A"}]}}}'
local prefix='SceneZOI_Declaration_'
local entries={[prefix..'author_a']=envelope('expression_set','author.a',shared),[prefix..'notes']=envelope('custom_kind','author.b','{"note":"arbitrary inert data"}'),[prefix..'bad']='not json',Ambition_None='ordinary native text'}
local reads,read_failure=0,false
inzoi={cli={execute=function(command)
 if command:find('table_get_all',1,true)then
  assert(command=='data.table_get_all alias=Text','Discovery supplied a pack or filename list')
  reads=reads+1;if read_failure then return false,'unavailable'end
  local fields={};for name,payload in pairs(entries)do fields[#fields+1]='{"iD":'..quote(name)..',"text":'..quote(payload)..'}'end
  return true,'ok','['..table.concat(fields,',')..']'
 end
 assert(not command:find('cfg_load',1,true),'Retired directory hid native discovery failure')
 return true,'ok'
end}}
local Files=require('SceneZOI.DataFiles');local snapshot=Files.refresh()
assert(snapshot.file_count==3 and snapshot.record_count==2 and #snapshot.warnings==1)
assert(#Files.documents('EXPRESSION_SET')==1 and #Files.documents('custom_kind')==1 and reads==1,'Discovery was not cached')
assert(Files.refresh()==snapshot,'Unchanged native rows replaced the library snapshot')
entries[prefix..'new_author_fragment']=envelope('ExPrEsSiOn_SeT','author.b','{"schema_version":2,"id":"SHARED SET","body":"female","contexts":{"Tongue Out":{"options":[{"animation":"/Test/B.B"}]}}}')
Files.refresh();local merged=D.compile(Files.documents('expression_set'))
assert(merged.sets['shared set'].contexts.idle and merged.sets['shared set'].contexts['tongue out']and #merged.warnings==0)
entries[prefix..'author_a']=nil;Files.refresh();merged=D.compile(Files.documents('expression_set'));assert(not merged.sets['shared set'].contexts.idle,'Removed native contribution stayed cached')
entries={[prefix..'bad']=envelope('expression_set','author.a','null')};assert(#Files.refresh().warnings==1)
entries={};assert(Files.refresh().file_count==0 and #Files.documents('expression_set')==0)
read_failure=true;assert(#Files.refresh().warnings==1,'Optional table failure became fatal')
read_failure=false;assert(#Files.refresh().warnings==0,'Read recovery kept a cached failure')
print('Expression data passed: strict inert JSON, case-insensitive contributions, transactional conflicts, native declaration discovery, multiple authors/kinds, unknown names, stable snapshots, removal and optional failure.')

local tiny=doc('tiny','tiny','idle','A');tiny.data.contexts.idle.options[1].weight=1e-12
assert(#D.compile({tiny}).warnings==0,'Positive weights were inconsistently rejected')
tiny.data.contexts.idle.options[1].label=false;assert(#D.compile({tiny}).warnings==1,'False clip label was silently defaulted')
