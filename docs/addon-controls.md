# Expanded add-on controls (API version 1)

Current runtime `20261104-facial-1` (following validated API-5) implements optional capabilities to the existing native-message
contract. Negotiate `get_version.features`: `explicit_bindings`, `preflight`,
`furniture_discovery`, `session_results`, `integration_leases`, `live_controls`,
`presentation_overrides`, `facial_poses`, `head_attachments`, `addon_data`, and `events: 2`. One active session,
controlled initiator participation, fixed membership and ordinary navigation remain
the release contract. This does not add autonomous starts or watch-only sequences.

## Starting and finding

`find_scenes`, `choose_random_scene` and all three starts accept optional
`bindings: {"giving": "20522", "receiving": "20526"}`. Bindings pin declared
roles to selected participants, independently of control status and body type.
Partial bindings are permitted; remaining roles use the same compatibility solver.
The selected participants must still form a complete distinct eligible roster.
Unknown roles cannot match a scene; an incompatible or duplicate assignment does
not silently get swapped. Search results return the actual complete assignment.

`validate_start` accepts the corresponding start arguments, optionally
`start_mode: "start_scene" | "start_random_scene" | "start_at_hub"`. The default
is direct when `scene_id` is present, otherwise a hub. It returns `valid`, the
matched scene/bindings, or a stable failure `code` and diagnostic `message`.
It checks current eligibility, control, recovery/busy gates, restrictions and
furniture availability. It does not reserve participants/furniture, depart groups,
load animation assets or create a session. Startup rechecks and may still fail.

`find_furniture` takes `origin_id`, optional `radius_m` (default 25, maximum 1000),
`scene_id` and `include_unavailable`. Results contain `furniture_id`, `distance_m`,
profile, `available` and `status` (`available`, `occupied`, `unknown`). It searches
loaded objects supported by enabled furniture declarations, using the existing
three-second occupancy cache. Unknown/stale status is never called available.
It does not reserve objects; occupancy and transform checks still run on entry.

`get_navigation {session_id}` returns current authored edges that pass lifetime
restrictions, fixed role assignment and furniture compatibility, plus `locked`.
Use this instead of reproducing host filtering. The backend still validates every
actual route. Navigation and `stop_session` remain exclusive to the creator/client;
the player's controls always remain available.

## Observation and outcomes

`subscribe` now returns `event_cursor` and a consistent current `session` snapshot
or JSON null. `get_session` also returns the cursor. Notifications include a host
cursor and per-session `event_index`; snapshots include that index. Notifications
already represented by a subscription snapshot must not be processed twice.
The SDK handles this comparison and duplicate events. No durable replay is promised.

`get_session_result {session_id}` returns `result` or null for the last **32** ended
sessions in this host instance. Snapshots/results include `result_facts`:

- `stop_reason` records the initiating reason. `stop_origin` records framework or
  add-on identity/reason. `cleanup_code` separately records the final barrier result,
  including `restore_error`/`restore_timeout` when applicable.
  `cleanup_complete` describes the participant/furniture/owned-engine barrier;
  independent global autosave/overhead restoration may still retry while idle.
- `playing_seconds` is host real time actually playing while game time advances;
  `playing_game_seconds` scales that time by the native game multiplier.
  Preparation, pause and cleanup count toward neither. `animation_seconds` is
  the independent animation clock and can be affected by speed modifiers.
- `visited_scenes` retains the latest 128 visits with their durations, including
  entered zero-duration visits. `played_scenes` retains the first 64 distinct
  scenes actually sampled and up to 16 directed actions per scene. Descriptive
  action summaries omit arbitrary extension blobs. `history_truncated` signals
  either limit. `peak_content_rating` spans actual playback, including content
  visited before returning to a GENERAL hub.
- `task_state` contains every task for every participant, including hidden/zero
  values, definition maximum, percentage, completion count and live controls.

Ended results are copied facts, not gameplay success or consent decisions.
Integrations decide rewards, consequences and once-only persistence themselves.
Teardown/process exit can prevent a final event/result. Host restart clears this
bounded store; it is not a save database.

The SDK calls optional `instance_changed(previous, current)` on a detected host
change, clears stale cursors/lease state and retires uncertain pending requests
with `host_changed`. Requests sent after negotiation carry `expected_instance_id`;
a different host rejects them before applying a mutation. Re-negotiate, subscribe
and explicitly register again. Do not blindly retry an uncertain gameplay reward.

## Cooperation between independent add-ons

Before writing modifiers, call `register_integration {capabilities:[...]}`.
Recognized capabilities are `interrupt`, `speed`, `tasks`, `presentation`,
`outfits`, `attachments`. Reading/subscribing grants none. Registration binds the
add-on/client/entity and expires after **12 host real seconds** without renewal;
`renew_integration {}` refreshes it. The supplied SDK renews every two real seconds.
Tick the SDK with real elapsed time even while gameplay is paused. Validation used independent creator/observer native clients; the temporary
acceptance mod has since been removed.

`release_integration {}` unregisters and releases that caller's modifiers/effects.
Re-registering replaces its capabilities and releases its previous effects.
`release_overrides {session_id}` releases effects/modifiers for that session while
retaining registration. Expiry/unload releases them too; unloading a foreign mod
is detected by lease expiry. Registrations are limited to 64, session attachments
to 32. This is cooperation between trusted executable mods, not an anti-cheat or
security boundary. No per-command popup is introduced.

`request_stop {session_id,reason}` needs `interrupt` (or creator identity). It
requests ordinary Exit for a manual/foreign session, records the caller/reason,
and notifies the creator through ordinary ending/ended events. It cannot cancel
cleanup or replace it. New writes are refused during cleanup.

Successful integration control/release operations emit `addon_control_changed`
while a session remains active, with copied
`integration {addon_id,client_id,operation}`. Interruption outcomes use the ordinary
ending/ended events. Speed changes retain
their ordinary speed event; task completions come exclusively from the task engine.

## Live controls

All operations below require the current `session_id`. Participant IDs are decimal
strings, not role names. Modifying progress/speed/outfits/attachments requires
playing readiness; reads may inspect preparation/cleanup.

| Operation | Additional arguments and behavior |
| --- | --- |
| `set_speed` | `speed_index` 1–4 selects 0.5, 1, 1.5, 2. Explicit last command wins with player controls. Requires `speed`. |
| `set_speed_multiplier` | `multiplier` 0.1–2. Per-caller temporary factor; combined factors clamp to 0.1–2 before existing completion slowdown. Does not overwrite the player's selector. Requires `speed`. |
| `get_task_state` | Complete copied `definitions` and participant rows, including `base_rate`, combined `rate_multiplier`, `player_rate_multiplier`, `addon_rate_multiplier`, `effective_rate` and completion hold. The player factor applies only to positive base rates; see [settings](settings.md#task-progress). `get_definitions` also includes task definitions. |
| `set_task_progress` | `participant_id`, `task_id`, `value` within 0–maximum. Requires `tasks`. |
| `modify_task_progress` | `participant_id`, `task_id`, `amount` within ±maximum; resulting progress clamps to 0–maximum. Requires `tasks`. |
| `set_task_controls` | `participant_id`, `task_id`, optional `rate_multiplier` 0–10 and/or `completion_hold` boolean. Per-caller factors combine and clamp to 0–10, before the player's separate 0.1–5 positive-progress factor. Zero freezes accumulation/decay. Any active hold blocks completion. Requires `tasks`. |

Setting progress to the maximum schedules ordinary engine completion on the next
positive playing tick. It never manufactures an event, response, animation or route.
While held, progress stays at the maximum with no completion/reset; release permits
one ordinary completion. Paused/preparing/transition/cleanup ticks cannot complete.
Releasing one integration cannot clear another's hold or mute. Task values persist
through node changes within the same session; they are not stored as preferences.

## Temporary presentation

| Operation | Additional arguments and behavior |
| --- | --- |
| `set_voice_mute` | `participant_id`, `muted` boolean. Any caller's mute suppresses that participant's framework voice and queued completion voice responses. It does not mute other audio engines or another mod's audio. Requires `presentation`. |
| `get_expression_sets` | Available set/context data. No requirement that an optional content pack is installed. |
| `get_facial_poses` | Installed inert facial-pose definitions, with body-specific bone targets. |
| `set_expression_override` | `participant_id`; an `expression_set`/`context` pair, a `facial_pose` ID, or both. Sets/poses must exist and match appearance body; contexts must exist in the set. Omitted instruction fields are not inherited from the scene. Most recent active override for that participant wins. Uses the existing owned facial engine, leaving saved preferences unchanged. Requires `presentation`. |
| `clear_expression_override` | `participant_id`; releases only this caller's expression override. |
| `get_outfit_state` | Participant item IDs, enabled state and readiness phase from the existing outfit engine. |
| `set_outfit_item` | `participant_id`, `item_id`, `enabled` boolean. Queues the existing acknowledged appearance/readiness path. Latest per-item override wins; releasing it exposes the next override or the captured session baseline. A player clothing edit supersedes add-on overrides for that item. Requires `outfits`. |
| `add_attachment` | `participant_id`, caller-local `effect_id`, `attachment {mesh,component?,socket,reference_bone,animation?}`. Existing owned skeletal-attachment engine; no arbitrary body/material/physics patch. `component` selects `body` (default) or `head`. Animated assets must match node duration; incompatible navigation retires them with a diagnostic. Requires `attachments`. |
| `remove_attachment` | `effect_id`; retires only that caller's component, with retryable cleanup. |
| `get_overrides` | Caller-owned modifiers, attachment phases (`pending`, `active`, `releasing`) and retained errors. Accepted creation is not proof of native readiness. |

Clothing acknowledgements use an internal native counter independent of UI command
IDs. Waiting for `playing`/outfit readback is required. Exit uses the original
session outfit snapshot, including failure/save recovery; temporary controls never
save personality, voice or outfit preferences. Attachments warm up hidden, and
failed cleanup retains ownership/retries independently after a bounded Exit timeout.

Optional effect assets can fail later in native loading/playback. Inspect
`get_overrides.errors`, participant `expression_error`/`facial_pose_error`/`voice_error`, ordinary events
and end cleanup code. An accepted effect command is not visual acceptance.

## Inert metadata and SDK helpers

Optional `addon_data` is supported on scenes, action records, tag definitions and
action definitions. Optional `participant_addon_data` maps declared roles to the
same namespace object. Example:

```json
{
  "addon_data": {"author.speech": {"mood": "warm", "weight": 0.5}},
  "participant_addon_data": {"receiving": {"author.effects": {"contact": "waist"}}}
}
```

Each namespace includes an author/add-on separator (`author.addon`) and contains
an object of inert JSON values. Each `addon_data` record is limited to 8 KiB,
eight nested levels and 1024 values. Unknown namespaces pass through uninterpreted;
there is no code evaluation, asset loading, automatic position inference or effect
execution. Existing authors can add annotations to their records; this version
does not add a separate third-party annotation-patch system.

SDK helpers consume copied public data:
`Client.roles(snapshot)` returns roleâ†’Zoi ID; `Client.actions(snapshot,id?)`
resolves actor/target/performer IDs; `Client.partners(snapshot,id,type?)` returns
all distinct applicable partners; `Client.task(snapshot,id,task_id)` returns the
normalized row; `Client.navigation(get_navigation_result)` respects host locking;
`Client.data(record,namespace)` reads extension data. Callers use canonical action
types from definitions/query results. No helper assumes a universal partner, gender
or an excitement task named by the framework.

Additional error codes include `capability_not_granted`, `integration_not_registered`,
`invalid_capability`, `integration_limit`, `attachment_limit`, `participant_not_found`,
`task_not_found`, `outfit_item_not_found`, `effect_already_exists`,
`expression_set_not_found`, `expression_context_not_found`, `incompatible_expression_set`,
`restore_pending`, `host_changed`. Branch on codes; messages remain diagnostic.

## Add-ons these contracts enable

These are use cases inferred from the supplied mod names, not claims about their
actual implementations or a promise to reproduce their assets/game systems.

| Add-on family | Framework integration |
| --- | --- |
| Romance, comfort, kissing, morning encounters | Find GENERAL actions/posture, bind the intended giver/receiver, find furniture, preflight and start, retain affectionate-only navigation limits. |
| Crime, relationship, religion, survival, trainers/merchants, experience | Subscribe or resync; inspect participants/context/actions and factual outcome; own persistence, witnesses, dialogue, payment, rewards and cooldowns in the add-on. Request ordinary interruption when its rules require it. |
| Endurance, fatigue, arousal, edging | Register generic task definitions; read normalized state, adjust progress/rates, hold/release completion per participant without fabricating completion events. |
| Expressions, tongues, undressing | Temporary facial contexts, independently owned compatible skeletal props and acknowledged clothing controls; restoration does not overwrite saved preferences. |
| Fluids, sweat, overlays, opacity, inflation, physics | Use action/partner/completion events and task state to drive the add-on's own native effects. Generic attachments are available; framework does not invent unsupported material, morph, cloth or physics interfaces or supply anatomy. |
| Director | Inspect host-filtered destinations and metadata; creator commands ordinary navigation/speed. Observation alone cannot seize another integration's navigation. |

The [authoring guide](addon-authoring.md) covers packaging and common pitfalls.
[Validation findings](validation/addon-api-20261104.md) distinguish source checks,
native evidence and author visual/audible acceptance. Temporary test scripts/mods
have been removed; SDK and isolated regressions remain.


### Refresh native owner wrappers

Keep a client's caller entity identity stable while refreshing its native wrapper
from current game callbacks. Call `client:refresh_owner(owner)`, or pass the fresh
owner as the optional second argument to `client:tick(real_seconds, owner)`.
Only matching entity IDs update stored pending-request/renewal references; another
Zoi cannot take over the caller. This matters when one Lua environment is reloaded
while an add-on in the other environment survives. A host-instance change still
requires explicit version negotiation, subscription and integration registration.

API-5 native validation covers actual voice mute/resume and muted clothing handoffs,
paused lease renewal, manual-session observers and host-only reload; see
`validation.json`. Author visual/audible judgement remains separate from native
emitter/asset/state diagnostics. A registered native add-on also passed fresh-process automatic Lua/declaration
loading and the full suite without manual mounting or diagnostic data patching.
