# Scene tasks

Build `20261103-tasks-1`, task schema 1. Scene tasks are optional, session-owned numerical state, independent of animation, expressions and audio. Task schema 1 remains its own data contract. Independent integrations observe tasks through the [public add-on API version 1](addons.md).

Independent add-ons can inspect normalized state, set/modify progress and apply
caller-scoped rate multipliers/completion holds through [live controls](addon-controls.md#live-controls).
Completion is still committed by the real task engine on a positive loop-playing tick.

## Register a definition

Add an entry to a pack manifest's `data_files`:

```json
{"kind":"scene_task","file":"example/tasks/spell_charge.json"}
```

The referenced file contains one definition:

```json
{
  "schema_version": 1,
  "id": "spell_charge",
  "label": "Spell charging",
  "maximum": 90,
  "initial": 0,
  "decay": 1,
  "completion_event": "spell_ready",
  "display": {
    "visible": true,
    "color": "#3185c3",
    "track_color": "#bfbfbf",
    "text_color": "#222222",
    "body_colors": {"female":"#df85ac", "male":"#3185c3"}
  },
  "metadata": {"category":"magic"}
}
```

Identifiers are exact, case-sensitive identifiers: lowercase ASCII letters, digits, underscores, dots and hyphens, starting with a letter, up to 96 characters. Prefix independent authors' IDs where practical. Scene references must match the registered ID exactly. Labels are nonempty text, up to 160 UTF-8 bytes. `maximum` is required, finite and between 0.001 and 1,000,000,000. `initial` defaults to 0 and must be within 0–maximum. `decay` defaults to 0 and is a nonnegative units-per-game-second rate, at most 1,000,000. `completion_event` is optional. `metadata` is an optional inert JSON object copied into completion payloads; it cannot contain executable callbacks.

All display settings are optional. `visible: false` suppresses indicators without disabling progression/events. Colors accept `#RRGGBB` only. `body_colors` optionally overrides the fallback ring color for the framework's existing appearance-body traits; those colors have no gameplay meaning. Without presentation data, the framework uses its neutral palette.

Definitions use the existing independent native declaration discovery: envelope kind `scene_task`, owner from the contributing pack, transport `Text_UI` / retail `Text`. They are not loose files read by the game. Build/package/install content edits normally. Discovery refreshes at startup, while idle and before Start. Every session captures its definitions and progress; changes to installed contributions apply to a later session.

Malformed definitions and conflicting IDs produce catalog diagnostics. A malformed contribution is isolated. Identical repeated definitions are accepted; a conflicting later definition does not overwrite the first in deterministic source order. Source builds reject malformed/conflicting task definitions before writing generated output.

## Per-scene progression

Nodes optionally declare a role-to-task map:

```json
"tasks": {
  "caster": {
    "spell_charge": {"rate":1, "cap_percent":100},
    "training": {"rate":0.5, "cap_percent":50}
  },
  "assistant": {
    "spell_charge": {"rate":0, "cap_percent":100}
  },
  "observer": {
    "spell_charge": {"rate":-0.25}
  }
}
```

The role names must be declared by that node. Each task reference must use its registered ID; an unavailable task is skipped with a diagnostic rather than ending the scene. Multiple tasks and repeated body types are supported without assuming a controlled participant or a two-person roster. No task block is required for existing scenes.

`rate` is required, finite, between -1,000,000 and 1,000,000 units/second. `cap_percent` defaults to 100 and ranges from 0 to 100. Its absolute cap is `maximum * cap_percent / 100`.

| Scene data | Behavior |
| --- | --- |
| Task omitted for a participant | Subtract configured decay. |
| Explicit rate 0 | Hold current value, without automatic decay. |
| Positive rate | Add progress up to its cap. Entering a lower cap preserves progress already above it. |
| Negative rate | Subtract progress to zero; the positive progression cap does not set a floor. |

Values always stay within 0–maximum. Percentage is `100 * value / maximum`; 90/90 and 200/200 both mean 100%. The tray displays whole percentages rounded down.

The [Scene Settings](settings.md#task-progress) female/male task-rate controls
multiply positive authored rates by 0.1–5, using each participant's appearance body
type. The default is 1. They combine with caller-scoped add-on rate modifiers;
authored negative rates and omitted-task decay are unaffected by the player
setting. Caps and completion holds remain authoritative. The setting changes
future accumulation without changing current values or direct API progress edits.

Rates use native game time, independent of SceneZOI's animation-speed selector. Game pause pauses progression and decay; game time controls scale them. Preparation, navigation handoff, outfit preparation and stopping do not accrue task time. All task progression and decay also pause throughout a `transition` node; see [transition scenes](transitions.md). No catch-up occurs for those held intervals.

Participant IDs own progress and completion counts for the session. Navigation keeps that state. Exit discards it, and a new session initializes from the definition. This tier does not write progress into game saves or persistent personality settings.

## Completion and subscriptions

Reaching maximum records a completion, resets value to zero, and queues `task_completed` through the existing `SceneZOI.Events` dispatcher. The engine emits at most one completion per participant/task/update; excess units from that update are discarded so reset means zero, including after a long frame. There is no terminal latch: subsequent progress can complete again. An initial value equal to maximum completes on the first positive-time playing update.

Core state is committed before observers run. Each observer gets an independent plain snapshot; observer exceptions are isolated. Excess notifications beyond the per-flush delivery budget remain queued for the next flush instead of being dropped. `completion_index` increases independently for each participant/task; combine it with session ID, participant ID and task ID for an idempotent external consequence key.

```lua
local Events = require("SceneZOI.Events")

-- All task completions:
local handle = Events.subscribe("task_completed", function(event)
    print(event.participant_id, event.task.id, event.task.completion_index)
end)

-- Only a content-defined completion event:
local ready = Events.subscribe_task("spell_ready", function(event)
    -- Apply a separate integration's gameplay outcome here.
end)

Events.unsubscribe(handle)
Events.unsubscribe(ready)
```

The snippet above is an **internal B1 observer**, not code to require from a
separate mod. Independent add-ons use the copied B2 SDK and request `subscribe`
with `events: ["task_completed", "task_route_selected", "task_route_failed"]`.
The version-1 JSON events contain the task/participant details below; use
`get_session` for copied `task_progress`. See [transport and events](addons.md).


The B1 completion payload includes existing session ID (`id`), node ID, revision, phase, participant roster, speed state and event index, plus:

```json
{
  "participant_id":"12345",
  "participant_role":"caster",
  "task": {
    "id":"spell_charge",
    "label":"Spell charging",
    "value":90,
    "maximum":90,
    "percent":100,
    "completed":true,
    "completion_index":1,
    "completion_event":"spell_ready",
    "metadata":{"category":"magic"}
  }
}
```

`Runtime.snapshot().task_progress[participant_id][task_id]` exposes copied current `value` and `completions` state. Completion payload value is the attained maximum, while that snapshot's current progress has already reset to zero. No native actors or mutable task state are exposed. A definition without `completion_event` still dispatches the generic completion event. Without an explicitly configured completion action, SceneZOI does not play completion media, change navigation or apply a gameplay consequence.

## Tray and layout

The fixed-width 132-pixel Scene Tasks tray sits 10 pixels to the right of the main panel and matches its height. Each row shows participant name, task label, SVG ring and percentage. Its content scrolls independently, preserving scroll position during updates. At zero, an omitted or decreasing task disappears; an explicitly increasing or held task remains visible. Once no visible rows remain, the tray is removed and configuration panels return to their previous arrangement.

With a tray present, outfit/personality/settings panels shift right by 142 pixels. Without it, their existing viewport-placement fallback remains in effect. The tray retains the requested immediate-right priority even near the viewport edge; the user can move/resize the main window to provide room. The combined native hit rectangle includes the tray and configuration panel. Existing drag, resize, input focus and Exit behavior are retained.

## Validation boundaries

Isolated tests cover independent rates/owners, caps, omitted decay, zero holds, negative rates, multiple task types, percentages, initial maximum, repeated completion/reset, navigation, game pause/speed independence, copied event payloads, filtered subscriptions, event bursts, malformed definitions, invalid references, source-build atomicity and backward compatibility. UI tests cover rings, labels, roster size, stale-frame rejection, reflow, resizing, scrolling CSS and input bounds. Browser rendering and ModKit validation are separate from native in-game acceptance; consult `validation.json` for this build's exact installed/live status.

### Native ring renderer correction

UI build `20261103-tasks-ui-2` draws partial progress with explicit SVG arc geometry rather than dashed circle strokes, and centers percentage text with a flex overlay. A synthetic in-game rendering check verifies the empty gray track, partial colored fill and centered text. That UI revision preserved task runtime build `20261103-tasks-1`; the later completion-sound runtime is `20261103-task-sounds-1`. Larger-roster isolated checks cover 3, 4, 16 and 64 participants, but authored 3+ scene playback has no live acceptance claim.

## Data-defined completion sounds

Runtime build `20261103-task-sounds-1` adds optional `on_completion` actions to schema-1 task definitions. The generic completion event is still emitted and progress reset independently of action success. A definition without actions retains its previous behavior.

```json
"on_completion": [
  {
    "type": "play_sound",
    "when": {"body": "male"},
    "clip": "/ExamplePack/Audio/ChargeReady.ChargeReady",
    "source": {"component": "body", "bones": ["pelvis"]},
    "volume": 1,
    "max_voices": 4,
    "attenuation": {"radius_cm": 100, "falloff_cm": 900}
  }
]
```

This is inert configuration, not executable expressions or a scripting language. Up to 32 actions are accepted. Currently `play_sound` is the supported action type; other types are rejected with diagnostics. `clip` must reference a SoundWave supplied by the contributing content package or another installed dependency.

The source always belongs to the **participant who completed the task**. `source.component` is `body` or `head`; `bones` contains 1–8 unique bone names, following the existing source resolver's position rules. One bone selects its world-space translation. Position is updated during playback, so a source follows the participant rather than remaining at the scene anchor. This does not bind the sound to a particular scene role, control status or actor index.

The optional `when.body` filter uses the framework's existing appearance-body trait (`male` or `female`). Omit `when` to apply the action to every completing participant. The filter and asset path belong to content data. Matching participants with the same body each own independent audio components.

`volume` defaults to 1, within 0–1. `max_voices` defaults to 4, within 1–16, and bounds overlapping one-shots **per task/action/participant**. A full pool stops/reuses its oldest voice without affecting another participant's pool. Optional attenuation uses the existing spatial audio adapter: radius defaults to 100 cm, falloff to 900 cm; supplied distances must be within 0–100,000 cm.

Each completion index is attempted once. A missing clip/source or native failure produces an optional-action diagnostic and never cancels the completion event or session. Failed optional plays are not retried on later frames, which could produce delayed cues for old completions; a later completion can try again. The native component remains owned through partial create/play failures and retryable cleanup.

One-shots do not loop or restart on frame updates. They use the existing native audio pitch limits and duration accounting: game pause/time controls affect playback; SceneZOI's animation-speed selector does not. They pause during scene/outfit preparation, survive navigation, and resume following the same participant. Exit stops/releases all task-action audio through the normal retained-subsystem lifecycle. No global mixer or game sound settings are changed.

This facility implements scene-local completion audio only. Persistent gameplay outcomes and other definition-level action types remain separate. Scene-level voice bindings, routing and procedural effects are implemented independently below. Content still ships no executable code. Native JSON declaration changes require normal package activation; replacing a JSON patch on disk does not prove the loaded native table changed.

## Scene-local task completion routes

Runtime `20261103-task-routes-1` adds the optional schema-3 node field `task_completion_routes`. It maps a **named participant role**, then an **exact registered task ID**, to a destination scene ID:

```json
"task_completion_routes": {
  "feeder": {
    "vampire_feeding": "vampires.release_bite"
  },
  "assistant": {
    "spell_charge": "magic.charged_pose"
  }
}
```

These roles must exist in the originating node. The map keys are task identifiers, not their optional completion-event labels. Definitions, identifiers, roles and destinations belong entirely to content. No particular task name, body type, actor index or controlled/NPC status has built-in routing behavior. Different scenes may map the same role/task to different destinations.

A participant's actual completion selects the entry for that participant's bound role. Another participant with the same body cannot use it. The resulting destination changes the entire fixed scene roster. Destinations can be regular loops or one-shot transitions; a transition then follows its existing `destination` and shared-clock timing rules.

All task completions in the update are committed first: counters reset, generic `task_completed` events queue, and definition-level completion actions run as before. Then the engine selects at most one matching route and enters the existing prepared-node handoff. Task state, completion counts, selected playback speed, fixed membership, original outfits and independently retained resources survive. This adds routing after completion; it does not defer the task reset/event/sound to an animation marker.

When several routes qualify in one update, the first by lexicographic role ID, task ID and participant ID wins, independent of participant iteration order. Every completion still occurs; other route requests are not queued for playback later in an unrelated scene. This is a deterministic shared-scene arbitration rule, not a priority based on body type. A self-route to a loop can explicitly restart that loop through the same handoff. Task-route cycles require new completions, unlike invalid automatic `transition.destination` cycles.

Candidate routes capture session ID, originating node/revision, participant ID/role, task ID and completion index. Stale candidates and requests during preparation, stopping, ended sessions or transition nodes cannot navigate. Transitions already freeze all task progression and decay, so there are no new task completions there.

The destination must preserve all named roles and their requirements. Missing/incompatible runtime destinations disable only the affected route and warn; an unavailable task registration also disables only its route. The current scene remains usable. Strict source validation rejects malformed role/task/target maps and incompatible known destinations before generated output changes; independent-pack references can be deferred to runtime discovery.

If destination resource loading fails for a valid route, the completed task remains completed/reset and the source loop continues. The route is not retried every frame; a later genuine completion may try again. The UI reports the automatic scene load failure, and native diagnostics identify role, task, source and target. All resources are loaded before the held outgoing pose/lifecycle is changed.

`SceneZOI.Events` exposes `task_route_selected` and `task_route_failed` snapshots. Their `task_route` property contains `session_id`, `source_node_id`, `source_revision`, `participant_id`, `participant_role`, `task_id`, `completion_index` and `target`. A selected event means resources loaded and handoff was selected; normal preparation/lifecycle failure can still occur afterward. Independent add-ons receive these copied details through `SceneZOI.API.Event`; the retired packed client bridge is removed.

Diagnostics now identify node/revision at playback entry and print selected/failed task routes, supporting read-only verification of automatic navigation. This tier does not implement an animation-marker system or pending climax state. Authors can supply completion animations as ordinary data-defined transition nodes without executable content-pack code.

## Accepted task-routing checkpoint

On 2026-11-03 the author accepted the reused-asset male task-completion route in-game. Read-only diagnostics corroborated the selected role/task destination, transition arrival, automatic idle arrival, one completion sound, zero reported attachment clock error and clean Exit. Task values were not logged per frame; freeze behavior remains covered by automated regressions. Both temporary HZoi nodes and their idle/profile references were removed on request. Generic routing to looping or transition scenes and all regression fixtures remain. Other roles, larger rosters and failure cases retain isolated coverage rather than a new live acceptance claim.

## Procedural completion responses

Runtime `20261103-completion-effects-1` adds optional scene-local `movement_timing` and `completion_responses` data. Existing completion reset/events/sounds remain independent. Authored routes have priority; otherwise content may enable a synchronized slowdown, a general fallback without timing, and independently owned bone oscillation. See [complete JSON authoring and clock/cleanup rules](completion-effects.md).


## Slow-motion audio policy (20261103-audio-slowmotion-1)

For native game time strictly between 0 and 1, SceneZOI audio keeps its normal 1x pitch/playback rate. This covers voices, continuous/contact SFX and completion one-shots, regardless of the control causing slow motion. Pause still pauses audio; native fast-forward retains existing pitch bounds. Scene animation speed never retimes audio. Clip timers use actual audio rate, so clips can finish while animation is still moving slowly. Contact cooldowns and authored gaps retain existing game-time scheduling.


## Completion voice bindings

Scene-local `task_completion_voices` rules can make the completing participant or another named participant play a response variant from their selected voice set. Responses are independently prioritized, fade the continuous voice and resume it afterward. Task events, sounds, authored routes and procedural effects remain intact. See [voice response authoring](voices.md#task-triggered-one-shot-voice-responses).


## Native audio completion (20261103-audio-finish-1)

The duration/rate estimate is now a lower bound for normal completion, not a forced stop. Once it expires, SceneZOI waits for the native AudioComponent to stop playing before recycling continuous clips, releasing one-shots or resuming normal voice after a response. This protects short tails and newly selected voice sets from audio-thread/startup delay. Pause freezes completion and its watchdog. A two-audio-second observed-wait watchdog bounds broken/looping native components; a long initial asset-loading frame does not consume this watchdog. If native state is unavailable, the existing timer fallback remains. Explicit voice-set changes, response priority fades, navigation, bounded pool stealing and Exit still intentionally stop owned playback.
