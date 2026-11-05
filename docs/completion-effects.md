# Task completion responses

Scene schema 3 supports generic scene-local visual completion responses. Content packs supply identifiers, timing and bone names as inert JSON; SceneZOI owns execution and cleanup. Task completion still resets progress, emits its normal event and executes definition-level completion sounds. These responses add no gameplay consequences or meaning to a task identifier.

## Complete content-pack example

HZoi-Reference's [movement timing and response block](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/02_standing_hand_job.json#L148)
uses one cycle per second and peak phase 0.5. The male role requests shared
slowdown plus its own shake; the female role requests only its own shake. Its
[task rates](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/02_standing_hand_job.json#L134) cap female progress at 50%, so that authored
response does not imply she completes from zero in this node. Compare
[the rear scene](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/04_standing_rear.json#L147), where both roles can reach 100%.
These adult-content examples are inert data; the
[worked guide](content-examples.md) explains their scope and independent ownership.

## Response priority

For each completion update, commit every participant's completion first. If any valid scene-local `task_completion_routes` entry matches, select the existing deterministic authored route and bypass procedural responses for that update. The destination may be a loop or a transition. If a selected route fails to load, report its failure; do not silently substitute a procedural response.

Otherwise, match `completion_responses[participant_role][exact_task_id]` to the actual completing participant. `enabled: true` explicitly opts into the supplied effects. With movement timing, a configured slowdown synchronizes to it; without timing it uses its general fallback. An omitted/disabled response causes no visual change. A shake-only response does not slow playback. Multiple tasks and any supported fixed roster, including repeated body types, use the same rules. Unknown task IDs are diagnosed and isolated at discovery. Strict source/runtime validation rejects malformed fields, unsafe values and response declarations on transition nodes.

```json
"movement_timing": {"cycles_per_second": 1, "peak_phase": 0.5},
"completion_responses": {
  "caster": {
    "spell_charge": {
      "enabled": true,
      "slowdown": {
        "repeats": 2,
        "high_speed": 0.5,
        "low_speed": 0.08333333333333333,
        "recovery": 0.4,
        "fallback_duration": 6
      },
      "shake": {
        "delay": 0.5,
        "duration": 3,
        "bursts": 1,
        "duty_cycle": 1,
        "frequency_hz": 18,
        "amplitude_degrees": 1.25,
        "bones": [
          {"bone":"upperarm_l", "child":"lowerarm_l", "weight":1},
          {"bone":"lowerarm_l", "child":"hand_l", "weight":0.4}
        ]
      }
    }
  }
}
```

Bone names in this example are rig-specific. The role and task must be declared normally. These optional fields extend existing schema-3 scene JSON, not the task definition or simulation-side outfit snapshot. Existing scenes need no changes.

## Regular movement timing

`cycles_per_second` describes the consistent underlying movement in the exported clip at default playback speed, even when slower gestures or pose changes are layered into that clip. It is within 0.001–60; clip duration times frequency must be a positive whole number, so the uniform rhythm repeats at the clip seam.

`peak_phase` defaults to 0.5, within 0–1. It names the pose around which the lowest-speed hold is centered. For a one-second cycle authored at 60 fps, phase 0.5 is frame 30; phase 0 and 1 describe the same repeating endpoint. Cycle response boundaries are half a period before/after each peak. The engine waits for the next response boundary at normal selected playback speed before starting its envelope. It does not seek or jump the clip.

Slowdown uses linear speed ramps in effect time. With default high/low values, a one-second authored cycle takes four effect seconds: 1.6 seconds to slow from 0.5 to 1/12, 0.8 seconds at 1/12, and 1.6 seconds to return to 0.5. The central pose is reached halfway through the low-speed hold. Two repeats therefore traverse two authored seconds over eight effect seconds, followed by recovery. This reproduces the reference envelope while avoiding frame-step drift through exact integration. No animation assets are generated.

## Uneven movement timing

For a rhythm that changes during a loop, replace frequency/phase with explicit equivalent peak-pose times in the original clip:

```json
"movement_timing": {"peak_times": [0.3, 1.1, 2.7]}
```

For a four-second clip, these are three authored peak moments. Markers must strictly increase, be within `[0, duration)`, and number 1–4096. Do not repeat the clip endpoint. Frequency and markers are mutually exclusive. Response boundaries lie halfway between neighboring peaks, including across the loop seam. Each side's ramp/hold duration adapts to its actual distance to the peak, so unequal intervals still put the lowest-speed hold around the authored pose. This supports changing cycle spacing; its visual quality still depends on meaningful markers. It does not infer physical contacts from bones.

## General fallback and settings

Omit `movement_timing` while supplying `enabled: true` and `slowdown` to permit the fallback. It uses 40% of `fallback_duration` to ramp high-to-low, 20% to hold and 40% to ramp back, then recovers to normal selected speed. It cannot promise alignment to a pose. `repeats` is used only for synchronized cycles; fallback duration is the complete envelope duration.

| Slowdown property | Default | Valid range |
| --- | --- | --- |
| `repeats` | 3 | Integer 1–32 |
| `high_speed` | 0.5 | 0.001–1 |
| `low_speed` | 1/12 | 0.001–high_speed |
| `recovery` | 0.4 seconds | 0.001–30 |
| `fallback_duration` | 6 seconds | 0.01–300 |

The multiplier applies over the user's selected scene speed. Effect time advances by native game time times that selected speed, without multiplying by the effect's own slowdown. Thus a speed change during the effect changes its remaining duration while preserving its authored phase. At scene speed 1 and native scale 1, the example two-repeat envelope lasts eight seconds plus synchronization wait and 0.4 recovery; scene speed 2 traverses that envelope twice as fast. Game pause freezes it; native fast-forward scales it. Body and independently owned attachment tracks keep the same shared sampled time. Task progression and audio remain on their existing native-game clocks and are not slowed by this animation multiplier.

## Generic shaking

The shake starts after its own game-time delay, independently of synchronization wait and playback slowdown. It applies sinusoidal local rotations with a triangular fade-in/out envelope per burst. Each burst spends `duty_cycle` of its interval shaking and the rest at zero correction. It uses native game time, not scene animation speed or the slowdown multiplier. Pause freezes the current shake pose.

| Shake property | Default | Valid range |
| --- | --- | --- |
| `delay` | 0.5 seconds | 0–30 |
| `duration` | 6 seconds | 0.01–300 |
| `bursts` | 3 | Integer 1–64 |
| `duty_cycle` | 0.7 | 0.001–1 |
| `frequency_hz` | 18 | 0.001–60 |
| `amplitude_degrees` | 1.25 | 0–45 |
| `bones` | Required | 1–64 unique bone entries |
| Bone `weight` | 1 | -2–2 |

Each bone entry requires `bone` and its direct `child`. Their local longitudinal axis defines the twist. Weight controls signed intensity, allowing a counter-moving opposite side. Reference-like leg profiles use upper/lower/foot weights 1, 0.4 and 0.05, with opposite-side weights multiplied by -0.8. Twisting minimizes positional disturbance; this is not a foot-locking IK solver and cannot guarantee planted contacts for every rig/pose.

The B1 adapter appends owned `FB1AdditiveBoneData` rows to the existing body's post-process `AdditiveBones`, using additive zero scale/translation and local quaternion corrections. It does not replace the main animation instance, clear native body fitting or modify the facial array. Copied corrections on appearance rebuilds are adopted; only recorded entries are updated/removed. Transient missing post-process instances wait for a later sample; unsupported/missing bones warn and retire that optional shake with cleanup retries. Completion, sound and scene playback continue independently.

## Concurrency, lifetime and diagnostics

All completions remain independent. One shared slowdown may be active at a time. Simultaneous eligible requests are sorted by role/task/participant ID, using the same stable convention as authored routes. Other participants still receive their own shaking. A later completion during an existing slowdown does not stack or queue another slowdown. Each participant owns at most one shaking response; a new completion restarts that participant's shake after releasing its previous correction. Completion indices suppress duplicate requests.

Outfit preparation freezes effect clocks and preserves ownership through body changes. Navigation cancels the slowdown and shaking; selected speed and session task progress remain. Exit releases every owned correction, retrying partial cleanup through the normal subsystem lifecycle. Transition nodes retain their existing all-task freeze and do not start these responses.

`Runtime.snapshot().completion_effects` exposes plain diagnostic state: `stage`, `source` (last participant/task key), `starts`, `shaking_participants`, and optional last `error`. It contains no mutable native objects. Independent add-ons use [version-1 session/task events and get_session](addons.md); visual responses do not redispatch completion. Logs include slowdown start/finish and heartbeat status with the current integrated speed factor and shake-owner count. This is scene-local presentation; gameplay mods should subscribe to the normal task-completion API for consequences.

Isolated checks cover exact reference timing/phase, uneven markers and seam wrapping, fallback, frame-size invariance, pause/native/user speed changes, repeated/simultaneous/group completions, body/attachment synchronization, route priority, local bone axes, copied/rebuilt arrays, partial mutations and independent retryable cleanup. Native API metadata and ModKit validation establish the exposed surface; first in-game visual acceptance of body shaking remains separate and must be recorded in validation reports.
