-- Optional material matching; pack profiles declare every source and destination.
local Profiles=require("SceneZOI.Profiles")
local M={}

local function valid(color)
    if not color then return false end
    for _, channel in ipairs({"R", "G", "B"}) do
        local value = color[channel]
        if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then return false end
    end
    return true -- A genuine black color is valid, not evidence of a missing value.
end

local function lookup(map, name)
    if map then return map:Find(name) end
end

local function dynamic(material)
    return material and material:IsA(UE.UMaterialInstanceDynamic:StaticClass())
end

local function hair_color(actor, parameter)
    local appearance = actor.AppearanceComponent
    local hair = appearance.AppearanceSetting.FinalHead.Hair
    -- FinalHead includes the resolved style. Explicit color overrides take priority.
    local color = lookup(hair.OverrideVectorParameters, parameter)
    if valid(color) then return color, "override" end
    color = lookup(hair.VectorParameters, parameter)
    if valid(color) then return color, "appearance" end
    -- Some styles leave their default color in the applied material instead of the
    -- appearance maps. Read that existing MID without modifying the character.
    for name, component in pairs(appearance.NamedComponents:ToTable()) do
        if tostring(name):lower() == "hair" or
            (appearance.LoadedHairMesh and component:GetSkeletalMeshAsset() == appearance.LoadedHairMesh) then
            local material = component:GetMaterial(0)
            if dynamic(material) then
                color = material:K2_GetVectorParameterValue(parameter)
                if valid(color) then return color, "material" end
            end
        end
    end
end

local function key(color)
    return string.format("%.6f,%.6f,%.6f", color.R, color.G, color.B)
end

function M.ready(attachment, body, profile_id)
    local profile=Profiles.material(profile_id)
    local mesh = body and body.mesh
    local material = mesh and mesh:GetMaterial(profile.source_material)
    -- A section layout can be ready before the appearance builder installs its
    -- final skin MID. Do not guess a color or expose the attachment during that gap.
    if not dynamic(material) then
        if attachment.color then attachment.color.frames = 0 end
        return false
    end
    local skin = material:K2_GetVectorParameterValue(profile.source_skin_parameter)
    local chromophore = material:K2_GetVectorParameterValue(profile.source_chromophore_parameter)
    local hair, source = hair_color(attachment.actor,profile.source_hair_parameter)
    if not valid(skin) or not valid(hair) then return false end
    assert(valid(chromophore) and chromophore.R > 0.000001 and chromophore.G > 0.000001 and chromophore.B > 0.000001,
        "Body material has no usable Chromophore Contribution for stock skin matching")
    local component = attachment.component
    local state = attachment.color
    if not state then
        state = {frames = 0}
        attachment.color = state -- Own partial creation until attachment cleanup.
        local skin_slot, hair_slot = component:GetMaterialIndex(profile.skin_slot), component:GetMaterialIndex(profile.hair_slot)
        assert(skin_slot >= 0 and hair_slot >= 0 and skin_slot ~= hair_slot, "Configured material slots are unavailable")
        -- Use the materials assigned to the mesh. Only per-attachment instances
        -- are created for tinting; there is no alternate skin asset to load/swap.
        state.skin = component:CreateDynamicMaterialInstance(skin_slot, component:GetMaterial(skin_slot), "SceneZOI_MatchedSkin")
        state.hair = component:CreateDynamicMaterialInstance(hair_slot, component:GetMaterial(hair_slot), "SceneZOI_MatchedHair")
        assert(state.skin and state.hair, "Could not create attachment color materials")
    end
    local signature = key(skin) .. ":" .. key(chromophore) .. ":" .. key(hair)
    if signature ~= state.signature or state.body_material ~= material then
        -- The matched material performs the verified stock ordinary-skin branch
        -- per pixel: desaturation, power 1.15, divide by Chromophore Contribution,
        -- multiply by SkinTone Color. Pass both resolved linear parameters directly.
        -- Dividing here by the default skin tone made colors1 visibly too pale.
        state.skin:SetVectorParameterValue(profile.skin_parameter, UE.FLinearColor(skin.R, skin.G, skin.B, 1))
        state.skin:SetVectorParameterValue(profile.chromophore_parameter, UE.FLinearColor(chromophore.R, chromophore.G, chromophore.B, 1))
        state.hair:SetVectorParameterValue(profile.hair_parameter, UE.FLinearColor(hair.R, hair.G, hair.B, 1))
        state.signature, state.body_material, state.frames = signature, material, 0
        state.skin_value, state.chromophore_value, state.hair_value, state.hair_source = key(skin), key(chromophore), key(hair), source
    end
    -- The color instances belong solely to this temporary component; destroying it
    -- and dropping attachment state releases them without touching body/hair MIDs.
    state.frames = state.frames + 1
    return state.frames >= 2
end

function M.status(attachment)
    local state = attachment and attachment.color
    if not state or not state.signature then return "color=waiting" end
    return "skin_linear=" .. state.skin_value .. ":skin_chromophore=" .. state.chromophore_value ..
        ":hair_linear=" .. state.hair_value .. ":hair_source=" .. state.hair_source
end

return M
