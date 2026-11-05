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
 local out={messages={},labels={},warnings={}}
 for _,doc in ipairs((source.by_kind or {}).localization or {})do
  local ok,err=pcall(function()
   local data=M.validate(doc.data)
   -- Check every conflict before accepting any field from this document.
   for culture,groups in pairs(data.translations)do for _,kind in ipairs({'messages','labels'})do
    local existing=out[kind][culture]or {}
    for key,text in pairs(groups[kind]or {})do assert(not existing[key]or existing[key]==text,'Conflicting localized text: '..key)end
   end end
   for culture,groups in pairs(data.translations)do for _,kind in ipairs({'messages','labels'})do
    out[kind][culture]=out[kind][culture]or {}
    for key,text in pairs(groups[kind]or {})do out[kind][culture][key]=text end
   end end
  end)
  if not ok then out.warnings[#out.warnings+1]=tostring(doc.source)..': '..tostring(err)end
 end
 return out
end
return M
