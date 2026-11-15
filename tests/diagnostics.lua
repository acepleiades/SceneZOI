package.path = "modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;" .. package.path
local Json = require("SceneZOI.Json")
local Protocol = require("SceneZOI.Protocol")
local cfg = {scene_history = Protocol.encode('{"event":"legacy_start","timestamp":1}\n')}
local snapshot = {nodes = {["hzoi.idle"] = {}, ["scenezoi.idle"] = {}}, warnings = {"one"},
    excluded = {["hzoi.optional"] = {code = "asset_unavailable", asset = "/Game/Optional.Asset"}}}
package.loaded["SceneZOI.DataFiles"] = {get = function()
    return {by_kind = {scene_pack = {{owner = "hzoi", data = {id = "hzoi", nodes = {{}, {}}}}, {owner = "scenezoi"}}}}
end}
package.loaded["SceneZOI.Catalog"] = {get_snapshot = function() return snapshot end}
inzoi = {cli = {execute = function(line)
    if line == "uimod.list" then
        return true, "", '[{"mod_id":"test/ui","parent":"test"}]'
    elseif line == "uimod.list_disabled" then
        return true, "", '[{"mod_id":"disabled-ui","directory":"private"}]'
    end
    local key = assert(line:match(" key=([%w_]+)"))
    if line:find("cfg_save", 1, true) then
        cfg[key] = assert(line:match(' value="([^"]*)"$'))
        return true
    end
    if cfg[key] then return true, "", Json.encode({value = cfg[key]}) end
    return false, "Key not found"
end}}

local function read_history()
    local list = {}
    for line in cfg.scene_history:gmatch("[^\n]+") do
        list[#list + 1] = line
    end
    return list
end
local function includes(row, ...)
    for _, field in ipairs({...}) do assert(row:find(field, 1, true), field) end
end

local mod = "SceneZOI.Diagnostics"
local diagnostics = require(mod)
diagnostics.record("start_requested", {client = "player", scene_id = "hzoi.idle",
    details = 'name "example"\nnew line'})
diagnostics.note_addon("third.party")
diagnostics.tick(1)
local inventory = cfg.mod_inventory
includes(inventory, "installed_list_available=false", "hzoi={scene_pack=1}",
    "playable_scenes_by_namespace={hzoi=1", "catalog_warning_count=1", "mounted_ui_mod_ids=[test]",
    "disabled_ui_only_mod_ids=[disabled-ui]", "observed_api_addons=[third.party]",
    "declared_scenes_by_namespace={hzoi=2}", "hzoi.optional={asset='/Game/Optional.Asset', code=asset_unavailable}")
assert(not inventory:find("installed_mod_ids=", 1, true))
local initial = read_history()
assert(#initial == 2)
includes(initial[1], "event=legacy_start")
includes(initial[2], "event=start_requested", "name \\u0022example\\u0022\\nnew line")
local handler = {IsA = function() return true end, ModManagementWidget = {
    TotalModItemMap = {ToTable = function() return {["HZoi_660649D8"] = true, ["SceneZOI_93C44199"] = true} end},
}}
local manager = {UIHandlerMap = {ToTable = function() return {handler} end}}
inzoi.UB1System = {Get = function() return {ManagerMap = {Find = function() return manager end}} end}
inzoi.EB1ManagerType = {UI = 1}
inzoi.UB1ModManagementUIHandler = {StaticClass = function() return 1 end}
diagnostics.tick(15)
includes(cfg.mod_inventory, "installed_list_available=true", "installed_mod_ids=[HZoi_660649D8")

package.loaded[mod] = nil
diagnostics = require(mod)
diagnostics.session({id = "session.1", node_id = "hzoi.idle",
    participants = {{id = "1", role = "lead", body = "male", control = "npc"}},
    result_facts = {cleanup_complete = false}}, "session_ended", "prepare_timeout", {client = "player", sequence = 1})
diagnostics.flush()
local rows = read_history()
assert(#rows == 3)
includes(rows[2], "event=start_requested")
includes(rows[3], "code=prepare_timeout", "role=lead", "cleanup_complete=false")
for i = 1, 300 do diagnostics.record("start_rejected", {sequence = i}) end
diagnostics.flush()
rows = read_history()
assert(#rows == 256)
includes(rows[1], "sequence=45 ")
includes(rows[#rows], "sequence=300 ")
diagnostics.boot("host.test")
diagnostics.tick(1)
diagnostics.record("start_requested", {scene_id = "hzoi.idle"})
diagnostics.shutdown()
includes(cfg.scene_history, "run_id=host.test", "environment_id=host.test.1", "event=runtime_boot", "event=runtime_unloaded")
includes(cfg.environment_history, "environment_id=host.test.1", "event=environment_snapshot")
print("Runtime diagnostics passed: multiple starts survive reload, bounded retention, and labeled mod inventory.")
