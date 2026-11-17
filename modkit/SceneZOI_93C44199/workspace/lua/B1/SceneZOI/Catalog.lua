-- A snapshot assembled from the declarations of enabled native data mods.
local Files=require('SceneZOI.DataFiles')
local Data=require('SceneZOI.SceneData')
local ProfileData=require('SceneZOI.ProfileData')
local VariantData=require('SceneZOI.VariantData')
local VariantSelection=require('SceneZOI.VariantSelection')
local Profiles=require('SceneZOI.Profiles')
local V=require('SceneZOI.DataValidation')
local Json=require('SceneZOI.Json')
local Protocol=require('SceneZOI.Protocol')
local Config=require('SceneZOI.Config')
local M = {}
local Localization=require('SceneZOI.Localization')
local Meta=require('SceneZOI.Metadata')
local Search=require('SceneZOI.SceneSearch')
local function load_track(path,duration)
 local asset=assert(UE.UObject.Load(path),"Scene animation is unavailable: "..path)
 local length=asset:GetPlayLength()
 assert(length>0 and math.abs(length-duration)<=Config.max_duration_difference,
  "Imported animation has unexpected duration: "..path)
 return asset,length
end

local function check_tracks(node)
 M.load(node)
 for _,spec in pairs(node.attachments or {})do
  assert(UE.UObject.Load(spec.mesh),"Scene attachment mesh is unavailable: "..spec.mesh)
  if spec.animation then load_track(spec.animation,node.duration)end
 end
end

function M.refresh(force)
 local source=Files.get()
 if not force and M.source==source and M.value then return M.value end
 local profiles=ProfileData.compile(source)
 local data=Data.compile(source.by_kind.scene_pack or {},check_tracks)
 data.metadata=Meta.compile(source)
 for _,warning in ipairs(data.metadata.warnings)do data.warnings[#data.warnings+1]=warning end
 for id,node in pairs(data.nodes)do
  local ok,value=pcall(Meta.resolve_scene,data.metadata,node)
  if ok then data.nodes[id]=value else
   data.nodes[id]=nil;data.excluded[id]={code='metadata_invalid'}
   data.warnings[#data.warnings+1]=id..': '..tostring(value)
  end
 end
 local TaskData=require('SceneZOI.TaskData')
 data.tasks=TaskData.compile(source)
 for _,warning in ipairs(data.tasks.warnings)do data.warnings[#data.warnings+1]=warning end
 for _,node in pairs(data.nodes)do
  node._task_keys={}
  local unavailable={}
  for _,field in ipairs({'tasks','task_completion_routes','completion_responses','task_completion_voices','task_completion_sounds'})do
   for role,tasks in pairs(node[field] or {})do
    for id,value in pairs(tasks)do
     local key,reason=TaskData.resolve(data.tasks,node,id)
     if key then node._task_keys[id]=key
     else
      if not unavailable[id] then
       data.warnings[#data.warnings+1]=reason..': '..node.id..' uses '..id
       unavailable[id]=true
      end
      if field~='tasks'then tasks[id]=nil end
     end
     if key and field=='task_completion_sounds'then
      for _,action in ipairs(value)do if action.sound_set then
       local set=data.sound_sets[action.sound_set]
       action._clips=set and set.default and set.default.clips
       if not action._clips then data.warnings[#data.warnings+1]='Unavailable completion sound set '..action.sound_set..' in '..node.id..' for '..role end
      end end
     end
    end
   end
  end
 end
 data.furniture=require('SceneZOI.FurnitureData').compile(source)
 for _,warning in ipairs(data.furniture.warnings)do data.warnings[#data.warnings+1]=warning end
 data.profiles=profiles
 for _,warning in ipairs(data.profiles.warnings)do data.warnings[#data.warnings+1]=warning end
 data.variants=VariantData.compile(source)
 for id,rule in pairs(profiles.rules)do
  if data.variants.attachments[id]then
   data.variants.warnings[#data.variants.warnings+1]='Attachment variant '..id..' shadows the selectable coverage declaration with the same ID; use distinct namespaced IDs'
  else
   local variant=V.copy(rule)
   variant.automatic_fallback=true
   for _,document in ipairs(source.by_kind.coverage_attachment or {})do
    if V.equal(document.data,rule)then variant._owner=document.owner;break end
   end
   data.variants.attachments[id]=variant
  end
 end
 table.sort(data.variants.warnings)
 for _,warning in ipairs(data.variants.warnings)do data.warnings[#data.warnings+1]=warning end
 for _,warning in ipairs(data.warnings)do print('[SceneZOI] Catalog warning: '..warning)end
 M.source,M.value=source,data;Profiles.set(data.profiles)
 require('SceneZOI.Diagnostics').catalog_changed()
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
  appearance=V.copy(node.appearance or {}),
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

function M.resolve_appearance(node,participants,explicit)
    local data=M.get_snapshot()
    return VariantSelection.resolve(node,participants,explicit,data.profiles,data.variants)
end

function M.variants(body)
    assert(body==nil or body=='male' or body=='female','Unsupported appearance body')
    local registry=M.get_snapshot().variants or {bodies={},attachments={}}
    local result={bodies=Json.array({}),attachments=Json.array({})}
    for _,kind in ipairs({'bodies','attachments'})do
        local ids={};for id in pairs(registry[kind])do ids[#ids+1]=id end;table.sort(ids)
        for _,id in ipairs(ids)do
            local definition=registry[kind][id]
            if not body or not definition.body or definition.body==body then
                local view=V.copy(definition)
                view.provider,view._owner=view._owner,nil
                result[kind][#result[kind]+1]=view
            end
        end
    end
    return result
end

function M.get(id,current)
    local node=V.copy(assert(M.get_snapshot().nodes[id], "Unknown scene node: " .. tostring(id)))
    if current then assert(Search.allowed(M.get_snapshot().nodes,node,current.session_restrictions),'Scene is restricted for this session')end
    M.resolve_appearance(node,current and current.participants,current and current.appearance_selections)
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
        local asset, length = load_track(path, node.duration)
        if duration then assert(math.abs(length - duration) <= Config.max_duration_difference,
            "Participant animation durations differ") end
        assets[role], duration = asset, length
    end
    return assets, duration
end

return M
