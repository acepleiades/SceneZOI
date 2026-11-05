package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local V=require('SceneZOI.DataValidation');local D=require('SceneZOI.LocalizationData');local J=require('SceneZOI.Json');local P=require('SceneZOI.Protocol')
local source={by_kind={localization={}}};local function add(d)source.by_kind.localization[#source.by_kind.localization+1]={source=d.id,data=d}end
local d={schema_version=1,id='designer.localization',translations={['en-US']={messages={['Exit']='Exit',['From {min} to {max}']='From {min} to {max}'},labels={['scene.designer.hub']='English hub'}},['fr-FR']={messages={['Exit']='Quitter',['From {min} to {max}']='De {min} à {max}'},labels={['scene.designer.hub']='Accueil français'}}}}
add(d);local invalid=V.copy(d);invalid.id='bad';invalid.translations['fr-FR'].messages['From {min} to {max}']='Sans paramètres';add(invalid)
local conflict=V.copy(d);conflict.id='conflict';conflict.translations['fr-FR'].messages.Exit='OTHER';conflict.translations['fr-FR'].messages.New='Nouveau';add(conflict)
local compiled=D.compile(source);assert(#compiled.warnings==2 and compiled.messages['fr-FR'].Exit=='Quitter'and not compiled.messages['fr-FR'].New,'Reject malformed/conflicting documents atomically')
package.loaded['SceneZOI.DataFiles']={get=function()return source end}
local language='fr-FR';local writes={}
inzoi={cli={execute=function(line)
 if line=='gameplay.get_settings'then return true,'',J.encode({language=language})end
 writes[#writes+1]=line;return true
end}}
local L=require('SceneZOI.Localization');assert(L.text('Exit')=='Exit','English fallback before native refresh')
L.refresh();assert(L.text('Exit')=='Quitter'and L.text('From {min} to {max}',{min=10,max=500})=='De 10 à 500')
assert(L.label('scene','designer.hub','Original')=='Accueil français');assert(L.label('scene','missing','Original')=='Original')
language='pt_BR';L.refresh();assert(L.culture=='pt-BR'and L.text('Exit')=='Exit'and L.label('scene','designer.hub','Original')=='English hub','Missing locale/entry falls back to English independently')
for _,culture in ipairs({'ko-KR','en-US','zh-CN','zh-TW','ja-JP','ru-RU','es-ES','pt-BR','pt-PT','de-DE','fr-FR','it-IT','pl-PL','tr-TR','nl-NL'})do assert(L.normalize(culture)==culture)end
language='xx';L.refresh();assert(L.culture=='en-US')
language='fr-FR';L.tick(2);assert(L.culture=='fr-FR','Idle refresh follows game setting changes')
L.toast('Exit');assert(writes[#writes]:find('Quitter',1,true))
print('Localization passed: native culture refresh, all 15 aliases, safe placeholders, independent English fallback, inert owner declarations, isolated conflicts and localized toasts.')
