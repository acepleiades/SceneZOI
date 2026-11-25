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
hub.attachment_rest_rotations = {lead = {['test.rule.lead'] = {joint_1 = {0, -20, 5}}}}
local target = scene('optional')
target.hide_if_tracks_missing = true
target.starting_hub = true
target.attachments = {prop = {participant = 'partner', socket = 'hand_l', reference_bone = 'root',
    mesh = named_mesh, animation = named_track}}
local transition = scene('handoff')
transition.kind, transition.destination = 'transition', target.id
hub.navigation = {{id = 'handoff', target = transition.id}}
local source = {by_kind = {
    scene_pack = {{owner = 'test', source = 'test', data = {schema_version = 3, id = 'test',
        nodes = {hub, target, transition},
        extensions = {{hub = hub.id, id = 'test.optional', target = target.id}}}}},
    scene_task = {{owner = 'test', source = 'task', data = {schema_version = 1, id = 'charge', label = 'Charge', maximum = 10}}},
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
check(true)
assert(not Catalog.get(target.id).attachments['test.rule.lead'].animation,
    'A missing optional fallback clip must keep its mesh at rest without pruning the scene')
assets[accessory] = 9
check(true)
assert(not Catalog.get(target.id).attachments['test.rule.lead'].animation,
    'A mismatched optional fallback clip must also keep its mesh at rest')
assets[accessory] = 10
check(true)
assets[named_mesh] = nil
check(false)
assets[named_mesh] = true
assets[named_track] = nil
check(false)
assets[named_track] = 10
assert(not Catalog.get_snapshot().nodes[target.id], 'Ongoing requests use the cached catalog')
assert(Catalog.refresh(true).nodes[target.id], 'Startup rechecks mounted assets even when declarations are unchanged')
local resolved_hub, resolved_target = Catalog.get(hub.id), Catalog.get(target.id)
local trackless = resolved_hub.attachments['test.rule.lead']
assert(trackless and not trackless.animation)
assert(V.equal(resolved_hub.attachment_rest_rotations.lead['test.rule.lead'].joint_1, {0, -20, 5}))
assert(resolved_target.attachments['test.rule.lead'].animation == accessory)
local SceneData = require('SceneZOI.SceneData')
for _,rotation in ipairs({{0, 0}, {0, 0, 0, 0}, {0, math.huge, 0}, {0, 0/0, 0}, {false, 0, 0},
                           {0, 0, -181}, {x = 0, y = 0, z = 0}}) do
    local invalid = V.copy(hub)
    invalid.attachment_rest_rotations.lead['test.rule.lead'].joint_1 = rotation
    assert(not pcall(SceneData.node, invalid, 'test'), 'Invalid attachment rotation was accepted')
end
local unbound = V.copy(hub)
unbound.attachment_rest_rotations.stranger = unbound.attachment_rest_rotations.lead
local accepted, error_message = pcall(SceneData.node, unbound, 'test')
assert(not accepted and error_message:find('Unbound attachment rotation owner stranger in test.hub', 1, true))

local Subsystems = require('SceneZOI.Subsystems')
local Diagnostics = require('SceneZOI.Diagnostics')
local warnings = {}
Diagnostics.record = function(event, fields)
    assert(event == 'attachment_rest_pose_warning')
    assert(fields.scene_id == hub.id)
    warnings[fields.attachment_id] = fields
end
resolved_hub.attachment_rest_rotations.lead.absent = {joint_1 = {0, 5, 0}}
resolved_hub.attachment_rest_rotations.lead.empty = {}
resolved_hub.attachment_rest_rotations.partner = {['test.rule.lead'] = {joint_1 = {0, 5, 0}}}
local loaded = Subsystems.load(resolved_hub, hub.duration)
assert(loaded[1].engine.id ~= 'attachment', 'Covered attachments can be declared without being instantiated')
assert(warnings.absent.participant_role == 'lead' and warnings.absent.detail == 'No attachment with this ID is declared for the scene.')
assert(warnings['test.rule.lead'].participant_role == 'partner' and warnings['test.rule.lead'].declared_role == 'lead')
assert(not warnings.empty, 'An empty map must not create a dangling reference warning')
assert(not warnings['test.rule.lead'].bone, 'Ownership warnings describe an attachment, not a bone')

warnings = {}
resolved_hub.attachment_rest_rotations.lead.absent = nil
resolved_hub.attachment_rest_rotations.partner = {prop = {joint_1 = {0, 5, 0}}}
local retained = {id='prop', owner_id=partner.id, engine={id='attachment'},
    context={node={attachment={participant='partner', mesh=named_mesh,
        socket='hand_l', reference_bone='root', retain_for_session=true}}}}
lead.AppearanceComponent = {AppearanceSetting={FinalStyle={Outfit={Garments={
    ToTable=function() return {{BodyFlags=1 << 1}} end,
}}}}}
loaded = Subsystems.load(resolved_hub, hub.duration, {
    participants={{id=lead.id, role='lead', body=lead.body, actor=lead}, {id=partner.id, role='partner', body=partner.body, actor=partner}},
    retained_subsystems={['attachment:prop']=retained},
})
assert(loaded[1].retained == retained and next(warnings) == nil,
    'Valid coverage and retained declarations must satisfy ownership before outfit filtering')
print('Optional tracks passed: asset availability, catalog pruning, and attachment pose ownership diagnostics.')

-- A two-goal gameplay add-on should work with its bundled bed route when the
-- optional library is absent. Other body-role combinations depend on content.
local baseBed, optionalBed = scene('base_bed'), scene('optional_bed')
local maleBed, femaleBed = scene('male_bed'), scene('female_bed')
local nodes = {baseBed, optionalBed}
for _, node in ipairs({baseBed, optionalBed, maleBed, femaleBed}) do
    node.furniture = {kind = 'bed.single', surface_height_cm = 0}
    node.tasks = {lead = {charge = {rate = 1}}, partner = {charge = {rate = 1}}}
end
optionalBed.hide_if_tracks_missing = true
optionalBed.tracks.partner = '/Optional/Bed.Bed'
maleBed.participants.partner.body = 'male'
femaleBed.participants.lead.body = 'female'
local gameplay_pack = {owner = 'test', source = 'gameplay', data = {
    schema_version = 3, id = 'test', nodes = nodes, extensions = {},
}}
source.by_kind.scene_pack = {gameplay_pack}
source.by_kind.coverage_attachment = nil
local bed_profile = {kind = 'bed.single', surface_height_cm = 68}
package.loaded['SceneZOI.Furniture'] = {
    available = function(id) if id == '50' then return bed_profile end end,
    prepare = function(id, node) assert(id == '50' and node.furniture.kind == 'bed.single') end,
}
local actors = require('SceneZOI.Runtime').actors
actors['3'] = {id = '3', body = 'male'}
actors['4'] = {id = '4', body = 'female'}
local function bedPreflight(first, second, named)
    return request('validate_start', {initiator = first, participants = {first, second}, furniture_id = '50',
        start_mode = 'start_autonomous_scene', scene_id = named, check_start_distance = false,
        goals = {{participant_id = first, task_id = 'charge'}, {participant_id = second, task_id = 'charge'}}})
end
Catalog.refresh(true)
local fallback = bedPreflight('1', '2')
assert(fallback.ok and fallback.result.valid and fallback.result.scene_id == baseBed.id, J.encode(fallback))
assert(not bedPreflight('1', '2', optionalBed.id).result.valid)
assert(bedPreflight('1', '3').result.code == 'no_matching_scenes')
assert(bedPreflight('2', '4').result.code == 'no_matching_scenes')
assets[optionalBed.tracks.partner] = 10
nodes[#nodes + 1], nodes[#nodes + 2] = maleBed, femaleBed
Catalog.refresh(true)
assert(bedPreflight('1', '2', optionalBed.id).result.valid)
assert(bedPreflight('1', '3', maleBed.id).result.valid)
assert(bedPreflight('2', '4', femaleBed.id).result.valid)
assert(not API.has_pending() and not Sessions.holder('1') and not Sessions.holder('4'))
print('Two-goal single-bed preflight passed with optional tracks and with content-provided same-body routes.')
