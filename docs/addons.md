# SceneZOI add-on API, version 1

Independent add-on acceptance was recorded on API-5. See [release validation](validation/README.md) for later runtime checks. Start with the [authoring guide](addon-authoring.md), use the [SDK](../sdk/README.md), and consult [live controls/results](addon-controls.md) for the extended contract. [Validation findings](validation/addon-api-20261104.md) record measured coverage and pitfalls.

Several sessions can run at once; see [concurrent and background sessions](#concurrent-and-background-sessions)
and [autonomous scenes](#autonomous-scenes). Scene Settings offers the unrestricted manual picker as an opt-in debug tool. Add-ons supply gameplay decisions;
content packs supply inert declarations; SceneZOI owns playback and cleanup.

## Supported transport

Use native Lua user messages from an independent **B2** add-on. Copy the SDK under
`sdk/lua/SceneZOIAddon/` into your own
mod's B2 source tree. It includes its own JSON codec and never requires framework
Lua modules. Adapt the add-on ID to your namespace.

Create one client with `Client.new("author.addon", callbacks)`, then call
`client:request(owner, request_id, operation, arguments)`. Forward native
`on_lua_message` calls to `client:on_message(kind, content)` and call
`client:tick(real_seconds)` for retries/timeouts. `owner` is a loaded FB2Character.
Callbacks are `response(response)` and `event(event, instance_id)`.

B1 handles client UI/config work; the independent public SDK client runs in B2. B1 Lua must use the native player controller for possession:
`entity.get_possessed` is B2-only from Lua, despite being usable by UI JavaScript.

Requests travel as JSON in `SceneZOI.API.Request` via `send_to_client`.
Replies travel back through `SceneZOI.API.Response`; subscribed notifications use
`SceneZOI.API.Event`. These native messages are routed on the requester's entity.
SDK clients filter by add-on ID and client ID because other modules on that
entity can observe the same messages.

Request envelope:

```json
{
  "api_version": 1,
  "addon_id": "author.addon",
  "client_id": "client.unique_instance",
  "request_id": "start.first",
  "operation": "start_at_hub",
  "arguments": {
    "initiator": "20522",
    "participants": ["20522", "20526"],
    "session_restrictions": {"allowed_content_ratings": ["GENERAL"]},
    "context": {"purpose": "affectionate_encounter"}
  }
}
```

The SDK creates its own client ID and, after negotiation, supplies optional
`expected_instance_id` to reject stale-host mutations. Refresh native owner
wrappers without changing caller entity identity; see the authoring guide. IDs are lowercase identifiers beginning with
a letter; participant/furniture IDs are decimal **strings**. Requests are limited
to 64 KiB. Context is an inert JSON object limited to 4 KiB. Keep native objects,
functions and executable expressions out of messages.

Responses contain `api_version`, `instance_id`, `addon_id`, `client_id`,
`request_id`, `ok`, `code`, and either `result` or a diagnostic `message`.
Malformed envelopes that cannot be safely correlated are ignored. Correlate valid
replies by request ID. Retry the identical request with its original ID; the
host resends its cached response without repeating the operation. Reusing an ID
with a different payload returns `request_id_reused`. The host retains the most
recent 256 responses per runtime; the SDK retries each second and times out after
12 supplied real seconds. Use a fresh request ID for each new operation.

## Operations

| Operation | Arguments / result |
| --- | --- |
| `get_version` | Returns API version, runtime build, host instance, features, maximum session count and `maximum_npc_sessions`. |
| `get_definitions` | Returns registered tags/actions, aliases, role descriptions, task definitions and the rating enum. |
| `get_scene` | `scene_id`; returns library metadata, role requirements, furniture and authored navigation. |
| `find_scenes` | Optional `search`, `participants`, `bindings`, `furniture_id`; returns all matches and count. |
| `choose_random_scene` | Same inputs; returns one uniformly chosen match or JSON null, plus count. |
| `start_scene` | Required `scene_id`, `participants`, `initiator`; optional bindings, search, restrictions, furniture and context. |
| `start_random_scene` | Required participants/initiator; optional bindings, search, restrictions, furniture and context. |
| `start_at_hub` | Same, additionally requiring an installed `starting_hub`. |
| `start_autonomous_scene` | See [autonomous scenes](#autonomous-scenes). |
| `list_sessions` | Returns copied snapshots of every session and the current event cursor. |
| `renew_session` | Required `session_id`; renews an owner lease. Only its owner may call it. |
| `set_auto_mode` | Required `session_id`, `enabled`; switches a planned session between automatic and manual. Only its owner may call it. |
| `get_session` | Optional `session_id`; returns a copied snapshot/null and current event cursor. |
| `navigate_to_scene` | Required `session_id`, `scene_id`; only the creating add-on/client may command it. |
| `stop_session` | Required `session_id`; only the creating add-on/client may command it. |
| `subscribe` | Optional `events` list, default `["*"]`, and `scope` (`focused`, `owned`, `all`; default `focused`). Returns event cursor and a current snapshot; observe manual and add-on sessions. |
| `unsubscribe` | Removes this caller's subscription. |
| `get_request_status` | Required original `request_id`; inspect asynchronous start progress. |
| `cancel_start` | Required original `start_request_id`; cancels a still-pending owned start. |


Extended operations are detailed in [the controls reference](addon-controls.md):

| Operations | Purpose |
| --- | --- |
| `validate_start`, `find_furniture`, `get_navigation` | Structured preflight, loaded supported furniture and host-filtered session choices. |
| `get_session_result` | Copied recent outcome/history and separate stop reason/cleanup barrier. |
| `register_integration`, `renew_integration`, `release_integration` | Explicit scoped observer rights and expiring ownership. |
| `request_stop`, `release_overrides`, `get_overrides` | Orderly interruption and caller-scoped release/inspection. |
| `set_speed`, `set_speed_multiplier` | Absolute selector and temporary composed speed factor. |
| `get_task_state`, `set_task_progress`, `modify_task_progress`, `set_task_controls` | Complete normalized tasks, real engine progress/rate/completion holds. |
| `set_voice_mute`, `get_expression_sets`, `get_facial_poses`, `set_expression_override`, `clear_expression_override` | Temporary participant voice/facial presentation. |
| `get_outfit_state`, `set_outfit_item`, `add_attachment`, `remove_attachment` | Acknowledged clothing and independently owned compatible props. |

`get_scene` describes the library, including unrestricted authored edges. For
session-specific choices, use `get_navigation {session_id}`; the host applies
lifetime restrictions, furniture context and fixed-role compatibility. The
framework's own controls already receive filtered navigation. Every actual
navigation request is checked by the host regardless of what an add-on displays.

Without participants, find/random operations search descriptive library data.
With participants they additionally check a complete distinct role assignment,
appearance-body/life-stage compatibility and matching furniture context. Furniture
queries require participants and an available loaded object. Existing reservation
checks run again when starting; a search result is not a reservation.

Scenes marked `hide_if_tracks_missing` enter the catalog only when all required
animation and attachment assets pass the catalog checks. Discovery and random
selection use that catalog, as do preflight and all start modes, including
autonomous starts. A start request that names a scene excluded by this check
returns `no_matching_scenes`. Incoming navigation, task routes and dependent
transitions are also removed. Install external libraries before launching the
game. See [optional animation assets](authoring.md#optional-animation-assets).

Standard API starts require the currently controlled Zoi as initiator and roster
member. Background and autonomous starts can use any eligible loaded initiator
in the roster. The add-on supplies the complete roster directly. API participants
leave gameplay groups through the same native departure helper as manual entry.
Cancellation does not rebuild those groups.

`accepted: true` means a start was queued, not that animation has begun. Group
departure, controls startup, cached save recovery, participant preparation and
furniture reservation still have to acknowledge readiness. Wait for
`session_started` or inspect status. A busy/no-match/invalid request does not
silently substitute another scene. Startup is bounded to 15 host real seconds.

## Concurrent and background sessions

Several sessions can run at once, each with its own roster, clock, tasks and
cleanup. A participant or piece of furniture belongs to one session at a time.
A start that overlaps a participant is refused with `participant_busy`. A start
that overlaps reserved furniture is refused with `furniture_unavailable`. A failure
in one session leaves other sessions running.

Pass `background: true` to `start_scene`, `start_random_scene` or `start_at_hub` to
allow an eligible loaded Zoi, including an NPC, to initiate the session. The panel
appears when the player controls a participant. Background starts accept two
optional objects.

| Field | Meaning |
| --- | --- |
| `placement` | `max_start_distance_m` (0-100, default 15) from each participant to the anchor, checked before the roster is held and again before playback. `exit`: `restore` (default) or `stay`, which applies only to ordinary Exit on floor the game reports as walkable. |
| `lifetime` | Exactly one of `deadline_seconds` or `lease_seconds` (renew with `renew_session`). Explicit values range from 1 to 7,200 seconds. Without a lifetime or plan, NPC-only scenes use the player's **Default NPC Scene Length** (5 to 120 in-game minutes, default 15). Other background starts default to 600 seconds. A timed plan defaults to the greater of 600 seconds and `duration × 1.5 + 60`, capped at 7,200 seconds. The deadline and the 7,200-second ceiling count time spent without a panel, including game pauses. A lease runs even with the panel visible. A lapsed lease ends with `owner_expired`. A deadline or ceiling ends with `lifetime_expired`. |

Scenes containing only NPCs are capped at `maximum_npc_sessions` from `get_version`
(15). A household scene does not count against the cap, and a player's own start is
never refused because of NPC scenes. The cap is known once the roster has been
checked, so it reports `session_limit` through `session_start_failed`.

A standing scene that would stand within 2 metres of another moves to the nearest
walkable floor, up to 6 metres away. If there is none, a background start ends with
`placement_unavailable`. Furniture does not move: busy furniture is simply busy.

The panel, task tray, input and autosave suspension belong to the session of the
**controlled Zoi**. Switching to a participant of another session switches them;
switching to a Zoi outside every session hides the panel while the other sessions
keep playing. A manual household session has 60 real seconds without the panel
before it ends with `lifetime_expired`. Returning resets that interval.
`get_session` without an ID returns the focused session. `list_sessions` returns
all sessions.

Subscriptions take an optional `scope`: `focused` (default, matching earlier
behavior), `owned` or `all`. An add-on's own sessions bypass the focus filter. Keep the relevant event names
in your subscription. If the original endpoint unloads, delivery can fall back
to the controlled Zoi when that endpoint is available.

Ending a session reports the outcome for each participant in `restoration`:
`restored`, `released_on_unload` or `deferred_recovery`. A save ends every session.

**Migration.** `controller_too_far` is no longer emitted: control can move anywhere
without ending a scene. `get_version` keeps `maximum_sessions: 1` for add-ons that
read it, and describes the player's single focused session. Check
`features.background_sessions` before using `background`.

## Autonomous scenes

Call `get_version` and check `features.autonomous_scenes` before using
`start_autonomous_scene`. Check `features.autonomous_stages` when using stage
counts or selectors. The operation uses background entry automatically and
starts with Auto-mode enabled, whether or not a participant is controlled.

Supply `initiator` and `participants` as decimal string IDs for loaded Zois.
Include the initiator in the roster. Optional `bindings` pin named roles and
`furniture_id` selects supported furniture. Use `scene_id` to pin the initial
node, or let SceneZOI select an eligible entry. `search` filters entry candidates.
`restrictions` applies throughout the session, including authored transitions,
completion routes and manual takeover. `placement` and `lifetime` use the
[background start fields](#concurrent-and-background-sessions).

| Plan field | Meaning |
| --- | --- |
| `goals` | Up to 16 `{participant_id, task_id, completions}` entries. Use an installed task ID from `get_definitions` and a roster member's ID. Each participant/task pair can appear once. `completions` is an integer from 1 to 100, defaults to 1, and counts new completions in this session. |
| `end_policy` | `{type:'goals'}` (default with goals), `{type:'duration', seconds, clock}` with 1–7,200 seconds and `clock` set to `game` (default) or `real`, or `{type:'addon'}`. Required without goals. |
| `task_progress_multiplier` | 0.1-5, default 1. Scales positive task rates under the plan. |
| `stages` | A positive integer or `{min, max}`, up to 16. Default 1. Chosen once and returned in the accepted response. |
| `required_stages` | Up to 16 `{stage?, match}` entries. Each scene query in `match` must match a loop that actually plays under Auto-mode. Omit `stage` to match any stage. A numbered stage must exist for every possible count. |
| `stage_preferences` | Up to 16 ordered `{from?, to?, match}` entries that rank eligible loops. `from` defaults to 0 and `to` defaults to 1. The first stage is at fraction 0 and the last at 1, evenly spaced. A one-stage plan is at 0. |
| `auto_speed` | `true` or omitted uses the 1 to 1.25 ramp across stages. Use `false` to disable it or `{start, finish}` with values from 0.5 to 1.5. The ramp affects animation speed. Task rates use game time. |

### Timed start with bundled content

This example plays the bundled female solo idle for 20 seconds of real playback.
Replace `20522` with the ID of a compatible loaded Zoi. Pass the object as
`arguments` to `start_autonomous_scene`.

```json
{
  "initiator": "20522",
  "participants": ["20522"],
  "scene_id": "scenezoi.solo_idle_female",
  "restrictions": {"allowed_content_ratings": ["GENERAL"]},
  "end_policy": {"type": "duration", "seconds": 20, "clock": "real"},
  "auto_speed": false
}
```

To preflight, send the same arguments to `validate_start` with
`start_mode: "start_autonomous_scene"`. Check `result.valid`. A successful
preflight leaves the roster and furniture available to other starts.

### Acceptance, progress and results

1. Check `reply.ok` and `reply.result.accepted`. The accepted result contains
   `start_request_id`, the selected `scene_id`, `autonomous: true`, the chosen
   `stages`, and `route_uncertain: true` if the bounded search could not prove a
   route. Proven incompatibility can return `goal_unreachable` or
   `required_stage_unavailable`. Lifetime restrictions stay in force.
2. Correlate `session_started` or `session_start_failed` by the original
   `request_id`. `session_started` provides the `session_id` for subsequent
   operations. Use `get_request_status` with the original request ID to recover
   status, or `get_session` with a known session ID to inspect playback.
3. On `session_ended`, inspect `plan.outcome`, the goal and stage results, and
   `result_facts.stop_reason` and `result_facts.cleanup_complete`. If you missed
   the event, query `get_session_result` with the session ID while the host still
   retains the result.

The planner follows authored navigation edges and transitions. It uses the
slowest goal's progress to advance stages. A goal's progress is its completed
count plus the current meter fraction, divided by its requested count. A goal
at 100% still needs the task engine's completion event to count as satisfied.
Stages move forward in order. A timed plan without goals divides its duration
evenly across stages. Both plan clocks pause during preparation, game pause and
manual takeover. The real clock ignores game speed and the game clock follows
it. Transitions count toward elapsed playback and finish before planned Exit.
Background deadlines and owner leases run independently of the plan clocks.

### End policies and safety stops

| Ending | Stop reason | `plan.outcome` |
| --- | --- | --- |
| Goals and required stages met, responses resolved | `ok` | `goals_met` |
| Duration elapsed (unmet goals stay reported) | `ok` | `duration_elapsed` |
| Add-on plan: goals met | none yet | Publishes `plan_goals_met` once, holds the loop and freezes fulfilled tasks until `stop_session`. |
| Add-on stays at the milestone without stopping | `owner_expired` | `wait_expired` after 300 seconds of active waiting |
| Nothing advanced for 90 seconds, including a completion hold that never lifts | `no_progress` | `no_progress` |
| Caps or restrictions left no route | `goal_unreachable` or `required_stage_unavailable` | same |
| Playback budget of 7,200 seconds | `playback_budget_exceeded` | same |

Copied snapshots carry `plan` with `auto_mode`, `state`, `outcome`, `goals`
(`participant_id`, `task_id`, `requested`, `completed`, `progress`, `satisfied`),
`required_stages` (ordered results with `stage` when specified and `met`),
`stage`, `stage_count`, `real_seconds` and `game_seconds`. Plan events are
`plan_goals_met`, `plan_stage_changed` and `plan_auto_mode_changed`.

With `end_policy.type: "addon"`, the owner can call `stop_session` at any time.
An add-on plan without goals stays in stage one. If using `lifetime.lease_seconds`,
call `renew_session` before it lapses. The SDK's automatic integration renewal
covers `register_integration` only.

A timed plan runs out its duration even if nothing is advancing, and reports what it did not reach.
Authored completion responses finish before the plan moves on, publishes `plan_goals_met` or ends.

A session with a plan shows an **Auto-mode** toggle in its panel, and an owner can
call `set_auto_mode` with `session_id` and `enabled`. While it is on, manual and
`navigate_to_scene` navigation is refused with `navigation_locked`. Off keeps the
node, tasks, goals and restrictions, and suspends automatic navigation, the ramp,
the plan multiplier, the plan clock and planned Exit. Stage credit is earned only
under Auto-mode. Turning it back on re-evaluates from the current state.

SceneZOI verifies technical eligibility. The add-on that starts an autonomous scene
decides who agrees to what, including age and consent rules for its content.

## Search and session restrictions

`search` selects the initial scene. `session_restrictions` is a separate,
session-owned copy controlling every scene that may play afterward.

Both use the same criteria:

| Field | Meaning |
| --- | --- |
| `allowed_content_ratings` | Any listed enum value; an empty list matches nothing. Unclassified scenes are excluded whenever this field is supplied. |
| `required_tags` | Every listed scene tag is required. |
| `any_tags` | At least one listed scene tag, when the list is nonempty. |
| `excluded_tags` | None of these scene tags may occur. |
| `required_actions`, `any_actions`, `excluded_actions` | Equivalent tests against registered action types. |
| `participant_tags` | Role-name map with `required_tags`, `any_tags`, `excluded_tags` for each specified role. |
| `action_filters` | Every filter must match an action record; specify `type` and optional `actor`, `target`, `performer` role names. |
| `starting_hub_only` | If true, restrict matching to starting hubs. Usually belongs in initial search, not lifetime restrictions. |

Use [factual pose descriptors](scene-metadata.md#describe-the-pose-not-a-culturally-named-position)
to interpret a layout. For example, require `on_top`, `straddling_partner` and
`facing_away` on a declared receiving role, together with a `vaginal_sex` action
targeting that role. Add `performer` only when the depicted movement requires it.
Roles vary between packs: inspect each action's target, then that role's tags;
do not assume the role is literally named `female` or `receiving`. An add-on can
derive its own position label or register its own namespaced tag. Core does not
expand named-position labels into inferred facts.

Aliases normalize consistently for scene references and queries. Authored
dictionary IDs and aliases use the documented lowercase underscore format. Unknown names
are errors. Rating limits, positive requirements and exclusions are combined.
No-match stays no-match; restrictions are never relaxed. Hubs do not bypass them.
The supplied hubs themselves have GENERAL hug actions and an affectionate tag.

Restrictions cover visible navigation, add-on direct navigation, automatic
transition destinations (including chains), random selection and task-completion
routes. A blocked manual/API route preserves the current scene. A transition
leading to a blocked destination is excluded before entry. Membership and role
assignments remain fixed; incompatible target roles/furniture still fail.

Ratings describe declared actions. They do not automatically classify or filter
manual outfit changes, saved voice choices, exposed attachments or other cosmetic
presentation. Content authors must describe rating-relevant activities accurately.

## Events and ownership

Snapshots include session `id`/public event `session_id`, event name/index, node ID,
revision, phase, participants/roles/body/control identity, speed, applicable task
details, resolved tags/actions and calculated `content_rating`. Add-on starts also
include `addon_id`, originating `request_id`, copied context and restrictions.
No mutable session/native objects cross the interface. JSON empty arrays and null
values retain their types through copied notifications.

The public stream follows the existing deferred runtime dispatcher:
`session_preparing`, `session_started`, `node_entered`, `node_leaving`,
`node_preparing`, `playback_speed_changed`, `game_clock_changed`,
`outfit_changing`, `outfit_changed`, `task_completed`, `task_route_selected`,
`task_route_failed`, `transition_completed`, `addon_control_changed`, `plan_goals_met`, `plan_stage_changed`,
`plan_auto_mode_changed`, `session_ending`, `session_ended`.
`session_start_failed` can occur before a session exists and carries its request
ID/code/message rather than a session snapshot. Starters are subscribed by default
if they have not already registered a subscription.

Started means playback readiness, not request acceptance. Ended follows the
ordinary cleanup barrier or its bounded timeout; inspect its `code` (for example
`restore_timeout`) and `result_facts.cleanup_complete` before assuming the
participant/furniture/owned-engine barrier succeeded. Ending records intent. World teardown/process exit may
prevent a final notification. Delivery is best effort with no durable event replay.
Opening Create a Zoi can end a session through the existing `saving` guard or the
`character_editor` fallback. Both use ordinary cleanup; integrations should treat
them as interruptions and allow a new session after returning to gameplay.
Opening Esc or pausing time alone does not end a session.
Re-register subscriptions after a runtime/host-instance change. Context IDs identify
the caller and prevent accidental control conflicts; they are not a security
boundary against other executable mods. The player's Exit always remains available.

Stable error codes include `unsupported_api_version`, `unknown_operation`,
`invalid_request`, `request_id_reused`, `request_not_found`,
`session_already_running`, `session_not_found`, `session_not_owned`,
`session_not_ready`, `initiator_not_controlled`, `no_matching_scenes`,
`furniture_unavailable`, `incompatible_furniture`, `navigation_locked`,
`participant_busy`, `participant_too_far`, `session_limit`, `goal_unreachable`,
`required_stage_unavailable`, `participant_not_found`, `task_not_found`,
`session_has_no_plan`, and `scene_restricted`. A queued start can later report `start_failed`;
`transport_timeout` is generated by the SDK. Diagnostic messages are for debugging,
not branching. Starting/playing does not imply consent: the integration owns its
gameplay decision while framework technical checks remain mandatory.

## Compatibility and examples

API version 1 is the public native-message contract. Internal Lua module paths,
UI mailboxes and the manual picker protocol are not an external API. Query version
and features before relying on them. Additional optional response fields may be
added within version 1; unknown response fields should be ignored. Unsupported
request versions fail explicitly.

See the [authoring guide](addon-authoring.md) for three integration patterns,
a [query using real content metadata](addon-authoring.md#query-real-content-declarations), and
common pitfalls. The temporary installable acceptance mod has been removed;
the reusable SDK is retained independently. Source regressions cover registry conflicts,
one-sided/mutual actions, copied JSON types, restricted API/UI/automatic/task routes,
startup acknowledgement, ownership, retries and failure isolation. The validation
report separates those checks from actual separate-package native evidence.
