-- A Runtime with its native and optional engines stubbed, for lifecycle and concurrency regressions.
local M = {}

function M.new()
    local fixture = {cfg = {}, sent = {}, samples = {}, autosave = {acquired = 0}, far = {}, sample_error = nil}
    local function noop() end
    local function yes() return true end
    local Protocol = require("SceneZOI.Protocol")
    local node = {id = "test.node", kind = "loop", participants = {first = {}, second = {}}, anchor_participant = "first", navigation = {}}
    fixture.node = node
    package.loaded["SceneZOI.Native"] = {capture = function(actor) return {actor = actor} end,
        restore = function(person) person.was_restored = true end, release_input = noop}
    package.loaded["SceneZOI.Subsystems"] = {load = function() return {} end, new = function()
        return {guard = noop, prepare = yes, enter = noop, status = function() return "ok" end, leave_node = noop,
            begin_outfit = noop, keep_body_unmerged = function() return false end, restore = noop}
    end}
    package.loaded["SceneZOI.Playback"] = {enter = noop, hold = yes, leave_node = noop, refresh_subsystem_tracks = noop,
        sample = function(current)
            if fixture.sample_error == current.token then error("Scene montage stopped unexpectedly") end
            fixture.samples[current.token] = (fixture.samples[current.token] or 0) + 1
        end}
    package.loaded["SceneZOI.Appearance"] = {capture = noop, ready = yes, status = function() return "" end}
    package.loaded["SceneZOI.Catalog"] = {refresh = noop, get = function() return node end,
        load = function() return {first = "a", second = "b"}, 4 end, simulation = function() return {} end,
        get_snapshot = function() return {nodes = {}, tasks = {}} end, publish = noop}
    package.loaded["SceneZOI.Binding"] = {resolve = function(people)
        local out = {}
        for _, person in ipairs(people) do out[person.role] = person end
        return out
    end}
    package.loaded["SceneZOI.Localization"] = {refresh = noop, tick = noop, toast = noop}
    package.loaded["SceneZOI.Settings"] = {boot = noop, publish = noop, request = noop, forget = noop}
    package.loaded["SceneZOI.Personality"] = {publish = noop, request = noop}
    package.loaded["SceneZOI.VoicePersonality"] = {publish = noop, request = noop}
    package.loaded["SceneZOI.OutfitControl"] = {publish = noop, request = noop, receive = noop}
    for _, name in ipairs({"DataFiles", "ExpressionLibrary", "FacialPoseLibrary", "VoiceLibrary"}) do
        package.loaded["SceneZOI." .. name] = {refresh = noop}
    end
    package.loaded["SceneZOI.SceneSearch"] = {allowed = yes}
    package.loaded["SceneZOI.AddonEffects"] = {idle = noop, retain = noop, restore = noop, tick = noop, release = noop, player_outfit = noop}
    package.loaded["SceneZOI.AddonControl"] = {reset = noop, tick = noop, init = noop, enter = noop, sample = noop, speed = function() return 1 end,
        ended = noop, release = noop, facts = function() return {} end}
    package.loaded["SceneZOI.ModeGuard"] = {update = function() return {editor = fixture.editor == true} end, can_restore_input = function() return true, {} end}
    package.loaded["SceneZOI.SceneVisuals"] = {tick = function() return {} end, restore = noop}
    package.loaded["SceneZOI.Furniture"] = {valid = yes, prepare = noop}
    package.loaded["SceneZOI.Tasks"] = {new = noop}
    package.loaded["SceneZOI.TaskRoutes"] = {select = noop}
    package.loaded["SceneZOI.TaskActions"] = {trigger = noop}
    package.loaded["SceneZOI.CompletionEffects"] = {multiplier = function() return 1 end, trigger = noop, snapshot = function() return {} end}
    package.loaded["SceneZOI.VoiceResponses"] = {trigger = noop}
    fixture.controlled = 1
    UE = {UGameplayStatics = {GetPlayerController = function()
        return {GetCharacterEntityId = function() return {Value = fixture.controlled} end}
    end}}
    inzoi = {UB1System = {Get = function() return {GetTimeManager = function() return {GetTimeScale = function() return 1 end} end} end},
        cli = {execute = function(line)
            local key = line:match(" key=([^ ]+)")
            if line == "gameplay.get_settings" then return true, "", '{"auto_save_enabled":"1"}' end
            if line:find("gameplay.set_autosave", 1, true) == 1 then
                fixture.autosave.enabled = line:find("enable=true", 1, true) ~= nil
                if not fixture.autosave.enabled then fixture.autosave.acquired = fixture.autosave.acquired + 1 end
                return true, ""
            end
            if line:find("uimod.cfg_save", 1, true) then fixture.cfg[key] = line:match(" value=(.*)"); return true, "" end
            if line:find("uimod.cfg_load", 1, true) then return fixture.cfg[key] ~= nil, "", fixture.cfg[key] end
            return true, ""
        end},
        message = {send_to_sim = function(id, kind, content)
            fixture.sent[#fixture.sent + 1] = {id = id.Value, kind = kind, fields = Protocol.unpack(content)}
        end}}
    fixture.Runtime = require("SceneZOI.Runtime")
    fixture.Events = require("SceneZOI.Events")
    fixture.Protocol = Protocol
    fixture.actors = {}
    function fixture.add_actor(id)
        local actor = {id = id, GetEntityId = function() return {Value = id} end,
            K2_GetActorLocation = function() return {X = 0, Y = 0, Z = 0} end,
            K2_GetActorRotation = function() return {Pitch = 0, Yaw = 0, Roll = 0} end}
        fixture.actors[id] = actor
        fixture.Runtime.register(actor)
        return actor
    end
    function fixture.clear_sent() fixture.sent = {} end
    function fixture.reply(token, id, kind, detail, revision)
        fixture.Runtime.reply(fixture.actors[id], Protocol.pack(token, kind, detail or "ok", revision or 0))
    end
    return fixture
end

return M
