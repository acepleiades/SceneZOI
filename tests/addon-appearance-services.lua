package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local V=require('SceneZOI.DataValidation')
local session={token='test.1',participants={{id='1',role='male',body='male'}}}
local calls={}
local variants={bodies={{id='test.body',body='male',mesh='/Test/Body.Body'}},
    attachments={{id='test.attachment',mesh='/Test/Attachment.Attachment'}}}
package.loaded['SceneZOI.Catalog']={variants=function(body)
    calls.filter=body;return variants
end}
package.loaded['SceneZOI.Runtime']={
    api_session=function(id)assert(id==session.token,'session_not_found');return session end,
    is_addon_owner=function(addon,client,token)
        assert(token==session.token);return addon=='owner'and client=='client'
    end,
    api_set_appearance=function(current,selections)
        assert(current==session);calls.selections=V.copy(selections);return {accepted=true,temporary=true}
    end,
    api_get_appearance=function(current)
        assert(current==session);return {appearance=V.copy(calls.selections or {})}
    end,
    api_clear_appearance=function(current,id)
        assert(current==session);calls.cleared=id;return {accepted=true,participant_id=id}
    end}
local Services=require('SceneZOI.AddonServices')
local actor={GetEntityId=function()return {Value=1}end}
local function call(operation,args,addon,client)
    local handled,result=Services.execute(actor,{operation=operation,arguments=args,
        addon_id=addon or 'owner',client_id=client or 'client'})
    assert(handled);return result
end
local result=call('get_appearance_variants',{})
assert(result.bodies[1].id=='test.body'and result.attachments[1].id=='test.attachment')
result.bodies[1].id='mutated'
assert(variants.bodies[1].id=='test.body','Query exposed the registry to mutation')
call('get_appearance_variants',{body='male'})
assert(calls.filter=='male')
assert(not pcall(call,'get_appearance_variants',{body='unsupported'}))
assert(not pcall(call,'get_appearance_variants',{session_id=session.token}))
local args={session_id=session.token,appearance={['1']={body_variant='test.body',attachment_variants={male_anatomy='test.attachment'}}}}
assert(not pcall(call,'set_appearance',args,'observer'))
assert(not pcall(call,'set_appearance',args,'owner','different_client'))
assert(not calls.selections,'Unowned write reached Runtime')
result=call('set_appearance',args)
assert(result.accepted and result.temporary and calls.selections['1'].body_variant=='test.body')
assert(call('get_appearance',{session_id=session.token},'observer').appearance['1'].body_variant=='test.body',
    'Read-only appearance inspection must remain available to observers')
session.preparing=true
assert(not pcall(call,'set_appearance',args))
assert(call('get_appearance',{session_id=session.token}).appearance['1'])
session.preparing=false;session.stopping=true
assert(not pcall(call,'set_appearance',args))
session.stopping=false
assert(not pcall(call,'set_appearance',{session_id=session.token,appearance=false}))
assert(not pcall(call,'set_appearance',{session_id=session.token}))
assert(not pcall(call,'set_appearance',{session_id=session.token,appearance={},unknown=true}))
assert(not pcall(call,'get_appearance',{session_id='other'}))
assert(not pcall(call,'get_appearance',{session_id=session.token,body='male'}))
call('set_appearance',{session_id=session.token,appearance={}})
assert(next(calls.selections)==nil,'Empty patch must reach runtime without inventing defaults')
assert(not pcall(call,'clear_appearance',{session_id=session.token,participant_id='1'},'observer'))
assert(not pcall(call,'clear_appearance',{session_id=session.token,participant_id='missing'}))
assert(not pcall(call,'clear_appearance',{session_id=session.token,participant_id=1}))
assert(not calls.cleared)
assert(call('clear_appearance',{session_id=session.token,participant_id='1'}).participant_id=='1')
session.preparing=true
assert(not pcall(call,'clear_appearance',{session_id=session.token,participant_id='1'}))
session.preparing=false;session.stopping=true
assert(not pcall(call,'clear_appearance',{session_id=session.token,participant_id='1'}))
print('Appearance services passed: discoverable variants, creator-only writes, observer reads, readiness and argument validation.')
