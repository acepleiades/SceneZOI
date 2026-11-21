package.path = "modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;" .. package.path
local Json = require("SceneZOI.Json")
local release_version = require("SceneZOI.ReleaseVersion")
local cfg = {scene_history = "event=previous_start timestamp=1\n", release_version = "old"}
local fail_read, fail_write, fail_version_write = nil, nil, false
local api_writes = 0
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
        if key == "api_trace" then api_writes = api_writes + 1 end
        if key == fail_write then return false, "Write failed" end
        if fail_version_write and key == "release_version" then return false, "Write failed" end
        cfg[key] = assert(line:match(' value="([^"]*)"$'))
        return true
    end
    if key == fail_read then return false, "Read failed" end
    -- The retail cfg bridge escapes apostrophes in addition to JSON escapes.
    if cfg[key] then return true, "", (Json.encode({value = cfg[key]}):gsub("'", "\\'")) end
    return false, "Key not found"
end}}

local function lines(body)
    local list = {}
    for line in body:gmatch("[^\n]+") do
        list[#list + 1] = line
    end
    return list
end

local function read_history()
    return lines(cfg.scene_history)
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
assert(initial[1] == "event=previous_start timestamp=1")
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
fail_read = "scene_history"
diagnostics.record("start_requested", {scene_id = "test.retry"})
diagnostics.flush()
assert(cfg.scene_history == before_retry)
fail_read, fail_write = nil, "scene_history"
diagnostics.flush()
assert(cfg.scene_history == before_retry)
fail_write = nil
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

-- API calls share one rolling file across runtime hosts, even if the first read fails.
local legacy = "api_trace_host_1_2_000001"
cfg[legacy] = "kind=call request_id=legacy-only\n"
diagnostics.record_api_trace({kind = "call", request_id = "old-host", sequence = 1})
assert(cfg.api_trace == nil, "Recording an API call must not write synchronously")
diagnostics.shutdown()
includes(cfg.api_trace, "kind=call", "run_id=host.test", "request_id=old-host ")
local before_reload = cfg.api_trace
local writes_before_reload = api_writes
package.loaded[mod] = nil
diagnostics = require(mod)
diagnostics.boot("host.new")
diagnostics.record_api_trace({kind = "call", request_id = "new-host.first", sequence = 1})
fail_read = "api_trace"
diagnostics.flush()
assert(cfg.api_trace == before_reload and api_writes == writes_before_reload,
    "A failed initial read must not overwrite existing traces")
diagnostics.record_api_trace({kind = "rejected", request_id = "new-host.second", sequence = 2})
fail_read, fail_write = nil, "api_trace"
diagnostics.flush()
assert(cfg.api_trace == before_reload, "A failed write must leave the earlier file intact")
fail_write = nil
diagnostics.flush()
local api_rows = lines(cfg.api_trace)
assert(#api_rows == 3 and api_rows[1] == lines(before_reload)[1])
includes(api_rows[2], "request_id=new-host.first ", "run_id=host.new")
includes(api_rows[3], "request_id=new-host.second ", "kind=rejected")
local saved_trace, writes_after_retry = cfg.api_trace, api_writes
diagnostics.flush()
assert(cfg.api_trace == saved_trace and api_writes == writes_after_retry,
    "An idle flush must neither duplicate nor rewrite API traces")

fail_write = "api_trace"
for i = 1, 600 do
    diagnostics.record_api_trace({kind = "call", request_id = "count." .. i, sequence = i})
end
diagnostics.flush()
assert(cfg.api_trace == saved_trace, "A burst during write failure must not replace the saved file")
fail_write = nil
diagnostics.flush()
api_rows = lines(cfg.api_trace)
assert(#api_rows == 512 and #cfg.api_trace <= 131072)
for i, line in ipairs(api_rows) do includes(line, "request_id=count." .. (88 + i) .. " ") end

local detail = string.rep("x", 2400)
for i = 1, 80 do
    diagnostics.record_api_trace({kind = "call", request_id = "bytes." .. i, sequence = i, arguments = {test = detail}})
end
diagnostics.flush()
api_rows = lines(cfg.api_trace)
assert(#api_rows > 1 and #api_rows < 80 and #cfg.api_trace <= 131072, "Byte cap must also evict old whole rows")
for i, line in ipairs(api_rows) do
    includes(line, "request_id=bytes." .. (80 - #api_rows + i) .. " ", "arguments={test=" .. detail .. "}")
end
assert(cfg[legacy] == "kind=call request_id=legacy-only\n", "Legacy pages must be left intact")
for key in pairs(cfg) do
    assert(not key:match("^api_trace_") or key == legacy, "No new trace page may be written")
end
print("API diagnostics passed: one file, prior hosts retained, read/write retries, idle writes, row and byte caps, and no new trace pages.")

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
local protocol = require("SceneZOI.Protocol")
diagnostics.prepare_wait(session, p, {session.token, "prepare_wait", "autonomy_enabled", "2", "none", "none", "none", "0", "0", "3",
    protocol.encode(Json.encode({autonomy_effective=true,autonomy_resolved=false,autonomy_notified=true,
        control_at_prepare="controlled",controlled_id="1",progress_source="prepare_retry",simulation_ticks=1,
        prepare_received=7,progress_attempts=8,commit_received=5,seconds_since_commit=1,
        unsafe_extra="private information",heartbeat_received=-1}))})
wait = diagnostics.wait_status(session,p)
assert(wait.simulation.autonomy_effective and not wait.simulation.autonomy_resolved and wait.simulation.autonomy_notified)
assert(wait.simulation.control_at_prepare=="controlled" and wait.simulation.prepare_received==7
    and wait.simulation.commit_received==5 and wait.simulation.seconds_since_commit==1
    and wait.simulation.heartbeat_received==nil and wait.simulation.unsafe_extra==nil)
session.age = session.age + 3
assert(diagnostics.wait_status(session,p).seconds_since_report == 3, "A stale wait must show its age at timeout")
diagnostics.prepare_wait(session,p,{session.token,"prepare_wait","autonomy_enabled","2","none","none","none","0","0","4",
    protocol.encode(Json.encode({commit_received="5",seconds_since_commit=-1}))})
wait = diagnostics.wait_status(session,p)
assert(wait.simulation.commit_received==nil and wait.simulation.seconds_since_commit==nil,
    "Invalid optional Commit observations are omitted")
diagnostics.prepare_wait(session,p,{session.token,"prepare_wait","autonomy_enabled","2","none","none","none","0","0","4","not_hex"})
assert(diagnostics.wait_status(session,p).simulation==nil,"Malformed optional observations do not break preparation diagnostics")
diagnostics.prepare_wait(session,p,{session.token,"prepare_wait","source_posture_releasing","2","none","none","none","none","none","none",
    protocol.encode(Json.encode({source_furniture_id="50",source_component="InteractionSlot_L",source_slot="InteractionSlot_L",
        source_posture_id="Sit",source_current_posture="Stand",source_current_target="-1",
        source_claim_pending=true,source_posture_standing=true,getup_queue_id="77",getup_state="finishing",
        getup_failure="native_getup_motion_unsettled",getup_queue_present=false,getup_motion_pending=true,
        getup_position_settled=false,getup_anim_id="NativeFurniturePose",getup_montage_id="NativeFurniturePoseMontage",
        getup_queue_result=37,unsafe_extra="ignored"}))})
wait=diagnostics.wait_status(session,p)
assert(wait.phase=="source_posture_releasing"and wait.simulation.source_furniture_id=="50"
    and wait.simulation.source_component=="InteractionSlot_L"and wait.simulation.source_slot=="InteractionSlot_L"
    and wait.simulation.source_claim_pending and wait.simulation.source_posture_standing
    and wait.simulation.source_current_target=="-1"and wait.simulation.unsafe_extra==nil,
    "Source furniture/posture waits retain only the bounded native observations")
assert(wait.simulation.getup_queue_id=="77"and wait.simulation.getup_state=="finishing"
    and not wait.simulation.getup_queue_present and wait.simulation.getup_motion_pending
    and not wait.simulation.getup_position_settled and wait.simulation.getup_queue_result==37
    and wait.simulation.getup_failure=="native_getup_motion_unsettled"
    and wait.simulation.getup_montage_id=="NativeFurniturePoseMontage",
    "Native GetUp diagnostics distinguish queue, montage and spatial completion")

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
