-- Optional presentation for exact add-on interaction IDs. Gameplay and click
-- handling stay with the add-on; the shared menu supplies the native rows.
local Files = require("SceneZOI.DataFiles")
local Diagnostics = require("SceneZOI.Diagnostics")
local Localization = require("SceneZOI.Localization")
local Validate = require("SceneZOI.DataValidation")

local M = {}
local COLLAPSED, HIDDEN, ICON_VISIBLE = 1, 2, 4
local DIMMED_OPACITY = 0.5
local EMOTION_TEXT = "/Game/Data/String/Data/ST_Emotion.ST_Emotion"
local entry_fields = {"id", "menu", "label", "translations", "icon", "mood_locks"}
local source, compiled
local changed, failed_icons = {}, {}

local function readLabel(spec)
    local label = Validate.name(spec.label)
    local translations = spec.translations or {}
    assert(Validate.object(translations), "Expected menu translations by culture")
    local count = 0
    for culture, value in pairs(translations) do
        assert(type(culture) == "string" and culture:match("^[a-z][a-z]%-[a-z][a-z]$"), "Invalid menu culture")
        Validate.name(value)
        count = count + 1
    end
    assert(count <= 32, "Too many menu translations")
    return {label = label, translations = translations}
end

local function readRules(data)
    Validate.fields(data, {"entries", "mood_tooltip"}, {"entries"})
    local tooltip
    if data.mood_tooltip ~= nil then
        Validate.fields(data.mood_tooltip, {"label", "translations"}, {"label"})
        tooltip = readLabel(data.mood_tooltip)
    end
    local rules = {object = {}, talk = {}}
    for _, entry in ipairs(Validate.array(data.entries, 64)) do
        Validate.fields(entry, entry_fields, {"id", "menu", "label"})
        local menu = rules[entry.menu]
        assert(menu and type(entry.id) == "string" and entry.id:match("^[%w_/%-~%.]+$"), "Invalid menu or interaction ID")
        local id = Validate.name(entry.id)
        assert(not menu[id], "Duplicate interaction ID " .. id)
        local rule = readLabel(entry)
        rule.injected = entry.menu == "object" and id:sub(1, 7) == "_UIMod_"
        if entry.icon ~= nil then
            assert(rule.injected, "A fallback icon requires a native UI Mod object trigger")
            rule.icon = Validate.asset(entry.icon)
        end
        if entry.mood_locks ~= nil then
            assert(entry.menu == "object", "Mood presentation applies to object actions")
            rule.moods = {}
            for _, mood in ipairs(Validate.array(entry.mood_locks, 32)) do
                assert(type(mood) == "string" and #mood <= 64 and mood:match("^%a[%w_]*$"), "Invalid native mood ID")
                rule.moods[mood] = true
            end
            assert(next(rule.moods), "Expected at least one mood lock")
            rule.tooltip = tooltip
        end
        menu[id] = rule
    end
    return rules
end

local function registry()
    local snapshot = Files.get()
    if source == snapshot then return compiled end
    source = snapshot
    compiled = {object = {}, talk = {}}
    for _, doc in ipairs(snapshot.by_kind.interaction_menu or {}) do
        local ok, contribution = pcall(readRules, doc.data)
        if ok then
            for menu, entries in pairs(contribution) do
                for id, rule in pairs(entries) do
                    local current = compiled[menu][id]
                    if current == nil then
                        compiled[menu][id] = rule
                    elseif current ~= false then
                        compiled[menu][id] = false
                        print("[SceneZOI] Interaction menu warning: conflicting rule for " .. id)
                    end
                end
            end
        else
            print("[SceneZOI] Interaction menu warning: " .. doc.source .. ": " .. tostring(contribution))
        end
    end
    return compiled
end

local function translated(spec, culture)
    return spec.translations[culture] or spec.translations["en-us"] or spec.label
end

---@param controller AB1PlayerController?
local function blockingMood(controller)
    if not controller or not inzoi.UB1EmotionComponent then return end
    local character = controller:GetB1Character()
    if not character then return end
    local components = character:K2_GetComponentsByClass(inzoi.UB1EmotionComponent:StaticClass())
    local emotion = components and components[1]
    local info = emotion and emotion.CurrentEmotionInfo
    if info and (tonumber(info.Level) or 0) >= 3 then return tostring(info.EmotionId) end
end

local function nativeTooltip(mood)
    local ok, value = pcall(function()
        return tostring(UE.UKismetTextLibrary.TextFromStringTable(EMOTION_TEXT,
            "Emotion_EmotionLevelDatas_Level3_" .. mood .. "_DisableTooltipTextId"))
    end)
    if ok and value ~= "" and value ~= "nil" and not value:find("MISSING STRING TABLE", 1, true) then return value end
end

local function brushResource(icon)
    return UE.UWidgetBlueprintLibrary.GetBrushResource(icon.Brush)
end

local function applyIcon(frame, row, state, path)
    local icon = row.BW_Image_Icon
    if not icon or icon:GetVisibility() ~= COLLAPSED then return end
    -- A Lua reference alone does not keep an Unreal texture alive. Resolve it
    -- in the current scan, then let the native brush hold it while it is shown.
    local texture = frame.textures[path]
    if not texture then
        texture = assert(UE.UObject.Load(path), "Interaction menu texture could not be loaded")
        frame.textures[path] = texture
    end
    local readable, original = pcall(brushResource, icon)
    icon:SetBrushFromTexture(texture, false)
    state.icon = {widget = icon, readable = readable, original = original, applied = texture}
    icon:SetVisibility(ICON_VISIBLE)
end

local function restoreMood(row, remembered, bound)
    if remembered.opacity ~= nil and row:GetRenderOpacity() == DIMMED_OPACITY then
        row:SetRenderOpacity(remembered.opacity)
    end
    if remembered.hover ~= nil and tostring(row.ToolTipText) == remembered.applied then
        row:SetToolTipText(remembered.hover)
    end
    local data = row.Data
    if bound and data == remembered.data and data.DimmedTooltipText == remembered.applied then
        data.IsDimmed = remembered.is_dimmed
        data.DimmedTooltipText = remembered.tooltip
    end
end

local function dim(row, data, state, rule, mood, frame)
    local remembered = state.mood
    if remembered and (remembered.data ~= data or not data.IsDimmed or data.DimmedTooltipText ~= remembered.applied) then
        restoreMood(row, remembered, false)
        state.mood = nil
        remembered = nil
    end
    -- The original native reason wins when the row was already disabled.
    if not remembered and data.IsDimmed then return end
    if not remembered then
        remembered = {data = data, is_dimmed = data.IsDimmed, tooltip = data.DimmedTooltipText}
        state.mood = remembered
    end
    if remembered.kind ~= mood or remembered.culture ~= frame.culture then
        remembered.kind, remembered.culture = mood, frame.culture
        if frame.tooltip == nil then frame.tooltip = nativeTooltip(mood) or false end
        local message = frame.tooltip or (rule.tooltip and translated(rule.tooltip, frame.culture))
            or Localization.text("This action is unavailable in this mood.")
        local hover = rule.injected and row.ToolTipText
        if hover ~= nil and hover ~= false and not row.ToolTipWidget
            and (remembered.hover == nil or tostring(hover) == remembered.applied) then
            if remembered.hover == nil then remembered.hover = tostring(hover) end
            row:SetToolTipText(message)
        end
        remembered.applied = message
    end
    if not data.IsDimmed then data.IsDimmed = true end
    if data.DimmedTooltipText ~= remembered.applied then data.DimmedTooltipText = remembered.applied end
    local opacity = row:GetRenderOpacity()
    if opacity > DIMMED_OPACITY then
        remembered.opacity = opacity
        row:SetRenderOpacity(DIMMED_OPACITY)
    end
end

local function restore(row)
    local state = changed[row]
    if not state then return end
    changed[row] = nil
    local caption = state.caption
    if caption and tostring(caption.widget:GetText()) == caption.applied then
        caption.widget:SetText(caption.original)
    end
    local icon = state.icon
    if icon then
        local ok, current = pcall(brushResource, icon.widget)
        if not ok or current == icon.applied then
            if icon.widget:GetVisibility() == ICON_VISIBLE then icon.widget:SetVisibility(COLLAPSED) end
            if icon.readable and ok then pcall(function() icon.widget:SetBrushResourceObject(icon.original) end) end
        end
    end
    if state.mood then
        local data = row.Data
        restoreMood(row, state.mood, data and tostring(data.InteractionBagId) == state.id)
    end
end

---@param controller AB1PlayerController?
function M.frame(controller)
    return {rules = registry(), controller = controller, culture = (Localization.culture or "en-US"):lower(),
        kept = {}, textures = {}}
end

---@param row UB1ObjectInteractionListEntry|UB1TalkInteractionListEntry
---@param isObject boolean
---@param id string?
---@param permitted boolean
function M.apply(frame, row, isObject, id, permitted)
    local rules = isObject and frame.rules.object or frame.rules.talk
    local rule = rules[id]
    if not rule or not permitted then
        restore(row)
        return
    end
    local visibility = row:GetVisibility()
    if visibility == COLLAPSED or visibility == HIDDEN then
        restore(row)
        return
    end
    local state = changed[row]
    if state and state.rule ~= rule then
        restore(row)
        state = nil
    end
    state = state or {id = id, rule = rule}
    changed[row] = state
    frame.kept[row] = true

    local caption = isObject and row.BW_Text_Content or not isObject and row.BW_CategoryText
    if caption then
        local current, label = tostring(caption:GetText()), translated(rule, frame.culture)
        if current ~= label then
            local previous = state.caption
            local original = previous and previous.widget == caption and previous.applied == current and previous.original or current
            state.caption = {widget = caption, original = original, applied = label}
            caption:SetText(label)
        end
    end
    if rule.icon and not failed_icons[rule.icon] then
        local ok, err = pcall(applyIcon, frame, row, state, rule.icon)
        if not ok then
            -- Keep filtering and styling the menu. Retry the optional image
            -- on the next open instead of loading a bad asset every frame.
            failed_icons[rule.icon] = true
            Diagnostics.record("interaction_menu_icon_failed", {
                interaction_id = id, asset = rule.icon, detail = Diagnostics.detail(err),
            })
        end
    end
    if rule.moods then
        if frame.mood == nil then
            local ok, result = pcall(blockingMood, frame.controller)
            frame.mood = ok and result or false
        end
        local mood = frame.mood
        if mood and rule.moods[mood] then
            dim(row, row.Data, state, rule, mood, frame)
        elseif state.mood then
            restoreMood(row, state.mood, true)
            state.mood = nil
        end
    end
end

function M.finish(frame)
    for row in pairs(changed) do
        if not frame.kept[row] then pcall(restore, row) end
    end
end

function M.stop()
    for row in pairs(changed) do pcall(restore, row) end
    failed_icons = {}
end

return M
