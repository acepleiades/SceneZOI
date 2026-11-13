package.path = 'modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;' .. package.path
local V = require('SceneZOI.DataValidation')
local male, female, accessory = '/Optional/M.M', '/Optional/F.F', '/Optional/A.A'
local mesh, named_mesh, named_track = '/Test/Mesh.Mesh', '/Test/Prop.Prop', '/Optional/P.P'
local assets = {}
UE = {UObject = {Load = function(path)
    local length = assets[path]
    if length == true then return {} end
    if length then return {GetPlayLength = function() return length end} end
end}}
inzoi = {cli = {execute = function() return true end}}
local function scene(name)
    return {id = 'test.' .. name, label = name, kind = 'loop', duration = 10, fps = 60,
        participants = {lead = {body = 'male'}, partner = {body = 'female'}},
        anchor_participant = 'lead', tracks = {lead = male, partner = female}, navigation = {}}
end
local hub = scene('hub')
hub.hub = hub.id
hub.task_completion_routes = {lead = {charge = 'test.optional'}}
local target = scene('optional')
target.hide_if_tracks_missing = true
target.starting_hub = true
target.attachments = {prop = {participant = 'partner', socket = 'hand_l', reference_bone = 'root',
    mesh = named_mesh, animation = named_track}}
local transition = scene('handoff')
transition.kind, transition.destination = 'transition', target.id
hub.navigation = {{id = 'handoff', target = transition.id}}
local source = {by_kind = {
    scene_pack = {{source = 'test', data = {schema_version = 3, id = 'test',
        nodes = {hub, target, transition},
        extensions = {{hub = hub.id, id = 'test.optional', target = target.id}}}}},
    scene_task = {{source = 'task', data = {schema_version = 1, id = 'charge', label = 'Charge', maximum = 10}}},
    body_profile = {{source = 'profile', data = {schema_version = 2, id = 'test.profile', section = 1,
        coverage_bit = 1, patch_mesh = mesh, patch_material_slot = 'skin'}}},
    coverage_attachment = {{source = 'rule', data = {schema_version = 1, id = 'test.rule', body = 'male',
        section = 1, attachment = {mesh = mesh, socket = 'pelvis', reference_bone = 'pelvis',
            body_profile = 'test.profile'}, node_animations = {[target.id] = accessory}}}},
}}
package.loaded['SceneZOI.DataFiles'] = {get = function() return source end, refresh = function() end}
local lead = {id = '1', body = 'male', GetEntityId = function() return {Value = 1} end}
local partner = {id = '2', body = 'female'}
package.loaded['SceneZOI.Traits'] = {
    capture = function(actor) return actor end,
    matches = function(requirement, person) return requirement.body == person.body end,
}
package.loaded['SceneZOI.Runtime'] = {
    actors = {['1'] = lead, ['2'] = partner},
    snapshot = function() end,
    check_start_distance = function() end,
}
UE.UGameplayStatics = {GetPlayerController = function() return {GetCharacterEntityId = lead.GetEntityId} end}
local J = require('SceneZOI.Json')
local response
inzoi.message = {send_to_sim = function(_, kind, raw)
    if kind == 'SceneZOI.API.Response' then response = J.decode(raw) end
end}
local API = require('SceneZOI.AddonAPI')
local Sessions = require('SceneZOI.Sessions')
local serial = 0
local function request(operation, arguments)
    serial = serial + 1
    response = nil
    API.receive(lead, J.encode({api_version = 1, addon_id = 'test.addon', client_id = 'test.client',
        request_id = 'request.' .. serial, operation = operation, arguments = arguments}))
    return assert(response)
end
local Catalog = require('SceneZOI.Catalog')
local function check(expected)
    source = V.copy(source)
    local data = Catalog.refresh()
    local origin = assert(data.nodes[hub.id])
    assert((data.nodes[target.id] ~= nil) == expected)
    assert((data.nodes[transition.id] ~= nil) == expected)
    assert(#Catalog.public_node(origin).navigation == (expected and 2 or 0))
    assert((origin.task_completion_routes.lead.charge == target.id) == expected)
    assert(pcall(Catalog.get, target.id) == expected)

    local lookup = request('get_scene', {scene_id = target.id})
    assert(lookup.ok == expected)
    local discovery = {participants = {'1', '2'}, search = {starting_hub_only = true}}
    local found = request('find_scenes', discovery)
    assert(found.ok and found.result.count == (expected and 1 or 0))
    if expected then assert(found.result.scenes[1].scene_id == target.id) end
    local choice = request('choose_random_scene', discovery)
    assert(choice.ok and choice.result.count == found.result.count)
    assert(expected and choice.result.scene.scene_id == target.id or not expected and choice.result.scene == J.null)

    local args = {initiator = '1', participants = discovery.participants, scene_id = target.id}
    local preflight = request('validate_start', args)
    assert(preflight.ok and preflight.result.valid == expected)
    assert(expected and preflight.result.scene_id == target.id or not expected and preflight.result.code == 'no_matching_scenes')
    if not expected then
        local named = request('start_scene', args)
        assert(not named.ok and named.code == 'no_matching_scenes')
        args.search = discovery.search
        args.scene_id = nil
        for _, operation in ipairs({'start_random_scene', 'start_at_hub', 'start_autonomous_scene'}) do
            if operation == 'start_autonomous_scene' then args.end_policy = {type = 'duration', seconds = 60} end
            local start = request(operation, args)
            assert(not start.ok and start.code == 'no_matching_scenes', operation .. ': ' .. tostring(start.message))
        end
        args.scene_id = target.id
        args.search = nil
        local autonomous = request('start_autonomous_scene', args)
        assert(not autonomous.ok and autonomous.code == 'no_matching_scenes')
    end
    assert(not API.has_pending() and Sessions.holder('1') == nil and Sessions.holder('2') == nil)
end
check(false)
assets[male] = 10
check(false)
assets[female] = 10
assets[mesh] = true
assets[named_mesh] = true
assets[named_track] = 10
check(false)
assets[accessory] = 9
check(false)
assets[accessory] = 10
check(true)
assets[named_mesh] = nil
check(false)
assets[named_mesh] = true
assets[named_track] = nil
check(false)
print('Optional tracks passed: no tracks, partial tracks, all tracks, invalid duration, attachment assets and catalog graph pruning.')
