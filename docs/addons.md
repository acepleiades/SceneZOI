# SceneZOI add-on API, version 1

First-release runtime: `20261104-facial-1`. Independent add-on acceptance was recorded on API-5; the final facial/runtime pass is recorded separately in [release validation](validation/README.md). Start with the [authoring guide](addon-authoring.md), use the [SDK](../sdk/README.md), and consult [live controls/results](addon-controls.md) for the extended contract. [Validation findings](validation/addon-api-20261104.md) record measured coverage and pitfalls.

SceneZOI supports one active session. Concurrent NPC-owned sessions remain deferred.
The unrestricted manual starter remains available. Add-ons supply gameplay decisions;
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
| `get_version` | Returns API version, runtime build, host instance, features and maximum session count. |
| `get_definitions` | Returns registered tags/actions, aliases, role descriptions, task definitions and the rating enum. |
| `get_scene` | `scene_id`; returns library metadata, role requirements, furniture and authored navigation. |
| `find_scenes` | Optional `search`, `participants`, `bindings`, `furniture_id`; returns all matches and count. |
| `choose_random_scene` | Same inputs; returns one uniformly chosen match or JSON null, plus count. |
| `start_scene` | Required `scene_id`, `participants`, `initiator`; optional bindings, search, restrictions, furniture and context. |
| `start_random_scene` | Required participants/initiator; optional bindings, search, restrictions, furniture and context. |
| `start_at_hub` | Same, additionally requiring an installed `starting_hub`. |
| `get_session` | Optional `session_id`; returns a copied snapshot/null and current event cursor. |
| `navigate_to_scene` | Required `session_id`, `scene_id`; only the creating add-on/client may command it. |
| `stop_session` | Required `session_id`; only the creating add-on/client may command it. |
| `subscribe` | Optional `events` list, default `["*"]`. Returns event cursor and a current snapshot; observe manual and add-on sessions. |
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

API starts require the currently controlled Zoi as initiator and roster member.
They do not open the picker because the add-on supplies the complete roster.
The manual picker is unchanged. API participants leave gameplay groups through
the same native departure helper; cancellation does not rebuild those groups.

`accepted: true` means a start was queued, not that animation has begun. Group
departure, controls startup, cached save recovery, participant preparation and
furniture reservation still have to acknowledge readiness. Wait for
`session_started` or inspect status. A busy/no-match/invalid request does not
silently substitute another scene. Startup is bounded to 15 host real seconds.

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
`task_route_failed`, `transition_completed`, `addon_control_changed`, `session_ending`, `session_ended`.
`session_start_failed` can occur before a session exists and carries its request
ID/code/message rather than a session snapshot. Starters are subscribed by default
if they have not already registered a subscription.

Started means playback readiness, not request acceptance. Ended follows the
ordinary cleanup barrier or its bounded timeout; inspect its `code` (for example
`restore_timeout`) and `result_facts.cleanup_complete` before assuming the
participant/furniture/owned-engine barrier succeeded. Ending records intent. World teardown/process exit may
prevent a final notification. Delivery is best effort with no durable event replay.
Re-register subscriptions after a runtime/host-instance change. Context IDs identify
the caller and prevent accidental control conflicts; they are not a security
boundary against other executable mods. The player's Exit always remains available.

Stable error codes include `unsupported_api_version`, `unknown_operation`,
`invalid_request`, `request_id_reused`, `request_not_found`,
`session_already_running`, `session_not_found`, `session_not_owned`,
`session_not_ready`, `initiator_not_controlled`, `no_matching_scenes`,
`furniture_unavailable`, `incompatible_furniture`, `navigation_locked`, and
`scene_restricted`. A queued start can later report `start_failed`;
`transport_timeout` is generated by the SDK. Diagnostic messages are for debugging,
not branching. Starting/playing does not imply consent: the integration owns its
gameplay decision while framework technical checks remain mandatory.

## Compatibility and examples

API version 1 is the public native-message contract. Internal Lua module paths,
UI mailboxes and the manual picker protocol are not an external API. Query version
and features before relying on them. Additional optional response fields may be
added within version 1; unknown response fields should be ignored. Unsupported
request versions fail explicitly.

See the [authoring guide](addon-authoring.md) for three integration patterns and
common pitfalls. The temporary installable acceptance mod has been removed;
the reusable SDK is retained independently. Source regressions cover registry conflicts,
one-sided/mutual actions, copied JSON types, restricted API/UI/automatic/task routes,
startup acknowledgement, ownership, retries and failure isolation. The validation
report separates those checks from actual separate-package native evidence.
