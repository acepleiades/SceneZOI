# Transition scenes

Scene schema 3 accepts `kind: "loop"` or `kind: "transition"`. Animation assets themselves need no special transition flag: the scene node determines playback behavior.

## Authoring

A transition uses the same participant, track, outfit, attachment, expression, gaze, voice and SFX fields as a loop. Add a destination and leave navigation empty:

```json
{
  "id": "example.stand_to_bow",
  "label": "Stand to Bow",
  "kind": "transition",
  "destination": "example.bow",
  "duration": 10,
  "fps": 60,
  "participants": {
    "lead": {"body":"male"},
    "partner": {"body":"female"}
  },
  "anchor_participant": "lead",
  "tracks": {
    "lead":"/ExamplePack/Animations/StandToBow_M.StandToBow_M",
    "partner":"/ExamplePack/Animations/StandToBow_F.StandToBow_F"
  },
  "navigation": []
}
```

An ordinary incoming navigation edge can target this ID. A transition cannot declare manual outgoing navigation, a hub identity, or `starting_hub: true`. A loop cannot declare `destination`. The destination must preserve the entire fixed roster and named-role requirements, just like manual navigation. Finite transition chains are supported; self-targets and automatic cycles are rejected. Source-only builds can defer references to independent packs; runtime resolves the combined enabled catalog.

Malformed shape data is rejected by the source/runtime validators. Missing, incompatible or cyclic automatic destinations are isolated before incoming links are exposed. If an otherwise valid destination's assets become unavailable at completion, the session exits with `transition_destination_error` and normal cleanup rather than hanging on a finished clip.

## Timing and handoff

The runtime samples all body and attachment tracks from the existing shared clock. It accumulates animation seconds as:

`elapsed += real_delta_seconds * native_game_scale * scene_speed`

Completion compares accumulated time with the imported clip duration; it does not use a fixed real-time timer or a montage-end callback. At native game scale 1, a ten-second transition takes 20 real seconds at scene speed 0.5, ten at 1, and five at 2. At native scale 3 and scene speed 2 it takes approximately 1.67 real seconds, plus any preparation time. Changing either rate mid-transition affects the remaining playback without resetting elapsed time. Game pause freezes the transition.

Unlike loops, transition sample time is clamped near the final pose and never uses modulo wrap. A small duration-relative tolerance avoids seeking a paused native montage exactly to a boundary that could retire it. After the full duration has elapsed, the final outgoing pose is held while the destination loads/prepares through the existing handoff lifecycle. The destination starts at zero once ready. Extra time from the crossing frame is not carried into the destination, so arrival never skips its opening frames.

Scene speed, participant identities, the session anchor, original outfits/restoration state, task progress and independently retained resources survive the handoff. No game animation instance is replaced, and only owned playback is stopped at Exit. The completed transition cannot restart because of a frame update or duplicate navigation packet.

Manual navigation is blocked in both the controls UI and runtime for the entire transition. Stale/forged navigation is acknowledged as `navigation_locked` without changing the node. Speed controls and Exit remain available. Existing outfit preparation can hold the transition at its current sample and resume without a clock reset. Preparation time does not advance animation time.

## Task and audio behavior

Every task value and completion counter freezes during a transition, regardless of whether its data declares positive, negative or zero rates, or omits the task. Automatic decay is also paused. This is an engine rule for the scene kind, rather than a per-task author workaround. Values resume their destination behavior only after that node is ready.

This does not pause the native game clock or all sound. Existing scene-directed voices/SFX follow their normal node lifetime, and retained task-completion one-shots follow their existing game-time/pause rules. No new task completion is generated while progress is frozen.

## Events and public state

The existing lifecycle events cover arrival/preparation/departure. A transition additionally queues `transition_completed` once when its playback duration is reached, before preparing its destination. The B1 event snapshot includes `node_kind` and `destination` as well as existing session/node identity, revision and participants. The event means the clip finished; destination asset failure can still cause a later session exit. Existing native event packet fields remain compatible, and clients can obtain kind/destination from the public catalog.

## Validation boundaries

Isolated checks cover source/runtime schema, missing/incompatible destinations, finite chains and cycles, repeated-body roles, all four scene speeds, native-time changes, pause, large frame overshoot, clamped body/attachment samples, all-task freeze, server/UI navigation lock, final-pose hold during delayed preparation, automatic arrival, retained speed/roster, task resumption, duplicate prevention, early Exit and failed-destination cleanup. These are not an authored live choreography acceptance claim. See `validation.json` for current native installation/acceptance status.

## Accepted reused-asset checkpoint

On 2026-11-03 the author confirmed the temporary HZoi transition worked perfectly. A read-only Lua-log review corroborated two transition-to-rear sequences, zero reported attachment clock discrepancy and clean Exit; task values were not logged frame by frame. The test scene, idle edge and profile track mapping were subsequently removed at the author's request. Generic transition support and isolated regression coverage remain. Purpose-authored transition choreography still awaits future assets.

## Task-triggered entry

A loop can use scene-local `task_completion_routes` to enter a transition after a named role completes a registered task. The full roster uses the destination; completion reset/events/actions occur before the handoff, and task state then freezes for the transition. See [the mapping, arbitration and failure rules](scene-tasks.md#scene-local-task-completion-routes).
