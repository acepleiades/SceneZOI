-- Inert display text only. IDs, dictionary meanings and executable behavior are never translated.
local V=require('SceneZOI.DataValidation')
local M={}
function M.placeholders(text)
 local result={};for name in text:gmatch('{([%w_]+)}')do result[name]=true end;return result
end
function M.validate(data)
 V.fields(data,{'schema_version','id','translations'},{'schema_version','id','translations'})
 assert(data.schema_version==1,'Unsupported localization schema');V.id(data.id)
 assert(V.object(data.translations),'Expected localization cultures')
 local cultures=0
 for culture,groups in pairs(data.translations)do
  cultures=cultures+1;assert(cultures<=64 and type(culture)=='string'and #culture<=35 and culture:match('^[a-z][a-z]%-[%w%-]+$'),'Invalid localization culture')
  V.fields(groups,{'messages','labels'})
  for _,kind in ipairs({'messages','labels'})do
   local rows=groups[kind]or {};assert(V.object(rows),'Expected localized text map');local count=0
   for key,text in pairs(rows)do
    count=count+1;assert(count<=2048 and type(key)=='string'and #key>0 and #key<=1024 and not key:find('[%z\1-\31]'),'Invalid localization key')
    assert(type(text)=='string'and #text>0 and #text<=4096 and text:match('%S')and not text:find('[%z\1-\31]'),'Invalid localized text')
    if kind=='messages'then assert(V.equal(M.placeholders(key),M.placeholders(text)),'Translation placeholders differ')end
   end
  end
 end
 return data
end
function M.compile(source)
 local out={messages={},labels={},warnings={},conflicts={}}
 local winners={messages={},labels={}}
 local docs=(source.by_kind or {}).localization or {}
 local ordered={}
 for _,doc in ipairs(docs)do if doc.owner=='scenezoi'then ordered[#ordered+1]=doc end end
 for _,doc in ipairs(docs)do if doc.owner~='scenezoi'then ordered[#ordered+1]=doc end end
 for _,doc in ipairs(ordered)do
  local ok,data=pcall(M.validate,doc.data)
  if not ok then out.warnings[#out.warnings+1]=tostring(doc.source)..': '..tostring(data)
  else
   for culture,groups in pairs(data.translations)do
    for _,kind in ipairs({'messages','labels'})do
     local bucket=out[kind][culture]or {};out[kind][culture]=bucket
     local owners=winners[kind][culture]or {};winners[kind][culture]=owners
     for key,text in pairs(groups[kind]or {})do
      if bucket[key]==nil then
       bucket[key]=text;owners[key]=doc.owner or doc.source
      elseif bucket[key]~=text then
       out.conflicts[#out.conflicts+1]={culture=culture,kind=kind,key=key,winner=owners[key],other=doc.owner or doc.source}
      end
     end
    end
   end
  end
 end
 table.sort(out.conflicts,function(a,b)
  if a.culture~=b.culture then return a.culture<b.culture end
  if a.kind~=b.kind then return a.kind<b.kind end
  if a.key~=b.key then return a.key<b.key end
  return a.other<b.other
 end)
 for _,conflict in ipairs(out.conflicts)do
  out.warnings[#out.warnings+1]='Conflicting localized text: '..conflict.culture..'/'..conflict.key..
   ' ('..conflict.winner..' wins over '..conflict.other..')'
 end
 return out
end
return M
