local Files=require('SceneZOI.DataFiles')
local Data=require('SceneZOI.LocalizationData')
local J=require('SceneZOI.Json')
local P=require('SceneZOI.Protocol')
local C=require('SceneZOI.Config')
local M={culture='en-US'}
local source,published,age,published_culture
local compiled={messages={},labels={},warnings={}}
local aliases={en='en-US',ko='ko-KR',ja='ja-JP',de='de-DE',fr='fr-FR',it='it-IT',es='es-ES',ru='ru-RU',pl='pl-PL',pt='pt-PT',tr='tr-TR',nl='nl-NL',zh='zh-CN'}
local canonical={};for _,v in pairs(aliases)do canonical[v:lower()]=v end;canonical['pt-br']='pt-BR';canonical['zh-tw']='zh-TW';canonical['zh-hans']='zh-CN';canonical['zh-hant']='zh-TW'
function M.normalize(value)
 if type(value)~='string'then return 'en-US'end
 value=value:gsub('_','-'):lower()
 return canonical[value]or aliases[value]or 'en-US'
end
local function library()return compiled end
function M.refresh()
 local ok,_,raw=inzoi.cli.execute('gameplay.get_settings')
 local decoded,value=pcall(J.decode,ok and raw or '')
 M.culture=M.normalize(decoded and type(value)=='table'and(value.language or value.Language)or nil)
 local current=Files.get()
 if current~=source then
  published=nil;source=current;compiled=Data.compile(current)
  for _,warning in ipairs(compiled.warnings)do print('[SceneZOI] Localization warning: '..warning)end
 end
 if published and published_culture==M.culture then return M.culture end
 local data=library();local packet=P.encode(J.encode({culture=M.culture,messages=data.messages,labels=data.labels}))
 if packet~=published then
  local saved=inzoi.cli.execute('uimod.cfg_save mod_id='..C.mod_id..' section='..C.section..' key=localization_state value='..packet)
  if saved then published=packet;published_culture=M.culture end
 end
 return M.culture
end
function M.tick(dt)
 age=(age or 0)+dt;if age>=2 then age=0;M.refresh()end
end
function M.text(english,values)
 local data=library().messages
 local text=(data[M.culture]or {})[english]or(data['en-US']or {})[english]or english
 return (text:gsub('{([%w_]+)}',function(key)return values and values[key]~=nil and tostring(values[key])or '{'..key..'}'end))
end
function M.label(kind,id,english)
 local data=library().labels;local key=kind..'.'..id
 return (data[M.culture]or {})[key]or(data['en-US']or {})[key]or english
end
function M.toast(english)
 return inzoi.cli.execute('toast.show message='..string.format('%q',M.text(english))..' lifetime=5 immediate=true')
end
return M
