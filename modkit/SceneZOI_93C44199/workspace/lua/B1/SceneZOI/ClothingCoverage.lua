-- Native mesh merging removes garment-covered body regions. Unmerged bodies
-- need the same resolved mask, independently of any optional region attachment.
local Diagnostics = require("SceneZOI.Diagnostics")
local M = {}
local REGION_COUNT, FULL, CROTCH = 32, 0xffffffff, 17
local layouts = {}

local function copy(value)
    local result = {}
    for key, item in pairs(value) do result[key] = type(item) == "table" and copy(item) or item end
    return result
end

local function path(value)
    if type(value) == "string" then return value == "None" and "" or value end
    if not value then return "" end
    local asset = value.AssetPath
    local package = tostring(asset.PackageName)
    return package == "None" and "" or package .. "." .. tostring(asset.AssetName)
end

local function flags(setting)
    local result = 0
    for _, garment in pairs(setting.FinalStyle.Outfit.Garments:ToTable()) do
        result = result | (garment.BodyFlags or 0)
    end
    result = result & FULL
    -- FB1AppearanceSetting::CombineBodyFlags preserves Crotch when every bit
    -- is hidden; native merging otherwise cannot produce a valid skeleton.
    if result == FULL then result = result & ~(1 << CROTCH) end
    return result
end

local function source_path(setting)
    local body = setting.FinalBody
    local override = path(body.OverrideMesh)
    return override ~= "" and override or path(body.BodyData.BodyMesh)
end

local function layout(source)
    if layouts[source] then return layouts[source] end
    local asset = assert(UE.UObject.Load(source), "Native body mesh is unavailable")
    local materials = asset.Materials:ToTable()
    assert(#materials == REGION_COUNT, "Native body does not expose the 32-region section layout")
    local result, seen = {}, {}
    for index, material in ipairs(materials) do
        local name = tostring(material.MaterialSlotName)
        assert(name ~= "" and name ~= "None" and not seen[name], "Ambiguous native body material slots")
        result[index], seen[name] = name, true
    end
    layouts[source] = result
    return result
end

local function target_layout(asset, names)
    local candidate = asset.Materials:ToTable()
    assert(#candidate >= REGION_COUNT, "Body variant lacks the native 32-region material layout")
    local found = {}
    for _, material in ipairs(candidate) do
        local name = tostring(material.MaterialSlotName)
        found[name] = (found[name] or 0) + 1
    end
    for _, name in ipairs(names) do
        assert(found[name] == 1, "Body variant needs one unambiguous native region slot: " .. name)
    end
end

local function source_layout(setting)
    local source = source_path(setting)
    assert(source ~= "", "Native body path is unavailable")
    assert(setting.FinalBody.BodyData.bMergeBodyMesh == true, "Native body does not declare section merging")
    return source, layout(source)
end

function M.compatible_body(actor, asset)
    local ok, reason = pcall(function()
        local _, names = source_layout(actor.AppearanceComponent.AppearanceSetting)
        target_layout(asset,names)
    end)
    if ok then return true end
    return false, tostring(reason)
end

local function state(current)
    current.clothing_coverage = current.clothing_coverage or {participants={},warnings={},warning_order={}}
    return current.clothing_coverage
end

local function person(current, participant)
    local all = state(current)
    local key = participant.id or participant.role
    all.participants[key] = all.participants[key] or {participant=participant,snapshots={}}
    return all.participants[key]
end

local function warning(current, record, reason, source, mesh)
    local all = state(current)
    local name = "unavailable"
    pcall(function() name = mesh:GetSkeletalMeshAsset():GetName() end)
    local key = tostring(record.participant.id) .. ":" .. tostring(source) .. ":" .. name .. ":" .. reason
    if all.warnings[key] then return end
    all.warnings[key] = true
    all.warning_order[#all.warning_order + 1] = key
    if #all.warning_order > 64 then all.warnings[table.remove(all.warning_order,1)] = nil end
    Diagnostics.record("clothing_coverage_warning", {session_id=current.token,scene_id=current.node and current.node.id,
        participant_id=record.participant.id,participant_role=record.participant.role,body_mesh=name,
        native_body=source,detail=reason})
end

local release_slot
local function snapshot(record, mesh, asset, source, names)
    local previous
    for _, value in ipairs(record.snapshots) do
        if value.mesh == mesh and value.asset == asset then
            if value.source == source then return value end
            previous = value
            break
        end
    end
    assert(mesh:GetNumMaterials() >= REGION_COUNT, "Rendered body is still merged or uses an unsupported section layout")
    target_layout(asset,names)
    local mapping, seen = {}, {}
    -- Native BodyFlags use the 32-part source's material order. The rendered
    -- variant may reorder those slots, so resolve each source name explicitly.
    for index, name in ipairs(names) do
        local target = mesh:GetMaterialIndex(name)
        assert(target >= 0 and not seen[target], "Rendered body is missing a native region slot: " .. name)
        mapping[index - 1], seen[target] = target, true
    end
    -- A merged body can retain one source slot's name while containing many
    -- regions. Only a complete native slot map establishes safe per-region edits.
    if previous then
        for section, lods in pairs(previous.slots) do
            for lod, owned in pairs(lods) do release_slot(mesh,section,lod,owned) end
        end
        previous.source, previous.mapping, previous.slots = source,mapping,{}
        return previous
    end
    local value = {mesh=mesh,asset=asset,source=source,mapping=mapping,slots={}}
    record.snapshots[#record.snapshots + 1] = value
    return value
end

local function original_from_attachments(current, participant, mesh, asset)
    local host = current.subsystems
    return host and host.body_visibility and host:body_visibility(participant,mesh,asset)
end

release_slot = function(mesh, section, lod, value)
    if not value.owned then return end
    -- A later visible write belongs to its author. Only undo our current mask.
    if mesh:IsMaterialSectionShown(section,lod) == false and value.original ~= false then
        mesh:ShowMaterialSection(section,section,value.original,lod)
    end
    value.owned = false
end

local function apply(current, record, value, mask)
    local mesh, participant = value.mesh, record.participant
    local attachment_originals = original_from_attachments(current,participant,mesh,value.asset)
    local hidden = {}
    for region = 0, REGION_COUNT - 1 do
        local section = value.mapping[region]
        local covered = (mask & (1 << region)) ~= 0
        if covered then hidden[#hidden + 1] = region + 1 end
        local slots = value.slots[section]
        if covered and not slots then slots = {}; value.slots[section] = slots end
        for lod = 0, mesh:GetNumLODs() - 1 do
            local owned = slots and slots[lod]
            if covered then
                local actual = mesh:IsMaterialSectionShown(section,lod)
                if not owned or not owned.owned then
                    local original = actual
                    local attachment = attachment_originals and attachment_originals[section]
                    if attachment and attachment[lod] ~= nil then original = attachment[lod] end
                    owned = {original=original,owned=true}
                    slots[lod] = owned
                end
                if actual ~= false then mesh:ShowMaterialSection(section,section,false,lod) end
            elseif owned then release_slot(mesh,section,lod,owned) end
        end
    end
    record.mask, record.wait = mask, "ready"
    local signature = tostring(value.asset) .. ":" .. value.source .. ":" .. tostring(mask)
    if record.reported ~= signature then
        record.reported = signature
        local name; pcall(function() name = value.asset:GetName() end)
        Diagnostics.record("clothing_coverage_changed", {session_id=current.token,scene_id=current.node and current.node.id,
            participant_id=participant.id,participant_role=participant.role,body_mesh=name,native_body=value.source,
            body_flags=mask,hidden_regions=hidden,mapped_regions=REGION_COUNT})
    end
end

function M.guard(current)
    if current.stopping or current.clothing_coverage and current.clothing_coverage.restored then return true end
    local ready = true
    for _, participant in ipairs(current.participants or {}) do
        local actor = participant.actor
        local setting = actor.AppearanceComponent.AppearanceSetting
        -- Ordinary merged bodies remain entirely under the game's renderer.
        if setting.Body.bUseMeshMerge == false and setting.FinalBody.bUseMeshMerge == false then
            local record = person(current,participant)
            local mesh, source = actor.Mesh
            local supported, names
            supported, source, names = pcall(source_layout,setting)
            if not supported then
                record.wait = tostring(source)
                local located, native = pcall(source_path,setting)
                warning(current,record,tostring(source),located and native or nil,mesh)
            else
              local ok, reason = pcall(function()
                local asset = assert(mesh and mesh:GetSkeletalMeshAsset(), "Rendered body mesh is unavailable")
                local value = snapshot(record,mesh,asset,source,names)
                apply(current,record,value,flags(setting))
              end)
              if not ok then
                record.wait = tostring(reason)
                ready = false
                -- Flags can arrive before native unmerging finishes. Keep the
                -- barrier closed without warning about a routine transient mesh.
                if not current.preparing then warning(current,record,tostring(reason),source,mesh) end
              end
            end
        end
    end
    return ready
end

function M.original_visibility(current, participant, mesh, asset)
    local all = current.clothing_coverage
    local record = all and all.participants[participant.id or participant.role]
    if not record or all.restored then return nil end
    for _, value in ipairs(record.snapshots) do
        if value.mesh == mesh and value.asset == asset then
            local result = {}
            for section, lods in pairs(value.slots) do
                for lod, owned in pairs(lods) do if owned.owned then
                    result[section] = result[section] or {}
                    result[section][lod] = owned.original
                end end
            end
            return next(result) and copy(result) or nil
        end
    end
end

function M.restore(current)
    local all = current.clothing_coverage
    if not all or all.restored then return end
    local failures = {}
    for _, record in pairs(all.participants) do
        for _, value in ipairs(record.snapshots) do
            local ok, failure = pcall(function()
                local mesh = record.participant.actor.Mesh
                if mesh ~= value.mesh or mesh:GetSkeletalMeshAsset() ~= value.asset then return end
                for section, lods in pairs(value.slots) do
                    for lod, owned in pairs(lods) do release_slot(mesh,section,lod,owned) end
                end
            end)
            if not ok then failures[#failures + 1] = tostring(failure) end
        end
    end
    assert(#failures == 0,table.concat(failures,"; "))
    all.restored = true
end

function M.status(current)
    local rows = {}
    for _, record in pairs(current.clothing_coverage and current.clothing_coverage.participants or {}) do
        rows[#rows + 1] = tostring(record.participant.role) .. ":flags=" .. tostring(record.mask or "unknown") .. ":" .. tostring(record.wait)
    end
    table.sort(rows)
    return "clothing_coverage=" .. (#rows > 0 and table.concat(rows,",") or "native")
end

return M
