package.path = "modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;" .. package.path

local furniture = "_UIMod_MyGame_ABC123/venue~scenezoi_furniture"
local ground = "MyGame_SelectVenue"
local romance = "MyGame_FindVenue"
local icon_path = "/Game/UI/Icon/Example.Example"
local tooltip = {label = "Mood restriction.", translations = {["pt-br"] = "Restrição de humor."}}
local addon = {source = "fixture", data = {
    mood_tooltip = tooltip,
    entries = {
        {id = furniture, menu = "object", label = "Invite Here", translations = {["pt-br"] = "Convidar aqui"},
            icon = icon_path, mood_locks = {"Sad", "Worried"}},
        {id = ground, menu = "object", label = "Invite Here", translations = {["pt-br"] = "Convidar aqui"},
            mood_locks = {"Sad", "Worried"}},
        {id = romance, menu = "talk", label = "Invite", translations = {["pt-br"] = "Convidar"}},
    },
}}

local snapshot = {by_kind = {interaction_menu = {addon}}}
local localization = {culture = "pt-BR", text = function(text) return text end}
package.loaded["SceneZOI.DataFiles"] = {get = function() return snapshot end}
package.loaded["SceneZOI.Localization"] = localization

local emotion = {CurrentEmotionInfo = {EmotionId = "Sad", Level = 2}}
local emotion_class, texture, default_texture, native_texture = {}, {}, {}, {}
local emotion_reads, texture_loads = 0, 0
local has_tooltip = true
local controller = {GetB1Character = function()
    emotion_reads = emotion_reads + 1
    return {K2_GetComponentsByClass = function(_, class)
        assert(class == emotion_class)
        return {emotion}
    end}
end}
inzoi = {UB1EmotionComponent = {StaticClass = function() return emotion_class end}}
UE = {
    UObject = {Load = function(path)
        assert(path == icon_path)
        texture_loads = texture_loads + 1
        return texture
    end},
    UWidgetBlueprintLibrary = {GetBrushResource = function(brush) return brush.texture end},
    UKismetTextLibrary = {TextFromStringTable = function(path, key)
        assert(path == "/Game/Data/String/Data/ST_Emotion.ST_Emotion")
        local mood = key:match("^Emotion_EmotionLevelDatas_Level3_(%a+)_DisableTooltipTextId$")
        return has_tooltip and ("Native tooltip: " .. assert(mood)) or "MISSING STRING TABLE"
    end},
}

local function entry(id, text, icon_visibility, is_talk)
    local label = {text = text, writes = 0}
    function label:GetText() return self.text end
    function label:SetText(value)
        self.text = value
        self.writes = self.writes + 1
    end
    local icon = {visibility = icon_visibility, Brush = {texture = default_texture}}
    function icon:GetVisibility() return self.visibility end
    function icon:SetVisibility(value) self.visibility = value end
    function icon:SetBrushFromTexture(value, match_size) assert(not match_size); self.Brush.texture = value end
    function icon:SetBrushResourceObject(value) self.Brush.texture = value end
    local row = {Data = {InteractionBagId = id, IsDimmed = false, DimmedTooltipText = ""},
        label = label, BW_Image_Icon = icon, visibility = 4, opacity = 1, ToolTipText = "", ToolTipWidget = false}
    if is_talk then row.BW_CategoryText = label else row.BW_Text_Content = label end
    function row:GetVisibility() return self.visibility end
    function row:GetRenderOpacity() return self.opacity end
    function row:SetRenderOpacity(value) self.opacity = value end
    function row:SetToolTipText(value) self.ToolTipText = value end
    return row
end

local sofa = entry(furniture, "", 1)
sofa.ToolTipText = "Previous hover"
local floor = entry(ground, "", 4)
local rejected = entry(furniture, "", 1)
local other = entry("OtherObjectAction", "Water Plant", 4)
local talk = entry(romance, "", 4, true)
local native_talk = entry("NativeMood", "Set the Mood", 4, true)
local menu = require("SceneZOIStarter.MenuRules")

local function apply(objects, talks)
    local frame = menu.frame(controller)
    for _, row in ipairs(objects or {}) do menu.apply(frame, row, true, row.Data.InteractionBagId, row ~= rejected) end
    for _, row in ipairs(talks or {}) do menu.apply(frame, row, false, row.Data.InteractionBagId, true) end
    menu.finish(frame)
end

local objects, talks = {sofa, floor, rejected, other}, {talk, native_talk}
apply(objects, talks)
assert(sofa.label.text == "Convidar aqui" and floor.label.text == sofa.label.text and talk.label.text == "Convidar")
assert(sofa.BW_Image_Icon.visibility == 4 and sofa.BW_Image_Icon.Brush.texture == texture)
assert(floor.BW_Image_Icon.Brush.texture == default_texture)
assert(rejected.label.writes == 0 and rejected.BW_Image_Icon.visibility == 1)
assert(other.label.writes == 0 and native_talk.label.writes == 0)
assert(sofa.opacity == 1 and not sofa.Data.IsDimmed, "A mild mood should leave the action available")
assert(texture_loads == 1 and emotion_reads == 1, "Matching rows share the frame mood and cached texture")
apply(objects, talks)
assert(sofa.label.writes == 1 and talk.label.writes == 1 and texture_loads == 1)

emotion.CurrentEmotionInfo.Level = 3
apply(objects, talks)
assert(sofa.opacity == 0.5 and sofa.Data.IsDimmed and sofa.ToolTipText == "Native tooltip: Sad")
assert(floor.opacity == 0.5 and floor.Data.IsDimmed and floor.Data.DimmedTooltipText == "Native tooltip: Sad")
assert(floor.ToolTipText == "" and talk.opacity == 1 and native_talk.opacity == 1)

has_tooltip = false
emotion.CurrentEmotionInfo.EmotionId = "Worried"
floor.Data = {InteractionBagId = ground, IsDimmed = true, DimmedTooltipText = "Native rule"}
apply(objects, talks)
assert(sofa.ToolTipText == "Restrição de humor." and sofa.Data.DimmedTooltipText == "Restrição de humor.")
assert(floor.opacity == 1 and floor.Data.IsDimmed and floor.Data.DimmedTooltipText == "Native rule")

-- Rebinding a list entry with a native label and image must preserve both.
sofa.Data.InteractionBagId = "UnrelatedFurniture"
sofa.Data.DimmedTooltipText = "New action restriction"
sofa.label.text = "Native caption"
sofa.BW_Image_Icon.Brush.texture = native_texture
sofa.ToolTipText = "Native hover"
apply(objects, talks)
assert(sofa.label.text == "Native caption" and sofa.ToolTipText == "Native hover")
assert(sofa.BW_Image_Icon.visibility == 4 and sofa.BW_Image_Icon.Brush.texture == native_texture)
assert(sofa.opacity == 1 and sofa.Data.IsDimmed and sofa.Data.DimmedTooltipText == "New action restriction")

-- The shared loop can close without a scan, then apply again on reopening.
menu.stop()
assert(floor.label.text == "" and talk.label.text == "")
localization.culture = "en-US"
sofa = entry(furniture, "Original caption", 1)
local previous_texture = texture
texture = {}
function sofa.BW_Image_Icon:SetBrushFromTexture(value, match_size)
    assert(not match_size and value ~= previous_texture, "The previous native texture was collected")
    self.Brush.texture = value
end
apply({sofa}, {talk})
assert(sofa.label.text == "Invite Here" and talk.label.text == "Invite")
assert(sofa.BW_Image_Icon.Brush.texture == texture and texture_loads == 2,
    "Reopening a menu must acquire a fresh native texture")
assert(sofa.ToolTipText == "Mood restriction.")
apply({}, {})
assert(sofa.label.text == "Original caption" and talk.label.text == "")
assert(sofa.BW_Image_Icon.visibility == 1 and sofa.BW_Image_Icon.Brush.texture == default_texture)
assert(sofa.opacity == 1 and not sofa.Data.IsDimmed and sofa.Data.DimmedTooltipText == "" and sofa.ToolTipText == "")

-- A malformed declaration cannot prevent other add-ons from applying.
snapshot = {by_kind = {interaction_menu = {{source = "invalid", data = {entries = {{id = ground, menu = "other"}}}}, addon}}}
apply({sofa}, {talk})
assert(sofa.label.text == "Invite Here")
-- Conflicting rules for the same ID are ignored, including after refresh.
snapshot = {by_kind = {interaction_menu = {addon, {source = "conflict", data = {
    entries = {{id = furniture, menu = "object", label = "Conflicting label"}},
}}}}}
apply({sofa}, {talk})
assert(sofa.label.text == "Original caption" and talk.label.text == "Invite")
menu.stop()
print("Shared interaction rules preserve native rows, localized captions, mood locks and recycled icons.")
