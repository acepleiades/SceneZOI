-- A snapshot assembled from the declarations of enabled native data mods.
local Files=require('SceneZOI.DataFiles')
local Data=require('SceneZOI.SceneData')
local ProfileData=require('SceneZOI.ProfileData')
local Profiles=require('SceneZOI.Profiles')
local V=require('SceneZOI.DataValidation')
local Json=require('SceneZOI.Json')
local Protocol=require('SceneZOI.Protocol')
local Config=require('SceneZOI.Config')
local M = {}
local Localization=require('SceneZOI.Localization')
local Meta=require('SceneZOI.Metadata')
local Search=require('SceneZOI.SceneSearch')
function M.refresh()
 local source=Files.get()
 if M.source==source and M.value then return M.value end
 local data=Data.compile(source.by_kind.scene_pack or {})
 data.metadata=Meta.compile(source)
 for _,warning in ipairs(data.metadata.warnings)do data.warnings[#data.warnings+1]=warning end
 for id,node in pairs(data.nodes)do
  local ok,value=pcall(Meta.resolve_scene,data.metadata,node)
  if ok then data.nodes[id]=value else data.nodes[id]=nil;data.warnings[#data.warnings+1]=id..': '..tostring(value)end
 end
 data.tasks=require('SceneZOI.TaskData').compile(source)
 for _,warning in ipairs(data.tasks.warnings)do data.warnings[#data.warnings+1]=warning end
 for _,node in pairs(data.nodes)do for role,tasks in pairs(node.tasks or {})do for id in pairs(tasks)do
  if not data.tasks.definitions[id]then data.warnings[#data.warnings+1]='Unavailable task '..id..' in '..node.id..' for '..role end
 end end end
 for _,node in pairs(data.nodes)do for role,routes in pairs(node.task_completion_routes or {})do for task in pairs(routes)do
  if not data.tasks.definitions[task]then
   data.warnings[#data.warnings+1]='Unavailable task route task '..task..' in '..node.id..' for '..role
   routes[task]=nil
  end
 end end end
 for _,node in pairs(data.nodes)do for role,responses in pairs(node.completion_responses or {})do for task in pairs(responses)do
  if not data.tasks.definitions[task]then
   data.warnings[#data.warnings+1]='Unavailable completion response task '..task..' in '..node.id..' for '..role
   responses[task]=nil
  end
 end end end
 for _,node in pairs(data.nodes)do for role,tasks in pairs(node.task_completion_voices or {})do for task in pairs(tasks)do
  if not data.tasks.definitions[task]then
   data.warnings[#data.warnings+1]='Unavailable task voice response '..task..' in '..node.id..' for '..role
   tasks[task]=nil
  end
 end end end
 data.furniture=require('SceneZOI.FurnitureData').compile(source)
 for _,warning in ipairs(data.furniture.warnings)do data.warnings[#data.warnings+1]=warning end
 data.profiles=ProfileData.compile(source)
 for _,warning in ipairs(data.profiles.warnings)do data.warnings[#data.warnings+1]=warning end
 for _,warning in ipairs(data.warnings)do print('[SceneZOI] Catalog warning: '..warning)end
 M.source,M.value=source,data;Profiles.set(data.profiles)
 M.publish()
 local count=0;for _ in pairs(data.nodes)do count=count+1 end
 pcall(inzoi.cli.execute,'uimod.cfg_save mod_id='..Config.mod_id..' section='..Config.section..' key=catalog_discovery value=nodes:'..count..'+warnings:'..#data.warnings)
 return data
end
function M.public_node(node,current)
 local navigation={}
 for _,edge in ipairs(node.navigation)do
  if not current or Search.allowed(M.get_snapshot().nodes,M.get_snapshot().nodes[edge.target],current.session_restrictions)then local view=V.copy(edge)
   view.label=edge._label_from_target and Localization.label('scene',edge.target,edge.label)or Localization.label('navigation',node.id..'.'..edge.id,edge.label)
   view._label_from_target=nil;navigation[#navigation+1]=view end
 end
 return {id=node.id,label=Localization.label('scene',node.id,node.label),kind=node.kind,destination=node.destination,starting_hub=node.starting_hub==true,
  addon_data=V.copy(node.addon_data or {}),participant_addon_data=V.copy(node.participant_addon_data or {}),
  navigation=Json.array(navigation),participants=V.copy(node.participants),furniture=V.copy(node.furniture),
  tags=Json.array(V.copy(node.tags or {})),participant_tags=V.copy(node.participant_tags or {}),actions=Json.array(V.copy(node.actions or {})),content_rating=node.content_rating}
end
function M.publish(current)
 local public={nodes={}}
 for id,node in pairs(M.get_snapshot().nodes)do public.nodes[id]=M.public_node(node,current)end
 local payload=Json.encode(public)
 if M.public_json~=payload then
  local ok=inzoi.cli.execute('uimod.cfg_save mod_id='..Config.mod_id..' section='..Config.section..' key=catalog_state value='..Protocol.encode(payload))
  if ok then M.public_json=payload end
 end
end

function M.get_snapshot()return M.value or M.refresh()end

function M.get(id,current)
    local node=V.copy(assert(M.get_snapshot().nodes[id], "Unknown scene node: " .. tostring(id)))
    if current then assert(Search.allowed(M.get_snapshot().nodes,node,current.session_restrictions),'Scene is restricted for this session')end
    local rules=M.get_snapshot().profiles.rules
    for rule_id,rule in pairs(rules)do
        for role,requirement in pairs(node.participants)do
            if requirement.body==rule.body then
                local attachment_id=rule_id..'.'..role
                node.attachments=node.attachments or {}
                assert(not node.attachments[attachment_id],'Conflicting exposure attachment ID')
                local spec=V.copy(rule.attachment)
                spec.participant,spec.when_undressed=role,true
                spec.animation=(rule.node_animations or {})[node.id]
                spec.retained_tracks=V.copy(rule.node_animations or {})
                spec._condition={body=rule.body,mesh_name=rule.mesh_name,body_age=rule.body_age,growth_steps=V.copy(rule.growth_steps)}
                spec._cleanup_layers=V.copy(rule.legacy_layers)
                node.attachments[attachment_id]=spec
            end
        end
    end
    for index=#node.navigation,1,-1 do
        local target=M.get_snapshot().nodes[node.navigation[index].target]
        if not target or not V.equal(node.furniture,target.furniture)or(current and not Search.allowed(M.get_snapshot().nodes,target,current.session_restrictions))then table.remove(node.navigation,index)end
    end
    return node
end
function M.simulation(node,participant)
 local layers,seen={},{}
 for _,spec in pairs(node.attachments or {})do
  if spec.participant==participant.role then for _,name in ipairs(spec._cleanup_layers or {})do if not seen[name]then layers[#layers+1]=name;seen[name]=true end end end
 end
 return {id=node.id,participants=node.participants,outfits=node.outfits,cleanup_layers=Json.array(layers)}
end

function M.destination(node, option,current)
    assert(node.kind~="transition", "Navigation is locked during a transition")
    for _, edge in ipairs(node.navigation) do
        if edge.id == option then return M.get(edge.target,current) end
    end
    error("Navigation option is unavailable from this node")
end

function M.task_destination(node,route,current)
    assert(node.id==route.source_node_id and
        ((node.task_completion_routes or {})[route.participant_role]or {})[route.task_id]==route.target,
        "Task completion route is no longer available")
    local target=M.get(route.target,current)
    assert(V.equal(target.participants,node.participants), "Task destination has an incompatible roster")
    assert(V.equal(target.furniture,node.furniture), 'Destination has incompatible furniture context')
    return target
end

function M.transition_destination(node,current)
    assert(node.kind=="transition", "Scene is not a transition")
    local target=M.get(node.destination,current)
    assert(V.equal(target.participants,node.participants), "Transition destination has an incompatible roster")
    assert(V.equal(target.furniture,node.furniture), 'Destination has incompatible furniture context')
    return target
end

function M.load(node)
    local assets, duration = {}, nil
    for role, path in pairs(node.tracks) do
        local asset = UE.UObject.Load(path)
        assert(asset, "Scene animation is unavailable: " .. path)
        local length = asset:GetPlayLength()
        assert(length > 0 and math.abs(length - node.duration) <= 0.0001, "Imported animation has unexpected duration")
        if duration then assert(math.abs(length - duration) <= 0.0001, "Participant animation durations differ") end
        assets[role], duration = asset, length
    end
    return assets, duration
end

return M
