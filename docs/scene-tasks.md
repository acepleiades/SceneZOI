# Add progress and completion to a scene

<a id="scene-tasks"></a>

A task gives a Zoi a meter that can fill, decay and complete. Use the shared
**Excitement** task for sexual scenes, with rates and effects chosen for each
activity. Other encounters can define their own tasks: a vampire feeding scene
could track Feeding on the vampire and Blood Depletion on the target.

SceneZOI handles progress and completion events. Your scene chooses the rates,
caps, sounds and visual responses; a gameplay mod decides consequences such as
payment or what happens to a drained target.

## Use the shared Excitement task

Add this fragment to a scene with `male` and `female` roles:

```json
"tasks": {
  "male": {"excitement": {"rate": 1, "cap_percent": 100}},
  "female": {"excitement": {"rate": 0.5, "cap_percent": 50}}
}
```

You do not need to redeclare `excitement`. SceneZOI supplies its maximum of 90,
initial value of zero, decay of 1 and `orgasm` completion-event label. At default
task-rate settings and Normal game speed, the male role gains one point per
second and can complete. The female gains half a point and stops gaining at
50%; she cannot complete from zero in this scene. For mutual completion, allow
both roles to reach 100%.

Completion resets the meter and emits `task_completed`. It does not create
orgasm animation, voices or gameplay outcomes by itself. Add the appropriate
[scene effects](completion-effects.md), [completion sounds](#play-a-completion-sound-in-one-scene)
or [voice responses](voices.md#task-triggered-one-shot-voice-responses).
Gameplay add-ons can [read and control task progress](addon-controls.md#live-controls).

## Check progress in game

Start the scene and watch each meter. Try another activity with different rates,
then an idle where the task is omitted: progress should decay there. A rate of
zero holds it instead. Navigate without exiting and confirm progress carries
over. Try game pause and fast-forward; those controls affect progression, while
the scene animation-speed selector does not.

If a meter is absent, check the role and exact task ID, whether its value is
zero and decaying, and any declaration warnings in `scenezoi_runtime`. To debug
effects, reach an actual completion; the displayed percentage resets afterward.

## Complete content-pack example

SceneZOI’s shared [Excitement definition](../packs/scenezoi/tasks/excitement.json)
sets the maximum and decay. [Standing Handjob](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/02_standing_hand_job.json)
defines per-role progression and caps. [Standing Rear](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/04_standing_rear.json)
adds a scene-local one-shot, a reaction from the selected voice set, a timed
slowdown, and independent leg shakes. Another pack can reuse the task and
choose its own completion presentation.
[Why these effects are separate](https://github.com/acepleiades/HZoi-Reference/blob/main/docs/authoring-walkthrough.md#give-task-completion-a-visible-or-audible-result)

## Register a definition

Add an entry to a pack manifest's `data_files`:

```json
{"kind":"scene_task","file":"example/tasks/feeding.json"}
```

Only define a new task when its meaning differs from an existing one. This
complete definition describes the vampire's Feeding meter. A separate Blood
Depletion meter needs its own definition, for example `vampires.blood_depletion`.
Completing either task does not automatically kill or change a Zoi.

```json
{
  "schema_version": 1,
  "id": "vampires.feeding",
  "label": "Feeding",
  "maximum": 90,
  "initial": 0,
  "decay": 1,
  "completion_event": "vampires.fed",
  "display": {
    "visible": true,
    "color": "#3185c3",
    "track_color": "#bfbfbf",
    "text_color": "#222222",
    "body_colors": {"female":"#df85ac", "male":"#3185c3"}
  },
  "metadata": {"category":"vampire_feeding"}
}
```

Identifiers are exact, case-sensitive identifiers: lowercase ASCII letters, digits, underscores, dots and hyphens, starting with a letter, up to 96 characters. Prefix independent authors' IDs where practical. Scene references must match the registered ID exactly. Labels are nonempty text, up to 160 UTF-8 bytes. `maximum` is required, finite and between 0.001 and 1,000,000,000. `initial` defaults to 0 and must be within 0–maximum. `decay` defaults to 0 and is a nonnegative units-per-game-second rate, at most 1,000,000. `completion_event` is optional. `metadata` is an optional inert JSON object copied into completion payloads; it cannot contain executable callbacks.

All display settings are optional. `visible: false` suppresses indicators without disabling progression/events. Colors accept `#RRGGBB` only. `body_colors` optionally overrides the fallback ring color for the framework's existing appearance-body traits; those colors have no gameplay meaning. Without presentation data, the framework uses its neutral palette.

The builder turns these source files into your pack's native declarations.
Build, package and install the pack, then restart inZOI; editing a loose JSON
file beside an installed mod does not update the loaded definitions. Active
sessions keep the library they captured at entry.
[Declaration packaging](package-split.md#native-declarations-and-author-builds)

### Choose which definition a scene uses

SceneZOI resolves each task ID in this order.

1. The current scene’s content pack, if it defines the task ID.
2. SceneZOI’s shared definition, if it has one.
3. The provider named by the scene in `task_providers`.
4. If no provider is named, the first pack ID alphabetically among the packs
   that define the task.

The pack ID is the internal identifier, independent of load order or the
mod that started the session. If the lookup reaches a named provider and it
is missing, the task is unavailable in that scene. When definitions disagree,
`scenezoi_runtime/mod_inventory.cfg` lists the providers and the fallback winner.

For example, suppose the `alpha` and `beta` packs both define `training.focus`.
Their own scenes each use their own definition. If SceneZOI has no definition
for that ID, a third pack’s scene can select Beta with
`"task_providers": {"training.focus": "beta"}`. With no named provider it uses
Alpha because `alpha` sorts first.

Each participant keeps one meter and completion count per task ID for the
session. This applies to manually started sessions and sessions started
through the API, with or without an autonomous goal. If a new scene changes
the maximum from 100 to 200, 40% carries over as 80 points. The destination's
rate and decay apply, and its cap limits further gains.

A scene change alone does not complete a task. A carried full meter waits for
a playing scene that permits completion. If the current scene cannot resolve
the task's definition, its meter stays parked until a later scene resolves it.
API calls and completion events use the same task ID across packs.

SceneZOI provides a shared `excitement` definition with the existing
`orgasm` completion-event identifier. HZoi and other packs can attach
their own effects to that task in their scene JSON. A malformed task is
isolated at runtime. The authoring build rejects conflicting definitions
within a single pack.

Two tasks can display the same label. Give independent tasks pack-prefixed IDs
such as `training.focus` and `meditation.focus`. When packs intentionally share
an ID, coordinate the definition and keep pack-specific effects on the scenes
that need them. The resolved definition governs the current scene.

See [shared declarations and conflicting IDs](authoring.md#shared-declarations-and-conflicting-ids)
for how to coordinate a shared task with another pack author. You can discuss
shared tasks and ask other developers for help in the
[OStim/SceneZOI Community Discord server](https://discord.gg/RECvhVaRcU).

## Per-scene progression

The shared Excitement example above uses the same format as a custom task.
For a feeding scene with `vampire` and `target` roles, this fragment progresses
the registered Feeding task and holds the target's progress on that same task:

```json
"tasks": {
  "vampire": {"vampires.feeding": {"rate": 1, "cap_percent": 100}},
  "target": {"vampires.feeding": {"rate": 0}}
}
```

If the target should accumulate Blood Depletion, register that separate task
and reference it on `target` instead. The rates are points per game second,
not percentages per second.

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

Participant IDs own progress and completion counts for the session. Navigation keeps that state. Exit discards it, and a new session initializes from the definition. Task progress belongs to the current session; it is not saved as a Zoi personality choice.

## Completion and subscriptions

Reaching maximum records a completion, resets value to zero, and queues `task_completed` through the existing `SceneZOI.Events` dispatcher. The engine emits at most one completion per participant/task/update; excess units from that update are discarded so reset means zero, including after a long frame. There is no terminal latch: subsequent progress can complete again. An initial value equal to maximum completes on the first positive-time playing update.

Core state is committed before observers run. Each observer gets an independent plain snapshot; observer exceptions are isolated. Excess notifications beyond the per-flush delivery budget remain queued for the next flush instead of being dropped. `completion_index` increases independently for each participant/task; combine it with session ID, participant ID and task ID for an idempotent external consequence key.

Independent gameplay add-ons use the public SDK. In the client created by
[Wire the SDK](addon-authoring.md#wire-the-sdk), inspect task completions in
its `event` callback, and subscribe once the connection is ready:

```lua
-- Reuses client, request and owner from the add-on guide's SDK setup.
request(owner, "subscribe", {
    scope = "all",
    events = {"task_completed"},
})
```

`scope = "all"` observes scenes started by other mods and the manual picker too.
Filter by the sessions your gameplay concerns. The callback receives copied
participant and task details, rather than native actors or mutable task state.
Use session ID, participant ID, task ID and completion index together to avoid
applying a consequence twice. Use `get_session` for current `task_progress`.
See [the API reference](addons.md) for event envelopes and subscriptions.

The B1 completion payload includes existing session ID (`id`), node ID, revision, phase, participant roster, speed state and event index, plus:

```json
{
  "participant_id":"12345",
  "participant_role":"male",
  "task": {
    "id":"excitement",
    "label":"Excitement",
    "value":90,
    "maximum":90,
    "percent":100,
    "completed":true,
    "completion_index":1,
    "completion_event":"orgasm"
  }
}
```

Use `get_session` to read copied current `task_progress`. The completion event
reports the attained maximum, while current progress has already reset to zero.
A task without a `completion_event` label still emits `task_completed`. Without
configured responses or routes, completing it does not play media, navigate or
apply gameplay consequences.

## Tray and layout

The Scene Tasks tray appears beside the main panel. Each row shows the Zoi,
task label, progress ring and whole percentage rounded down. Rows scroll if
needed. A zero-valued omitted or decreasing task disappears; a task explicitly
increasing or held stays visible. `display.visible: false` hides a task's meter
without disabling its progression or events.

## Data-defined completion sounds

Keep a pack-specific completion sound on the scenes that should play it. Put
vocal reactions in [voice responses](voices.md#task-triggered-one-shot-voice-responses)
so they use the Zoi's chosen voice and volume control.

### Play a completion sound in one scene

Add a rule under `task_completion_sounds` for the role and task that trigger
the sound. You can supply a `clip` path or a `sound_set` ID with default clips
from a [sound set](sfx.md#data). The source follows the completing Zoi.

```json
"task_completion_sounds": {
  "male": {
    "excitement": [{
      "type": "play_sound",
      "sound_set": "designer.ejaculation",
      "source": {"component": "body", "bones": ["pelvis"]}
    }]
  }
}
```

Declare `designer.ejaculation` in your manifest's `sound_sets` with its actual
clip paths, or use `clip` to reference a SoundWave directly. HZoi uses this
scene-local approach so its ejaculation sound does not appear in another pack's
scenes simply because they share Excitement.

A scene rule takes precedence over the task-wide `on_completion` list
for that role and task. An empty list silences the task-wide action in that
scene. When a role has no scene-level rule, the definition’s completion sound applies.

### Define a sound for every use of a task

A task definition can declare `on_completion` actions when every use of
that definition should get the cue. This example is a field
inside a task definition; replace the clip path with your own SoundWave.
Completion and progress reset still occur if the optional sound fails.

```json
"on_completion": [
  {
    "type": "play_sound",
    "when": {"body": "male"},
    "clip": "/ExamplePack/Audio/Completion.Completion",
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

This task-wide facility plays completion audio on any matching scene using the definition. Persistent gameplay outcomes and other definition-level action types remain separate. Scene-level voice bindings, routing and procedural effects are implemented independently below. Content still ships no executable code. Native JSON declaration changes require normal package activation; replacing a JSON patch on disk does not prove the loaded native table changed.

## Scene-local task completion routes

Use `task_completion_routes` when completion should enter another animation.
For example, move a sexual scene into an authored orgasm transition, or make
a vampire release the bite after feeding. Add this field to the source scene;
its destination scenes must exist in the installed pack:

```json
"task_completion_routes": {
  "vampire": {
    "vampires.feeding": "vampires.release_bite"
  }
}
```

Use the exact role and task IDs from the source scene. For example, the
route above listens for `vampires.feeding`, not its `vampires.fed` event label.
Another scene can route completion of the same task to a different destination.

Completion uses the completing Zoi's role. Both regular loops and one-shot
transitions can be destinations; a transition then follows its own `destination`.

All completions in an update reset progress and emit their events first.
Then SceneZOI selects at most one route and prepares its destination, retaining
task state, completion counts, speed and original restoration state. This route
starts after completion, rather than waiting for a particular animation frame.

If several routes qualify together, the first by sorted role ID, then task ID,
then participant ID wins. Every completion still occurs; other routes are not
queued for later. A route can restart its own loop. Returning through task
routes requires new completions, unlike an invalid automatic transition cycle.

A route changes the scene for the whole roster. Keep every role and its
requirements compatible with the destination. Missing tasks or incompatible
destinations disable the affected route with a warning; the current scene can
still play. If destination assets fail to load, the task stays completed/reset
and the source loop continues. A later completion can try the route again;
the failed one is not retried every frame.

Gameplay add-ons can observe `task_route_selected` and `task_route_failed`.
Their copied `task_route` details identify the session, source node/revision,
participant/role, task, completion index and target. Selection confirms that
resources loaded and the handoff was chosen, rather than guaranteeing the
destination finished preparing. Use normal lifecycle events for that result.
[API events](addons.md)

For an authored orgasm animation, use a [transition](transitions.md) as the
destination. For slowdown and shaking over the current loop, use
[procedural responses](completion-effects.md) instead. A qualifying authored
route takes priority over those procedural effects.

## Procedural completion responses

Use scene-local `movement_timing` and `completion_responses` to animate a response when a task completes. Existing completion reset/events/sounds remain independent. Authored routes have priority; otherwise content may enable a synchronized slowdown, a general fallback without timing, and independently owned bone oscillation. See [complete JSON authoring and clock/cleanup rules](completion-effects.md).


## Completion voice bindings

Scene-local `task_completion_voices` rules can make the completing participant or another named participant play a response variant from their selected voice set. Responses are independently prioritized, fade the continuous voice and resume it afterward. Task events, sounds, authored routes and procedural effects remain intact. See [voice response authoring](voices.md#task-triggered-one-shot-voice-responses).
