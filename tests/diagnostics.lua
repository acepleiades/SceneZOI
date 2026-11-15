package.path = "modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;" .. package.path
local Json = require("SceneZOI.Json")
local Protocol = require("SceneZOI.Protocol")
local cfg = {scene_history = Protocol.encode('{"event":"legacy_start","timestamp":1}\n')}
local fail_read, fail_write = false, false
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
        if fail_write and key == "scene_history" then return false, "Write failed" end
        cfg[key] = assert(line:match(' value="([^"]*)"$'))
        return true
    end
    if fail_read and key == "scene_history" then return false, "Read failed" end
    -- The retail cfg bridge escapes apostrophes in addition to JSON escapes.
    if cfg[key] then return true, "", (Json.encode({value = cfg[key]}):gsub("'", "\\'")) end
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
    details = 'name "example"\nnew line \\ with an apostrophe: it\'s saved'})
diagnostics.note_addon("third.party")
diagnostics.tick(1)
local inventory = cfg.mod_inventory
includes(inventory, "hzoi={scene_pack=1}",
    "playable_scenes_by_namespace={hzoi=1", "catalog_warning_count=1", "mounted_ui_mod_ids=[test]",
    "disabled_ui_only_mod_ids=[disabled-ui]", "observed_api_addons=[third.party]",
    "declared_scenes_by_namespace={hzoi=2}", "hzoi.optional={asset='/Game/Optional.Asset', code=asset_unavailable}")
local initial = read_history()
assert(#initial == 2)
includes(initial[1], "event=legacy_start")
includes(initial[2], "event=start_requested", [[name \u0022example\u0022\nnew line \\ with an apostrophe: it\u0027s saved]])

package.loaded[mod] = nil
diagnostics = require(mod)
diagnostics.session({id = "session.1", node_id = "hzoi.idle",
    participants = {{id = "1", role = "lead", body = "male", control = "npc"}},
    result_facts = {cleanup_complete = false}}, "session_ended", "prepare_timeout", {client = "player", sequence = 1})
diagnostics.flush()
local rows = read_history()
assert(#rows == 3)
assert(rows[2] == initial[2], "Reload must retain the quoted record and its original escapes")
includes(rows[3], "code=prepare_timeout", "role=lead", "cleanup_complete=false")

package.loaded[mod] = nil
diagnostics = require(mod)
local before_retry = cfg.scene_history
fail_read = true
diagnostics.record("start_requested", {scene_id = "test.retry"})
diagnostics.flush()
assert(cfg.scene_history == before_retry)
fail_read, fail_write = false, true
diagnostics.flush()
assert(cfg.scene_history == before_retry)
fail_write = false
diagnostics.flush()
local recovered = read_history()
assert(#recovered == 4 and recovered[2] == initial[2])
includes(recovered[4], "event=start_requested", "scene_id=test.retry")

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
includes(cfg.environment_history, "observed_api_addons=[third.party]")
print("Runtime diagnostics passed: native apostrophe escapes, retained history across reload and storage retries, bounded retention, and labeled mod inventory.")
