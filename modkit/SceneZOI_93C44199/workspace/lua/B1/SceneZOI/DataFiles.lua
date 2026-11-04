-- Inert declarations contributed by enabled native data mods. Never executes pack code.
local Json=require('SceneZOI.Json')
local Config=require('SceneZOI.Config')
local M={}
local cached_raw,cached_entries
local function object(value)
 return type(value)=='table'and getmetatable(value)and getmetatable(value).__jsonkind=='object'
end
local function key(value)
 assert(type(value)=='string'and #value<=96,'Invalid declaration identifier')
 value=value:match('^%s*(.-)%s*$'):lower()
 assert(value:match('^[a-z][a-z0-9_.%-]*$'),'Invalid declaration identifier')
 return value
end
local function decode(text,maximum)
 assert(type(text)=='string','Expected declaration JSON text')
 if text:sub(1,3)=='\239\187\191'then text=text:sub(4)end
 return Json.decode(text,maximum)
end
local function column(row,name)
 for field,value in pairs(row)do if type(field)=='string'and field:lower()==name then return value end end
end
local function read()
 local ok,message,raw=inzoi.cli.execute('data.table_get_all alias='..Config.data_table)
 assert(ok,'Declaration table read failed: '..tostring(message))
 raw=raw or message
 if cached_entries and raw==cached_raw then return cached_entries end
 local packet=decode(raw,16777216)
 assert(type(packet)=='table'and getmetatable(packet)and getmetatable(packet).__jsonkind=='array','Invalid declaration table response')
 local entries={}
 local prefix=Config.data_prefix:lower()
 for _,row in ipairs(packet)do
  local id=object(row)and column(row,'id')
  if type(id)=='string'and id:sub(1,#prefix):lower()==prefix then
   assert(entries[id]==nil,'Duplicate declaration row: '..id)
   entries[id]=column(row,'text')or false
  end
 end
 cached_raw,cached_entries=raw,entries
 return entries
end
function M.refresh()
 local result={by_kind={},warnings={},file_count=0,record_count=0}
 local ok,entries=pcall(read)
 if ok and M.entries==entries and M.value then return M.value end
 if not ok then result.warnings[1]=tostring(entries);entries={}end
 M.entries=entries
 local names={};for name in pairs(entries)do names[#names+1]=name end
 table.sort(names,function(a,b)if a:lower()==b:lower()then return a<b end;return a:lower()<b:lower()end)
 result.file_count=#names
 if #names>4096 then result.warnings[#result.warnings+1]='Too many declaration files (maximum 4096)';names={}end
 for _,name in ipairs(names)do
  local source=Config.data_table..'/'..name
  local valid,err=pcall(function()
   assert(#name<=240 and name:match('^[%w_.%-]+$'),'Invalid declaration row identifier')
   local envelope=decode(entries[name])
   assert(object(envelope),'Expected declaration envelope')
   for field in pairs(envelope)do assert(field=='schema_version'or field=='kind'or field=='owner'or field=='data','Unknown declaration field: '..tostring(field))end
   assert(envelope.schema_version==1,'Unsupported declaration envelope version')
   local kind,owner=key(envelope.kind),key(envelope.owner)
   assert(object(envelope.data),'Expected declaration data object')
   result.by_kind[kind]=result.by_kind[kind]or {}
   local documents=result.by_kind[kind]
   documents[#documents+1]={source=source,owner=owner,data=envelope.data}
   result.record_count=result.record_count+1
  end)
  if not valid then result.warnings[#result.warnings+1]=source..': '..tostring(err)end
 end
 local signature={}
 for _,name in ipairs(names)do local raw=tostring(entries[name]);signature[#signature+1]=name..':'..#raw..':'..raw end
 for _,warning in ipairs(result.warnings)do signature[#signature+1]='warning:'..warning end
 result.signature=table.concat(signature,'\n')
 if M.value and M.value.signature==result.signature then return M.value end
 M.value=result
 for _,warning in ipairs(result.warnings)do print('[SceneZOI] Data warning: '..warning)end
 local kinds={};for kind,docs in pairs(result.by_kind)do kinds[#kinds+1]=kind..':'..#docs end;table.sort(kinds)
 local status='native_rows:'..result.file_count..'+records:'..result.record_count..'+warnings:'..#result.warnings..'+kinds:'..(#kinds>0 and table.concat(kinds,',')or 'none')
 -- Plain diagnostic only; publishing failure must not prevent scene startup.
 pcall(inzoi.cli.execute,'uimod.cfg_save mod_id='..Config.mod_id..' section='..Config.section..' key=data_discovery value='..status:gsub(',','+'))
 return result
end
function M.get()return M.value or M.refresh()end
function M.documents(kind)return M.get().by_kind[key(kind)]or {}end
return M
