package.path = "modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;" .. package.path
local Json = require("SceneZOI.Json")
local Protocol = require("SceneZOI.Protocol")
local release_version = require("SceneZOI.ReleaseVersion")
local cfg = {scene_history = Protocol.encode('{"event":"legacy_start","timestamp":1}\n'), release_version = "old"}
local fail_read, fail_write, fail_version_write = false, false, false
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
        if fail_version_write and key == "release_version" then return false, "Write failed" end
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
fail_version_write = true
diagnostics.boot("host.test")
assert(cfg.release_version == "old")
fail_version_write = false
diagnostics.tick(1)
assert(cfg.release_version == release_version, "Publish the loaded package version after a temporary write failure")
diagnostics.record("start_requested", {scene_id = "hzoi.idle"})
diagnostics.shutdown()
includes(cfg.scene_history, "run_id=host.test", "environment_id=host.test.1", "event=runtime_boot", "event=runtime_unloaded")
includes(cfg.environment_history, "environment_id=host.test.1", "event=environment_snapshot")
includes(cfg.scene_history, "release_version=" .. release_version)
includes(cfg.environment_history, "release_version=" .. release_version)
includes(cfg.mod_inventory, "release_version=" .. release_version)
includes(cfg.environment_history, "observed_api_addons=[third.party]")
print("Runtime diagnostics passed: native apostrophe escapes, retained history across reload and storage retries, bounded retention, and labeled mod inventory.")

local actor = {x = 0, CharacterMovement = {MovementMode = 1, CustomMovementMode = 0},
    Mesh = {GetAnimInstance = function()
        return {GetCurrentActiveMontage = function() return nil end}
    end}}
function actor:K2_GetActorLocation() return {X = self.x, Y = 0} end
function actor:GetActorEnableCollision() return true end
local p = {id = "1", role = "lead", actor = actor, control = "controlled", movement_mode = 1,
    collision = false, restoration = "restored"}
local session = {token = "scene.diagnostic", node = {id = "test.idle"}, age = 2, revision = 1,
    participants = {p}, save_records = {}, furniture = {}, cleanup_complete = true}
assert(diagnostics.wait_status(session, p).phase == "awaiting_snapshot")
session.save_records[p.id] = {}
assert(diagnostics.wait_status(session, p).phase == "awaiting_save_ack")
session.save_ready = true
assert(diagnostics.wait_status(session, p).phase == "awaiting_furniture")
session.furniture_ready = true
assert(diagnostics.wait_status(session, p).phase == "awaiting_simulation_status")
diagnostics.prepare_wait(session, p, {session.token, "prepare_wait", "interaction_cancelling", "1", "456", "BookRead", "ReadBook"})
assert(diagnostics.wait_status(session, p).queue_id == "456")
assert(diagnostics.wait_status(session, p).action_type == "BookRead")
session.revision = 2
assert(diagnostics.wait_status(session, p).phase == "awaiting_simulation_status", "An earlier node's wait must not leak into the next node")
diagnostics.prepare_wait(session, p, {session.token, "prepare_wait", "autonomy_enabled", "2",
    "none", "none", "none", "0", "0", "2"})
local wait = diagnostics.wait_status(session, p)
assert(wait.autonomy_option == false and wait.autonomy_follows_parent == false and wait.autonomy_disable_attempts == 2)

local occupied = false
local actors = {["1"] = actor}
local function sample(dt) diagnostics.tick_exit(dt, actors, function() return occupied end) end
local function after(status)
    diagnostics.flush()
    includes(read_history()[#read_history()], "event=participant_post_exit", "status=" .. status)
    return read_history()[#read_history()]
end
diagnostics.watch_exit(session)
actor.x = 500 -- A restoration or teleport before the first read is not evidence of walking.
sample(.5)
actor.x = 550
sample(1)
sample(1.5)
includes(after("movement_observed"), "horizontal_displacement_cm=50", "expected_movement_mode=1",
    "expected_collision=false", "collision=true", "active_montage=none")
diagnostics.watch_exit(session)
sample(.5); sample(2.5)
includes(after("no_movement_observed"), "movement_observed=false")
actor.CharacterMovement.MovementMode = 0
diagnostics.watch_exit(session)
sample(.5); sample(2.5)
includes(after("movement_disabled"), "movement_mode=0")
diagnostics.watch_exit(session)
occupied = true
sample(1)
includes(after("participant_reserved"), "samples=0")
occupied = false
diagnostics.watch_exit(session)
actors["1"] = {}
sample(1)
includes(after("participant_unavailable"), "samples=0")
print("Participant diagnostics passed: preparation waits, post-exit changes, idle/disabled movement, reservations and replaced actor isolation.")
